#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-profile05-a2c-attribution-${GITHUB_RUN_ID:-local}-$"
CANDIDATE_TOL="${APPROX02_CANDIDATE_TOL:-1e-4}"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/exact" "$BUILD/a2" "$BUILD/py"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PROFILE05_A2C_ATTRIBUTION_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
run_main(Path("$BUILD/modflow-bin"),owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=Path("$BUILD/downloads"),force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

python3 - "$BUILD/a2/mod_fgc44_real_swap_c_bridge.f90" "$CANDIDATE_TOL" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90").read_text()
tol=sys.argv[2]
old="""    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL; p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL; p%root_extraction_active=.false.
"""
new=f"""    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL
    p%ponding_tolerance=TOL; p%practical_richards_a2c_active=.true.; p%root_extraction_active=.false.
"""
if old not in src: raise SystemExit("A2 tolerance seam missing")
Path(sys.argv[1]).write_text(src.replace(old,new,1))
PY
cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$BUILD/exact/mod_fgc44_real_swap_c_bridge.f90"

python3 - "$BUILD/py/test_a2_e2e.py" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_swap_modflow_end_to_end.py").read_text()
src=src.replace("import tempfile\n","import tempfile\nimport time\n",1)
needle="""            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
rep="""            coupling_start=time.perf_counter()
            for outer in range(1,min(40,session.max_solve_iterations)+1):
"""
if needle not in src: raise SystemExit("coupling loop seam missing")
src=src.replace(needle,rep,1)
needle='            require(converged,"real SWAP + MODFLOW coupling did not converge")\n'
rep=needle+'            coupling_seconds=time.perf_counter()-coupling_start\n'
if needle not in src: raise SystemExit("convergence seam missing")
src=src.replace(needle,rep,1)
needle='            print(f"FGC44_LEDGER_EXCHANGE_M={ledger_exchange:.17g}")\n'
rep=needle+'            print(f"APPROX02_A2_E2E_COUPLING_SECONDS={coupling_seconds:.17g}")\n'
if needle not in src: raise SystemExit("print seam missing")
src=src.replace(needle,rep,1)
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
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
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  BRIDGE_PLACEHOLDER
)

compile_variant(){
  local name="$1"
  local out="$BUILD/$name"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    if [[ "$source" == BRIDGE_PLACEHOLDER ]]; then source="$BUILD/$name/mod_fgc44_real_swap_c_bridge.f90"; fi
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O2 -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile $name $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$out/libfgc44_swap.so" || fail "link $name"
}
compile_variant exact
compile_variant a2

export PYTHONPATH="$ROOT/src/adapter:$ROOT/tests/fgc/support"
exact_status=FAIL
a2c_status=FAIL
for mode in exact a2; do
  label="$mode"
  [[ "$mode" == "a2" ]] && label="a2c"
  echo "PROFILE05_A2C_ATTRIBUTION_RUNNING=$label"
  set +e
  LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/$mode/libfgc44_swap.so" \
    python3 "$BUILD/py/test_a2_e2e.py" > "$BUILD/$mode.txt" 2>&1
  rc=$?
  set -e
  if [[ $rc -eq 0 ]] && grep -Fq 'FGC44_REAL_SWAP_MODFLOW_END_TO_END=PASS' "$BUILD/$mode.txt"; then
    echo "PROFILE05_A2C_ATTRIBUTION_ARM|MODE=$label|STATUS=PASS"
    if [[ "$mode" == "exact" ]]; then exact_status=PASS; else a2c_status=PASS; fi
  else
    echo "PROFILE05_A2C_ATTRIBUTION_ARM|MODE=$label|STATUS=FAIL|RC=$rc"
    grep -E 'SWAP corrector trial failed|RuntimeError|FGC44_.*FAIL' "$BUILD/$mode.txt" || true
  fi
done

echo "PROFILE05_A2C_ATTRIBUTION_RESULT|EXACT=$exact_status|A2C=$a2c_status"

if [[ "$exact_status" == "PASS" && "$a2c_status" == "PASS" ]]; then
python3 - "$BUILD/exact.txt" "$BUILD/a2.txt" <<'PY'
import re,sys
def read(path):
    txt=open(path).read()
    def v(name):
        m=re.search(rf'^{re.escape(name)}=(.+)$',txt,re.M)
        if not m: raise SystemExit(f'missing {name} in {path}')
        return m.group(1).strip()
    return dict(
      head=float(v('FGC44_FINAL_HEAD_M')),
      qswap=float(v('FGC44_FINAL_Q_SWAP_M_PER_S')),
      residual=float(v('FGC44_FINAL_FLUX_RESIDUAL')),
      ledger=float(v('FGC44_LEDGER_EXCHANGE_M')),
      seconds=float(v('APPROX02_A2_E2E_COUPLING_SECONDS')),
      iters=len(re.findall(r'^FGC44_ITER=',txt,re.M)),
    )
e=read(sys.argv[1]); a=read(sys.argv[2])
print(
  f"PROFILE05_A2C_ATTRIBUTION_TIMING|EXACT_SECONDS={e['seconds']:.9f}|A2C_SECONDS={a['seconds']:.9f}"
  f"|RATIO={a['seconds']/e['seconds']:.9f}|SPEEDUP_PERCENT={(1-a['seconds']/e['seconds'])*100:.6f}"
)
print(
  f"PROFILE05_A2C_ATTRIBUTION_IDENTITY|HEAD_DIFF={a['head']-e['head']:.17e}"
  f"|QSWAP_DIFF={a['qswap']-e['qswap']:.17e}|LEDGER_DIFF={a['ledger']-e['ledger']:.17e}"
  f"|ITER_DIFF={a['iters']-e['iters']}"
)
if abs(e['residual'])>1e-15 or abs(a['residual'])>1e-15:
    raise SystemExit('coupled residual gate drift')
PY
fi

echo "FPE_PROFILE05_A2C_FAILURE_ATTRIBUTION=OBSERVED"
