#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail() { echo "F_VQ93_FAIL $*" >&2; exit 193; }

OWNER=08be50f248f3e169a3f1aeebd263cfe95b0dccd0
OWNER_BASE=1f33328e2ddc0d28450d35647c1c97f293b1e622
OWNER_BRANCH=work/eb-i25-accepted-multisubstep-sensible-boundary
MODULE=src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
CARRIER=src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
OWNER_TEST=tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90
OWNER_CONTRACT=tests/eb/EB-I25_CONTRACT.md
OWNER_GATE=tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh
OWNER_WORKFLOW=.github/workflows/eb-i25-multisubstep-sensible-boundary.yml
OWNER_CHECKPOINT=tests/eb/EB-I25_CHECKPOINT.json
QUAL_GATE=tests/eb/run_f_vq93_eb_i25_independent_gate.sh
QUAL_WORKFLOW=.github/workflows/f-vq93-eb-i25-independent.yml
STATUS=qualification/F-VQ93_STATUS.json

# Evidence follows relevant dependency validity, not unrelated canonical movement.
git fetch -q origin integration/f-ci-canonical
LIVE="$(git rev-parse origin/integration/f-ci-canonical)"
git merge-base --is-ancestor "$OWNER_BASE" "$LIVE" || fail 'live canonical no longer descends from EB-I25 owner base'
[[ "$(git merge-base "$OWNER" HEAD)" == "$OWNER" ]] || fail 'qualification branch is not descended from exact EB-I25 owner head'

OWNER_PATHS=(
  "$MODULE"
  "$BACKEND"
  "$CARRIER"
  "$OWNER_TEST"
  "$OWNER_CONTRACT"
  "$OWNER_GATE"
  "$OWNER_WORKFLOW"
  "$OWNER_CHECKPOINT"
)
for path in "${OWNER_PATHS[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$OWNER:$path")" ]] || fail "qualification mutated owner evidence $path"
done

echo "F_VQ93_OWNER_HEAD_GUARD=PASS owner=$OWNER live_canonical=$LIVE"

# These inherited dependencies were immutable across the EB-I25 owner delta.
DEPENDENCIES=(
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_eb_i23_sensible_boundary_runtime.f90
  src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/process/mod_external_liquid_water_temperature.f90
  src/process/mod_whole_column_sensible_energy_accounting.f90
  src/process/mod_restricted_soil_temperature.f90
  src/process/mod_soil_temperature_contract.f90
)
for path in "${DEPENDENCIES[@]}"; do
  [[ "$(git rev-parse "$LIVE:$path")" == "$(git rev-parse "$OWNER_BASE:$path")" ]] || fail "live dependency drift $path"
  [[ "$(git rev-parse "$OWNER:$path")" == "$(git rev-parse "$OWNER_BASE:$path")" ]] || fail "owner unexpectedly changed inherited dependency $path"
done
echo 'F_VQ93_DEPENDENCY_SURFACE_GUARD=PASS'

while IFS= read -r path; do
  case "$path" in "$QUAL_GATE"|"$QUAL_WORKFLOW"|"$STATUS") ;; *) fail "qualification mutated out-of-scope path: $path" ;; esac
done < <(git diff --name-only "$OWNER" HEAD)
echo 'F_VQ93_QUALIFICATION_ONLY_DELTA=PASS'

python3 - "$OWNER_CHECKPOINT" "$OWNER" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
owner=sys.argv[2]
assert p['workunit']=='EB-I25'
assert p['owner_head_sha']==owner
assert p['owner_verdict']=='qualifies'
assert 'F-VQ93' in p['next_action']
assert p['owner_qualification_run'].endswith('/34986684267')
print('F_VQ93_OWNER_CHECKPOINT_PROVENANCE=PASS')
PY

