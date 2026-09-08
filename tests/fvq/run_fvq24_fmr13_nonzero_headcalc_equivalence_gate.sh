#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq24-$$"
FMR12=e639ca5ae703d6bdb97829a0bd7d2762db1d8a9a
FMR13=985058c0261d284424432a65bded16b7fc9107cb
FMR13_TREE=310b0b419181456b7c0af029e42de742fa96f19d
FVQ23_CLOSEOUT=fbd30628f3a072021cd3f4ab8e45f28df547d5de
FSI18_CLOSEOUT=8c5438a73e8ae4c9fcbd9de9fdd82d9a600626b2
FSI18_PROBE_BLOB=1a0898cfd927455d9219db0f59ac238943cd1435
FSI18_TOP_PROVIDER_BLOB=cf8905a97dcb928b18f129bf1f76a9230da82151
FSI18_REFERENCE_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
SHARED_CONTRACT_BLOB=0a57b07712f93538cbfaf9130838682307cede09
SUPPORT_FIXTURE_BLOB=23c00e4a188e88bc36ef95cbe4faaacdd6aad639
mkdir -p "$BUILD"
trap 'git -C "$ROOT" worktree remove --force "$BUILD/fmr12" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git rev-parse "$FMR13^{tree}")" == "$FMR13_TREE" ]] || {
  echo 'FVQ24_FMR13_TREE_LOCK=FAIL' >&2; exit 1; }
git merge-base --is-ancestor "$FVQ23_CLOSEOUT" HEAD || {
  echo 'FVQ24_FVQ23_LINEAGE_LOCK=FAIL' >&2; exit 1; }
git diff --quiet "$FMR13" -- src || {
  echo 'FVQ24_CANDIDATE_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FMR13" -- src >&2
  exit 1
}
echo 'FVQ24_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

expected_delta=$'src/legacy/b1_10_port/headcalc.f90\nsrc/solver/mod_reference_linear_solver.f90\nsrc/solver/mod_reference_richards_workspace.f90'
actual_delta="$(git diff --name-only "$FMR12" "$FMR13" -- src | sort)"
[[ "$actual_delta" == "$expected_delta" ]] || {
  echo 'FVQ24_FMR12_FMR13_PRODUCTION_DELTA=FAIL' >&2
  printf 'expected:\n%s\nactual:\n%s\n' "$expected_delta" "$actual_delta" >&2
  exit 1
}
echo 'FVQ24_FMR12_FMR13_PRODUCTION_DELTA_EXACTLY_THREE_SOLVER_SEAM_PATHS=PASS'

check_commit_blob() {
  local commit="$1" path="$2" expected="$3" actual
  actual="$(git rev-parse "$commit:$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ24_COMMIT_BLOB_MISMATCH commit=$commit path=$path expected=$expected actual=$actual" >&2
    exit 1
  }
}
check_current_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FVQ24_CURRENT_BLOB_MISMATCH path=$path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_commit_blob "$FMR12" src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353
check_commit_blob "$FMR12" src/solver/mod_soil_water_solver_contract.f90 "$SHARED_CONTRACT_BLOB"
check_commit_blob "$FMR12" tests/fsi/fsi04_real_headcalc_stubs.f90 "$SUPPORT_FIXTURE_BLOB"
check_current_blob src/legacy/b1_10_port/headcalc.f90 1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
check_current_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_current_blob src/solver/mod_reference_richards_workspace.f90 178d3289e09583c256b1aa400407d468d9c18e68
check_current_blob src/solver/mod_soil_water_solver_contract.f90 "$SHARED_CONTRACT_BLOB"
check_current_blob tests/fsi/fsi04_real_headcalc_stubs.f90 "$SUPPORT_FIXTURE_BLOB"
check_commit_blob "$FSI18_CLOSEOUT" tests/fsi/test_fsi18_reference_convergence_cliff.F90 "$FSI18_PROBE_BLOB"
check_commit_blob "$FSI18_CLOSEOUT" tests/fsi/mod_fsi07_top_provider.f90 "$FSI18_TOP_PROVIDER_BLOB"
check_commit_blob "$FSI18_CLOSEOUT" tests/fsi/fsi18_make_reference_tridag_stubs.py "$FSI18_REFERENCE_GENERATOR_BLOB"
echo 'FVQ24_SOURCE_LOCKS=PASS'

# Materialize the exact F-MR12 predecessor and immutable historical test-only
# stimulus/reference helpers. Nothing is copied into production source.
git worktree add --detach "$BUILD/fmr12" "$FMR12" >/dev/null
git show "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90" > "$BUILD/probe.F90"
git show "$FSI18_CLOSEOUT:tests/fsi/mod_fsi07_top_provider.f90" > "$BUILD/mod_fsi07_top_provider.f90"
git show "$FSI18_CLOSEOUT:tests/fsi/fsi18_make_reference_tridag_stubs.py" > "$BUILD/make_reference_tridag_stubs.py"

