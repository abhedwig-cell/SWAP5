from __future__ import annotations
import argparse, json, math, re
from collections import Counter, defaultdict
from pathlib import Path

TRAJ=re.compile(r"^F_ROSS25_TRAJECTORY\|ID=(?P<id>\d+)\|MATERIAL=(?P<material>[^|]+)\|PROFILE=(?P<profile>[^|]+)\|POLICY=(?P<policy>[^|]+)\|COMPLETE=(?P<complete>[^|]+)\|REF_ALL=(?P<ref_all>[^|]+)\|ROSS_ALL=(?P<ross_all>[^|]+)\|REF_FIRST_FAIL=(?P<ref_fail>\d+)\|ROSS_FIRST_FAIL=(?P<ross_fail>\d+)\|ENVELOPE_FIRST_FAIL=(?P<env_fail>\d+)\|REF_REASON=(?P<ref_reason>[^|]+)\|ROSS_REASON=(?P<ross_reason>[^|]+)\|K2=(?P<k2>\d+)\|K4=(?P<k4>\d+)\|K8=(?P<k8>\d+)\|MAX_HINF=(?P<max_hinf>[^|]+)\|MAX_TINF=(?P<max_tinf>[^|]+)\|MAX_DSTORAGE=(?P<max_dst>[^|]+)\|FINAL_HINF=(?P<final_hinf>[^|]+)\|FINAL_TINF=(?P<final_tinf>[^|]+)\|FINAL_DSTORAGE=(?P<final_dst>[^|]+)\|CUM_EXTERNAL=(?P<cum_ext>[^|]+)\|REF_CUM_BAL=(?P<ref_bal>[^|]+)\|ROSS_CUM_BAL=(?P<ross_bal>[^|]+)$")
CP=re.compile(r"^F_ROSS25_CHECKPOINT\|ID=(?P<id>\d+)\|STEP=(?P<step>\d+)\|HINF=(?P<hinf>[^|]+)\|HRMS=(?P<hrms>[^|]+)\|TINF=(?P<tinf>[^|]+)\|TRMS=(?P<trms>[^|]+)\|DSTORAGE=(?P<dst>[^|]+)\|TIER=(?P<tier>K2|K4|K8)\|TEMP=(?P<temp>[^|]+)\|ROSS_MASS=(?P<mass>[^|]+)$")

def b(x:str)->bool: return x.strip().upper().startswith("T")
def f(x:str)->float: return float(x)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--input",type=Path,required=True); ap.add_argument("--output",type=Path,required=True)
    a=ap.parse_args(); text=a.input.read_text(errors="replace")
    rows=[]
    for line in text.splitlines():
        m=TRAJ.match(line.strip())
        if not m: continue
        d=m.groupdict()
        rows.append({
          "id":int(d["id"]),"material":d["material"].strip(),"profile":d["profile"].strip(),"policy":d["policy"].strip(),
          "complete":b(d["complete"]),"reference_valid_all":b(d["ref_all"]),"rossfast_valid_all":b(d["ross_all"]),
          "reference_first_fail":int(d["ref_fail"]),"rossfast_first_fail":int(d["ross_fail"]),"envelope_first_fail":int(d["env_fail"]),
          "reference_reason":d["ref_reason"].strip(),"rossfast_reason":d["ross_reason"].strip(),
          "K2":int(d["k2"]),"K4":int(d["k4"]),"K8":int(d["k8"]),
          "max_head_inf":f(d["max_hinf"]),"max_theta_inf":f(d["max_tinf"]),"max_storage_diff":f(d["max_dst"]),
          "final_head_inf":f(d["final_hinf"]),"final_theta_inf":f(d["final_tinf"]),"final_storage_diff":f(d["final_dst"]),
          "cumulative_external":f(d["cum_ext"]),"reference_cumulative_balance":f(d["ref_bal"]),"rossfast_cumulative_balance":f(d["ross_bal"])
        })
    if len(rows)!=216: raise RuntimeError(f"expected 216 trajectories, got {len(rows)}")
    cps=[]
    for line in text.splitlines():
        m=CP.match(line.strip())
        if m:
            d=m.groupdict(); cps.append({"id":int(d["id"]),"step":int(d["step"]),"head_inf":f(d["hinf"]),"head_rms":f(d["hrms"]),"theta_inf":f(d["tinf"]),"theta_rms":f(d["trms"]),"storage_diff":f(d["dst"]),"tier":d["tier"],"temporal_indicator":f(d["temp"]),"rossfast_mass_residual":f(d["mass"])})
    by_policy=defaultdict(list); by_profile=defaultdict(list); by_material=defaultdict(list)
    for r in rows:
        by_policy[r["policy"]].append(r); by_profile[r["profile"]].append(r); by_material[r["material"]].append(r)
    def group(vals):
        complete=[r for r in vals if r["complete"]]
        return {
          "trajectories":len(vals),
          "complete":len(complete),
          "rossfast_valid_all":sum(r["rossfast_valid_all"] for r in vals),
          "reference_valid_all":sum(r["reference_valid_all"] for r in vals),
          "envelope_loss":sum(r["envelope_first_fail"]>0 for r in vals),
          "K2":sum(r["K2"] for r in vals),"K4":sum(r["K4"] for r in vals),"K8":sum(r["K8"] for r in vals),
          "max_final_head_inf":max((r["final_head_inf"] for r in complete),default=None),
          "max_final_theta_inf":max((r["final_theta_inf"] for r in complete),default=None),
          "max_final_storage_diff":max((r["final_storage_diff"] for r in complete),default=None),
          "max_abs_rossfast_cumulative_balance":max((abs(r["rossfast_cumulative_balance"]) for r in vals),default=None)
        }
    checkpoints=defaultdict(list)
    for c in cps: checkpoints[c["step"]].append(c)
    result={
      "schema":"swap5.f-ross25.serial-hydrologic-validation-result.v1","workunit":"F-ROSS25","phase":"MEASURED",
      "trajectory_count":len(rows),"checkpoint_record_count":len(cps),
      "aggregate":group(rows),
      "failure_reasons":{
        "reference":dict(Counter(r["reference_reason"] for r in rows if not r["reference_valid_all"])),
        "rossfast":dict(Counter(r["rossfast_reason"] for r in rows if not r["rossfast_valid_all"]))
      },
      "by_policy":{k:group(v) for k,v in sorted(by_policy.items())},
      "by_profile":{k:group(v) for k,v in sorted(by_profile.items())},
      "by_material":{k:group(v) for k,v in sorted(by_material.items())},
      "checkpoint_envelopes":{str(step):{
        "count":len(vals),
        "max_head_inf":max(x["head_inf"] for x in vals),
        "max_theta_inf":max(x["theta_inf"] for x in vals),
        "max_storage_diff":max(x["storage_diff"] for x in vals),
        "tier_counts":dict(Counter(x["tier"] for x in vals)),
        "max_temporal_indicator":max(x["temporal_indicator"] for x in vals),
        "max_abs_rossfast_mass_residual":max(abs(x["rossfast_mass_residual"]) for x in vals)
      } for step,vals in sorted(checkpoints.items())},
      "rows":rows,"checkpoints":cps,
      "gate":"PASS"
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,indent=2,sort_keys=True))
    print("F_ROSS25_SUMMARY_GATE=PASS")

if __name__=="__main__": main()
