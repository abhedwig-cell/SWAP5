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
M1C3_RESULT=integration/m1/M1_C3_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER_QUALIFICATION.json
M1C3_TASK2_BLOB=0406d3180262b06a5a393b605cc553a912a26aa0
M1C3_TOP_ADAPTER_BLOB=8a59211335f44034a93d9ecd0d7a8920ee9baa39
M1C3_TOP_PROVIDER_BLOB=42fb85a03e6835a839574bf6d4b4c01472a01236
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

# F-CI75/Status-A remain the default moving authority. M1-C3 is a later
# independently qualified semantic successor for the Task2 adapter only.
# SoilWater and transaction ownership remain byte-identical to the admitted
# F-CI75/Status-A lineage.
if [[ -f "$M1C3_RESULT" ]]; then
  python3 - "$M1C3_RESULT" <<'PY'
import json,sys
s=json.load(open(sys.argv[1],encoding='utf-8'))
assert s['qualification_verdict']=='PASS_FINAL_WHOLE_HUPSEL_TYPED_ADAPTER'
assert s['m1_c3_scientific_gate_pass'] is True
assert s['owner_qualification']['conclusion']=='success'
assert s['independent_qualification']['conclusion']=='success'
assert s['external_exact_asset_execution']['accepted_interval_identity'] is True
assert s['external_exact_asset_execution']['result_bal_exact_reference_identity'] is True
assert s['external_exact_asset_execution']['result_blc_exact_reference_identity'] is True
print('FCI93_M1C3_QUALIFIED_SUCCESSOR_RECEIPT=PASS')
PY
  [[ "$(git rev-parse "HEAD:$TASK2")" == "$M1C3_TASK2_BLOB" ]] || fail 'M1-C3 Task2 successor blob drift'
  [[ "$(git rev-parse HEAD:src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90)" == "$M1C3_TOP_ADAPTER_BLOB" ]] || fail 'M1-C3 dynamic-top adapter blob drift'
  [[ "$(git rev-parse HEAD:src/solver/mod_b110_dynamic_top_boundary_provider.f90)" == "$M1C3_TOP_PROVIDER_BLOB" ]] || fail 'M1-C3 dynamic-top provider blob drift'
  [[ "$(git rev-parse "HEAD:$SOILWATER")" == "$(git rev-parse "$FCI75:$SOILWATER")" ]] || fail 'M1-C3 changed legacy SoilWater'
  [[ "$(git rev-parse "HEAD:$SOILWATER")" == "$(git rev-parse "$STATUS_A:$SOILWATER")" ]] || fail 'M1-C3 SoilWater differs from Status-A'
  echo 'FCI93_CURRENT_M1C3_SEMANTIC_SUCCESSOR_BLOBS=PASS'
else
  for path in "$TASK2" "$SOILWATER"; do
    [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$FCI75:$path")" ]] || fail "post-FCI75 composition drift: $path"
    [[ "$(git rev-parse "HEAD:$path")" == "$(git rev-parse "$STATUS_A:$path")" ]] || fail "post-Status-A composition drift: $path"
  done
  echo 'FCI93_CURRENT_FSI35_SUCCESSOR_BLOBS=PASS'
fi
[[ "$(git rev-parse "HEAD:$TX")" == "$TX_BLOB" ]] || fail 'transaction-reference dependency drift'

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

# The immutable F-KT15 stub predates the later explicit SWSOPHY import used by
# the M1-C3 profile guard. Add only that interface symbol, with the historical
# analytical default, without changing any oracle calculation.
python3 - "$BUILD/fkt15_stubs.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle='module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n'
assert needle in s
if 'integer :: swsophy = 0' not in s:
    s=s.replace(needle,needle+'  integer :: swsophy = 0\n',1)
p.write_text(s)
print('FCI93_M1C3_HISTORICAL_STUB_INTERFACE_SHIM=PASS')
PY

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
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90
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
