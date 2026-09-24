#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";BUILD="${RUNNER_TEMP:-/tmp}/ahl26h-${GITHUB_RUN_ID:-local}-$$";mkdir -p "$BUILD/o2";trap 'rm -rf "$BUILD"' EXIT;cd "$ROOT"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(tests/fsi/fsi04_real_headcalc_stubs.f90 src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/solver/mod_fixed_flux_top_boundary_provider.f90 src/solver/mod_reference_richards_temporal_indicator.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 research/ahl/mod_ahl26f_pdi_analytical.f90 research/ahl/mod_ahl26f_pdi_lookup.f90)
objects=();for source in "${SRC[@]}";do obj="$BUILD/o2/$(basename "${source%.*}").o";gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c "$source" -o "$obj";objects+=("$obj");done
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c research/ahl/test_ahl26h_case.f90 -o "$BUILD/o2/test.o";gfortran -O2 "${objects[@]}" "$BUILD/o2/test.o" -o "$BUILD/o2/test"
RESULT="${1:-/tmp/ahl26h.txt}";:>"$RESULT"
ksel=""
for kt in 0.0003 0.0001;do td="$BUILD/k-$kt";PYTHONPATH=research/ahl python3 research/ahl/ahl26h_generate_tables.py "$td" 1e-5 1e-2 "$kt"|tee -a "$RESULT";set +e;"$BUILD/o2/test" "$td/PDI10_BIMODAL.dat" PDI10_BIMODAL wet -10 -7.5 0.25 >>"$RESULT" 2>&1;rc=$?;set -e;echo "AHL26H_K_STAGE tol=$kt rc=$rc"|tee -a "$RESULT";if [[ $rc -eq 0 ]];then ksel="$kt";break;fi;done
[[ -n "$ksel" ]]||{ echo "AHL26H_NO_K_REPAIR"|tee -a "$RESULT";exit 1; }
rsel_theta="";rsel_c=""
for spec in "3e-6 0.003" "1e-6 0.001";do read -r tt ct <<< "$spec";td="$BUILD/r-$tt";PYTHONPATH=research/ahl python3 research/ahl/ahl26h_generate_tables.py "$td" "$tt" "$ct" 0.001|tee -a "$RESULT";set +e;"$BUILD/o2/test" "$td/PDI10_BIMODAL.dat" PDI10_BIMODAL mid -1000 -800 0.25 >>"$RESULT" 2>&1;rc=$?;set -e;echo "AHL26H_R_STAGE theta=$tt logc=$ct rc=$rc"|tee -a "$RESULT";if [[ $rc -eq 0 ]];then rsel_theta="$tt";rsel_c="$ct";break;fi;done
[[ -n "$rsel_theta" ]]||{ echo "AHL26H_NO_RET_REPAIR"|tee -a "$RESULT";exit 1; }
echo "AHL26H_SELECTED k=$ksel theta=$rsel_theta logc=$rsel_c"|tee -a "$RESULT"
TDIR="$BUILD/final";PYTHONPATH=research/ahl python3 research/ahl/ahl26h_generate_tables.py "$TDIR" "$rsel_theta" "$rsel_c" "$ksel"|tee -a "$RESULT"
fail=0
for spec in "PDI8_REFERENCE wet -10 -7.5 0.25" "PDI8_REFERENCE mid -1000 -800 0.25" "PDI8_REFERENCE dry -100000 -80000 0.25" "PDI10_BIMODAL wet -10 -7.5 0.25" "PDI10_BIMODAL mid -1000 -800 0.25" "PDI10_BIMODAL dry -100000 -80000 0.125";do read -r m reg h hb dt <<< "$spec";set +e;"$BUILD/o2/test" "$TDIR/$m.dat" "$m" "$reg" "$h" "$hb" "$dt" >>"$RESULT" 2>&1;rc=$?;set -e;echo "AHL26H_MATRIX_CASE $m:$reg dt=$dt rc=$rc"|tee -a "$RESULT";[[ $rc -ne 0 ]]&&fail=1;done
[[ $fail -eq 0 ]]&&echo "AHL26H_MATRIX_6_OF_6=PASS"|tee -a "$RESULT"||{ echo "AHL26H_MATRIX=FAIL"|tee -a "$RESULT";exit 1; }
