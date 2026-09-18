#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG_COMMIT=43ff77f832bd188a5a6e740cd1dd5b6ab30b5d0f
PREREG=integration/f-rom/F-ROM0TA5_PREREGISTRATION.json
TA3_RESULT=integration/f-rom/F-ROM0TA3_RESULT.json
TEST=tests/rom/test_f_rom0ta5_prescribed_head_sample.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-f-rom0ta5-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM0TA5_EVIDENCE_DIR:-$ROOT/F-ROM0TA5_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM0TA5_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "TA5 preregistration is not ancestor"
mapfile -t SRC_DELTA < <(git diff --name-only "$PREREG_COMMIT"...HEAD -- src)
[[ "${#SRC_DELTA[@]}" -eq 1 && "${SRC_DELTA[0]}" == "src/runtime/mod_fmr_serialized_reference_backend.f90" ]] || {
  printf 'F_ROM0TA5_SOURCE_DELTA=%s\n' "${SRC_DELTA[*]:-NONE}" >&2
  fail "TA5 source allowlist"
}
git diff --quiet "$PREREG_COMMIT"...HEAD -- reference || fail "TA5 reference tree changed"
grep -Fq '(parameters%bottom_mode /= 2 .and. parameters%bottom_mode /= 5)'   src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "mode2/mode5 sample admission guard missing"
echo "F_ROM0TA5_SOURCE_SCOPE=PASS"
echo "F_ROM0TA5_REFERENCE_TREE_IMMUTABLE=PASS"

python3 - "$PREREG" "$TA3_RESULT" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
r=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_SOURCE_MUTATION"
assert p["source_scope"]["allowed_production_file"]=="src/runtime/mod_fmr_serialized_reference_backend.f90"
assert p["source_scope"]["kernel_reference_floor_sample_core_change_allowed"] is False
assert p["source_scope"]["transaction_core_change_allowed"] is False
assert p["source_scope"]["reference_solver_change_allowed"] is False
assert p["rom1a_authorized"] is False
assert r["implementation"]["new_tx_temporal_mode"] is False
assert r["implementation"]["canonical_interval_runtime_changed"] is False
assert r["implementation"]["reference_or_solver_source_changed"] is False
assert r["sample_invariants"]["successful_sample_count"] > 0
print("F_ROM0TA5_PREREGISTRATION_AND_TA3_AUTHORITY=PASS")
PY

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/rom0ta5_stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/rom0ta5_stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "TA5 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM0TA5_ROW|MATERIAL=B01|MODE=MODE2|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B01 mode2 O$opt"
  grep -Fq 'F_ROM0TA5_ROW|MATERIAL=B01|MODE=MODE5|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B01 mode5 O$opt"
  grep -Fq 'F_ROM0TA5_ROW|MATERIAL=B14|MODE=MODE2|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B14 mode2 O$opt"
  grep -Fq 'F_ROM0TA5_ROW|MATERIAL=B14|MODE=MODE5|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B14 mode5 O$opt"
  grep -Fq 'F_ROM0TA5_PRESCRIBED_HEAD_SAMPLE_GATE=PASS' "$EVIDENCE/o$opt.txt" || fail "TA5 gate O$opt"
done
cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "TA5 O0/O2 output drift"

# Fail-closed solver/mass semantics are inherited unchanged from the TA3 kernel
# sample core. TA5 is allowed to change only the FMR admission guard.
git diff --quiet "$PREREG_COMMIT"...HEAD -- src/kernel/mod_kernel_transactions.f90 || fail "kernel sample core changed"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src/transaction/mod_transaction_reference.f90 || fail "transaction core changed"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src/runtime/mod_canonical_interval_runtime.f90 || fail "canonical interval runtime changed"
git diff --quiet "$PREREG_COMMIT"...HEAD -- src/adapter/mod_reference_richards_legacy_binding.f90 || fail "Reference solver binding changed"
echo "F_ROM0TA5_TA3_FAIL_CLOSED_SAMPLE_CORE_PRESERVED=PASS"
echo "F_ROM0TA5_ORDINARY_RUNTIME_CORE_UNCHANGED=PASS"

sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" > "$EVIDENCE/sha256.txt"
git diff --check "$PREREG_COMMIT"...HEAD
echo "F_ROM0TA5_DIFF_CHECK=PASS"
echo "F_ROM0TA5_CAPABILITY_GATE=PASS"
