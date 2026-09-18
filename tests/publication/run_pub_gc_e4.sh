#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e4-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/bridge"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "PUB_GC_E3D_FAIL $*" >&2; exit 1; }

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
nm -D "$BUILD/bridge/libfgc44_swap.so" | grep -q 'fgc44_e4_head_trial_c' || fail "missing E4 head-trial C ABI"

OUT="${PUB_GC_EVIDENCE_DIR:-$ROOT/build/pub-gc-e4}"
mkdir -p "$OUT"
: > "$OUT/head.jsonl"
: > "$OUT/flux.jsonl"
: > "$OUT/output.txt"

IDS=(B1 B2 B3 B4 B5)
WINDOWS=(1e-4 1e-3 1e-3 1e-2 1e-2)
QBOTS=(1e-6 1e-6 1e-4 1e-6 1e-4)
FRACTIONS=(1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 1e-1)

for i in "${!IDS[@]}"; do
  id="${IDS[$i]}"
  window="${WINDOWS[$i]}"
  q0="${QBOTS[$i]}"
  echo "PUB_GC_E4_HEAD baseline=$id window=$window q0=$q0" | tee -a "$OUT/output.txt"
  CASE_OUT="$(
    FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
    E4_BASELINE_ID="$id" E4_WINDOW_DAY="$window" E4_QBOT_CM_PER_DAY="$q0" \
      python3 tests/publication/test_pub_gc_e4_head_response.py
  )"
  printf '%s\n' "$CASE_OUT" | tee -a "$OUT/output.txt"
  JSON_LINE="$(printf '%s\n' "$CASE_OUT" | sed -n 's/^E4_HEAD_JSON=//p' | tail -n 1)"
  test -n "$JSON_LINE" || fail "missing E4 head record $id"
  printf '%s\n' "$JSON_LINE" >> "$OUT/head.jsonl"

  for frac in "${FRACTIONS[@]}"; do
    qminus="$(python3 -c "print(float('$q0')*(1.0-float('$frac')))")"
    qplus="$(python3 -c "print(float('$q0')*(1.0+float('$frac')))")"
    for side in minus plus; do
      if [[ "$side" == "minus" ]]; then q="$qminus"; else q="$qplus"; fi
      POINT_OUT="$(
        FGC44_SWAP_LIB="$BUILD/bridge/libfgc44_swap.so" \
        E4_BASELINE_ID="$id" E4_WINDOW_DAY="$window" E4_QBOT_CM_PER_DAY="$q" \
        E4_FRACTION="$frac" E4_SIDE="$side" \
          python3 tests/publication/test_pub_gc_e4_flux_predictor.py
      )"
      printf '%s\n' "$POINT_OUT" | tee -a "$OUT/output.txt"
      JSON_POINT="$(printf '%s\n' "$POINT_OUT" | sed -n 's/^E4_FLUX_JSON=//p' | tail -n 1)"
      test -n "$JSON_POINT" || fail "missing E4 flux record $id $frac $side"
      printf '%s\n' "$JSON_POINT" >> "$OUT/flux.jsonl"
    done
  done
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import csv,json,statistics,sys
from collections import defaultdict
from pathlib import Path
import numpy as np

out=Path(sys.argv[1])
heads=[json.loads(x) for x in (out/"head.jsonl").read_text().splitlines() if x.strip()]
flux=[json.loads(x) for x in (out/"flux.jsonl").read_text().splitlines() if x.strip()]
if len(heads)!=5:
    raise SystemExit(f"expected 5 E4 head scans, got {len(heads)}")
if len(flux)!=70:
    raise SystemExit(f"expected 70 E4 flux points, got {len(flux)}")

def plateau(records,value_key):
    candidates=[]
    for i in range(len(records)-2):
        triple=records[i:i+3]
        if [x["sequence_index"] for x in triple] != list(range(triple[0]["sequence_index"],triple[0]["sequence_index"]+3)):
            continue
        if any(x.get(value_key) is None or x.get("signal",0.0)<=x.get("signal_floor",0.0) for x in triple):
            continue
        vals=[float(x[value_key]) for x in triple]
        med=statistics.median(vals)
        denom=max(abs(med),np.finfo(float).tiny)
        spread=(max(vals)-min(vals))/denom
        if spread<=0.01:
            candidates.append({"start":triple[0]["scale"],"end":triple[-1]["scale"],"median":med,"relative_spread":spread})
    return candidates

flux_by=defaultdict(dict)
for r in flux:
    flux_by[(r["baseline_id"],float(r["fraction"]))][r["side"]]=r

