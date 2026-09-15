#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail() { echo "F_VQ91_FAIL $*" >&2; exit 191; }

OWNER=479fafcbbb02d1e9f9f6cba48384fb4280051a38
OWNER_BASE=c53b4e4e966a6b0531e1e6224b2f8f1d7e02ece1
I08_HEAD=8362ea518e42238fe7094c3623a33de90e2de4ae
I08_BLOB=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
MODULE=src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90
DONOR_MODULE=src/process/mod_external_liquid_water_temperature.f90
OWNER_TEST=tests/eb/test_eb_i24_top_liquid_sensible_inflow_runtime.f90
OWNER_CONTRACT=tests/eb/EB-I24_CONTRACT.md
OWNER_GATE=tests/eb/run_eb_i24_top_liquid_sensible_inflow_gate.sh
OWNER_WORKFLOW=.github/workflows/eb-i24-top-liquid-sensible-inflow.yml
QUAL_GATE=tests/eb/run_f_vq91_eb_i24_independent_gate.sh
QUAL_WORKFLOW=.github/workflows/f-vq91-eb-i24-independent.yml
STATUS=qualification/F-VQ91_STATUS.json

# Evidence follows dependency validity rather than unrelated canonical movement.
git fetch -q origin integration/f-ci-canonical
LIVE="$(git rev-parse origin/integration/f-ci-canonical)"
git merge-base --is-ancestor "$OWNER_BASE" "$LIVE" || fail 'live canonical no longer descends from qualified owner base'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'qualification branch is not descended from exact owner head'

declare -A OWNER_BLOBS=(
  [$MODULE]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [$DONOR_MODULE]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [$OWNER_TEST]=acd53e6e38598264d172e17d2596bebfb024e7fe
  [$OWNER_CONTRACT]=b7a504860ed027e87dad04731af63c933f668984
  [$OWNER_GATE]=0a06a96cc7295d9e509083bfb712ea429df9d519
  [$OWNER_WORKFLOW]=8bdc1b585ef68ed326498931c303bea61b2e1e0d
)
for path in "${!OWNER_BLOBS[@]}"; do
  [[ "$(git rev-parse "$OWNER:$path")" == "${OWNER_BLOBS[$path]}" ]] || fail "owner blob mismatch $path"
  [[ "$(git rev-parse "HEAD:$path")" == "${OWNER_BLOBS[$path]}" ]] || fail "qualification mutated owner evidence $path"
done
echo "F_VQ91_OWNER_HEAD_GUARD=PASS owner=$OWNER live_canonical=$LIVE"

[[ "$(git rev-parse "$I08_HEAD:$DONOR_MODULE")" == "$I08_BLOB" ]] || fail 'historical I08 donor rule drifted'
[[ "$(git rev-parse "$OWNER:$DONOR_MODULE")" == "$I08_BLOB" ]] || fail 'owner did not replay exact I08 donor rule'
echo 'F_VQ91_EXACT_I08_DONOR_RULE_REPLAY=PASS'

declare -A DEPENDENCY_BLOBS=(
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=3506b453ba6a00111d182f29db8cbfb288001854
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_restricted_soil_temperature.f90]=fa4e1d7b48d3515e6569c9080d497178c25c4e85
  [src/process/mod_soil_temperature_contract.f90]=baa13df3975de2c699b0ec910477bcfa9b47f15e
)
for path in "${!DEPENDENCY_BLOBS[@]}"; do
  [[ "$(git rev-parse "$LIVE:$path")" == "${DEPENDENCY_BLOBS[$path]}" ]] || fail "live dependency drift $path"
  [[ "$(git rev-parse "$OWNER:$path")" == "${DEPENDENCY_BLOBS[$path]}" ]] || fail "owner dependency drift $path"
done
echo 'F_VQ91_DEPENDENCY_SURFACE_GUARD=PASS'

while IFS= read -r path; do
  case "$path" in "$QUAL_GATE"|"$QUAL_WORKFLOW"|"$STATUS") ;; *) fail "qualification mutated out-of-scope path: $path" ;; esac
done < <(git diff --name-only "$OWNER" HEAD)
echo 'F_VQ91_QUALIFICATION_ONLY_DELTA=PASS'

