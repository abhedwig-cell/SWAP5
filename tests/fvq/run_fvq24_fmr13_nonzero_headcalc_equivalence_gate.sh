#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq24-$$"
CANDIDATE=985058c0261d284424432a65bded16b7fc9107cb
CANDIDATE_TREE=310b0b419181456b7c0af029e42de742fa96f19d
FVQ23_CLOSEOUT=fbd30628f3a072021cd3f4ab8e45f28df547d5de
FSI18_CLOSEOUT=8c5438a73e8ae4c9fcbd9de9fdd82d9a600626b2
FSI18_PROBE_BLOB=1a0898cfd927455d9219db0f59ac238943cd1435
FSI18_TOP_PROVIDER_BLOB=cf8905a97dcb928b18f129bf1f76a9230da82151
SUPPORT_FIXTURE_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fsi18" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git rev-parse "$CANDIDATE^{tree}")" == "$CANDIDATE_TREE" ]] || {
  echo 'FVQ24_CANDIDATE_TREE_LOCK=FAIL' >&2; exit 1; }
git merge-base --is-ancestor "$FVQ23_CLOSEOUT" HEAD || {
  echo 'FVQ24_FVQ23_LINEAGE_LOCK=FAIL' >&2; exit 1; }
git diff --quiet "$CANDIDATE" -- src || {
  echo 'FVQ24_CANDIDATE_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$CANDIDATE" -- src >&2
  exit 1
}
echo 'FVQ24_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ24_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/legacy/b1_10_port/headcalc.f90 1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/solver/mod_reference_richards_workspace.f90 178d3289e09583c256b1aa400407d468d9c18e68
check_blob tests/fsi/fsi04_real_headcalc_stubs.f90 "$SUPPORT_FIXTURE_BLOB"
[[ "$(git rev-parse "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90")" == "$FSI18_PROBE_BLOB" ]] || {
  echo 'FVQ24_FSI18_PROBE_SOURCE_LOCK=FAIL' >&2; exit 1; }
[[ "$(git rev-parse "$FSI18_CLOSEOUT:tests/fsi/mod_fsi07_top_provider.f90")" == "$FSI18_TOP_PROVIDER_BLOB" ]] || {
  echo 'FVQ24_FSI18_TOP_PROVIDER_SOURCE_LOCK=FAIL' >&2; exit 1; }
echo 'FVQ24_SOURCE_LOCKS=PASS'

# Reproduce the exact pre-seam F-SI18 reference-TRIDAG control in isolation.
git worktree add --detach "$BUILD/fsi18" "$FSI18_CLOSEOUT" >/dev/null
(
  cd "$BUILD/fsi18"
  FSI18_TRIDAG_EVIDENCE_DIR="$BUILD/fsi18-evidence" \
    bash tests/fsi/run_fsi18_reference_tridag_control_gate.sh > "$BUILD/fsi18-control.log"
)
grep -Fq 'FSI18_REFERENCE_TRIDAG_CONTROL_GATE=PASS_DIAGNOSTIC_ONLY' "$BUILD/fsi18-control.log"
grep -Fq 'FSI18_REFERENCE_TRIDAG_ALL_NONZERO_CONVERGED=YES' "$BUILD/fsi18-control.log"
echo 'FVQ24_FSI18_REFERENCE_CONTROL=PASS'

# Materialize only immutable historical test fixtures needed by the five-case
# probe. They are not copied into the repository and are not production input.
git show "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90" \
  > "$BUILD/test_fsi18_reference_convergence_cliff.F90"
git show "$FSI18_CLOSEOUT:tests/fsi/mod_fsi07_top_provider.f90" \
  > "$BUILD/mod_fsi07_top_provider.f90"

# F-SI18 was written after the explicit physical-config request field existed.
# The exact F-MR13 runtime lineage predates that field and still represents the
# admitted inactive macropore route through swmacro=0. The historical probe sets
# swmacro=0 explicitly before any solve, so its one false physical-config write
# is redundant for this candidate. Remove exactly that obsolete API write from
# the temporary copy, while source-locking every physical/numerical stimulus we
# need for the equivalence claim.
python3 - "$BUILD/test_fsi18_reference_convergence_cliff.F90" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
needle = '    request%physical%macropore_active = .false.\n'
if s.count(needle) != 1:
    raise SystemExit(f'FVQ24 expected exactly one obsolete inactive macropore write, found {s.count(needle)}')