summaries=[]
derivative_rows=[]
for h in heads:
    if not h.get("ready"):
        raise SystemExit(f"preregistered baseline unavailable: {h}")
    if h["production_parity"]["status"]!="PASS":
        raise SystemExit(f"E4 production parity failed: {h['baseline_id']}")
    if tuple(h["authority_state_after"])!=(0,0.0,0,0.0):
        raise SystemExit(f"E4 authority drift: {h['baseline_id']}")

    bid=h["baseline_id"]; href=float(h["reference_head_m"]); uA=float(h["u_A"])
    reps=h["repeats"]
    vr=[float(r["V_u_m"]) for r in reps]
    sr=[float(r["storage_change_m"]) for r in reps]
    vnoise=max(vr)-min(vr); snoise=max(sr)-min(sr)
    vfloor=max(vnoise,256*np.finfo(float).eps*max(abs(statistics.median(vr)),1e-20))
    sfloor=max(snoise,256*np.finfo(float).eps*max(abs(statistics.median(sr)),1e-20))

    hd=[]; first_failed=None; largest_centered=None
    for idx,p in enumerate(h["perturbations"]):
        d=float(p["delta_h_m"])
        row={"baseline_id":bid,"sequence_index":idx,"scale":d,"delta_h_m":d,
             "centered_available":bool(p["centered_available"]),"J_R":None,"J_S":None,"J_B":None,
             "response_balance_closure":None,"V_signal":0.0,"S_signal":0.0,"B_signal":0.0}
        if p["centered_available"]:
            vm=float(p["minus"]["V_u_m"]); vp=float(p["plus"]["V_u_m"])
            sm=float(p["minus"]["storage_change_m"]); sp=float(p["plus"]["storage_change_m"])
            bm=float(p["minus"]["other_net_m"]); bp=float(p["plus"]["other_net_m"])
            row["V_signal"]=abs(vp-vm); row["S_signal"]=abs(sp-sm); row["B_signal"]=abs(bp-bm)
            row["J_R"]=(vp-vm)/(2*d); row["J_S"]=(sp-sm)/(2*d); row["J_B"]=(bp-bm)/(2*d)
            row["response_balance_closure"]=row["J_S"]-row["J_B"]+row["J_R"]
            largest_centered=d
        elif first_failed is None:
            first_failed=d
        hd.append(row); derivative_rows.append(row)

    jr_records=[dict(r,signal=r["V_signal"],signal_floor=vfloor) for r in hd]
    js_records=[dict(r,signal=r["S_signal"],signal_floor=sfloor) for r in hd]
    jr_plateau=plateau(jr_records,"J_R")
    js_plateau=plateau(js_records,"J_S")

    uf=[]
    for idx,frac in enumerate((1e-4,3e-4,1e-3,3e-3,1e-2,3e-2,1e-1)):
        pair=flux_by[(bid,frac)]
        minus=pair.get("minus"); plus=pair.get("plus")
        rec={"sequence_index":idx,"scale":frac,"fraction":frac,"u_FD":None,"signal":0.0,"signal_floor":0.0}
        if minus and plus and minus.get("ready") and plus.get("ready"):
            hm=float(minus["h_end_m"]); hp=float(plus["h_end_m"])
            qm=float(minus["qbot_cm_per_day"]); qp=float(plus["qbot_cm_per_day"])
            dh=hp-hm
            floor=256*np.finfo(float).eps*max(abs(href),1.0)
            rec["signal"]=abs(dh); rec["signal_floor"]=floor
            if abs(dh)>floor:
                rec["u_FD"]=((qp-qm)*float(h["window_day"]))/(100.0*dh)
        uf.append(rec)
    ufd_plateau=plateau(uf,"u_FD")

    def est(cands):
        return cands[0]["median"] if cands else None
    jr=est(jr_plateau); js=est(js_plateau); ufd=est(ufd_plateau)
    valid_jb=[r["J_B"] for r in hd if r.get("J_B") is not None]
    jb=statistics.median(valid_jb) if valid_jb else None
    def discrepancy(a,b,opposite=False):
        if a is None or b is None: return None
        num=abs(a+b) if opposite else abs(a-b)
        return num/max(abs(a),abs(b),np.finfo(float).tiny)

    summaries.append({
        "baseline_id":bid,"window_day":float(h["window_day"]),"qbot_cm_per_day":float(h["qbot_cm_per_day"]),
        "reference_head_m":href,"u_A":uA,
        "repeatability_V_range_m":vnoise,"repeatability_storage_range_m":snoise,
        "largest_centered_head_delta_m":largest_centered,"first_failed_head_delta_m":first_failed,
        "J_R_plateau_candidates":jr_plateau,"J_S_plateau_candidates":js_plateau,"u_FD_plateau_candidates":ufd_plateau,
        "J_R_estimate":jr,"J_S_estimate":js,"J_B_median":jb,"u_FD_estimate":ufd,
        "E_AFD":discrepancy(uA,ufd),
        "E_AS_plus":discrepancy(uA,js),"E_AS_minus":discrepancy(uA,js,opposite=True),
        "E_AR_plus":discrepancy(uA,jr),"E_AR_minus":discrepancy(uA,jr,opposite=True),
        "J_R_over_u_A":None if jr is None else jr/uA,
        "J_S_over_u_A":None if js is None else js/uA,
        "head_derivatives":hd,"u_FD_sequence":uf,
    })

payload={"schema":"pub-gc-e4-response-identity-v1","baseline_count":len(summaries),
         "head_scan_count":len(heads),"flux_point_count":len(flux),"summaries":summaries}
(out/"PUB_GC_E4_RESULT.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")

with (out/"PUB_GC_E4_DERIVATIVES.csv").open("w",newline="") as fh:
    fields=["baseline_id","delta_h_m","centered_available","J_R","J_S","J_B","response_balance_closure","V_signal","S_signal","B_signal"]
    w=csv.DictWriter(fh,fieldnames=fields); w.writeheader()
    for r in derivative_rows: w.writerow({k:r.get(k) for k in fields})

print(json.dumps(payload,indent=2,sort_keys=True))
print("PUB_GC_E4_RESPONSE_IDENTITY_COMPLETE=PASS")
PY
