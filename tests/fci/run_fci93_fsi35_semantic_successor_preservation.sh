#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FCI93_FAIL $*" >&2; exit 93; }

# Historical F-CI58P/F-SI35 authorities remain immutable evidence.
POSTIMAGE=3cf018a44b0d3e626fdf66cb3ab5a34e06ee165d
COMPOSITION=040627c77720829c297a0ba06e908efce683133c
ADMISSION=daaa41509a55be43c00cd6b92cf2ddf9590e35db
OWNER=15ccbf4b6bcf6895b824a68c221762bef0bc08b9
OWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae
FVQ68=fd93e50da5973f3e15c8f1b7fa57d72df6c31b72
OLD_TASK2_BLOB=3090e1d3d5701a87b3624412ad88590e17369d63
OLD_SOILWATER_BLOB=c1850ea7fa82a1ed8974af57e1da95aa11a771be

# F-CI75 is the admitted semantic successor that intentionally changed the
# F-SI35 composition surfaces after independent requalification.
FCI75=60294b4f66a2fcd19132d7c6f23457c4962b17e1
FCI75_OWNER=19a67f7c398fcadbcbc9729509680a1c0c5424f3
FCI75_VQ92=f4f98637e963e07e2bedf7ef6acbcaab36e07e5a
STATUS_A=50346642bd565f79134ea17d5462e544b354998c
FKT15_DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
TASK2=src/adapter/mod_b110_production_soil_water_task2.f90
SOILWATER=src/legacy/b1_10_port/soilwater.f90
CONTRACT=src/solver/mod_soil_water_solver_contract.f90
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
BUILD="${RUNNER_TEMP:-/tmp}/fci93-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for object in "$POSTIMAGE" "$COMPOSITION" "$ADMISSION" "$OWNER" "$OWNER_SOURCE" "$FVQ68" \
              "$FCI75" "$FCI75_OWNER" "$FCI75_VQ92" "$STATUS_A" "$FKT15_DONOR"; do
  git cat-file -e "$object^{commit}" 2>/dev/null || fail "missing authority $object"
done

# Preserve the original exact F-SI35 evidence as historical evidence. HEAD is
# deliberately not required to equal those old blobs because F-CI75 superseded
# that moving-byte-lock after semantic requalification.
for spec in "$TASK2:$OLD_TASK2_BLOB" "$SOILWATER:$OLD_SOILWATER_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  for ref in "$COMPOSITION" "$ADMISSION" "$POSTIMAGE" "$OWNER_SOURCE" "$OWNER" "$FVQ68"; do
    [[ "$(git rev-parse "$ref:$path")" == "$blob" ]] || fail "historical F-SI35 authority drift ref=$ref path=$path"
  done
done
echo 'FCI93_HISTORICAL_FSI35_EXACT_AUTHORITIES=PASS'

# The successor and Status-A authorities must both be in the current lineage.
git merge-base --is-ancestor "$POSTIMAGE" HEAD || fail 'current head does not descend from F-SI35 admission postimage'
git merge-base --is-ancestor "$FCI75" HEAD || fail 'current head does not descend from F-CI75 semantic successor'
git merge-base --is-ancestor "$STATUS_A" HEAD || fail 'current head does not descend from Status-A scientific baseline'
echo 'FCI93_SUCCESSOR_LINEAGE=PASS'

# The two F-SI35 composition surfaces changed at F-CI75 and have not changed
# since. Bind current preservation to those admitted successor blobs, not to the
# superseded F-CI58P pre-successor blobs.
for path in "$TASK2" "$SOILWATER"; do
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$FCI75:$path")" ]] || fail "post-FCI75 composition drift: $path"
  [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$STATUS_A:$path")" ]] || fail "post-Status-A composition drift: $path"
done
[[ "$(git rev-parse "HEAD:$TX")" == "$TX_BLOB" ]] || fail 'transaction-reference dependency drift'
echo 'FCI93_CURRENT_FSI35_SUCCESSOR_BLOBS=PASS'