required = [
    'swmacro = 0',
    'real(real64), parameter :: perturbation(ncases) = [0.0_real64, 3.0e-12_real64, -3.0e-12_real64, &',
    '1.0e-11_real64, -1.0e-11_real64]',
    'request%boundary%bottom_mode = 7',
    'request%numerical%max_iterations = 8',
    'request%numerical%max_backtracking = 4',
    'request%numerical%conductivity_implicit_mode = 0',
    'request%numerical%conductivity_mean_method = 1',
    'request%numerical%compartment_balance_tolerance = 1.0e-12_real64',
    'request%numerical%total_balance_tolerance = 1.0e-12_real64',
    'request%numerical%head_abs_tolerance = 1.0e-12_real64',
    'request%numerical%head_rel_tolerance = 1.0e-12_real64',
    'request%numerical%ponding_tolerance = 1.0e-12_real64',
]
for token in required:
    if token not in s:
        raise SystemExit(f'FVQ24 historical probe stimulus lock missing: {token}')
s = s.replace(needle, '', 1)
p.write_text(s, encoding='utf-8')
print('FVQ24_FSI18_TO_FMR13_REQUEST_COMPATIBILITY_ADAPTER=PASS_SINGLE_REDUNDANT_FALSE_WRITE_REMOVED')
PY

# Remove the three legacy external linear-solver stubs from the otherwise exact
# support fixture so the current production HeadCalc is forced through the
# F-MR13 reference-linear-solver seam. This transformation is implemented here,
# not by invoking the F-SI19 producer helper.
python3 - "$BUILD/current-stubs.f90" <<'PY'
from pathlib import Path
import re
import sys
src = Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text(encoding='utf-8')
for name in ('tridag', 'bandec', 'banbks'):
    pat = re.compile(rf'(?ims)^subroutine\s+{name}\b.*?^end\s+subroutine\s+{name}\s*\n')
    hits = list(pat.finditer(src))
    if len(hits) != 1:
        raise SystemExit(f'FVQ24 expected one {name} support routine, found {len(hits)}')
    src = pat.sub('', src, count=1)
for forbidden in ('subroutine tridag', 'subroutine bandec', 'subroutine banbks'):
    if forbidden in src.lower():
        raise SystemExit(f'FVQ24 legacy solver support remains: {forbidden}')
Path(sys.argv[1]).write_text(src, encoding='utf-8')
print('FVQ24_SOLVERLESS_SUPPORT_FIXTURE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
PRODUCTION_SRC=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/current-stubs.f90" -o "$OUT/current-stubs.o"
  objects+=("$OUT/current-stubs.o")

  for src in "${PRODUCTION_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/mod_fsi07_top_provider.f90" -o "$OUT/mod_fsi07_top_provider.o"
  objects+=("$OUT/mod_fsi07_top_provider.o")

  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    -c "$BUILD/test_fsi18_reference_convergence_cliff.F90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

  "$OUT/test" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/test" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$OUT/run-a.txt"
  for i in 1 2 3 4 5; do
    grep -Fq "FSI18_CASE_${i}_CONVERGED=T" "$OUT/run-a.txt"
  done
  cmp "$OUT/run-a.txt" "$BUILD/fsi18-evidence/reference-tridag-o${opt}.txt"
  echo "FVQ24_HEADCALC_O${opt}=PASS_BITWISE_FSI18_REFERENCE"
done

cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FVQ24_HEADCALC_O0_O2_IDENTITY=PASS'
echo 'FVQ24_ALL_FIVE_CASES_CONVERGED=PASS'
echo 'FVQ24_NONZERO_CASES_2_TO_5_CONVERGED=PASS'
echo "FVQ24_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/run-a.txt" | cut -d' ' -f1)"

git diff --quiet "$CANDIDATE" -- src || {
  echo 'FVQ24_POST_TEST_PRODUCTION_IMMUTABILITY=FAIL' >&2; exit 1; }
echo 'FVQ24_POST_TEST_PRODUCTION_IMMUTABILITY=PASS'
echo 'FVQ24_FMR13_NONZERO_HEADCALC_REFERENCE_EQUIVALENCE_GATE PASS'
