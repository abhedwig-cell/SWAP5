#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "FVQ68_FAIL $*" >&2; exit 68; }
CANDIDATE=5898e6616dbb6871a9f52d489038235ba1172cae
CANONICAL=267f2a6ec61f78d3ba4ce75b3e5a7fdc08479135

# Independent source identity: qualification may add evidence only.
git merge-base --is-ancestor "$CANONICAL" "$CANDIDATE" || fail 'candidate lost canonical ancestry'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'qualification branch not rooted in exact candidate'
for p in \
  src/adapter/mod_b110_production_soil_water_task2.f90 \
  src/legacy/b1_10_port/soilwater.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_process_hydraulic_view.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 \
  src/runtime/mod_groundwater_predictor_corrector_window.f90 \
  src/transaction/mod_transaction_reference.f90; do
  [[ "$(git rev-parse HEAD:$p)" == "$(git rev-parse $CANDIDATE:$p)" ]] || fail "source changed during independent qualification: $p"
done
echo 'FVQ68_EXACT_CANDIDATE_SOURCE_IDENTITY=PASS'

# Independently assert the architectural property, rather than trusting owner metadata.
! grep -Eqi '(^|[^[:alnum:]_])headcalc([^[:alnum:]_]|$)' src/legacy/b1_10_port/soilwater.f90 || fail 'MOD_SoilWater still knows HeadCalc'
grep -Fq 'call run_b110_production_task2(worker)' src/legacy/b1_10_port/soilwater.f90 || fail 'worker service dispatch missing'
grep -Fq 'call run_b110_production_task2()' src/legacy/b1_10_port/soilwater.f90 || fail 'standalone service dispatch missing'
grep -Fq 'class(soil_water_solver_t), intent(inout) :: solver' src/adapter/mod_b110_production_soil_water_task2.f90 || fail 'common dynamic solver seam absent'

violations=0
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  case "$hit" in
    src/adapter/mod_reference_richards_legacy_binding.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    src/adapter/mod_b110_production_soil_water_task2.f90:*) echo "ADAPTER_BOUNDARY_ALLOWED $hit" ;;
    *) echo "PRODUCTION_INTERFACE_VIOLATION $hit" >&2; violations=$((violations+1)) ;;
  esac
done < <(grep -RinE --include='*.f90' 'call[[:space:]]+headcalc[[:space:]]*\(' src || true)
[[ $violations -eq 0 ]] || fail "$violations production HeadCalc violations"
echo 'SOLVER_INTERNAL_ALLOWED src/legacy/b1_10_port/headcalc.f90'
echo 'FVQ68_INDEPENDENT_HEADCALC_DEPENDENCY_AUDIT=PASS'

# Re-execute the source-bound numerical/transaction/boundary/dispatcher oracle.
bash tests/fsi/run_fsi35_mandatory_solver_seam_gate.sh
echo 'FVQ68_INDEPENDENT_REPLAY=PASS'

echo 'FVQ68_FSI35_INDEPENDENT_QUALIFICATION=PASS'
