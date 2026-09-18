#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

BASE_DT=0.0016
REF_DT=0.0008
BASE_STEPS=32
REF_STEPS=64
CASES=[
  "B01_E1_NOMINAL_FLUX",
  "B01_E2_DRYING_FLUX",
  "B14_E1_NOMINAL_FLUX",
  "B14_E2_DRYING_FLUX",
]

def fields(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1);out[k]=v
    return out

def dtkey(v): return round(float(v),7)

def parse(path: str):
    text=pathlib.Path(path).read_text()
    steps={}; nodes={}; passes={}; fails={}
    for line in text.splitlines():
        if "F_ROM0T1_STEP|" in line:
            r=fields(line.split("F_ROM0T1_STEP|",1)[1])
            steps[(r["CASE"],dtkey(r["DT"]),int(r["STEP"]))]=r
        elif "F_ROM0T1_NODE|" in line:
            r=fields(line.split("F_ROM0T1_NODE|",1)[1])
            nodes[(r["CASE"],dtkey(r["DT"]),int(r["STEP"]),int(r["NODE"]))]=(float(r["H"]),float(r["THETA"]))
        elif "F_ROM0T1_CASE_PASS|" in line:
            r=fields(line.split("F_ROM0T1_CASE_PASS|",1)[1])
            passes[(r["CASE"],dtkey(r["DT"]))]=r
        elif "F_ROM0T1_CASE_FAIL|" in line:
            r=fields(line.split("F_ROM0T1_CASE_FAIL|",1)[1])
            fails[(r["CASE"],dtkey(r["DT"]))]=r
    return text,steps,nodes,passes,fails

def rms(vals): return math.sqrt(sum(v*v for v in vals)/len(vals))

