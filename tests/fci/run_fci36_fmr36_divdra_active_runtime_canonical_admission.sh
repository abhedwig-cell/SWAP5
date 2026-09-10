#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci36-$$"
EVIDENCE_DIR="${FCI36_EVIDENCE_DIR:-}"
BASE="c0fc660c1e68064f77f4ec4f3376d385fbe88b4a"
OWNER="a543775abeea4760dba2ea5c99c47fe4862c845f"
FVQ51="716d0952c2a9580b213cd22d8c3c1dc824f53dff"
HELPER="src/runtime/mod_fmr_divdra_serialized_composition.f90"
RUNTIME="src/runtime/mod_fmr_divdra_serialized_runtime.f90"
HELPER_BLOB="5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5"
RUNTIME_BLOB="9a384658ec37b68d2ef911e741aa89707dcb3e77"
FVQ51_TEST_BLOB="b8206e0388568f5e792304af9bf9bd889212a10c"
FVQ51_RUNNER_BLOB="7af4f66974ad71b06523341bad7e3a173c13dcca"
EXPECTED_HASH="a2e8056d5d1ab9e2ae52204b5dd3418a253603300726a51660db86f050895f87"
EXPECTED_SRC_TREE="91afa55dfcfdeedd2dd166f804a2dc91c5ee3e30"
EXPECTED_REFERENCE_TREE="9d08625217d7c0a7385df9da6a04183bcd9cb9e6"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FCI36_GATE_FAIL $*" >&2; exit 36; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift path=$path expected=$expected actual=$actual"
}

# Source-lineage and exact admission scope.
git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD is not descended from exact F-CI35 canonical base'
if git cat-file -e "$BASE:$HELPER" 2>/dev/null; then fail 'helper unexpectedly existed on canonical base'; fi
if git cat-file -e "$BASE:$RUNTIME" 2>/dev/null; then fail 'runtime unexpectedly existed on canonical base'; fi
printf '%s\n' "$HELPER" "$RUNTIME" | sort > "$BUILD/expected-src.txt"
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src.txt"
cmp -s "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || { cat "$BUILD/actual-src.txt" >&2; fail 'src delta is not exactly the two admitted F-MR36 files'; }
[[ -z "$(git diff --name-only "$BASE"..HEAD -- reference)" ]] || fail 'reference delta is not zero'
check_blob "$HELPER" "$HELPER_BLOB"
check_blob "$RUNTIME" "$RUNTIME_BLOB"
check_blob src/process/mod_drainage_spatial_distribution.f90 1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
check_blob src/runtime/mod_fmr_divdra_runtime_binding.f90 e4737fb6f00a11ed16e34bee44b3442ac84b31aa
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 fe5a06c9af59308cdad86c5126379f413591b0cd
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
[[ "$(git rev-parse HEAD:src)" == "$EXPECTED_SRC_TREE" ]] || fail 'src postimage tree drift'
[[ "$(git rev-parse HEAD:reference)" == "$EXPECTED_REFERENCE_TREE" ]] || fail 'reference postimage tree drift'
echo 'FCI36_EXACT_TWO_PRODUCTION_SOURCE_ADDITIONS=PASS'
echo 'FCI36_REFERENCE_TREE_UNCHANGED=PASS'
echo 'FCI36_PRIOR_DIVDRA_AND_GENERIC_RUNTIME_AUTHORITIES_PRESERVED=PASS'

# Owner and independent qualification authority locks.
python3 - "$OWNER" "$FVQ51" <<'PY'
import json, subprocess, sys
owner, fvq = sys.argv[1:]
o = json.loads(subprocess.check_output(['git','show',f'{owner}:integration/f-mr/F-MR36_STATUS.json'], text=True))
assert o['decision'] == 'QUALIFIED_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_READY_FOR_INDEPENDENT_REQUALIFICATION'
assert o['candidate']['composition_blob'] == '5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5'
assert o['candidate']['runtime_blob'] == '9a384658ec37b68d2ef911e741aa89707dcb3e77'
assert o['state']['owner_qualified'] is True
v = json.loads(subprocess.check_output(['git','show',f'{fvq}:integration/f-vq/F-VQ51_STATUS.json'], text=True))
assert v['decision'] == 'QUALIFIED_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_FOR_CANONICAL_ADMISSION'
assert v['state']['tested'] is True
assert v['state']['independently_qualified'] is True
assert v['state']['canonical_admitted'] is False
assert v['candidate']['composition_blob'] == '5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5'
assert v['candidate']['runtime_blob'] == '9a384658ec37b68d2ef911e741aa89707dcb3e77'
e = json.loads(subprocess.check_output(['git','show',f'{fvq}:integration/f-vq/F-VQ51_EVIDENCE.json'], text=True))
assert e['independent_decision'] == 'QUALIFIED_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_FOR_CANONICAL_ADMISSION'
assert e['decisive_independent_ci']['output_sha256'] == 'a2e8056d5d1ab9e2ae52204b5dd3418a253603300726a51660db86f050895f87'
assert e['single_active_matrix']['case_count'] == 12
assert e['multi_column_and_failure_evidence']['two_active_columns_no_cross_contamination'] is True
assert e['mass_and_architecture']['all_30_invariants_reviewed'] is True
print('FCI36_OWNER_AND_FVQ51_AUTHORITIES=PASS')
PY

