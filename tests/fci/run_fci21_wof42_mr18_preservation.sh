#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci21-wof42-mr18-$$"
BASE="ed0219402072f121856d82cb6068ab74c70f34d1"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() {
  echo "FCI21_WOF42_MR18_PRESERVATION_FAIL $*" >&2
  exit 1
}

phase="${1:-all}"

check_blob() {
  local path="$1" expected="$2" label="$3"
  local actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || fail "$label blob drift expected=$expected got=$actual"
}

# F-CI21 may differ from the exact F-WOF42 base only on the frozen temporal
# production closure. Preservation-only commits below this point may add tests,
# workflows and evidence, never additional src changes.
cat > "$BUILD/expected-src-delta.txt" <<'EOF'
src/adapter/mod_reference_richards_legacy_binding.f90
src/runtime/mod_canonical_contracts.f90
src/runtime/mod_fmr_runtime_core.f90
src/runtime/mod_fmr_serialized_reference_backend.f90
src/solver/mod_fixed_flux_top_boundary_provider.f90
src/solver/mod_reference_richards_temporal_indicator.f90
src/solver/mod_soil_water_solver_contract.f90
src/transaction/mod_fkt_temporal_indicator_history.f90
EOF
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src-delta.txt"
diff -u "$BUILD/expected-src-delta.txt" "$BUILD/actual-src-delta.txt" || fail "production delta no longer equals frozen F-CI21 temporal closure"
echo 'FCI21_WOF42_MR18_PRODUCTION_DELTA_LOCK=PASS'

# Freeze the historical qualification runners and both F-MR18 production
# surfaces before translating only obsolete branch-lineage checks.
check_blob tests/fwof/run_fwof42_crop_persistence_layout_gate.sh a20d69e9d0274c824d01102a223b97d1754d3010 fwof42_runner
check_blob tests/fmr/run_fmr18_accepted_commit_receipt_gate.sh 21363a2e30e30a7e2803b0f0ead72f2890674b4f fmr18_ab_runner
check_blob tests/fmr/run_fmr18_multiswap_receipt_gate.sh 729b5e679420f7e7e3badb3f092c029f3b5992c6 fmr18_c_runner
check_blob src/runtime/mod_fmr_accepted_commit_receipt.f90 6798b3296b426950bf028814585c3f5de9be950b fmr18_receipt_module
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 6559237c887e9a8476beb479546becdfe9339920 fmr18_multiswap_runtime
echo 'FCI21_WOF42_MR18_AUTHORITY_AND_PRODUCTION_BLOB_LOCK=PASS'

run_wof42() {
  bash tests/fwof/run_fwof42_crop_persistence_layout_gate.sh | tee "$BUILD/fwof42.out"
  grep -Fq 'FWOF42_CROP_PERSISTENCE_LAYOUT_COMPLETENESS_GATE PASS' "$BUILD/fwof42.out" || fail "F-WOF42 final marker missing"
  grep -Fq 'FWOF42_EXTERNAL_REPRESENTATION_O0_O2_IDENTITY=PASS' "$BUILD/fwof42.out" || fail "F-WOF42 O0/O2 marker missing"
  grep -Fq 'FWOF41_PRODUCTION_OWNER_PERSISTENCE_QUALIFICATION_GATE PASS' "$BUILD/fwof42.out" || fail "F-WOF41 nested owner persistence marker missing"
  echo 'FCI21_FWO42_POSTIMAGE_PRESERVATION=PASS'
}

run_mr18_ab() {
  python3 - tests/fmr/run_fmr18_accepted_commit_receipt_gate.sh "$BUILD/run_mr18_ab.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"\n'
new_root = 'ROOT="${FCI21_ROOT:?FCI21_ROOT not set}"\n'
if src.count(old_root) != 1:
    raise SystemExit(f'F-CI21 MR18 A/B root anchor count={src.count(old_root)}')
src = src.replace(old_root, new_root, 1)
start = src.find('# F-MR18 may add exactly one generic production module at this gate.')
end_marker = "echo 'FMR18_EXACT_ADDITIVE_SOURCE_DELTA=PASS'\n"
end = src.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('F-CI21 MR18 A/B historical source-delta block not found')
end += len(end_marker)
replacement = "# F-CI21 translation: the qualified receipt production blob is locked by the outer replay.\n" \
              "# The historical one-file base..HEAD assertion is intentionally not reinterpreted after materialization.\n" \
              "echo 'FCI21_MR18_AB_POSTIMAGE_LINEAGE_TRANSLATION=PASS'\n"
src = src[:start] + replacement + src[end:]
Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
  chmod +x "$BUILD/run_mr18_ab.sh"
  FCI21_ROOT="$ROOT" bash "$BUILD/run_mr18_ab.sh" | tee "$BUILD/mr18-ab.out"
  grep -Fq 'FMR18_ACCEPTED_COMMIT_RECEIPT_GATE PASS' "$BUILD/mr18-ab.out" || fail "F-MR18 A/B final marker missing"
  grep -Fq 'FMR18_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/mr18-ab.out" || fail "F-MR18 A/B O0/O2 marker missing"
  grep -Fq 'FMR18_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS' "$BUILD/mr18-ab.out" || fail "F-MR18 A/B F-WOF34 transcript marker missing"
  echo 'FCI21_MR18_ACCEPTED_COMMIT_RECEIPT_POSTIMAGE_PRESERVATION=PASS'
}

