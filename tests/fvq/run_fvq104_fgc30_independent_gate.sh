#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANONICAL="dba238b4b20551dcc36e9121ffe25f19a5b1ac0e"
OWNER_BASE="8e0de81a62527bc7d8e49068f1ffd4a8a85aeec3"
OWNER_HEAD="e1f086d6f1dc2b60c2b1fc5a2b61b52dc9fa452b"

declare -A OWNER_BLOBS=(
  [src/runtime/mod_modflow6_swap_predictor_response.f90]="e16c9935670643fbbbcb9388eb52ba698764c493"
  [src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90]="15c859e5cb62ba8442879fdec153438e4aadff89"
  [src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90]="47bc673094132e4f128647b467a861c51b2aba50"
  [src/runtime/mod_modflow6_swap_predictor_origin.f90]="b7bc66ad473ae404f5c0b1e54b0a70d536038c33"
  [src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90]="f32453168667917a06d8fde483887e1e9a5cbffd"
)

git merge-base --is-ancestor "$OWNER_BASE" "$CANONICAL"
git merge-base --is-ancestor "$OWNER_BASE" "$OWNER_HEAD"
test "$(git merge-base "$OWNER_BASE" "$OWNER_HEAD")" = "$OWNER_BASE"

for path in "${!OWNER_BLOBS[@]}"; do
  test "$(git rev-parse "$OWNER_HEAD:$path")" = "${OWNER_BLOBS[$path]}"
done

mapfile -t owner_src_delta < <(git diff --name-only "$OWNER_BASE..$OWNER_HEAD" -- 'src/**' | sort)
expected_src=(
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
)
test "${#owner_src_delta[@]}" -eq "${#expected_src[@]}"
for i in "${!expected_src[@]}"; do test "${owner_src_delta[$i]}" = "${expected_src[$i]}"; done

if git diff --name-only "$CANONICAL..HEAD" -- 'src/**' | grep -q .; then
  echo 'FVQ104_SCOPE_FAIL verifier branch modifies production source' >&2
  exit 20
fi
while IFS= read -r path; do
  case "$path" in
    tests/fvq/test_fvq104_fgc30_independent.f90|tests/fvq/run_fvq104_fgc30_independent_gate.sh|.github/workflows/f-vq104-fgc30-independent.yml|qualification/F-VQ104_*) ;;
    *) echo "FVQ104_SCOPE_FAIL unexpected verifier path: $path" >&2; exit 21 ;;
  esac
done < <(git diff --name-only "$CANONICAL..HEAD")

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/owner"
for path in "${!OWNER_BLOBS[@]}"; do
  git show "$OWNER_HEAD:$path" > "$work/owner/$(basename "$path")"
done

python3 - "$work/owner" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
response=(root/'mod_modflow6_swap_predictor_response.f90').read_text()
bottom=(root/'mod_modflow6_swap_prescribed_qbot_bottom_face.f90').read_text()
adapter=(root/'mod_modflow6_swap_predictor_tangent_adapter.f90').read_text()
origin=(root/'mod_modflow6_swap_predictor_origin.f90').read_text()
assembler=(root/'mod_modflow6_swap_predictor_candidate_assembler.f90').read_text()

for token in [
    'u = duration_day / dh_bot_end_cm_per_qbot_cm_per_day',
    'q_u_cm_per_day = u * delta_h_bot_cm / duration_day - q_bot_predictor_cm_per_day',
    'case (MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT)',
    'if (.not. coverage%tangent_complete())'
]:
    assert token in response, token
for token in [
    'pressure_head_cm = bottom_node_pressure_head_cm + bottom_half_distance_cm',
    'qbot_cm_per_day * conductivity_direction / bottom_conductivity_cm_per_day**2',
    'swap_bottom_pressure_head_cm_to_interface_head_m'
]:
    assert token in bottom, token
for token in [
    'endpoint%coverage%drainage_covered = .false.',
    'if (.not. endpoint%coverage%tangent_complete())',
    'endpoint%authoritative = .false.'
]:
    assert token in adapter, token
for token in [
    'origin%h_bot_start_m = accepted_interface%h_swap_m',
    'origin%accepted_h_groundwater_m = accepted_interface%h_groundwater_m',
    'q_swap_m_per_s + accepted_interface%q_groundwater_m_per_s'
]:
    assert token in origin, token
for token in [
    'candidate%current_lineage_id() /= origin%lineage%swap_lineage_id',
    'candidate%origin_revision() /= origin%lineage%swap_origin_revision',
    'candidate%origin_interval',
    'kernel_result%bottom_interface_exchange_available',
    'qbot_cm_per_day = -kernel_result%terminal_bottom_outward_flux_native',
    'endpoint%trajectory_generation /= kernel_result%accepted_trajectory_direction%generation',
    'endpoint%coverage%tangent_complete()',
    'call compose_modflow6_swap_predictor_response'
]:
    assert token in assembler, token
for forbidden in ['commit_candidate', 'commit_prepared', 'groundwater_commit', 'publication_committed = .true.']:
    assert forbidden not in assembler.lower(), forbidden
print('FVQ104_OWNER_STATIC_CONTRACT=PASS')
print('FVQ104_CANDIDATE_PROVENANCE_GUARDS=PASS')
print('FVQ104_NONCOMMITTING_ASSEMBLER=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  "$work/owner/mod_modflow6_swap_predictor_response.f90"
  "$work/owner/mod_modflow6_swap_prescribed_qbot_bottom_face.f90"
  "$work/owner/mod_modflow6_swap_predictor_tangent_adapter.f90"
  "$work/owner/mod_modflow6_swap_predictor_origin.f90"
  "$work/owner/mod_modflow6_swap_predictor_candidate_assembler.f90"
)

compile_and_run(){
  local opt="$1"
  local out="$work/o$opt"
  mkdir -p "$out"
  local objects=()
  local source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c tests/fvq/test_fvq104_fgc30_independent.f90 -o "$out/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
}

compile_and_run 0
compile_and_run 2
diff -u "$work/o0/output.txt" "$work/o2/output.txt"

for marker in   FVQ104_INDEPENDENT_BOTTOM_FACE_FD   FVQ104_DRAINAGE_TANGENT_FAIL_CLOSED   FVQ104_INDEPENDENT_U_QU_ALGEBRA   FVQ104_RESPONSE_COVERAGE_FAIL_CLOSED   FVQ104_ORIGIN_SWAP_HEAD_PROVENANCE   FVQ104_ORIGIN_FAIL_CLOSED   FVQ104_INDEPENDENT_NUMERICAL_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/o0/output.txt"
done

cat "$work/o0/output.txt"
echo "FVQ104_CANONICAL_BASE=PASS:$CANONICAL"
echo "FVQ104_OWNER_HEAD=PASS:$OWNER_HEAD"
for path in "${!OWNER_BLOBS[@]}"; do
  echo "FVQ104_OWNER_BLOB=PASS:$path:${OWNER_BLOBS[$path]}"
done
echo 'FVQ104_VERIFIER_PRODUCTION_DELTA=PASS:NONE'
echo 'FVQ104_O0_O2_IDENTITY=PASS'
echo 'FVQ104_DECISION=INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW'
