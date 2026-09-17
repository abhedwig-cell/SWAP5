#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PRE_CANONICAL="b142669ddc8c280ef08b31f5af65c120c1cfeaf1"
OWNER_HEAD="e1f086d6f1dc2b60c2b1fc5a2b61b52dc9fa452b"
FVQ104_HEAD="376b42e274caa09e9f69fb974e292592f5424244"
FVQ104_STATUS_BLOB="bc0c2d0ba92643faac81927f21931289b87766a7"

declare -A OWNER_BLOBS=(
  [src/runtime/mod_modflow6_swap_predictor_response.f90]="e16c9935670643fbbbcb9388eb52ba698764c493"
  [src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90]="15c859e5cb62ba8442879fdec153438e4aadff89"
  [src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90]="47bc673094132e4f128647b467a861c51b2aba50"
  [src/runtime/mod_modflow6_swap_predictor_origin.f90]="b7bc66ad473ae404f5c0b1e54b0a70d536038c33"
  [src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90]="f32453168667917a06d8fde483887e1e9a5cbffd"
)

git merge-base --is-ancestor "$PRE_CANONICAL" HEAD

for path in "${!OWNER_BLOBS[@]}"; do
  test "$(git rev-parse "$OWNER_HEAD:$path")" = "${OWNER_BLOBS[$path]}"
  test "$(git rev-parse "HEAD:$path")" = "${OWNER_BLOBS[$path]}"
done

mapfile -t src_delta < <(git diff --name-only "$PRE_CANONICAL..HEAD" -- 'src/**' | sort)
expected_src=(
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
)
test "${#src_delta[@]}" -eq "${#expected_src[@]}"
for i in "${!expected_src[@]}"; do
  test "${src_delta[$i]}" = "${expected_src[$i]}"
done
echo 'FCI97_EXACT_FIVE_MODULE_PRODUCTION_DELTA=PASS'

test "$(git rev-parse HEAD:qualification/F-VQ104_STATUS.json)" = "$FVQ104_STATUS_BLOB"
test "$(git rev-parse "$FVQ104_HEAD:qualification/F-VQ104_STATUS.json")" = "$FVQ104_STATUS_BLOB"

