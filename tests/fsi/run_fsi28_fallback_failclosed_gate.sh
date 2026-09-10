#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi28-fallback-$$"
FSI19_CLOSEOUT=d3a1bc8eef243b6109af8871398c06e1840fb367
FSI19_ORACLE_BLOB=bf8c9d85c98157d128086d2c2fb20f6129b98e63
HEADCALC_BLOB=55893f1f5ccba2052ad681743aa155b69f351246
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI28_FALLBACK_FAIL $*" >&2; exit 1; }

git cat-file -e "$FSI19_CLOSEOUT^{commit}" || fail 'F-SI19 closeout commit unavailable'
[[ "$(git rev-parse "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90")" == "$FSI19_ORACLE_BLOB" ]] || \
  fail 'F-SI19 direct linear-solver oracle drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$HEADCALC_BLOB" ]] || \
  fail 'HeadCalc source authority drift'

echo 'FSI28_FALLBACK_SOURCE_LOCK=PASS'

# Part 1: independently re-execute the already-qualified F-SI19 direct oracle
# against the CURRENT F-SI28 linear-solver module. This proves that the current
# production TRIDAG still reports its singular-pivot ierror routes and that the
# production band solver remains executable, without manufacturing an invalid
# Richards column merely to force the rare fallback.
git show "$FSI19_CLOSEOUT:tests/fsi/test_fsi19_reference_linear_solver.f90" > "$BUILD/test_fsi19_reference_linear_solver.f90"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 "$BUILD/test_fsi19_reference_linear_solver.f90" -o "$OUT/test"
  "$OUT/test" > "$OUT/run.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1000=PASS' "$OUT/run.txt" || fail "O${opt} missing first-pivot singular route"
  grep -Fq 'FSI19_TRIDAG_IERROR_1002=PASS' "$OUT/run.txt" || fail "O${opt} missing interior-pivot singular route"
  grep -Fq 'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run.txt" || fail "O${opt} missing band N4 oracle"
  grep -Fq 'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run.txt" || fail "O${opt} missing band N5 oracle"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/run.txt" || fail "O${opt} direct oracle failed"
  echo "FSI28_FALLBACK_LINEAR_SOLVER_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/o0/run.txt" "$BUILD/o2/run.txt" || fail 'O0/O2 direct linear-solver oracle differs'
echo 'FSI28_FALLBACK_LINEAR_SOLVER_ORACLE_O0_O2_IDENTITY=PASS'

# Part 2: prove the actual production control-flow safety invariant. The claim
# being qualified is conditional publication safety: IF HeadCalc takes its
# alternative linear-solver fallback, no prescribed-qbot tangent may be
# published. A contrived singular hydraulic column would test a different
# property (reachability under invalid/extreme physics) and is intentionally not
# introduced here.
python3 - <<'PY'
from pathlib import Path
import re

head = Path('src/legacy/b1_10_port/headcalc.f90').read_text()
adapter = Path('src/adapter/mod_reference_richards_legacy_binding.f90').read_text()
contract = Path('src/solver/mod_soil_water_solver_contract.f90').read_text()

# Result default is fail closed.
assert re.search(r'type,\s*public\s*::\s*soil_water_interface_sensitivity_t.*?logical\s*::\s*available\s*=\s*\.false\.',
                 contract, re.I | re.S)
assert 'result = soil_water_solve_result_t()' in adapter

# HeadCalc: every normal TRIDAG failure enters the alternative route, increments
# the worker diagnostic before the alternative solve, and does not clear that
# diagnostic before returning to the adapter.
fallback = re.search(
    r'call\s+reference_tridag\s*\(.*?\)\s*\n.*?'
    r'if\s*\(\s*ierror\s*/=\s*0\s*\)\s*then(.*?)end\s*if',
    head, re.I | re.S)
assert fallback, 'HeadCalc TRIDAG fallback block not found'
block = fallback.group(1)
inc = re.search(r'ctx%diagnostics%alternative_solver_calls\s*=\s*ctx%diagnostics%alternative_solver_calls\s*\+\s*1', block, re.I)
call = re.search(r'call\s+alternative_solver\s*\(\s*\)', block, re.I)
assert inc and call, 'fallback counter/call missing'
assert inc.start() < call.start(), 'fallback diagnostic must be incremented before alternative solve'
post_headcalc = adapter.split('call headcalc', 1)[1]
assert 'a23bu_reset_attempt_diagnostics' not in post_headcalc.lower(), 'fallback diagnostic reset after HeadCalc'

# Adapter: the only publication of available=.true. and the only extra tangent
# backsolve counter increment are structurally inside a guard requiring zero
# alternative-solver calls. Hence fallback=>counter>0=>publication block skipped.
assert len(re.findall(r'interface_sensitivity%available\s*=\s*\.true\.', adapter, re.I)) == 1
assert len(re.findall(r'interface_sensitivity_backsolves\s*=\s*interface_sensitivity_backsolves\s*\+\s*1', adapter, re.I)) == 1
pub = re.search(
    r'if\s*\(\s*sensitivity_capture.*?alternative_solver_calls\s*==\s*0.*?\)\s*then(.*?)end\s*if',
    adapter, re.I | re.S)
assert pub, 'qualified tangent publication guard not found'
pub_block = pub.group(1)
assert re.search(r'interface_sensitivity_backsolves\s*=\s*interface_sensitivity_backsolves\s*\+\s*1', pub_block, re.I)
assert re.search(r'interface_sensitivity%available\s*=\s*\.true\.', pub_block, re.I)
assert re.search(r"interface_sensitivity%method\s*=\s*'same-tridag-factor'", pub_block, re.I)

# Local cost accounting also defaults fail closed and is copied only after the
# guarded production path has been evaluated.
assert re.search(r'interface_sensitivity_backsolves\s*=\s*0', adapter, re.I)
assert re.search(r'result%diagnostics%interface_sensitivity_backsolves\s*=\s*interface_sensitivity_backsolves', adapter, re.I)

print('FSI28_FALLBACK_HEADCALC_IERROR_TO_ALTERNATIVE_ROUTE=PASS')
print('FSI28_FALLBACK_PUBLICATION_GUARD_ZERO_ALT_CALLS=PASS')
print('FSI28_FALLBACK_DEFAULT_SENSITIVITY_UNAVAILABLE=PASS')
print('FSI28_FALLBACK_ZERO_TANGENT_BACKSOLVE_BY_CONTROL_FLOW=PASS')
PY

echo 'FSI28_FALLBACK_FAILCLOSED_COMPOSITION_GATE PASS'