check_i25_contract() {
  local file="$1"
  grep -Fq 'numerical_config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF' "$file" || return 1
  grep -Fq 'output%accepted_substeps /= 1' "$file" || return 1
  grep -Fq 'publication%carrier_sample_count_value /= 2' "$file" || return 1
  grep -Fq 'if (parameters%snow_active) then' "$file" || return 1
  grep -Fq 'if (any_outflow) then' "$file" || return 1
  grep -Fq 'publication%boundary_value%top_advective_available = .false.' "$file" || return 1
  grep -Fq 'inflow_cm = -total_exchange' "$file" || return 1
  grep -Fq 'resolve_external_liquid_water_temperature' "$file" || return 1
  grep -Fq 'evaluate_liquid_water_sensible_transport' "$file" || return 1
  grep -Fq 'J_CM2_TO_J_M2 * boundary_energy_j_cm2' "$file" || return 1
  grep -Fq 'EB_I25_TOP_SINGLE_SUBSTEP_INHERITED' "$file" || return 1
}
check_i25_contract "$MODULE" || fail 'independent I25 source contract failed'
grep -Fq 'type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier' "$BACKEND" || fail 'top carrier is not attempt-owned'
grep -Fq 'call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)' "$BACKEND" || fail 'top carrier missing checkpoint copy'
grep -Fq 'call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)' "$BACKEND" || fail 'top carrier missing rollback restore'
grep -Fq 'record_top_sensible_boundary_sample' "$BACKEND" || fail 'accepted trial sample recording seam missing'
grep -Fq 'does not publish a whole-column sensible-energy residual' "$OWNER_CONTRACT" || fail 'nonclaim missing from contract'
grep -Fq 'complete SWAP5 Energy Balance' "$OWNER_CONTRACT" || fail 'full-EB nonclaim missing from contract'
echo 'F_VQ93_STRUCTURAL_FAIL_CLOSED_GUARDS=PASS'

# Independent executable oracle for the carrier itself. It constructs a rejected
# working sample, restores the checkpoint, then verifies that only the two
# accepted contiguous samples are materialized and aggregated.
ORACLE_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq93-oracle-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$ORACLE_DIR"
cat > "$ORACLE_DIR/oracle.f90" <<'F90'
program fvq93_carrier_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_carrier_t, &
       fmr_top_sensible_boundary_candidate_t, fmr_top_sensible_boundary_sample_t
  implicit none
  type(fmr_top_sensible_boundary_carrier_t) :: live, checkpoint
  type(fmr_top_sensible_boundary_candidate_t) :: candidate
  type(fmr_top_sensible_boundary_sample_t) :: sample
  real(real64) :: total_exchange, total_energy, a, b
  logical :: ok, available

  call live%initialize(3, ok); if (.not. ok) error stop 1
  call live%append(0.0_real64, 0.5_real64, -0.10_real64, .true., 2.0_real64, 3.0_real64, 1.0_real64, ok)
  if (.not. ok) error stop 2
  call live%copy_to(checkpoint)

  ! This sample represents discarded trial-local work and must disappear on restore.
  call live%append(0.5_real64, 0.75_real64, -99.0_real64, .true., 7.0_real64, 9.0_real64, 2.0_real64, ok)
  if (.not. ok) error stop 3
  call live%restore_from(checkpoint)
  call live%append(0.5_real64, 1.0_real64, -0.20_real64, .true., 3.0_real64, 4.0_real64, 1.0_real64, ok)
  if (.not. ok) error stop 4

  call live%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
  if (.not. ok .or. .not. candidate%ready()) error stop 5
  if (candidate%sample_count() /= 2) error stop 6
  call candidate%sample_at(1, sample, available); if (.not. available) error stop 7
  if (abs(sample%top_exchange_native + 0.10_real64) > 1.0e-14_real64) error stop 8
  call candidate%sample_at(2, sample, available); if (.not. available) error stop 9
  if (abs(sample%top_exchange_native + 0.20_real64) > 1.0e-14_real64) error stop 10
  call candidate%total_top_exchange(total_exchange, available); if (.not. available) error stop 11
  if (abs(total_exchange + 0.30_real64) > 1.0e-14_real64) error stop 12
  call candidate%total_boundary_energy(total_energy, available); if (.not. available) error stop 13
  if (abs(total_energy - 5.0_real64) > 1.0e-14_real64) error stop 14
  call candidate%interval(a, b, available); if (.not. available) error stop 15
  if (a /= 0.0_real64 .or. b /= 1.0_real64) error stop 16

  ! Non-contiguous accepted provenance must fail closed.
  call live%clear(); call live%initialize(2, ok); if (.not. ok) error stop 17
  call live%append(0.0_real64, 0.4_real64, -0.1_real64, .true., 1.0_real64, 2.0_real64, 1.0_real64, ok)
  if (.not. ok) error stop 18
  call live%append(0.5_real64, 1.0_real64, -0.2_real64, .true., 1.0_real64, 2.0_real64, 1.0_real64, ok)
  if (.not. ok) error stop 19
  call live%materialize_candidate(0.0_real64, 1.0_real64, candidate, ok)
  if (ok .or. candidate%ready()) error stop 20

  write(*,'(A)') 'F_VQ93_INDEPENDENT_CARRIER_ROLLBACK_ORACLE=PASS'
