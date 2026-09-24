#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)";BUILD="${RUNNER_TEMP:-/tmp}/ahl25f-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o2";trap 'rm -rf "$BUILD"' EXIT;cd "$ROOT"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(tests/fsi/fsi04_real_headcalc_stubs.f90 src/solver/mod_soil_water_accepted_step_direction_contract.f90 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 src/runtime/mod_a23bu_worker_execution_context.f90 src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_reference_richards_workspace.f90 src/solver/mod_reference_richards_state_binding.f90 src/solver/mod_reference_linear_solver.f90 src/solver/mod_b110_default_mvg_provider.f90 src/solver/mod_b110_source_sink_provider.f90 src/solver/mod_b110_root_sink_provider.f90 src/solver/mod_fixed_flux_top_boundary_provider.f90 src/solver/mod_reference_richards_temporal_indicator.f90 tests/fmr/mod_fmr04_fixed_top_provider.f90 src/legacy/b1_10_port/headcalc.f90 src/adapter/mod_reference_richards_legacy_binding.f90 research/ahl/mod_ahl25d_model3_analytical.f90 research/ahl/mod_ahl25d_model3_lookup.f90)
objects=();for source in "${SRC[@]}";do obj="$BUILD/o2/$(basename "${source%.*}").o";gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c "$source" -o "$obj";objects+=("$obj");done
gfortran "${COMMON[@]}" -O2 -J "$BUILD/o2" -I "$BUILD/o2" -c research/ahl/test_ahl25d_model3_richards.f90 -o "$BUILD/o2/test.o";gfortran -O2 "${objects[@]}" "$BUILD/o2/test.o" -o "$BUILD/o2/test"
RESULT="${1:-/tmp/ahl25f.txt}";:>"$RESULT";selected=""
for tol in 0.0003 0.0001;do
  TDIR="$BUILD/tables-$tol";PYTHONPATH=research/ahl python3 research/ahl/ahl25f_generate_tables.py "$TDIR" "$tol"|tee -a "$RESULT"
  fail=0
  for spec in "M3_SEPARATED wet -10 -7.5" "M3_DOMINANT_SECOND dry -500 -400";do
    read -r m reg h hb <<< "$spec";set +e;"$BUILD/o2/test" "$TDIR/$m.dat" "$m" "$reg" "$h" "$hb" >>"$RESULT" 2>&1;rc=$?;set -e
    echo "AHL25F_STAGE1 tol=$tol case=$m:$reg rc=$rc"|tee -a "$RESULT";[[ $rc -ne 0 ]]&&fail=1
  done
  if [[ $fail -eq 0 ]];then selected="$tol";echo "AHL25F_SELECTED $tol"|tee -a "$RESULT";break;fi
done
[[ -n "$selected" ]]||{ echo "AHL25F_NO_K_LIMIT_CLOSES"|tee -a "$RESULT";exit 1; }
TDIR="$BUILD/tables-$selected";fail=0
for m in M3_BALANCED M3_SEPARATED M3_DOMINANT_SECOND;do
 for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400";do
  read -r reg h hb <<< "$spec";set +e;"$BUILD/o2/test" "$TDIR/$m.dat" "$m" "$reg" "$h" "$hb" >>"$RESULT" 2>&1;rc=$?;set -e
  echo "AHL25F_STAGE2 case=$m:$reg rc=$rc"|tee -a "$RESULT";[[ $rc -ne 0 ]]&&fail=1
 done
done
[[ $fail -eq 0 ]]&&echo "AHL25F_MATRIX_9_OF_9=PASS"|tee -a "$RESULT"||{ echo "AHL25F_MATRIX=FAIL"|tee -a "$RESULT";exit 1; }
