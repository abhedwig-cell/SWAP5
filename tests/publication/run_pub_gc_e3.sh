#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e3-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E3_FAIL $*" >&2; exit 1; }

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
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
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
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_swap_initialize_configured_c' || fail "missing configurable SWAP C ABI"
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc34_publish_c' || fail "missing F-GC34 publisher C ABI"

OUT="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e3}"
mkdir -p "$OUT"
: > "$OUT/cases.jsonl"
: > "$OUT/case-output.txt"

WINDOWS=(1e-4 1e-3 1e-2)
QBOTS=(1e-6 1e-3 1e-2 1e-1)
KS=(0.01 0.1 1.0 10.0)

for window in "${WINDOWS[@]}"; do
  for qbot in "${QBOTS[@]}"; do
    for kval in "${KS[@]}"; do
      echo "PUB_GC_E3_CASE window=$window qbot=$qbot K=$kval" | tee -a "$OUT/case-output.txt"
      CASE_OUT="$(
        LIBMF6="$BUILD/modflow-bin/libmf6.so" \
        FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
        E3_WINDOW_DAY="$window" \
        E3_QBOT_CM_PER_DAY="$qbot" \
        E3_K_M_PER_DAY="$kval" \
        python3 tests/publication/test_pub_gc_e3_case.py
      )"
      printf '%s\n' "$CASE_OUT" | tee -a "$OUT/case-output.txt"
      JSON_LINE="$(printf '%s\n' "$CASE_OUT" | sed -n 's/^E3_JSON=//p' | tail -n 1)"
      test -n "$JSON_LINE" || fail "missing structured case record window=$window qbot=$qbot K=$kval"
      printf '%s\n' "$JSON_LINE" >> "$OUT/cases.jsonl"
    done
  done
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import csv
import json
import math
import sys
from collections import Counter
from pathlib import Path

out=Path(sys.argv[1])
records=[json.loads(line) for line in (out/"cases.jsonl").read_text().splitlines() if line.strip()]
if len(records)!=48:
    raise SystemExit(f"expected 48 E3 cases, got {len(records)}")

keys={(float(r["window_day"]),float(r["predictor_qbot_cm_per_day"]),float(r["k_m_per_day"])) for r in records}
if len(keys)!=48:
    raise SystemExit("duplicate or missing E3 matrix keys")

allowed={
    "CONVERGED",
    "SWAP_PREDICTOR_UNAVAILABLE",
    "SWAP_LOOSE_TRIAL_FAILED",
    "MODFLOW_LOOSE_NOT_CONVERGED",
    "MODFLOW_LOOSE_ERROR",
    "SWAP_ITERATIVE_TRIAL_FAILED",
    "MODFLOW_ITERATIVE_ERROR",
    "COUPLING_ITERATION_LIMIT",
}
bad=[r for r in records if r.get("status") not in allowed]
if bad:
    raise SystemExit(f"unexpected E3 statuses: {bad[:3]}")

control=next(r for r in records
             if float(r["window_day"])==1e-4
             and float(r["predictor_qbot_cm_per_day"])==1e-6
             and float(r["k_m_per_day"])==1.0)
if control["status"]!="CONVERGED":
    raise SystemExit(f"E3 control did not converge: {control['status']}")

ci=control["iterative"]
expected_h=-0.71499996773317653
expected_q=-1.2708557527755854e-13
if abs(float(ci["head_m"])-expected_h)>5e-12:
    raise SystemExit(f"E3 control head drift: {ci['head_m']}")
if abs(float(ci["q_swap_m_per_s"])-expected_q)>5e-18:
    raise SystemExit(f"E3 control q drift: {ci['q_swap_m_per_s']}")

for r in records:
    if r["status"]=="CONVERGED":
        it=r["iterative"]
        vals=[
            it["head_m"],it["q_gw_m_per_s"],it["q_swap_m_per_s"],it["residual_m_per_s"],
            r["delta_h_iter_minus_loose_m"],
            r["delta_qswap_iter_minus_loose_m_per_s"],
            r["loose_relative_flux_mismatch"],
        ]
        if not all(math.isfinite(float(v)) for v in vals):
            raise SystemExit("nonfinite converged E3 measurement")
        if abs(float(it["residual_m_per_s"]))>1e-15:
            raise SystemExit("converged E3 case above flux tolerance")