# Adapt only the temporary probe to the request generation shared by F-MR12 and
# F-MR13. F-SI18 added an explicit physical-config member after that lineage;
# the shared runtime represents this admitted inactive option with swmacro=0.
# Also synchronize legacy time/numerical globals to the values already present
# in the request, because this earlier adapter generation validates and consumes
# those globals. Physical stimulus, states, fluxes and tolerances are unchanged.
python3 - "$BUILD/probe.F90" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
old_use = '  use variables, only: fldtmin\n'
new_use = '''  use variables, only: fldtmin, dt, swbotb, maxit, maxbacktr, swkimpl, swkmean, dtmin, &
       CritDevBalCp, CritDevBalTot, critdevh2cp, critdevh1cp, critdevponddt
'''
if s.count(old_use) != 1:
    raise SystemExit(f'FVQ24 expected one legacy-global use line, found {s.count(old_use)}')
s = s.replace(old_use, new_use, 1)
physical = '    request%physical%macropore_active = .false.\n'
if s.count(physical) != 1:
    raise SystemExit(f'FVQ24 expected one later physical-config write, found {s.count(physical)}')
s = s.replace(physical, '', 1)
old_init = '  swmacro = 0\n  fldtmin = .false.\n'
new_init = '''  swmacro = 0
  fldtmin = .false.
  dt = step_duration
  swbotb = 7
  maxit = 8
  maxbacktr = 4
  swkimpl = 0
  swkmean = 1
  dtmin = 1.0e-6_real64
  CritDevBalCp = 1.0e-12_real64
  CritDevBalTot = 1.0e-12_real64
  critdevh2cp = 1.0e-12_real64
  critdevh1cp = 1.0e-12_real64
  critdevponddt = 1.0e-12_real64
'''
if s.count(old_init) != 1:
    raise SystemExit(f'FVQ24 expected one legacy-global initialization anchor, found {s.count(old_init)}')
s = s.replace(old_init, new_init, 1)
solve_anchor = '    call solver%solve(request, workspace, result)\n'
solve_repl = solve_anchor + "    if (result%diagnostics%alternative_solver_calls /= 0) error stop 'FVQ24 five-case TRIDAG probe unexpectedly used band fallback'\n"
if s.count(solve_anchor) != 1:
    raise SystemExit(f'FVQ24 expected one solve anchor, found {s.count(solve_anchor)}')
s = s.replace(solve_anchor, solve_repl, 1)
required = [
    'real(real64), parameter :: head0 = -75.0_real64',
    'real(real64), parameter :: step_duration = 1.0_real64',
    'real(real64), parameter :: perturbation(ncases) = [0.0_real64, 3.0e-12_real64, -3.0e-12_real64, &',
    '1.0e-11_real64, -1.0e-11_real64]',
    'qdra(1,node) = 1.0e-5_real64*real(node,real64)',
    'qdra(2,node) = -2.0e-6_real64*real(node+1,real64)',
    'request%boundary%bottom_mode = 7',
    'request%boundary%bottom_flux = -k0',
    'request%numerical%max_iterations = 8',
    'request%numerical%max_backtracking = 4',
    'request%numerical%conductivity_implicit_mode = 0',
    'request%numerical%conductivity_mean_method = 1',
    'request%numerical%compartment_balance_tolerance = 1.0e-12_real64',
    'request%numerical%total_balance_tolerance = 1.0e-12_real64',
    'request%numerical%head_abs_tolerance = 1.0e-12_real64',
    'request%numerical%head_rel_tolerance = 1.0e-12_real64',
    'request%numerical%ponding_tolerance = 1.0e-12_real64',
    'request%base_state%pressure_head = head0',
]
for token in required:
    if token not in s:
        raise SystemExit(f'FVQ24 stimulus lock missing: {token}')
p.write_text(s, encoding='utf-8')
print('FVQ24_SHARED_RUNTIME_PROBE_ADAPTER=PASS')
PY

# The F-MR12 support fixture contains a known zero-correction TRIDAG stub. For
# the predecessor oracle replace exactly that test stub with the independently
# pinned SWAP 4.3.1 Thomas operation order used by F-SI18.
python3 "$BUILD/make_reference_tridag_stubs.py" \
  "$BUILD/fmr12/tests/fsi/fsi04_real_headcalc_stubs.f90" "$BUILD/fmr12-reference-stubs.f90" \
  > "$BUILD/reference-generator.log"
