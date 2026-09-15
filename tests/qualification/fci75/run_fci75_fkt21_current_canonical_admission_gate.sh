#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

BASE=70fae8bb570b56ff0f1002e14c6c67e6adb6be53
OWNER=19a67f7c398fcadbcbc9729509680a1c0c5424f3
OWNER_RECEIPT=eee5f15a742d11b268d2a872a4c376e1f2c475c0
VQ92=f4f98637e963e07e2bedf7ef6acbcaab36e07e5a
FSI35_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae
FKT15_DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
BUILD="${RUNNER_TEMP:-/tmp}/fci75-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FCI75_FAIL $*" >&2; exit 75; }

for object in "$BASE" "$OWNER" "$OWNER_RECEIPT" "$VQ92" "$FSI35_SOURCE" "$FKT15_DONOR"; do
  git cat-file -e "$object^{commit}" 2>/dev/null || git fetch --no-tags origin "$object" >/dev/null 2>&1 || fail "missing authority $object"
done

git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate does not descend from reconciled canonical base'
LIVE_CANONICAL="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE_CANONICAL" == "$BASE" ]] || fail "live canonical moved expected=$BASE actual=$LIVE_CANONICAL"
echo "FCI75_CANONICAL_BASE_LOCK=PASS head=$LIVE_CANONICAL"

allowed=(
  integration/f-ci/F-CI75_STATUS.json
  src/adapter/mod_b110_production_soil_water_task2.f90
  src/adapter/mod_b1_10_recoverable_reference_model.f90
  src/adapter/mod_b1_10_reference_model.f90
  src/adapter/mod_b1_10_accepted_trajectory_transaction_executor.f90
  src/legacy/b1_10_port/soilwater.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_accepted_trajectory_transaction_binding.f90
  tests/fkt/run_fkt21_qualification.sh
  tests/fkt/test_fkt21_accepted_trajectory_direction.f90
  tests/fkt/test_fkt21_provenance.f90
  tests/fkt/test_fkt21_publication_identity.f90
  tests/fkt/test_fkt21_transaction_binding.f90
  tests/fkt/test_fkt21_worker_acceptance_binding.f90
  tests/qualification/fci75/run_fci75_fkt21_current_canonical_admission_gate.sh
  .github/workflows/fci75-fkt21-current-canonical-admission.yml
)
mapfile -t changed < <(git diff --name-only "$BASE"..HEAD)
for path in "${changed[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do [[ "$path" == "$candidate" ]] && ok=1 && break; done
  [[ "$ok" -eq 1 ]] || fail "out-of-scope candidate path: $path"
done
echo 'FCI75_SCOPE_LOCK=PASS'

production=(
  src/adapter/mod_b110_production_soil_water_task2.f90
  src/adapter/mod_b1_10_recoverable_reference_model.f90
  src/adapter/mod_b1_10_reference_model.f90
  src/adapter/mod_b1_10_accepted_trajectory_transaction_executor.f90
  src/legacy/b1_10_port/soilwater.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_accepted_trajectory_transaction_binding.f90
)
owner_tests=(
  tests/fkt/run_fkt21_qualification.sh
  tests/fkt/test_fkt21_accepted_trajectory_direction.f90
  tests/fkt/test_fkt21_provenance.f90
  tests/fkt/test_fkt21_publication_identity.f90
  tests/fkt/test_fkt21_transaction_binding.f90
  tests/fkt/test_fkt21_worker_acceptance_binding.f90
)
for path in "${production[@]}" "${owner_tests[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$OWNER:$path")" ]] || fail "owner-qualified blob mismatch: $path"
done
echo 'FCI75_OWNER_POSTIMAGE_EXACT=PASS'

check_si37(){
  local ref="$1"
  [[ "$(git rev-parse "$ref:src/solver/mod_soil_water_accepted_step_direction_contract.f90")" == 52698b1ad2350bf787862a053a49c7c73c3358f0 ]] || fail "F-SI37 contract drift at $ref"
  [[ "$(git rev-parse "$ref:src/solver/mod_b110_default_mvg_directional_provider.f90")" == b1e794d2f0e661a2abb14280a59175e1cf1d5724 ]] || fail "F-SI37 MVG directional provider drift at $ref"
  [[ "$(git rev-parse "$ref:src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90")" == 0a957376b9a9fdea00ab6009f129803fb5341e4a ]] || fail "F-SI37 dynamic-top directional adapter drift at $ref"
  [[ "$(git rev-parse "$ref:src/adapter/mod_reference_richards_accepted_step_directional_service.f90")" == ef395ac3fb0cf6f347031bf2081a74b74b5167ae ]] || fail "F-SI37 accepted-step service drift at $ref"
}
check_si37 HEAD
check_si37 "$BASE"
echo 'FCI75_FSI37_INHERITED_DEPENDENCIES_EXACT=PASS'