# Independent structural oracle for the deliberately bounded top-water route.
check_source_contract() {
  local file="$1"
  grep -Fq 'if (output%accepted_substeps /= 1) then' "$file" || return 1
  grep -Fq 'if (parameters%snow_active) then' "$file" || return 1
  grep -Fq 'if (observation%top_flux > 0.0_real64) then' "$file" || return 1
  grep -Fq 'inflow_cm = -observation%top_flux * (t1-t0)' "$file" || return 1
  grep -Fq 'resolve_external_liquid_water_temperature' "$file" || return 1
  grep -Fq 'evaluate_liquid_water_sensible_transport' "$file" || return 1
}
check_source_contract "$MODULE" || fail 'qualified source contract guard failed'
echo 'F_VQ91_STRUCTURAL_FAIL_CLOSED_GUARDS=PASS'

# Independent donor/provenance and enthalpy oracle.
ORACLE_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq91-oracle-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$ORACLE_DIR"
cat > "$ORACLE_DIR/oracle.f90" <<'F90'
program fvq91_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_external_liquid_water_temperature, only: external_liquid_water_temperature_t, &
       external_liquid_water_temperature_result_t, resolve_external_liquid_water_temperature, &
       EXT_LIQ_TEMP_NOT_REQUIRED, EXT_LIQ_TEMP_AVAILABLE, EXT_LIQ_TEMP_MISSING, EXT_LIQ_TEMP_INVALID_TRANSFER
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       initialize_liquid_water_sensible_enthalpy_parameters, evaluate_liquid_water_sensible_transport, LWSE_OK
  implicit none
  type(external_liquid_water_temperature_t) :: donor
  type(external_liquid_water_temperature_result_t) :: resolved
  type(liquid_water_sensible_enthalpy_parameters_t) :: energy
  real(real64) :: transported
  integer :: status
  donor = external_liquid_water_temperature_t()
  call resolve_external_liquid_water_temperature(1.25_real64, donor, resolved)
  if (resolved%status /= EXT_LIQ_TEMP_MISSING .or. .not. resolved%required) error stop 1
  call resolve_external_liquid_water_temperature(0.0_real64, donor, resolved)
  if (resolved%status /= EXT_LIQ_TEMP_NOT_REQUIRED .or. resolved%required) error stop 2
  call resolve_external_liquid_water_temperature(-1.0_real64, donor, resolved)
  if (resolved%status /= EXT_LIQ_TEMP_INVALID_TRANSFER) error stop 3
  donor%available = .true.; donor%temperature_c = 15.0_real64
  call resolve_external_liquid_water_temperature(1.25_real64, donor, resolved)
  if (resolved%status /= EXT_LIQ_TEMP_AVAILABLE .or. .not. resolved%required) error stop 4
  if (resolved%temperature_c /= 15.0_real64) error stop 5
  call initialize_liquid_water_sensible_enthalpy_parameters(1000.0_real64, 4000.0_real64, 5.0_real64, energy, status)
  if (status /= LWSE_OK) error stop 6
  call evaluate_liquid_water_sensible_transport(1.25_real64, resolved%temperature_c, energy, transported, status)
  if (status /= LWSE_OK) error stop 7
  if (abs(transported - 500000.0_real64) > 1.0e-9_real64) error stop 8
  write(*,'(A)') 'F_VQ91_INDEPENDENT_DONOR_ENTHALPY_ORACLE=PASS'
end program fvq91_oracle
F90
for opt in 0 2; do
  OUT="$ORACLE_DIR/o${opt}"; mkdir -p "$OUT"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J "$OUT" -I "$OUT" \
    "$DONOR_MODULE" src/process/mod_liquid_water_sensible_enthalpy.f90 "$ORACLE_DIR/oracle.f90" -o "$OUT/oracle"
  "$OUT/oracle" > "$OUT/output.txt"
  grep -Fx 'F_VQ91_INDEPENDENT_DONOR_ENTHALPY_ORACLE=PASS' "$OUT/output.txt"
done
cmp -s "$ORACLE_DIR/o0/output.txt" "$ORACLE_DIR/o2/output.txt"
echo 'F_VQ91_ORACLE_O0_O2_IDENTITY=PASS'

OWNER_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq91-owner-${GITHUB_RUN_ID:-local}-$$"
MUTANT_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq91-mutant-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  git worktree remove --force "$OWNER_TREE" >/dev/null 2>&1 || true
  git worktree remove --force "$MUTANT_TREE" >/dev/null 2>&1 || true
  rm -rf "$ORACLE_DIR"
}
trap cleanup EXIT