# F-CI93 is a semantic preservation gate for F-SI35, not a repository-wide
# production freeze. Later admitted capabilities may add or change unrelated
# src/reference paths. Record such delta for provenance, while the exact locks
# above and the semantic replay below remain the fail-closed F-SI35 guard.
mapfile -t POST_STATUS_DELTA < <(git diff --name-only "$STATUS_A..HEAD" -- src reference)
if [[ "${#POST_STATUS_DELTA[@]}" -gt 0 ]]; then
  printf 'FCI93_POST_STATUS_PRODUCTION_REFERENCE_DELTA=%s\n' "$(IFS=,; echo "${POST_STATUS_DELTA[*]}")"
else
  echo 'FCI93_POST_STATUS_PRODUCTION_REFERENCE_DELTA=NONE'
fi
echo 'FCI93_DEPENDENCY_AWARE_SUCCESSOR_POLICY=PASS'

# Permanent architecture invariants from F-SI35 remain semantic conditions.
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
echo 'FCI93_FSI35_TYPED_SEAM_HEADCALC_ISOLATION=PASS'

# Re-run the exact semantic preservation matrix established by F-CI75 against
# the current production postimage. Historical test inputs remain immutable;
# implementation modules are compiled from HEAD at O0 and O2.
for spec in \
  "$FKT15_DONOR:tests/fkt/fkt15_production_task2_stubs.f90:$BUILD/fkt15_stubs.f90" \
  "$FKT15_DONOR:tests/fkt/test_fkt15_production_task2.f90:$BUILD/fkt15_task2.f90" \
  "$FKT15_DONOR:tests/fkt/test_fkt15_production_surface_regimes.f90:$BUILD/fkt15_surface.f90" \
  "$OWNER_SOURCE:tests/fsi/test_fsi35_task2_dispatch_equivalence.f90:$BUILD/fsi35_dispatch.f90"; do
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

run_replay(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
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
    grep -Fq "$mark" "$out/task2.txt" || { cat "$out/task2.txt" >&2; fail "$tag missing $mark"; }
  done

  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fkt15_surface.f90" -o "$out/surface-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/surface-test.o" -o "$out/surface-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/surface-test" > "$out/surface.txt"
  for mark in FKT15_PRODUCTION_SURFACE_FLUX=PASS FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS FKT15_PRODUCTION_PONDED_HEAD=PASS FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do
    grep -Fq "$mark" "$out/surface.txt" || { cat "$out/surface.txt" >&2; fail "$tag missing $mark"; }
  done

  gfortran "${FLAGS[@]}" "$opt" -J "$out" -I "$out" -c "$BUILD/fsi35_dispatch.f90" -o "$out/dispatch-test.o"
  gfortran "${FLAGS[@]}" "$opt" "${objs[@]}" "$out/soilwater.o" "$out/dispatch-test.o" -o "$out/dispatch-test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/dispatch-test" > "$out/dispatch.txt"
  grep -Fq 'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "$tag standalone/worker equivalence"; }
  grep -Fq 'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS' "$out/dispatch.txt" || { cat "$out/dispatch.txt" >&2; fail "$tag common solver service"; }
}

run_replay -O0 o0
run_replay -O2 o2
cmp "$BUILD/o0/task2.txt" "$BUILD/o2/task2.txt" || fail 'Task2 O0/O2 output drift'
cmp "$BUILD/o0/surface.txt" "$BUILD/o2/surface.txt" || fail 'surface O0/O2 output drift'
cmp "$BUILD/o0/dispatch.txt" "$BUILD/o2/dispatch.txt" || fail 'dispatch O0/O2 output drift'
echo 'FCI93_FSI35_CURRENT_SEMANTIC_REPLAY=PASS'
echo 'FCI93_FSI35_SUCCESSOR_PRESERVATION=PASS'