python3 - "$VQ92" "$OWNER" <<'PY'
import json, subprocess, sys
vq92, owner = sys.argv[1:]
raw = subprocess.check_output(['git','show',f'{vq92}:qualification/F-VQ92_STATUS.json'], text=True)
s = json.loads(raw)
assert s['decision'] == 'PASS'
assert s['phase'] == 'INDEPENDENT_QUALIFICATION_COMPLETE'
assert s['source_authority']['qualified_source_sha'] == owner
assert s['qualification']['workflow_conclusion'] == 'success'
assert s['qualification']['O0_O2_output_identity'] is True
assert all(v == 'PASS' for v in s['independent_claim_checks'].values())
print('FCI75_VQ92_IMMUTABLE_AUTHORITY=PASS')
PY
[[ "$(git rev-parse "$VQ92:tests/qualification/fvq92/test_fvq92_fkt21_independent.f90")" == 560b6148c042413e6190f116aad761f1764ec57f ]] || fail 'F-VQ92 oracle blob drift'

bash tests/fkt/run_fkt21_qualification.sh | tee "$BUILD/fkt21-owner.txt"
grep -Fq 'FKT21_QUALIFICATION PASS' "$BUILD/fkt21-owner.txt" || fail 'owner F-KT21 replay missing final PASS'
echo 'FCI75_FKT21_OWNER_GATE_REPLAY=PASS'

git show "$VQ92:tests/qualification/fvq92/test_fvq92_fkt21_independent.f90" > "$BUILD/fvq92.f90"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_vq92(){
  local opt="$1" tag="$2" out="$BUILD/vq92-$tag"
  mkdir -p "$out"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_transaction_binding.f90 -o "$out/binding.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fvq92.f90" -o "$out/test.o"
  gfortran "$opt" "$out/contract.o" "$out/trajectory.o" "$out/publication.o" "$out/transaction.o" "$out/binding.o" "$out/test.o" -o "$out/fvq92"
  "$out/fvq92" > "$out/output.txt"
  for mark in \
    FVQ92_WHOLE_WINDOW_CENTERED_FD=PASS \
    FVQ92_REJECTED_STEP_NO_LEAK=PASS \
    FVQ92_RETRY_ABA_REJECTED=PASS \
    FVQ92_TRANSACTION_PUBLICATION_GUARDS=PASS \
    FVQ92_SHORTENED_INTERVAL_PROVENANCE=PASS \
    F_VQ92_INDEPENDENT_ORACLE=PASS; do
    grep -Fq "$mark" "$out/output.txt" || { cat "$out/output.txt" >&2; fail "VQ92 replay $tag missing $mark"; }
  done
}
run_vq92 -O0 o0
run_vq92 -O2 o2
cmp "$BUILD/vq92-o0/output.txt" "$BUILD/vq92-o2/output.txt" || fail 'VQ92 O0/O2 output drift on composed candidate'
echo 'FCI75_VQ92_INDEPENDENT_ORACLE_REPLAY=PASS'

SOILWATER=src/legacy/b1_10_port/soilwater.f90
TASK2=src/adapter/mod_b110_production_soil_water_task2.f90
CONTRACT=src/solver/mod_soil_water_solver_contract.f90
! grep -Eqi '(^|[^[:alnum:]_])headcalc([^[:alnum:]_]|$)' "$SOILWATER" || fail 'MOD_SoilWater regained HeadCalc dependency'
grep -Fq 'use mod_b110_production_soil_water_task2, only: run_b110_production_task2' "$SOILWATER" || fail 'Task2 service binding missing'
grep -Fq 'call run_b110_production_task2(worker)' "$SOILWATER" || fail 'worker Task2 bypasses common service'
grep -Fq 'call run_b110_production_task2()' "$SOILWATER" || fail 'standalone Task2 bypasses common service'
grep -Fq 'type, abstract, public :: soil_water_solver_t' "$CONTRACT" || fail 'common solver contract missing'
grep -Fq 'class(soil_water_solver_t), intent(inout) :: solver' "$TASK2" || fail 'typed common solver seam missing'
grep -Fq 'type, extends(soil_water_solver_t) :: b110_legacy_compat_solver_t' "$TASK2" || fail 'legacy compatibility path escaped typed seam'
grep -Fq 'call invoke_soil_water_solver(solver, request, workspace, result)' "$TASK2" || fail 'common solver invocation missing'
violations=0
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  case "$hit" in
    src/adapter/mod_reference_richards_legacy_binding.f90:*|src/adapter/mod_b110_production_soil_water_task2.f90:*) ;;
    *) echo "PRODUCTION_INTERFACE_VIOLATION $hit" >&2; violations=$((violations+1)) ;;
  esac
