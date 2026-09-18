#!/usr/bin/env python3
from __future__ import annotations
import argparse,collections,hashlib,json,math,pathlib

def kv(s):
    out={}
    for part in s.split("|"):
        if "=" in part:
            k,v=part.split("=",1);out[k]=v
    return out
def b(v): return str(v).strip().upper() in {"T","TRUE",".TRUE.","1"}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    raw=pathlib.Path(a.input).read_text()
    repeat=pathlib.Path(a.repeat).read_text()

    states=[]; nodes=[]; histories=[]; fallbacks=[]; blocked=[]; summary={}
    for line in raw.splitlines():
        if "ROM1AS1_STATE|" in line:
            states.append(kv(line.split("ROM1AS1_STATE|",1)[1]))
        elif "ROM1AS1_NODE|" in line:
            nodes.append(kv(line.split("ROM1AS1_NODE|",1)[1]))
        elif "ROM1AS1_HISTORY_PASS|" in line:
            histories.append(kv(line.split("ROM1AS1_HISTORY_PASS|",1)[1]))
        elif "ROM1AS1_FALLBACK|" in line:
            fallbacks.append(kv(line.split("ROM1AS1_FALLBACK|",1)[1]))
        elif "ROM1AS1_UNAUTHORIZED_FALLBACK_BLOCK|" in line:
            blocked.append(kv(line.split("ROM1AS1_UNAUTHORIZED_FALLBACK_BLOCK|",1)[1]))
        elif line.startswith("ROM1AS1_") and "=" in line and "|" not in line:
            k,v=line.split("=",1);summary[k]=v.strip()

    expected={f"D{i:02d}" for i in range(1,9)}|{f"H{i:02d}" for i in range(1,5)}
    by_hist=collections.defaultdict(list)
    for r in states: by_hist[r.get("HISTORY","")].append(r)
    node_count=collections.Counter((r.get("HISTORY",""),int(r.get("STEP","0"))) for r in nodes)
    split_count=collections.Counter(r.get("SPLIT","").strip() for r in states)

    structure=(set(by_hist)==expected and len(states)==768 and
               all(len(by_hist[h])==64 for h in expected) and
               len(nodes)==768*16 and
               all(node_count[(h,s)]==16 for h in expected for s in range(1,65)) and
               split_count["DISCOVERY"]==512 and split_count["HELD_OUT"]==256)
    progression=True
    finite=True
    max_mass=0.0
    policy_counts=collections.Counter()
    fallback_state_count=0
    for h,rows in by_hist.items():
        rows=sorted(rows,key=lambda r:int(r["STEP"]))
        for i,r in enumerate(rows,1):
            progression &= int(r["STEP"])==i and int(r["REV"])==i+2
            numeric=[float(r[k]) for k in ("REL_T","T","TOTAL_STORAGE","UPPER_STORAGE","LOWER_STORAGE",
                                           "TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE","BOTTOM_FLUX","MASS")]
            finite &= all(math.isfinite(x) for x in numeric)
            max_mass=max(max_mass,abs(float(r["MASS"])))
            policy=r.get("REFERENCE_POLICY","")
            policy_counts[policy]+=1
            fb=b(r["FALLBACK"])
            fallback_state_count+=int(fb)
            if not fb:
                progression &= policy=="STRICT_ORIGINAL"
            elif int(r["BOTTOM_MODE"])==2:
                progression &= policy=="MODE2_D2_FALLBACK" and r["SYMBOL"] in {"HOLD","TOP_PLUS","TOP_MINUS"}
            elif int(r["BOTTOM_MODE"])==5:
                progression &= policy=="MODE5_D4_FALLBACK" and r["SYMBOL"] in {"BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"}
            else:
                progression=False

    hmin=math.inf;hmax=-math.inf;tmin=math.inf;tmax=-math.inf
    for r in nodes:
        hv=float(r["H"]);tv=float(r["THETA"])
        finite &= math.isfinite(hv) and math.isfinite(tv)
        hmin=min(hmin,hv);hmax=max(hmax,hv);tmin=min(tmin,tv);tmax=max(tmax,tv)

    trigger_ok=True
    mode2_fb=0;mode5_fb=0
    for r in fallbacks:
        mode=int(r["BOTTOM_MODE"]);symbol=r["SYMBOL"]
        trigger_ok &= (r["CLASS"]=="RETRY_TOTAL_ONLY" and int(r["BAL_FLAGS"])==0 and int(r["HEAD_FLAGS"])==0 and
                       float(r["ABS_TOTAL_RESIDUAL_CM"])<=float(r["REP_BOUND_CM"]))
        if mode==2:
            mode2_fb+=1
            trigger_ok &= symbol in {"HOLD","TOP_PLUS","TOP_MINUS"}
        elif mode==5:
            mode5_fb+=1
            trigger_ok &= symbol in {"BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL"}
        else:
            trigger_ok=False

    history_ok=(len(histories)==12 and {r["HISTORY"] for r in histories}==expected and
                all(int(r["STATES"])==64 for r in histories))
    summary_ok=(summary.get("ROM1AS1_HISTORY_COUNT")=="12" and
                summary.get("ROM1AS1_DISCOVERY_HISTORY_COUNT")=="8" and
                summary.get("ROM1AS1_HELDOUT_HISTORY_COUNT")=="4" and
                summary.get("ROM1AS1_STATE_COUNT")=="768" and
                summary.get("ROM1AS1_DISCOVERY_STATE_COUNT")=="512" and
                summary.get("ROM1AS1_HELDOUT_STATE_COUNT")=="256" and
                summary.get("ROM1AS1_B14_MATERIAL_TRANSFER_GENERATED")=="FALSE" and
                "ROM1AS1_EXECUTION_COMPLETE=PASS" in raw)
    repeat_identity=raw==repeat
    hard_mass=max_mass<=1e-12
    qualified=all([structure,progression,finite,trigger_ok,history_ok,summary_ok,repeat_identity,hard_mass,len(blocked)==0])
    decision="ROM1AS1_REACHABLE_STATE_LIBRARY_QUALIFIED" if qualified else "ROM1AS1_REACHABLE_STATE_LIBRARY_NO_GO"

    result={
      "schema":"swap5.rom1as1.result.v1",
      "work_unit":"ROM-1A-S1",
      "decision":decision,
      "library":{
        "material":"B01",
        "history_count":len(histories),
        "accepted_state_count":len(states),
        "discovery_state_count":split_count["DISCOVERY"],
        "held_out_state_count":split_count["HELD_OUT"],
        "node_record_count":len(nodes),
        "policy_counts":dict(policy_counts),
        "fallback_state_count":fallback_state_count,
        "mode2_D2_fallback_count":mode2_fb,
        "mode5_D4_fallback_count":mode5_fb,
        "unauthorized_fallback_block_count":len(blocked),
      },
      "ranges":{
        "pressure_head_cm":[hmin,hmax],
        "water_content":[tmin,tmax],
        "max_abs_step_mass_residual_cm":max_mass,
      },
      "gates":{
        "history_and_profile_structure":structure,
        "revision_and_policy_progression":progression,
        "finite_outputs_and_profiles":finite,
        "every_fallback_trigger_valid":trigger_ok,
        "all_histories_pass":history_ok,
        "summary_counts":summary_ok,
        "hard_mass_gate":hard_mass,
        "repeat_stdout_bitwise_identity":repeat_identity,
        "combined_mode5_fallback_never_used":len(blocked)==0 and all(not (int(r["BOTTOM_MODE"])==5 and r["SYMBOL"].startswith("COMBINED")) for r in fallbacks),
        "B14_not_executed":summary.get("ROM1AS1_B14_MATERIAL_TRANSFER_GENERATED")=="FALSE",
      },
      "payload":{
        "raw_sha256":hashlib.sha256(raw.encode()).hexdigest(),
        "repeat_sha256":hashlib.sha256(repeat.encode()).hexdigest(),
        "full_profiles_retained_in_ci_artifact":True,
      },
      "scientific_firewalls":{
        "original_ROM1A_failure_reclassified":False,
        "history_or_split_changed":False,
        "reduced_coordinate_selected":False,
        "POD_fit":False,
        "memory_variable_selected":False,
        "closure_fit":False,
        "B14_inspected":False,
      },
      "rom1b_authorized":qualified,
      "production_solver_authorized":False,
      "production_reference_fallback_admitted":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if qualified else 2
if __name__=="__main__":
    raise SystemExit(main())