python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('qualification/F-VQ104_STATUS.json').read_text())
assert s['verdict'] == 'INDEPENDENTLY_QUALIFIED_FOR_ADMISSION_REVIEW'
assert s['canonical_baseline'] == 'dba238b4b20551dcc36e9121ffe25f19a5b1ac0e'
assert s['owner']['qualified_source_head'] == 'e1f086d6f1dc2b60c2b1fc5a2b61b52dc9fa452b'
assert s['independence']['verifier_production_delta'] == 'NONE'
assert s['independence']['production_finite_difference_runtime_fallback_admitted'] is False
assert 'no active-drainage analytic tangent' in s['preserved_limits']
assert 'no MODFLOW6/XMI backend' in s['preserved_limits']
print('FCI97_FVQ104_EVIDENCE_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
response=Path('src/runtime/mod_modflow6_swap_predictor_response.f90').read_text()
adapter=Path('src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90').read_text()
assembler=Path('src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90').read_text()
assert 'u = duration_day / dh_bot_end_cm_per_qbot_cm_per_day' in response
assert 'q_u_cm_per_day = u * delta_h_bot_cm / duration_day - q_bot_predictor_cm_per_day' in response
assert 'endpoint%coverage%drainage_covered = .false.' in adapter
assert 'endpoint%authoritative = .false.' in adapter
for token in [
    'candidate%current_lineage_id() /= origin%lineage%swap_lineage_id',
    'candidate%origin_revision() /= origin%lineage%swap_origin_revision',
    'kernel_result%bottom_interface_exchange_available',
    'qbot_cm_per_day = -kernel_result%terminal_bottom_outward_flux_native',
    'endpoint%coverage%tangent_complete()'
]:
    assert token in assembler, token
low=assembler.lower()
for forbidden in ['commit_candidate','commit_prepared','groundwater_commit','publication_committed = .true.']:
    assert forbidden not in low, forbidden
print('FCI97_PRODUCTION_CONTRACT_AUDIT=PASS')
print('FCI97_ACTIVE_DRAINAGE_REMAINS_FAIL_CLOSED=PASS')
print('FCI97_NONCOMMITTING_PREDICTOR_ASSEMBLER=PASS')
PY

work="$(mktemp -d)"
trap 'rm -rf "$work"; rm -f tests/fgc/test_fgc30_production_predictor_tangent_endpoint.f90 tests/fgc/run_fgc30_production_predictor_tangent_endpoint.sh' EXIT

# Replay the qualified owner production endpoint gate against the admission
# postimage without admitting owner test artifacts.
test ! -e tests/fgc/test_fgc30_production_predictor_tangent_endpoint.f90
test ! -e tests/fgc/run_fgc30_production_predictor_tangent_endpoint.sh
git show "$OWNER_HEAD:tests/fgc/test_fgc30_production_predictor_tangent_endpoint.f90" >   tests/fgc/test_fgc30_production_predictor_tangent_endpoint.f90
git show "$OWNER_HEAD:tests/fgc/run_fgc30_production_predictor_tangent_endpoint.sh" >   tests/fgc/run_fgc30_production_predictor_tangent_endpoint.sh
bash tests/fgc/run_fgc30_production_predictor_tangent_endpoint.sh > "$work/owner.txt"
for marker in   FGC30_PRODUCTION_ACCEPTED_TRAJECTORY_BINDING   FGC30_PRODUCTION_TANGENT_ENDPOINT_AUTHORITATIVE   FGC30_PRODUCTION_CENTERED_FD_ORACLE   FGC30_PRODUCTION_TANGENT_FD_AGREEMENT   FGC30_PRODUCTION_CANDIDATE_ASSEMBLER   FGC30_PRODUCTION_TYPED_PREDICTOR_RESPONSE   FGC30_PRODUCTION_PROVENANCE_FAIL_CLOSED   FGC30_PRODUCTION_DRAINAGE_TANGENT_FAIL_CLOSED   FGC30_PRODUCTION_TANGENT_O0_O2_IDENTITY   FGC30_PRODUCTION_PREDICTOR_TANGENT_QUALIFICATION; do
  grep -q "^${marker}=PASS$" "$work/owner.txt"
done
cat "$work/owner.txt"
echo 'FCI97_OWNER_PRODUCTION_REPLAY=PASS'

# Replay the independent verifier fixture against the exact admission postimage.
git show "$FVQ104_HEAD:tests/fvq/test_fvq104_fgc30_independent.f90" > "$work/test_fvq104.f90"

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
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
)

compile_vq(){
  local opt="$1"
  local out="$work/vq_o$opt"
  mkdir -p "$out"
  local objects=()
  local source obj
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$work/test_fvq104.f90" -o "$out/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
}
compile_vq 0
compile_vq 2
diff -u "$work/vq_o0/output.txt" "$work/vq_o2/output.txt"

for marker in   FVQ104_INDEPENDENT_BOTTOM_FACE_FD   FVQ104_DRAINAGE_TANGENT_FAIL_CLOSED   FVQ104_INDEPENDENT_U_QU_ALGEBRA   FVQ104_RESPONSE_COVERAGE_FAIL_CLOSED   FVQ104_ORIGIN_SWAP_HEAD_PROVENANCE   FVQ104_ORIGIN_FAIL_CLOSED   FVQ104_INDEPENDENT_NUMERICAL_ORACLE; do
  grep -q "^${marker}=PASS$" "$work/vq_o0/output.txt"
done
cat "$work/vq_o0/output.txt"

echo "FCI97_PRE_CANONICAL=PASS:$PRE_CANONICAL"
echo "FCI97_OWNER_HEAD=PASS:$OWNER_HEAD"
echo "FCI97_FVQ104_HEAD=PASS:$FVQ104_HEAD"
echo 'FCI97_INDEPENDENT_REPLAY=PASS'
echo 'FCI97_INDEPENDENT_O0_O2_IDENTITY=PASS'
echo 'FCI97_DECISION=QUALIFIED_FOR_CANONICAL_ADMISSION'