def trajectory_summary(steps,case,dt,nsteps):
    rows=[steps[(case,dt,i)] for i in range(1,nsteps+1)]
    return {
      "max_abs_step_mass_residual_cm":max(abs(float(r["MASS"])) for r in rows),
      "nonlinear_iterations_range":[min(int(r["NL"]) for r in rows),max(int(r["NL"]) for r in rows)],
      "backtracking_range":[min(int(r["BACK"]) for r in rows),max(int(r["BACK"]) for r in rows)],
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    text,steps,nodes,passes,fails=parse(a.input)
    repeat=pathlib.Path(a.repeat).read_text()
    repeat_identity=text==repeat
    structural=True
    expected={(case,dt) for case in CASES for dt in (BASE_DT,REF_DT)}
    outcome_keys=set(passes)|set(fails)
    structural &= outcome_keys==expected and not (set(passes)&set(fails))
    all_pairs_pass=set(passes)==expected
    results={}
    all_finite=True
    outcomes={}
    for case,dt in sorted(expected):
        key=(case,dt)
        if key in passes:
            outcomes[f"{case}@{dt:.4f}"]={"status":"PASS","steps":int(passes[key]["STEPS"])}
        elif key in fails:
            r=fails[key]
            outcomes[f"{case}@{dt:.4f}"]={
              "status":"FAIL","step":int(r["STEP"]),"time0_day":float(r["T0"]),"time1_day":float(r["T1"]),
              "solver_status":int(r["STATUS"]),"route":r["ROUTE"],"nonlinear_iterations":int(r["NL"]),
              "internal_retries":int(r["IR"]),"backtracking_attempts":int(r["BACK"])
            }
        else:
            outcomes[f"{case}@{dt:.4f}"]={"status":"MISSING"}

    for case in CASES:
        per=[]
        if (case,BASE_DT) not in passes or (case,REF_DT) not in passes:
            results[case]={"common_endpoint_count":0,"max_over_time":{},"final_time":None,"DT_BASE":{},"DT_REFINED":{}}
            continue
        for j in range(1,BASE_STEPS+1):
            kb=(case,BASE_DT,j)
            kr=(case,REF_DT,2*j)
            if kb not in steps or kr not in steps:
                structural=False; continue
            rb=steps[kb]; rr=steps[kr]
            tb=float(rb["T"]); tr=float(rr["T"])
            if abs(tb-tr)>1e-15: structural=False
            hb=[];hr=[];tbtheta=[];trtheta=[]
            for i in range(1,17):
                nb=(case,BASE_DT,j,i); nr=(case,REF_DT,2*j,i)
                if nb not in nodes or nr not in nodes:
                    structural=False; break
                hb.append(nodes[nb][0]);tbtheta.append(nodes[nb][1])
                hr.append(nodes[nr][0]);trtheta.append(nodes[nr][1])
            if len(hb)!=16: continue
            dh=[hb[i]-hr[i] for i in range(16)]
            dtheta=[tbtheta[i]-trtheta[i] for i in range(16)]
            row={
              "base_step":j,
              "refined_step":2*j,
              "time_day":tb,
              "D_h_inf_cm":max(abs(x) for x in dh),
              "D_h_rms_cm":rms(dh),
              "D_theta_inf":max(abs(x) for x in dtheta),
              "D_theta_rms":rms(dtheta),
              "D_total_storage_abs_cm":abs(float(rb["TOTAL_STORAGE"])-float(rr["TOTAL_STORAGE"])),
              "D_upper_0_40cm_storage_abs_cm":abs(float(rb["UPPER_STORAGE"])-float(rr["UPPER_STORAGE"])),
              "D_lower_40_160cm_storage_abs_cm":abs(float(rb["LOWER_STORAGE"])-float(rr["LOWER_STORAGE"])),
              "D_cumulative_top_exchange_abs_cm":abs(float(rb["CUM_TOP"])-float(rr["CUM_TOP"])),
              "D_cumulative_bottom_exchange_abs_cm":abs(float(rb["CUM_BOTTOM"])-float(rr["CUM_BOTTOM"])),
              "D_terminal_bottom_flux_abs_cm_per_day":abs(float(rb["BOTTOM_FLUX"])-float(rr["BOTTOM_FLUX"])),
            }
            all_finite &= all(math.isfinite(v) for v in row.values() if isinstance(v,float))
            per.append(row)
        if len(per)!=BASE_STEPS: structural=False
        names=[
          "D_h_inf_cm","D_h_rms_cm","D_theta_inf","D_theta_rms",
          "D_total_storage_abs_cm","D_upper_0_40cm_storage_abs_cm","D_lower_40_160cm_storage_abs_cm",
          "D_cumulative_top_exchange_abs_cm","D_cumulative_bottom_exchange_abs_cm",
          "D_terminal_bottom_flux_abs_cm_per_day"
        ]
        maxima={}
        for name in names:
            if per:
                rr=max(per,key=lambda x:x[name])
                maxima[name]={"value":rr[name],"base_step":rr["base_step"],"refined_step":rr["refined_step"],"time_day":rr["time_day"]}
        try:
            base_summary=trajectory_summary(steps,case,BASE_DT,BASE_STEPS)
            ref_summary=trajectory_summary(steps,case,REF_DT,REF_STEPS)
        except KeyError:
            structural=False;base_summary={};ref_summary={}
        results[case]={
          "common_endpoint_count":len(per),
          "max_over_time":maxima,
          "final_time":per[-1] if per else None,
          "DT_BASE":base_summary,
          "DT_REFINED":ref_summary,
        }

    hard_mass=all_pairs_pass and all(
      results[c][level]["max_abs_step_mass_residual_cm"]<=1e-12
      for c in CASES for level in ("DT_BASE","DT_REFINED")
    )
    measured=structural and all_pairs_pass and all_finite and hard_mass and repeat_identity
    result={
      "schema":"swap5.f-rom0t1-result.v1",
      "work_unit":"ROM-0T1",
      "decision":"ORIGINAL_TEMPORAL_REFERENCE_FLOOR_MEASURED" if measured else "ORIGINAL_TEMPORAL_REFERENCE_FLOOR_NOT_MEASURABLE_UNDER_FROZEN_CONTROL",
      "geometry":"16x10 cm over 160 cm",
      "base_dt_day":BASE_DT,
      "refined_dt_day":REF_DT,
      "horizon_day":0.0512,
      "common_endpoints_per_case":BASE_STEPS,
      "threshold_rule":"MEASURE_ONLY_NO_POST_RESULT_NUMERICAL_ACCEPTANCE_THRESHOLD",
      "structural_complete":structural,
      "all_required_pairs_complete":all_pairs_pass,
      "outcomes":outcomes,
      "all_metrics_finite":all_finite if all_pairs_pass else None,
      "hard_mass_gate_pass":hard_mass if all_pairs_pass else None,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "cases":results,
      "scientific_negative_is_not_ci_failure":True,
      "production_or_reference_source_mutated":False,
      "rom1a_authorized":False,
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