done < <(grep -RinE --include='*.f90' 'call[[:space:]]+headcalc[[:space:]]*\(' src || true)
[[ "$violations" -eq 0 ]] || fail "$violations HeadCalc production-interface violations"
echo 'FCI75_FSI35_TYPED_SEAM_HEADCALC_ISOLATION=PASS'

for spec in \
  "$FKT15_DONOR:tests/fkt/fkt15_production_task2_stubs.f90:$BUILD/fkt15_stubs.f90" \
  "$FKT15_DONOR:tests/fkt/test_fkt15_production_task2.f90:$BUILD/fkt15_task2.f90" \
  "$FKT15_DONOR:tests/fkt/test_fkt15_production_surface_regimes.f90:$BUILD/fkt15_surface.f90" \
  "$FSI35_SOURCE:tests/fsi/test_fsi35_task2_dispatch_equivalence.f90:$BUILD/fsi35_dispatch.f90"; do
  ref="${spec%%:*}"; rest="${spec#*:}"; path="${rest%%:*}"; out="${rest#*:}"
  git show "$ref:$path" > "$out" || fail "cannot materialize semantic oracle $ref:$path"
done

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULES=(
  "$BUILD/fkt15_stubs.f90"
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/adapter/mod_b110_production_soil_water_task2.f90
)
run_fsi35_replay(){
  local opt="$1" tag="$2" out="$BUILD/fsi35-$tag"
  mkdir -p "$out"; objs=()
  for src in "${MODULES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$SOILWATER" -o "$out/soilwater.o"
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_task2.f90" -o "$out/task2-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/task2-test.o" -o "$out/task2-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/task2-test" > "$out/task2.txt"
  for mark in FKT15_ACCEPTED_TYPED_ROUTE=PASS FKT15_ACCEPTED_SENSITIVITY=PASS FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS FKT15_RETRY_FAIL_CLOSED=PASS FKT15_PRODUCTION_TASK2_GATE=PASS; do
    grep -Fq "$mark" "$out/task2.txt" || { cat "$out/task2.txt" >&2; fail "FSI35 task2 $tag missing $mark"; }
  done
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_surface.f90" -o "$out/surface-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/surface-test.o" -o "$out/surface-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/surface-test" > "$out/surface.txt"
  for mark in FKT15_PRODUCTION_SURFACE_FLUX=PASS FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS FKT15_PRODUCTION_PONDED_HEAD=PASS FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do
    grep -Fq "$mark" "$out/surface.txt" || { cat "$out/surface.txt" >&2; fail "FSI35 surface $tag missing $mark"; }
  done
  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fsi35_dispatch.f90" -o "$out/dispatch-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/soilwater.o" "$out/dispatch-test.o" -o "$out/dispatch-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/dispatch-test" > "$out/dispatch.txt"
  grep -Fq 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "FSI35 dispatch $tag equivalence"; }
  grep -Fq 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "FSI35 dispatch $tag service"; }
}
run_fsi35_replay -O0 o0
run_fsi35_replay -O2 o2
cmp "$BUILD/fsi35-o0/task2.txt" "$BUILD/fsi35-o2/task2.txt" || fail 'FSI35 Task2 O0/O2 output drift'
cmp "$BUILD/fsi35-o0/surface.txt" "$BUILD/fsi35-o2/surface.txt" || fail 'FSI35 surface O0/O2 output drift'
cmp "$BUILD/fsi35-o0/dispatch.txt" "$BUILD/fsi35-o2/dispatch.txt" || fail 'FSI35 dispatch O0/O2 output drift'
echo 'FCI75_FSI35_SEMANTIC_PRESERVATION_REPLAY=PASS'
echo 'FCI75_MOVING_CURRENT_WORKER_SEMANTICS_REQUALIFIED=PASS'
echo 'F-CI75 QUALIFY GATE PASS'
