#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-solve01-p1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SOLVE01_P1_FAIL $*" >&2; exit 1; }

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

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
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
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
  tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/bridge/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD/bridge" -I "$BUILD/bridge" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$BUILD/bridge/libfgc44_swap.so" || fail "link F-GC44 shared library"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_c' || fail "missing SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

OUT="$BUILD/p1.txt"
: > "$OUT"
for rep in 1 2 3; do
  for policy in exact e4 eh; do
    raw="$(LIBMF6="$BUILD/modflow-bin/libmf6.so" FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
      python3 tests/fpe/test_fpe_solve01_p1_live_corrector.py "$policy")" || {
        printf '%s\n' "$raw" >&2
        fail "$policy rep=$rep"
      }
    line="$(printf '%s\n' "$raw" | grep '^SOLVE01_P1_RAW|' | tail -1)"
    [[ -n "$line" ]] || fail "missing P1 record $policy rep=$rep"
    printf '%s|REP=%s\n' "$line" "$rep" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import json,math,statistics,sys
arms={"exact":[],"e4":[],"eh":[]}
for line in open(sys.argv[1]):
    if not line.startswith("SOLVE01_P1_RAW|"): continue
    payload,rep=line.strip().split("|REP=",1)
    d=json.loads(payload.split("|",1)[1]); d["rep"]=int(rep)
    arms[d["policy"]].append(d)
for p,rs in arms.items():
    if len(rs)!=3: raise SystemExit(f"missing reps {p}")
    sig={(r["iterations"],r["exact_trials"],r["approximate_responses"],r["validation_count"],
          r["validation_failures"],r["final_head"],r["final_q_swap"],r["final_q_gw"],
          r["final_residual"],r["revision"],r["ledger_count"],r["ledger_exchange"],
          r["prepare_solve_calls"],r["finalize_solve_calls"],r["finalize_time_step_calls"]) for r in rs}
    if len(sig)!=1: raise SystemExit(f"nondeterministic live coupling {p}: {sig}")

e=arms["exact"][0]
for p in ("e4","eh"):
    r=arms[p][0]
    if r["iterations"] > e["iterations"]+1:
        raise SystemExit(f"{p} external iteration penalty exceeds gate")
    if r["validation_failures"]>1:
        raise SystemExit(f"{p} repeated exact final-validation recovery")
    if r["exact_trials"] > e["exact_trials"]:
        raise SystemExit(f"{p} exact trial count exceeds E0")
    if abs(r["final_head"]-e["final_head"])>5e-10:
        raise SystemExit(f"{p} endpoint head drift")
    if abs(r["final_residual"])>1e-15:
        raise SystemExit(f"{p} exact final residual gate")
    if r["revision"]!=1 or r["ledger_count"]!=1:
        raise SystemExit(f"{p} publication count failure")
    if r["prepare_solve_calls"]!=1 or r["finalize_solve_calls"]!=1 or r["finalize_time_step_calls"]!=1:
        raise SystemExit(f"{p} MODFLOW publication lifecycle failure")

for p in ("exact","e4","eh"):
    rs=arms[p]
    med=statistics.median(x["loop_ns"] for x in rs)
    ratio=med/statistics.median(x["loop_ns"] for x in arms["exact"])
    r=rs[0]
    print(f"SOLVE01_P1_ARM|POLICY={p.upper()}|ITERATIONS={r['iterations']}|EXACT_TRIALS={r['exact_trials']}"
          f"|APPROX_RESPONSES={r['approximate_responses']}|VALIDATIONS={r['validation_count']}"
          f"|VALIDATION_FAILURES={r['validation_failures']}|MEDIAN_LOOP_NS={med:.3f}|RUNTIME_RATIO={ratio:.9f}"
          f"|FINAL_HEAD={r['final_head']:.17e}|FINAL_RESIDUAL={r['final_residual']:.17e}"
          f"|LEDGER_EXCHANGE={r['ledger_exchange']:.17e}")
print("SOLVE01_P1_SUMMARY|E4=PASS|EH=PASS|LIVE_MODFLOW6=6.8.0")
print("FPE_SOLVE01_P1=PASS")
PY
