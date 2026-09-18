#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e5a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E5A_FAIL $*" >&2; exit 1; }

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


OUT="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e5a}"
mkdir -p "$OUT"
: > "$OUT/cases.jsonl"
: > "$OUT/output.txt"

BASELINES=(B1 B3 B4)
SYS=(0.02 0.15 0.30)
METHODS=(FP AITKEN IQN_COLD UA_FROZEN JR_ORACLE)

for baseline in "${BASELINES[@]}"; do
  for sy in "${SYS[@]}"; do
    for method in "${METHODS[@]}"; do
      echo "PUB_GC_E5A_CASE baseline=$baseline Sy=$sy method=$method" | tee -a "$OUT/output.txt"
      CASE_OUT="$(
        LIBMF6="$BUILD/modflow-bin/libmf6.so" \
        FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
        E5A_BASELINE_ID="$baseline" \
        E5A_SPECIFIC_YIELD="$sy" \
        E5A_METHOD="$method" \
          python3 tests/publication/test_pub_gc_e5a_case.py
      )"
      printf '%s\n' "$CASE_OUT" | tee -a "$OUT/output.txt"
      JSON_LINE="$(printf '%s\n' "$CASE_OUT" | sed -n 's/^E5A_JSON=//p' | tail -n 1)"
      test -n "$JSON_LINE" || fail "missing E5A structured case $baseline $sy $method"
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
from collections import Counter,defaultdict
from pathlib import Path

out=Path(sys.argv[1])
records=[json.loads(x) for x in (out/"cases.jsonl").read_text().splitlines() if x.strip()]
if len(records)!=45:
    raise SystemExit(f"expected 45 E5a cases, got {len(records)}")

methods=("FP","AITKEN","IQN_COLD","UA_FROZEN","JR_ORACLE")
baselines=("B1","B3","B4")
sys=(0.02,0.15,0.30)
keys={(r["baseline_id"],float(r["specific_yield"]),r["method"]) for r in records}
expected={(b,s,m) for b in baselines for s in sys for m in methods}
if keys!=expected:
    raise SystemExit("E5a case key mismatch")

allowed={
    "CONVERGED",
    "SWAP_PREDICTOR_UNAVAILABLE",
    "SWAP_CORRECTOR_UNAVAILABLE",
    "MODFLOW_ERROR",
    "COUPLING_ITERATION_LIMIT",
    "NONFINITE_UPDATE",
}
for r in records:
    if r["status"] not in allowed:
        raise SystemExit(f"unregistered E5a status: {r}")
    if int(r["N_predictor"])!=1:
        raise SystemExit("E5a common predictor count changed")
    if int(r["W_SWAP_upper"])!=1+int(r["N_corrector_attempted"]):
        raise SystemExit("E5a SWAP work accounting mismatch")
    if r["status"]=="CONVERGED":
        if abs(float(r["final_residual_m_per_s"]))>1e-15:
            raise SystemExit("E5a converged result exceeds coupling tolerance")
        vals=[
            r["final_head_m"],r["final_q_swap_m_per_s"],
            r["final_q_model_m_per_s"],r["final_residual_m_per_s"],
        ]
        if not all(math.isfinite(float(v)) for v in vals):
            raise SystemExit("nonfinite E5a converged output")

groups=defaultdict(dict)
for r in records:
    groups[(r["baseline_id"],float(r["specific_yield"]))][r["method"]]=r

case_summaries=[]
solution_disagreement_count=0
for (baseline,sy),g in sorted(groups.items()):
    conv=[r for r in g.values() if r["status"]=="CONVERGED"]
    disagreement=False
    max_dh=0.0
    max_dq=0.0
    for i,a in enumerate(conv):
        for b in conv[i+1:]:
            max_dh=max(max_dh,abs(float(a["final_head_m"])-float(b["final_head_m"])))
            max_dq=max(max_dq,abs(float(a["final_q_swap_m_per_s"])-float(b["final_q_swap_m_per_s"])))
    if max_dh>1e-10 or max_dq>1e-14:
        disagreement=True
        solution_disagreement_count+=1

    row={
        "baseline_id":baseline,
        "specific_yield":sy,
        "solution_disagreement":disagreement,
        "max_pairwise_head_difference_m":max_dh,
        "max_pairwise_qswap_difference_m_per_s":max_dq,
    }
    for method in methods:
        r=g[method]
        prefix=method.lower()
        row[prefix+"_status"]=r["status"]
        row[prefix+"_W_SWAP_upper"]=r["W_SWAP_upper"]
        row[prefix+"_outer_iterations"]=r.get("outer_iterations")
        row[prefix+"_final_residual_m_per_s"]=r.get("final_residual_m_per_s")
    case_summaries.append(row)

