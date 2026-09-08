#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq23-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CANDIDATE=985058c0261d284424432a65bded16b7fc9107cb
CANDIDATE_TREE=310b0b419181456b7c0af029e42de742fa96f19d
FMR13_STATUS_BLOB=6a53239713ea1682087f7e3628eff7e538c5809b
FMR13_GATE_BLOB=d6df5a11d39d459ede9efee8f426dea362aafc4e
FSI19_CLOSEOUT=d3a1bc8eef243b6109af8871398c06e1840fb367
FSI19_ORACLE_BLOB=bf8c9d85c98157d128086d2c2fb20f6129b98e63
LINEAR_SOLVER_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
HEADCALC_BLOB=1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
WORKSPACE_BLOB=178d3289e09583c256b1aa400407d468d9c18e68

[[ "$(git rev-parse "$CANDIDATE^{tree}")" == "$CANDIDATE_TREE" ]] || {
  echo 'FVQ23_CANDIDATE_TREE_LOCK=FAIL' >&2; exit 1; }
git merge-base --is-ancestor "$CANDIDATE" HEAD
# Qualification artifacts may differ from the candidate; production source may not.
git diff --quiet "$CANDIDATE" -- src || {
  echo 'FVQ23_CANDIDATE_PRODUCTION_IMMUTABILITY=FAIL' >&2; exit 1; }
echo 'FVQ23_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ23_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/solver/mod_reference_linear_solver.f90 "$LINEAR_SOLVER_BLOB"
check_blob src/legacy/b1_10_port/headcalc.f90 "$HEADCALC_BLOB"
check_blob src/solver/mod_reference_richards_workspace.f90 "$WORKSPACE_BLOB"
[[ "$(git rev-parse "$CANDIDATE:integration/f-mr/F-MR13_STATUS.json")" == "$FMR13_STATUS_BLOB" ]]
[[ "$(git rev-parse "$CANDIDATE:tests/fmr/run_fmr13_reference_linear_solver_runtime_gate.sh")" == "$FMR13_GATE_BLOB" ]]
[[ "$(git rev-parse "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90")" == "$FSI19_ORACLE_BLOB" ]]
echo 'FVQ23_SOURCE_BOUND_CANDIDATE_LOCKS=PASS'

python3 - <<'PY'
import json
from pathlib import Path
s = json.loads(Path('integration/f-mr/F-MR13_STATUS.json').read_text())
assert s['status'] == 'QUALIFIED_FSI19_REFERENCE_LINEAR_SOLVER_SEAM_IN_FMR_REAL_PHYSICS_LINEAGE'
assert s['state'] == {'implemented': True, 'persisted': True, 'tested': True, 'qualified': True}
assert s['physics_changed'] is False
assert s['numerical_controls_changed'] is False
assert s['retry_policy_changed'] is False
assert s['mass_requirement_relaxed'] is False
assert s['transaction_semantics_changed'] is False
assert s['reference_mode_preserved'] is True
assert s['scientific_admission'] is False
assert s['execution_classes']['BALANCED'] == 'DEFINED_NOT_ADMITTED'
assert s['execution_classes']['THROUGHPUT'] == 'DEFINED_NOT_ADMITTED'
assert s['execution_classes']['FALLBACK'] == 'DEFINED_NOT_ADMITTED'
print('FVQ23_FMR13_CLAIM_BOUNDARY=PASS')

h = Path('src/legacy/b1_10_port/headcalc.f90').read_text().lower()
w = Path('src/solver/mod_reference_richards_workspace.f90').read_text().lower()
assert 'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve' in h
assert 'call reference_tridag(' in h
assert 'call reference_band_solve(' in h
assert 'call tridag(' not in h
assert 'call bandec(' not in h
assert 'call banbks(' not in h
assert 'real(real64), allocatable :: tridag_gamma(:)' in w
print('FVQ23_SOLVER_ROUTING_AND_WORKER_SCRATCH=PASS')
PY

# Independently re-execute the source-bound legacy-equivalence oracle from the
# F-SI19 qualification source against the exact F-MR13 production module.
git show "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90" > "$BUILD/test_linear_solver_oracle.f90"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 "$BUILD/test_linear_solver_oracle.f90" -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt"
  "$OUT/test" > "$OUT/run-b.txt"
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N1=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N7=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1000=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1002=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/run-a.txt"
  echo "FVQ23_LEGACY_LINEAR_SOLVER_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FVQ23_LEGACY_LINEAR_SOLVER_ORACLE_O0_O2_IDENTITY=PASS'

# Independently re-run the exact owner-composed real-physics gate and require
# the scientific invariants relevant to admission, rather than trusting its exit code alone.
bash tests/fmr/run_fmr13_reference_linear_solver_runtime_gate.sh > "$BUILD/fmr13.txt" 2>&1 || {
  cat "$BUILD/fmr13.txt" >&2
  exit 1
}
for marker in \
  'FMR13_PRODUCTION_DELTA_EXACTLY_THREE_SOLVER_SEAM_PATHS=PASS' \
  'FMR13_EXACT_BASE_PLUS_FSI19_DELTA=PASS' \
  'FMR13_ARCHITECTURAL_LINEAR_SOLVER_SEAM=PASS' \
  'FMR13_FSI19_DIRECT_ORACLE_O0_O2_IDENTITY=PASS' \
  'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' \
  'FMR09_HARD_MASS_BALANCE=PASS' \
  'FPM03_SSDI_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS' \
  'FMR06_SNOW_ROLLBACK=PASS' \
  'FMR06_SNOW_REPLAY_BITWISE=PASS' \
  'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' \
  'FVQ20_ROLLBACK_REPLAY=PASS' \
  'FVQ18_FIXED_TRANSACTION_REPLAY=PASS' \
  'FMR13_AUTHORITATIVE_MASS_TRANSACTION_REPLAY_REGRESSION=PASS' \
  'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS' \
  'FMR12_O0_O2_OUTPUT_IDENTITY=PASS' \
  'FMR13_FMR12_FMR10_RUNTIME_REGRESSION=PASS' \
  'FMR13_REFERENCE_LINEAR_SOLVER_RUNTIME_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/fmr13.txt" || {
    echo "FVQ23_REQUIRED_RUNTIME_MARKER_MISSING: $marker" >&2
    cat "$BUILD/fmr13.txt" >&2
    exit 1
  }
done

grep -Fq 'FMR09_OUTPUT_SHA256=920ec4876c528dc3af9f5de4616f50a1214b3c87e999d9261bf57a348cf2f08d' "$BUILD/fmr13.txt"
grep -Fq 'FMR12_OUTPUT_SHA256=5e70234b073d7d865075ec8d315755426b47d825539e0a0d74df6c122e733e29' "$BUILD/fmr13.txt"
echo 'FVQ23_EXISTING_SCIENTIFIC_RUNTIME_ORACLES_PRESERVED=PASS'
echo 'FVQ23_AUTHORITATIVE_MASS_AND_TRANSACTION_SEMANTICS=PASS'

# Gate execution itself may create only temporary ignored/test files; production stays immutable.
git diff --quiet "$CANDIDATE" -- src

echo "FVQ23_DIRECT_ORACLE_SHA256=$(sha256sum "$BUILD/o0/run-a.txt" | cut -d' ' -f1)"
echo "FVQ23_FMR13_GATE_SHA256=$(sha256sum "$BUILD/fmr13.txt" | cut -d' ' -f1)"
echo 'FVQ23_FMR13_REFERENCE_LINEAR_SOLVER_SCIENTIFIC_NO_CHANGE_GATE PASS'