grep -Fq 'FSI18_ZERO_CORRECTION_TRIDAG_REPLACED=PASS' "$BUILD/reference-generator.log"
grep -Fq 'FSI18_REFERENCE_TRIDAG_OPERATION_ORDER=SWAP_4_3_1_THOMAS' "$BUILD/reference-generator.log"
echo 'FVQ24_FMR12_REFERENCE_TRIDAG=PASS_SW4_3_1_THOMAS'

# F-MR13 must not resolve any of the old external linear-solver symbols. Strip
# only those three routines from its otherwise byte-identical support fixture.
python3 - "$BUILD/fmr13-solverless-stubs.f90" <<'PY'
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
print('FVQ24_FMR13_SOLVERLESS_SUPPORT_FIXTURE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_and_run() {
  local tree="$1" mode="$2" opt="$3" support="$4" out="$5"
  mkdir -p "$out"
  local objects=()
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$support" -o "$out/support.o"
  objects+=("$out/support.o")

  local sources=(
    src/runtime/mod_a23bu_worker_execution_context.f90
    src/solver/mod_soil_water_solver_contract.f90
  )
  if [[ "$mode" == fmr13 ]]; then
    sources+=(src/solver/mod_reference_linear_solver.f90)
  fi
  sources+=(
    src/solver/mod_reference_richards_workspace.f90
    src/solver/mod_reference_richards_state_binding.f90
    src/solver/mod_b110_default_mvg_provider.f90
    src/solver/mod_b110_source_sink_provider.f90
    src/solver/mod_b110_root_sink_provider.f90
    src/legacy/b1_10_port/headcalc.f90
    src/adapter/mod_reference_richards_legacy_binding.f90
  )

  local src obj
  for src in "${sources[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$tree/$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" \
    -c "$BUILD/mod_fsi07_top_provider.f90" -o "$out/top-provider.o"
  objects+=("$out/top-provider.o")
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" \
    -c "$BUILD/probe.F90" -o "$out/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$out/probe.o" -o "$out/probe"
  "$out/probe" > "$out/run-a.txt" 2>&1 || { cat "$out/run-a.txt" >&2; return 1; }
  "$out/probe" > "$out/run-b.txt" 2>&1 || { cat "$out/run-b.txt" >&2; return 1; }
  cmp "$out/run-a.txt" "$out/run-b.txt"
  grep -Fq 'FSI18_REFERENCE_CONVERGENCE_CLIFF_PROBE PASS' "$out/run-a.txt"
  local i
  for i in 1 2 3 4 5; do
    grep -Fq "FSI18_CASE_${i}_CONVERGED=T" "$out/run-a.txt"
  done
}

for opt in 0 2; do
  compile_and_run "$BUILD/fmr12" fmr12 "$opt" "$BUILD/fmr12-reference-stubs.f90" "$BUILD/fmr12-o$opt"
  echo "FVQ24_FMR12_REFERENCE_O${opt}=PASS_ALL_FIVE_CONVERGED"

  compile_and_run "$ROOT" fmr13 "$opt" "$BUILD/fmr13-solverless-stubs.f90" "$BUILD/fmr13-o$opt"
  echo "FVQ24_FMR13_CANDIDATE_O${opt}=PASS_ALL_FIVE_CONVERGED"

  cmp "$BUILD/fmr12-o$opt/run-a.txt" "$BUILD/fmr13-o$opt/run-a.txt"
  echo "FVQ24_FMR12_FMR13_HEADCALC_O${opt}=PASS_BITWISE"
done

cmp "$BUILD/fmr12-o0/run-a.txt" "$BUILD/fmr12-o2/run-a.txt"
echo 'FVQ24_FMR12_O0_O2_IDENTITY=PASS'
cmp "$BUILD/fmr13-o0/run-a.txt" "$BUILD/fmr13-o2/run-a.txt"
echo 'FVQ24_FMR13_O0_O2_IDENTITY=PASS'
echo 'FVQ24_ALL_FIVE_CASES_CONVERGED_BOTH_SIDES=PASS'
echo 'FVQ24_NONZERO_CASES_2_TO_5_CONVERGED_BOTH_SIDES=PASS'
echo 'FVQ24_FIVE_CASE_PROBE_BAND_FALLBACK=ZERO_BOTH_SIDES'
echo "FVQ24_OUTPUT_SHA256=$(sha256sum "$BUILD/fmr13-o0/run-a.txt" | cut -d' ' -f1)"

git diff --quiet "$FMR13" -- src || {
  echo 'FVQ24_POST_TEST_PRODUCTION_IMMUTABILITY=FAIL' >&2; exit 1; }
echo 'FVQ24_POST_TEST_PRODUCTION_IMMUTABILITY=PASS'
echo 'FVQ24_FMR13_NONZERO_HEADCALC_PREDECESSOR_EQUIVALENCE_GATE PASS'