run_mr18_c() {
  python3 - tests/fmr/run_fmr18_multiswap_receipt_gate.sh "$BUILD/run_mr18_c.sh" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
old_root = 'ROOT="$(cd "$(dirname "$0")/../.." && pwd)"\n'
new_root = 'ROOT="${FCI21_ROOT:?FCI21_ROOT not set}"\n'
if src.count(old_root) != 1:
    raise SystemExit(f'F-CI21 MR18 C root anchor count={src.count(old_root)}')
src = src.replace(old_root, new_root, 1)
start = src.find('cat > "$BUILD/expected-source-delta.txt" <<\'EOF\'')
end_marker = "echo 'FMR18C_EXACT_TWO_FILE_SOURCE_DELTA=PASS'\n"
end = src.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('F-CI21 MR18 C historical source-delta block not found')
end += len(end_marker)
replacement = "# F-CI21 translation: exact MR18 production blobs and the complete F-CI21 src closure\n" \
              "# are locked by the outer replay. Do not reinterpret the historical two-file delta.\n" \
              "echo 'FCI21_MR18C_POSTIMAGE_LINEAGE_TRANSLATION=PASS'\n"
src = src[:start] + replacement + src[end:]

# F-CI21 adds a production dependency to the already-qualified legacy binding.
# Add only the required compile predecessors to Gate C's disposable module list;
# do not change its executable test program or any scientific/transaction oracle.
needle = "  src/legacy/b1_10_port/headcalc.f90\n  src/adapter/mod_reference_richards_legacy_binding.f90\n"
replacement = ("  src/legacy/b1_10_port/headcalc.f90\n"
               "  src/solver/mod_fixed_flux_top_boundary_provider.f90\n"
               "  src/solver/mod_reference_richards_temporal_indicator.f90\n"
               "  src/adapter/mod_reference_richards_legacy_binding.f90\n")
if src.count(needle) != 1:
    raise SystemExit(f'F-CI21 MR18 C temporal compile-dependency anchor count={src.count(needle)}')
src = src.replace(needle, replacement, 1)
print('FCI21_MR18C_TEMPORAL_COMPILE_DEPENDENCY_TRANSLATION=PASS')

# Gate C originally nested F-CI19 solely to prove composition preservation on
# its then-current tree. On F-CI21 that historical source-lineage boundary is
# obsolete. Replace only that trailing composition replay with the current
# F-CI21 source/compile gate. All Gate C behavioral, mass-identity, transcript
# and O0/O2 checks above this boundary remain byte-for-byte unchanged.
start = src.find('# Reexecute F-CI19 composition preservation on the current tree.')
if start < 0:
    raise SystemExit('F-CI21 MR18 C nested F-CI19 boundary not found')
replacement = '''# F-CI21 current composition preservation supersedes the historical nested F-CI19 lineage replay.
bash "$ROOT/tests/fci/run_fci21_temporal_materialization_gate.sh" > "$BUILD/fci21-materialization.out" 2>&1 || {
  cat "$BUILD/fci21-materialization.out" >&2
  fail "F-CI21 current materialization gate"
}
grep -Fq 'FCI21_SOURCE_BLOB_LOCK=PASS' "$BUILD/fci21-materialization.out"
grep -Fq 'FCI21_PRODUCTION_SCOPE_GUARD=PASS' "$BUILD/fci21-materialization.out"
grep -Fq 'FCI21_TEMPORAL_COMPILE_O0=PASS' "$BUILD/fci21-materialization.out"
grep -Fq 'FCI21_TEMPORAL_COMPILE_O2=PASS' "$BUILD/fci21-materialization.out"
grep -Fq 'FCI21_TEMPORAL_MATERIALIZATION_GATE PASS' "$BUILD/fci21-materialization.out"
echo 'FMR18C_FCI21_CURRENT_COMPOSITION_PRESERVATION=PASS'
echo 'FMR18_MULTISWAP_RECEIPT_GATE PASS'
'''
src = src[:start] + replacement
Path(sys.argv[2]).write_text(src, encoding='utf-8')
PY
  chmod +x "$BUILD/run_mr18_c.sh"
  FCI21_ROOT="$ROOT" bash "$BUILD/run_mr18_c.sh" | tee "$BUILD/mr18-c.out"
  grep -Fq 'FMR18_MULTISWAP_RECEIPT_GATE PASS' "$BUILD/mr18-c.out" || fail "F-MR18 Gate C final marker missing"
  grep -Fq 'FMR18C_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/mr18-c.out" || fail "F-MR18 Gate C O0/O2 marker missing"
  grep -Fq 'FMR18C_FWO34_EXACT_TRANSCRIPT_PRESERVATION=PASS' "$BUILD/mr18-c.out" || fail "F-MR18 Gate C F-WOF34 transcript marker missing"
  grep -Fq 'FMR18C_FCI21_CURRENT_COMPOSITION_PRESERVATION=PASS' "$BUILD/mr18-c.out" || fail "F-MR18 Gate C current composition marker missing"
  echo 'FCI21_MR18_MULTISWAP_RECEIPT_POSTIMAGE_PRESERVATION=PASS'
}

case "$phase" in
  wof42) run_wof42 ;;
  mr18-ab) run_mr18_ab ;;
  mr18-c) run_mr18_c ;;
  all)
    run_wof42
    run_mr18_ab
    run_mr18_c
    ;;
  *) fail "unknown phase $phase" ;;
esac

echo "FCI21_WOF42_MR18_PRESERVATION_${phase^^}=PASS"