end program fvq93_carrier_oracle
F90
for opt in 0 2; do
  OUT="$ORACLE_DIR/o${opt}"; mkdir -p "$OUT"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -O"$opt" -J "$OUT" -I "$OUT" \
    "$CARRIER" "$ORACLE_DIR/oracle.f90" -o "$OUT/oracle"
  "$OUT/oracle" > "$OUT/output.txt"
  grep -Fx 'F_VQ93_INDEPENDENT_CARRIER_ROLLBACK_ORACLE=PASS' "$OUT/output.txt"
done
cmp -s "$ORACLE_DIR/o0/output.txt" "$ORACLE_DIR/o2/output.txt" || fail 'carrier oracle O0/O2 drift'
echo 'F_VQ93_CARRIER_ORACLE_O0_O2_IDENTITY=PASS'

OWNER_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq93-owner-${GITHUB_RUN_ID:-local}-$$"
MUTANT_TREE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq93-mutant-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  git worktree remove --force "$OWNER_TREE" >/dev/null 2>&1 || true
  git worktree remove --force "$MUTANT_TREE" >/dev/null 2>&1 || true
  rm -rf "$ORACLE_DIR"
}
trap cleanup EXIT

# Replay the immutable owner executable gate. Only its obsolete exact-live-head
# assertion is bypassed in this disposable copy; dependency validity was checked above.
git worktree add --detach "$OWNER_TREE" "$OWNER" >/dev/null
python3 - "$OWNER_TREE/$OWNER_GATE" "$OWNER_TREE/fvq93-owner-replay.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old='test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL"\n'
if s.count(old)!=1: raise SystemExit('owner exact-head replay anchor mismatch')
s=s.replace(old, ': # live dependency validity checked independently by F-VQ93\n')
Path(sys.argv[2]).write_text(s)
PY
(cd "$OWNER_TREE" && bash fvq93-owner-replay.sh)
echo 'F_VQ93_EXACT_OWNER_RUNTIME_REPLAY=PASS'

# Adversarial source broadening must be rejected by an oracle not owned by EB-I25.
git worktree add --detach "$MUTANT_TREE" "$OWNER" >/dev/null
python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old='publication%carrier_sample_count_value /= 2'; new='publication%carrier_sample_count_value < 2'
if s.count(old)!=1: raise SystemExit('sample-count mutant anchor mismatch')
p.write_text(s.replace(old,new))
PY
set +e; check_i25_contract "$MUTANT_TREE/$MODULE"; rc=$?; set -e
[[ $rc -ne 0 ]] || fail 'sample-count broadening mutant unexpectedly qualified'
echo 'F_VQ93_SAMPLE_COUNT_BROADENING_MUTANT_REJECTED=PASS'
git -C "$MUTANT_TREE" checkout -- "$MODULE"

python3 - "$MUTANT_TREE/$MODULE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old='if (any_outflow) then'; new='if (.false.) then'
if s.count(old)!=1: raise SystemExit('outflow mutant anchor mismatch')
p.write_text(s.replace(old,new))
PY
set +e; check_i25_contract "$MUTANT_TREE/$MODULE"; rc=$?; set -e
[[ $rc -ne 0 ]] || fail 'outflow fail-closed mutant unexpectedly qualified'
echo 'F_VQ93_OUTFLOW_BROADENING_MUTANT_REJECTED=PASS'
git -C "$MUTANT_TREE" checkout -- "$MODULE"

python3 - "$MUTANT_TREE/$BACKEND" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); old='call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)'; new='! mutant removes top carrier rollback restore'
if s.count(old)!=1: raise SystemExit('rollback mutant anchor mismatch')
p.write_text(s.replace(old,new))
PY
if grep -Fq 'call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)' "$MUTANT_TREE/$BACKEND"; then
  fail 'rollback-removal mutant unexpectedly retained restore seam'
fi
echo 'F_VQ93_ROLLBACK_REMOVAL_MUTANT_REJECTED=PASS'

echo 'F_VQ93_INDEPENDENT_QUALIFICATION=PASS'
echo "F_VQ93_QUALIFIED_OWNER=$OWNER"
echo "F_VQ93_LIVE_CANONICAL=$LIVE"
