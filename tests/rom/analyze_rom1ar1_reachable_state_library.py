#!/usr/bin/env python3
from __future__ import annotations
import argparse, collections, hashlib, json, math, pathlib

def kv(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def as_bool(v: str) -> bool:
    return v.strip().upper() in {"T","TRUE",".TRUE.","1"}

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    repeat_identity=raw==repeat
    state_rows=[]
    node_rows=[]
    history_rows=[]
    fallbacks=[]
    summary={}
    for line in raw.splitlines():
        if "ROM1AR1_STATE|" in line:
            state_rows.append(kv(line.split("ROM1AR1_STATE|",1)[1]))
        elif "ROM1AR1_NODE|" in line:
            node_rows.append(kv(line.split("ROM1AR1_NODE|",1)[1]))
        elif "ROM1AR1_HISTORY_PASS|" in line:
            history_rows.append(kv(line.split("ROM1AR1_HISTORY_PASS|",1)[1]))
        elif "ROM1AR1_FALLBACK|" in line:
            fallbacks.append(kv(line.split("ROM1AR1_FALLBACK|",1)[1]))
        elif line.startswith("ROM1AR1_") and "=" in line and "|" not in line:
            k,v=line.split("=",1)
            summary[k]=v

    expected_histories={f"D{i:02d}" for i in range(1,9)}|{f"H{i:02d}" for i in range(1,5)}
    by_history=collections.defaultdict(list)
    for r in state_rows:
        by_history[r.get("HISTORY","")].append(r)
    nodes_by_state=collections.Counter((r.get("HISTORY",""),int(r.get("STEP","0"))) for r in node_rows)

    history_structure_ok=set(by_history)==expected_histories and all(len(by_history[h])==64 for h in expected_histories)
    node_structure_ok=(len(node_rows)==768*16 and
                       all(nodes_by_state[(h,s)]==16 for h in expected_histories for s in range(1,65)))
    split_counts=collections.Counter(r.get("SPLIT","").strip() for r in state_rows)
    split_ok=split_counts["DISCOVERY"]==512 and split_counts["HELD_OUT"]==256

    finite_state_metrics=True
    max_abs_mass=0.0
    fallback_state_count=0
    for r in state_rows:
        vals=[r["REL_T"],r["T"],r["TOTAL_STORAGE"],r["UPPER_STORAGE"],r["LOWER_STORAGE"],
              r["TOP_EXCHANGE"],r["BOTTOM_OUTWARD_EXCHANGE"],r["BOTTOM_FLUX"],r["MASS"]]
        nums=[float(v) for v in vals]
        finite_state_metrics &= all(math.isfinite(v) for v in nums)
        max_abs_mass=max(max_abs_mass,abs(float(r["MASS"])))
        fallback_state_count+=int(as_bool(r["FALLBACK"]))
    fallback_semantics_ok=True
    fallback_mode_counts=collections.Counter()
    for f in fallbacks:
        try:
            mode=int(f["BOTTOM_MODE"])
            fallback_mode_counts[mode]+=1
            rep=float(f["REP_BOUND_CM"])
            integ=float(f["ABS_TOTAL_RESIDUAL_CM"])
            fallback_semantics_ok &= (
                mode in {2,5}
                and f["CLASS"]=="RETRY_TOTAL_ONLY"
                and int(f["BAL_FLAGS"])==0
                and int(f["HEAD_FLAGS"])==0
                and float(f["RMAX"])<=1e-12
                and abs(float(f["RSUM"]))>1e-12
                and math.isfinite(rep) and rep>0.0
                and math.isfinite(integ) and integ<=rep
            )
        except Exception:
            fallback_semantics_ok=False
    fallback_count_consistent=(len(fallbacks)==fallback_state_count)

    finite_nodes=True
    hmin=math.inf; hmax=-math.inf; tmin=math.inf; tmax=-math.inf
    for r in node_rows:
        h=float(r["H"]); th=float(r["THETA"])
        finite_nodes &= math.isfinite(h) and math.isfinite(th)
        hmin=min(hmin,h); hmax=max(hmax,h); tmin=min(tmin,th); tmax=max(tmax,th)

    progression_ok=True
    for h,rows in by_history.items():
        rows=sorted(rows,key=lambda r:int(r["STEP"]))
        for i,r in enumerate(rows,1):
            progression_ok &= int(r["STEP"])==i
            progression_ok &= int(r["REV"])==2+i

    history_pass_ok=(len(history_rows)==12 and {r.get("HISTORY","") for r in history_rows}==expected_histories and
                     all(int(r.get("STATES","0"))==64 for r in history_rows))
    gate_marker="ROM1AR1_EXECUTION_COMPLETE=PASS" in raw
    b14_not_generated=summary.get("ROM1AR1_B14_MATERIAL_TRANSFER_GENERATED")=="FALSE"
    summary_counts_ok=(summary.get("ROM1AR1_HISTORY_COUNT")=="12" and
                       summary.get("ROM1AR1_DISCOVERY_HISTORY_COUNT")=="8" and
                       summary.get("ROM1AR1_HELDOUT_HISTORY_COUNT")=="4" and
                       summary.get("ROM1AR1_STATE_COUNT")=="768" and
                       summary.get("ROM1AR1_DISCOVERY_STATE_COUNT")=="512" and
                       summary.get("ROM1AR1_HELDOUT_STATE_COUNT")=="256")

    qualified=all([
        repeat_identity, history_structure_ok, node_structure_ok, split_ok, finite_state_metrics,
        finite_nodes, progression_ok, history_pass_ok, gate_marker, b14_not_generated,
        summary_counts_ok, max_abs_mass<=1e-12, fallback_semantics_ok, fallback_count_consistent
    ])
    decision="ROM1AR1_REACHABLE_STATE_LIBRARY_QUALIFIED" if qualified else "ROM1AR1_REACHABLE_STATE_LIBRARY_NO_GO"
    result={
      "schema":"swap5.rom1ar1.result.v1",
      "work_unit":"ROM-1A-R1",
      "decision":decision,
      "library":{
        "material":"B01",
        "history_count":12,
        "discovery_histories":8,
        "held_out_histories":4,
        "accepted_state_count":len(state_rows),
        "discovery_state_count":split_counts["DISCOVERY"],
        "held_out_state_count":split_counts["HELD_OUT"],
        "node_record_count":len(node_rows),
        "nodes_per_state":16,
        "fallback_state_count":fallback_state_count,
        "fallback_diagnostic_record_count":len(fallbacks),
        "fallback_mode_counts":{str(k):v for k,v in sorted(fallback_mode_counts.items())},
      },
      "ranges":{
        "pressure_head_cm":[hmin,hmax],
        "water_content":[tmin,tmax],
        "max_abs_step_mass_residual_cm":max_abs_mass,
      },
      "gates":{
        "repeat_stdout_bitwise_identity":repeat_identity,
        "history_structure":history_structure_ok,
        "node_structure":node_structure_ok,
        "split_counts":split_ok,
        "finite_primary_outputs":finite_state_metrics,
        "finite_full_profiles":finite_nodes,
        "revision_progression":progression_ok,
        "history_pass_records":history_pass_ok,
        "hard_mass_gate":max_abs_mass<=1e-12,
        "fallback_semantics":fallback_semantics_ok,
        "fallback_count_consistent":fallback_count_consistent,
        "b14_material_transfer_not_generated":b14_not_generated,
      },
      "payload":{
        "raw_sha256":hashlib.sha256(raw.encode()).hexdigest(),
        "repeat_sha256":hashlib.sha256(repeat.encode()).hexdigest(),
        "profile_payload_in_ci_artifact":True,
      },
      "scientific_firewalls":{
        "reduced_coordinate_selected":False,
        "pod_or_modal_basis_fit":False,
        "memory_variable_selected":False,
        "closure_model_fit":False,
        "b14_outcomes_inspected_for_state_design":False,
        "held_out_histories_used_for_coordinate_enrichment":False,
      },
      "rom1b_authorized":qualified,
      "successor_reference_authority":{"mode2":"ROM1AD2","mode5":"ROM-0R-R3D4"},
      "production_solver_authorized":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if qualified else 2

if __name__=="__main__":
    raise SystemExit(main())