oracle_domain=[]
work_signals=defaultdict(list)
for row in case_summaries:
    if row["baseline_id"] not in ("B3","B4") or row["solution_disagreement"]:
        continue
    oracle_ok=row["jr_oracle_status"]=="CONVERGED"
    iqn_ok=row["iqn_cold_status"]=="CONVERGED"
    if oracle_ok and not iqn_ok:
        oracle_domain.append({
            "baseline_id":row["baseline_id"],
            "specific_yield":row["specific_yield"],
            "oracle_status":row["jr_oracle_status"],
            "iqn_status":row["iqn_cold_status"],
        })
    if oracle_ok and iqn_ok:
        wo=int(row["jr_oracle_W_SWAP_upper"])
        wi=int(row["iqn_cold_W_SWAP_upper"])
        absolute=wi-wo
        relative=(wi-wo)/wi if wi>0 else 0.0
        qualifies=absolute>=2 and relative>=0.25
        work_signals[row["baseline_id"]].append({
            "specific_yield":row["specific_yield"],
            "oracle_work":wo,
            "iqn_work":wi,
            "absolute_reduction":absolute,
            "relative_reduction":relative,
            "qualifies":qualifies,
        })

row_gate={}
for baseline in ("B3","B4"):
    vals=work_signals.get(baseline,[])
    row_gate[baseline]=sum(1 for x in vals if x["qualifies"])>=2

oracle_value_signal=bool(oracle_domain) or any(row_gate.values())
screening_status="ORACLE_VALUE_SIGNAL" if oracle_value_signal else "FAIL_UPPER_BOUND"

status_counts=Counter(r["status"] for r in records)
payload={
    "schema":"pub-gc-e5a-oracle-upper-bound-v1",
    "case_count":len(records),
    "physical_case_count":len(groups),
    "method_count":len(methods),
    "status_counts":dict(sorted(status_counts.items())),
    "solution_disagreement_count":solution_disagreement_count,
    "case_summaries":case_summaries,
    "oracle_convergence_domain_expansion":oracle_domain,
    "oracle_work_signals":dict(work_signals),
    "oracle_row_gate":row_gate,
    "screening_status":screening_status,
    "screening_rule":{
        "domain_expansion":"oracle converges where IQN_COLD does not in B3/B4",
        "work_signal":"at least 2 fewer full-window SWAP evaluations and >=25% reduction in at least 2 of 3 Sy cases for B3 or B4",
    },
}
(out/"PUB_GC_E5A_RESULT.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")

summary_fields=sorted({k for r in case_summaries for k in r})
with (out/"PUB_GC_E5A_TABLE.csv").open("w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=summary_fields)
    w.writeheader()
    for r in case_summaries:
        w.writerow(r)

trace_fields=[
    "baseline_id","specific_yield","method","outer",
    "head_m","q_model_m_per_s","q_swap_m_per_s","residual_m_per_s",
    "slope_per_s","modflow_converged","trial_status","omega_used",
]
with (out/"PUB_GC_E5A_TRACE.csv").open("w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=trace_fields)
    w.writeheader()
    for r in records:
        for t in r.get("trace",[]):
            row={
                "baseline_id":r["baseline_id"],
                "specific_yield":r["specific_yield"],
                "method":r["method"],
            }
            row.update(t)
            w.writerow({k:row.get(k) for k in trace_fields})

print(json.dumps({
    "screening_status":screening_status,
    "status_counts":payload["status_counts"],
    "solution_disagreement_count":solution_disagreement_count,
    "oracle_convergence_domain_expansion":oracle_domain,
    "oracle_work_signals":payload["oracle_work_signals"],
    "oracle_row_gate":row_gate,
},indent=2,sort_keys=True))
print("PUB_GC_E5A_COMPLETE=PASS")
PY