[[ "$(git rev-parse "$FVQ51:tests/fvq/test_fvq51_divdra_active_runtime_callsite.f90")" == "$FVQ51_TEST_BLOB" ]] || fail 'F-VQ51 test source drift'
[[ "$(git rev-parse "$FVQ51:tests/fvq/run_fvq51_divdra_active_runtime_callsite.sh")" == "$FVQ51_RUNNER_BLOB" ]] || fail 'F-VQ51 runner source drift'
git show "$FVQ51:tests/fvq/test_fvq51_divdra_active_runtime_callsite.f90" > "$BUILD/test.f90"
# Replay the exact qualification harness hygiene transformation used by F-VQ51.
python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
s=s.replace('    allocate(req(', '    if (allocated(req)) deallocate(req)\n    allocate(req(')
p.write_text(s)
PY
echo 'FCI36_FVQ51_INDEPENDENT_VERIFIER_SOURCE_LOCK=PASS'

python3 - <<'PY'
import json
p=json.load(open('integration/f-ci/F-CI36_ARCHITECTURE_AUDIT.json'))
assert p['overall']=='NO_ADVERSE_ARCHITECTURE_DELTA_WITHIN_RESTRICTED_SCOPE'
ids=[x['id'] for x in p['invariants']]
assert ids==list(range(1,31))
allowed={'SATISFIED','SATISFIED_WITHIN_SERIALIZED_SCOPE'}
assert all(x['status'] in allowed for x in p['invariants'])
print('FCI36_ALL_30_ARCHITECTURE_INVARIANTS=PASS')
PY

python3 - <<'PY'
from pathlib import Path
p=Path('.github/workflows/fci-canonical.yml').read_text()
assert 'run_fci36_fmr36_divdra_active_runtime_canonical_admission.sh' in p
assert '91afa55dfcfdeedd2dd166f804a2dc91c5ee3e30' in p
assert 'FCI36_CANONICAL_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE=PASS' in p
print('FCI36_BROAD_CANONICAL_MOVING_AUTHORITY_UPDATED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/process/mod_drainage_spatial_distribution.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_divdra_runtime_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  for src in "$HELPER" "$RUNTIME"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr04_fixed_top_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/mod_fmr04_fixed_top_provider.f90 -o "$obj"
  objects+=("$obj")
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "independent verifier O$opt execution"; }
  for marker in \
    'FVQ51_INACTIVE_EXACT_IDENTITY=PASS' \
    'FVQ51_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS' \
    'FVQ51_FAIL_CLOSED_PREMUTATION_MATRIX=PASS' \
    'FVQ51_VALID_SINGLE_ACTIVE_CASES=12' \
    'FVQ51_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing F-VQ51 O$opt marker $marker"; }
  done
  [[ "$(grep -c '^FVQ51_SINGLE ' "$OUT/output.txt")" == 12 ]] || fail "O$opt single-case count"
  echo "FCI36_FVQ51_REPLAY_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail 'F-VQ51 O0/O2 output identity'; }
HASH="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
[[ "$HASH" == "$EXPECTED_HASH" ]] || fail "independent output hash drift expected=$EXPECTED_HASH actual=$HASH"
echo "FCI36_FVQ51_OUTPUT_SHA256=$HASH"
echo 'FCI36_FVQ51_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  cp "$BUILD/o0/output.txt" "$EVIDENCE_DIR/o0-output.txt"
  cp "$BUILD/o2/output.txt" "$EVIDENCE_DIR/o2-output.txt"
  printf '%s\n' "$HASH" > "$EVIDENCE_DIR/output-sha256.txt"
  git rev-parse HEAD > "$EVIDENCE_DIR/tested-head.txt"
  git rev-parse HEAD:src > "$EVIDENCE_DIR/src-tree.txt"
  git rev-parse HEAD:reference > "$EVIDENCE_DIR/reference-tree.txt"
  git rev-parse "HEAD:$HELPER" > "$EVIDENCE_DIR/composition-blob.txt"
  git rev-parse "HEAD:$RUNTIME" > "$EVIDENCE_DIR/runtime-blob.txt"
fi

echo 'FCI36_CANONICAL_ADMISSION_GATE=PASS'