status_counts=Counter(r["status"] for r in records)
conv=[r for r in records if r["status"]=="CONVERGED"]

def absmax(field):
    return max((abs(float(r[field])) for r in conv), default=None)

summary={
    "schema":"pub-gc-e3-result-v1",
    "matrix_case_count":len(records),
    "status_counts":dict(sorted(status_counts.items())),
    "converged_count":len(conv),
    "control_status":control["status"],
    "control_head_m":ci["head_m"],
    "control_q_swap_m_per_s":ci["q_swap_m_per_s"],
    "control_residual_m_per_s":ci["residual_m_per_s"],
    "max_abs_delta_h_m":absmax("delta_h_iter_minus_loose_m"),
    "max_abs_delta_qswap_m_per_s":absmax("delta_qswap_iter_minus_loose_m_per_s"),
    "max_loose_relative_flux_mismatch":max((float(r["loose_relative_flux_mismatch"]) for r in conv),default=None),
}
(out/"PUB_GC_E3_RESULT.json").write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")

fields=[
    "window_day","predictor_qbot_cm_per_day","k_m_per_day","status","failure_stage",
    "predictor_hcof_m2_per_day","predictor_rhs_m3_per_day","predictor_reference_head_m",
    "loose_modflow_iterations","loose_head_m","loose_q_gw_m_per_s","loose_q_swap_m_per_s","loose_residual_m_per_s",
    "coupling_outer_iterations","iterative_head_m","iterative_q_gw_m_per_s","iterative_q_swap_m_per_s",
    "iterative_residual_m_per_s","delta_h_iter_minus_loose_m",
    "delta_qswap_iter_minus_loose_m_per_s","loose_relative_flux_mismatch",
]
with (out/"PUB_GC_E3_CASES.csv").open("w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=fields)
    w.writeheader()
    for r in records:
        lo=r.get("loose",{})
        it=r.get("iterative",{})
        w.writerow({
            "window_day":r.get("window_day"),
            "predictor_qbot_cm_per_day":r.get("predictor_qbot_cm_per_day"),
            "k_m_per_day":r.get("k_m_per_day"),
            "status":r.get("status"),
            "failure_stage":r.get("failure_stage"),
            "predictor_hcof_m2_per_day":r.get("predictor_hcof_m2_per_day"),
            "predictor_rhs_m3_per_day":r.get("predictor_rhs_m3_per_day"),
            "predictor_reference_head_m":r.get("predictor_reference_head_m"),
            "loose_modflow_iterations":lo.get("modflow_iterations"),
            "loose_head_m":lo.get("head_m"),
            "loose_q_gw_m_per_s":lo.get("q_gw_m_per_s"),
            "loose_q_swap_m_per_s":lo.get("q_swap_m_per_s"),
            "loose_residual_m_per_s":lo.get("residual_m_per_s"),
            "coupling_outer_iterations":it.get("coupling_outer_iterations"),
            "iterative_head_m":it.get("head_m"),
            "iterative_q_gw_m_per_s":it.get("q_gw_m_per_s"),
            "iterative_q_swap_m_per_s":it.get("q_swap_m_per_s"),
            "iterative_residual_m_per_s":it.get("residual_m_per_s"),
            "delta_h_iter_minus_loose_m":r.get("delta_h_iter_minus_loose_m"),
            "delta_qswap_iter_minus_loose_m_per_s":r.get("delta_qswap_iter_minus_loose_m_per_s"),
            "loose_relative_flux_mismatch":r.get("loose_relative_flux_mismatch"),
        })

ranked=sorted(
    conv,
    key=lambda r: abs(float(r.get("delta_h_iter_minus_loose_m",0.0))),
    reverse=True,
)
(out/"top-head-corrections.json").write_text(json.dumps(ranked[:10],indent=2,sort_keys=True)+"\n")
print(json.dumps(summary,indent=2,sort_keys=True))
PY

echo "PUB_GC_E3_MATRIX_COMPLETE=PASS"
echo "PUB_GC_E3_CONTROL_REPRODUCTION=PASS"
echo "PUB_GC_E3_ZERO_AUTHORITY_MUTATION=PASS"