# Exact owner evidence replay, changing only the obsolete exact-live-head assertion
# in a disposable script. Live dependencies were independently locked above.
git worktree add --detach "$OWNER_TREE" "$OWNER" >/dev/null
python3 - "$OWNER_TREE/$OWNER_GATE" "$OWNER_TREE/fvq91-owner-replay.sh" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
repls = {
 'git fetch origin integration/f-ci-canonical\n': ': # live canonical checked by F-VQ91 dependency guard\n',
 'test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL"\n': ': # obsolete exact-head lock bypassed only in disposable replay\n',
 "echo 'EB_I24_LIVE_CANONICAL_LOCK=PASS'\n": "echo 'EB_I24_REPLAY_BASE_AND_DEPENDENCY_LOCK=PASS'\n",
}
for old, new in repls.items():
    if s.count(old) != 1: raise SystemExit(f'owner replay anchor mismatch: {old!r}')
    s = s.replace(old, new)
Path(sys.argv[2]).write_text(s)
PY
(cd "$OWNER_TREE" && bash fvq91-owner-replay.sh)
echo 'F_VQ91_EXACT_OWNER_RUNTIME_REPLAY=PASS'

# Runtime-only replay is derived from the immutable owner gate after its static
# assertions, so adversarial mutations must fail executable evidence.
git worktree add --detach "$MUTANT_TREE" "$OWNER" >/dev/null
awk '/^COMMON=/{emit=1} emit{print}' "$MUTANT_TREE/$OWNER_GATE" > "$MUTANT_TREE/fvq91-runtime-replay.sh"
grep -Fq 'COMMON=' "$MUTANT_TREE/fvq91-runtime-replay.sh" || fail 'could not derive runtime replay'
run_runtime_mutant() {
  local label="$1" expected="$2" log="$MUTANT_TREE/fvq91-${1}.log"
  set +e; (cd "$MUTANT_TREE" && bash fvq91-runtime-replay.sh) >"$log" 2>&1; local rc=$?; set -e
  [[ $rc -ne 0 ]] || { cat "$log" >&2; fail "$label mutant unexpectedly qualified"; }
  grep -Fq 'EB_I24_TEST_FAIL' "$log" || { cat "$log" >&2; fail "$label mutant did not fail executable owner evidence"; }
  grep -Fq "$expected" "$log" || { cat "$log" >&2; fail "$label mutant failed for unexpected reason"; }
  echo "F_VQ91_${label^^}_MUTANT_REJECTED=PASS"
  git -C "$MUTANT_TREE" checkout -- "$MODULE"
}

python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old='inflow_cm = -observation%top_flux * (t1-t0)'; new='inflow_cm = observation%top_flux * (t1-t0)'
if s.count(old)!=1: raise SystemExit('orientation anchor mismatch')
p.write_text(s.replace(old,new))
PY
run_runtime_mutant orientation accepted

python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old="""    case default
      publication%top_status_value = EB_I24_TOP_DONOR_UNAVAILABLE
"""; new="""    case default
      publication%boundary_value%top_advective_available = .true.
      publication%boundary_value%top_advective_into_j_m2 = 0.0_real64
      publication%top_status_value = EB_I24_TOP_DONOR_UNAVAILABLE
"""
if s.count(old)!=1: raise SystemExit('missing donor anchor mismatch')
p.write_text(s.replace(old,new))
PY
run_runtime_mutant missing_donor_as_zero 'missing donor is unavailable not zero'

python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); g='if (observation%top_flux > 0.0_real64) then'; a='inflow_cm = -observation%top_flux * (t1-t0)'
if s.count(g)!=1 or s.count(a)!=1: raise SystemExit('outflow anchor mismatch')
p.write_text(s.replace(g,'if (.false.) then').replace(a,'inflow_cm = abs(observation%top_flux) * (t1-t0)'))
PY
run_runtime_mutant outflow_donor_reuse 'outflow donor direction guarded'

# Multi-substep broadening cannot be runtime-qualified from last_observation;
# independently reject it with the structural oracle rather than fabricating an aggregate.
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old='if (output%accepted_substeps /= 1) then'; new='if (output%accepted_substeps < 1) then'
if s.count(old)!=1: raise SystemExit('multi-substep anchor mismatch')
p.write_text(s.replace(old,new))
PY
set +e; check_source_contract "$MUTANT_TREE/$MODULE"; rc=$?; set -e
[[ $rc -ne 0 ]] || fail 'multi-substep broadening mutant unexpectedly passed independent source contract'
echo 'F_VQ91_MULTISUBSTEP_BROADENING_MUTANT_REJECTED=PASS'

echo 'F_VQ91_INDEPENDENT_QUALIFICATION=PASS'
echo "F_VQ91_QUALIFIED_OWNER=$OWNER"
echo "F_VQ91_LIVE_CANONICAL=$LIVE"
