#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib

def fields(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1);out[k]=v
    return out

def parse(path: str):
    text=pathlib.Path(path).read_text()
    steps={}; nodes={}; passes={}
    geom=None
    for line in text.splitlines():
        if "F_ROM0V1_STEP|" in line:
            r=fields(line.split("F_ROM0V1_STEP|",1)[1])
            key=(r["CASE"],int(r["STEP"]))
            steps[key]=r
            geom=int(r["GEOM_N"])
        elif "F_ROM0V1_NODE|" in line:
            r=fields(line.split("F_ROM0V1_NODE|",1)[1])
            key=(r["CASE"],int(r["STEP"]),int(r["NODE"]))
            nodes[key]=(float(r["H"]),float(r["THETA"]),float(r["Z"]),float(r["DZ"]))
            geom=int(r["GEOM_N"])
        elif "F_ROM0V1_CASE_PASS|" in line:
            r=fields(line.split("F_ROM0V1_CASE_PASS|",1)[1])
            passes[r["CASE"]]=r
            geom=int(r["GEOM_N"])
    return text,geom,steps,nodes,passes

def rms(vals):
    return math.sqrt(sum(v*v for v in vals)/len(vals))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--g16",required=True)
    ap.add_argument("--g32",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    t16,g16,s16,n16,p16=parse(a.g16)
    t32,g32,s32,n32,p32=parse(a.g32)
    cases=["B01_E1_NOMINAL_FLUX","B14_E2_DRYING_FLUX"]
    structural=(g16==16 and g32==32 and set(p16)==set(cases) and set(p32)==set(cases))
    results={}
    all_finite=True
    top_identity=True
    for case in cases:
        per=[]
        for step in range(1,65):
            k=(case,step)
            if k not in s16 or k not in s32:
                structural=False
                continue
            a16=s16[k];a32=s32[k]
            if float(a16["T"])!=float(a32["T"]):
                structural=False
            h16=[];th16=[];h32=[];th32=[]
            for i in range(1,17):
                nk=(case,step,i)
                if nk not in n16: structural=False; break
                h16.append(n16[nk][0]);th16.append(n16[nk][1])
            for i in range(1,33):
                nk=(case,step,i)
                if nk not in n32: structural=False; break
                h32.append(n32[nk][0]);th32.append(n32[nk][1])
            if len(h16)!=16 or len(h32)!=32: continue
            h32map=[0.5*(h32[2*i]+h32[2*i+1]) for i in range(16)]
            th32map=[0.5*(th32[2*i]+th32[2*i+1]) for i in range(16)]
            dh=[h16[i]-h32map[i] for i in range(16)]
            dt=[th16[i]-th32map[i] for i in range(16)]
            row={
              "step":step,
              "time_day":float(a16["T"]),
              "D_h_inf_cm":max(abs(x) for x in dh),
              "D_h_rms_cm":rms(dh),
              "D_theta_inf":max(abs(x) for x in dt),
              "D_theta_rms":rms(dt),
              "D_total_storage_abs_cm":abs(float(a16["TOTAL_STORAGE"])-float(a32["TOTAL_STORAGE"])),
              "D_upper_storage_abs_cm":abs(float(a16["UPPER_STORAGE"])-float(a32["UPPER_STORAGE"])),
              "D_lower_storage_abs_cm":abs(float(a16["LOWER_STORAGE"])-float(a32["LOWER_STORAGE"])),
              "D_cumulative_bottom_exchange_abs_cm":abs(float(a16["CUM_BOTTOM"])-float(a32["CUM_BOTTOM"])),
              "D_terminal_bottom_flux_abs_cm_per_day":abs(float(a16["BOTTOM_FLUX"])-float(a32["BOTTOM_FLUX"])),
              "D_cumulative_prescribed_top_exchange_abs_cm":abs(float(a16["CUM_TOP"])-float(a32["CUM_TOP"])),
            }
            top_identity &= float(a16["CUM_TOP"])==float(a32["CUM_TOP"])
            all_finite &= all(math.isfinite(v) for v in row.values() if isinstance(v,float))
            per.append(row)
        if len(per)!=64: structural=False
        names=[
          "D_h_inf_cm","D_h_rms_cm","D_theta_inf","D_theta_rms",
          "D_total_storage_abs_cm","D_upper_storage_abs_cm","D_lower_storage_abs_cm",
          "D_cumulative_bottom_exchange_abs_cm","D_terminal_bottom_flux_abs_cm_per_day",
          "D_cumulative_prescribed_top_exchange_abs_cm"
        ]
        maxima={}
        for name in names:
            if per:
                rr=max(per,key=lambda x:x[name])
                maxima[name]={"value":rr[name],"step":rr["step"],"time_day":rr["time_day"]}
        results[case]={
          "common_endpoint_count":len(per),
          "max_over_time":maxima,
          "final_time":per[-1] if per else None,
          "G16":{
            "max_abs_step_mass_residual_cm":max(abs(float(s16[(case,i)]["MASS"])) for i in range(1,65)) if all((case,i) in s16 for i in range(1,65)) else None,
            "representation_bound_cm_range":[
              min(float(s16[(case,i)]["REP_BOUND_CM"]) for i in range(1,65)),
              max(float(s16[(case,i)]["REP_BOUND_CM"]) for i in range(1,65))
            ] if all((case,i) in s16 for i in range(1,65)) else None,
            "nonlinear_iterations_range":[
              min(int(s16[(case,i)]["NL"]) for i in range(1,65)),
              max(int(s16[(case,i)]["NL"]) for i in range(1,65))
            ] if all((case,i) in s16 for i in range(1,65)) else None,
            "backtracking_range":[
              min(int(s16[(case,i)]["BACK"]) for i in range(1,65)),
              max(int(s16[(case,i)]["BACK"]) for i in range(1,65))
            ] if all((case,i) in s16 for i in range(1,65)) else None
          },
          "G32":{
            "max_abs_step_mass_residual_cm":max(abs(float(s32[(case,i)]["MASS"])) for i in range(1,65)) if all((case,i) in s32 for i in range(1,65)) else None,
            "representation_bound_cm_range":[
              min(float(s32[(case,i)]["REP_BOUND_CM"]) for i in range(1,65)),
              max(float(s32[(case,i)]["REP_BOUND_CM"]) for i in range(1,65))
            ] if all((case,i) in s32 for i in range(1,65)) else None,
            "nonlinear_iterations_range":[
              min(int(s32[(case,i)]["NL"]) for i in range(1,65)),
              max(int(s32[(case,i)]["NL"]) for i in range(1,65))
            ] if all((case,i) in s32 for i in range(1,65)) else None,
            "backtracking_range":[
              min(int(s32[(case,i)]["BACK"]) for i in range(1,65)),
              max(int(s32[(case,i)]["BACK"]) for i in range(1,65))
            ] if all((case,i) in s32 for i in range(1,65)) else None
          }
        }
    hard_mass=all(
      results[c][g]["max_abs_step_mass_residual_cm"] is not None and
      results[c][g]["max_abs_step_mass_residual_cm"]<=1e-12
      for c in cases for g in ("G16","G32")
    ) if structural else False
    measured=structural and all_finite and hard_mass and top_identity
    result={
      "schema":"swap5.f-rom0v1-result.v1",
      "work_unit":"ROM-0V1",
      "decision":"VERTICAL_REFERENCE_FLOOR_MEASURED" if measured else "VERTICAL_REFERENCE_FLOOR_NOT_MEASURABLE",
      "comparison":"16x10 cm vs 32x5 cm over 160 cm",
      "dt_day":0.0008,
      "horizon_day":0.0512,
      "common_endpoints_per_case":64,
      "mapping":{
        "pressure_head":"pair-average fine heads = linear interpolation to coarse centre",
        "water_content":"pair-average fine theta = storage-conservative coarse-layer theta"
      },
      "threshold_rule":"MEASURE_ONLY_NO_POST_RESULT_NUMERICAL_ACCEPTANCE_THRESHOLD",
      "structural_complete":structural,
      "all_metrics_finite":all_finite,
      "hard_mass_gate_pass":hard_mass,
      "prescribed_top_exchange_identity":top_identity,
      "cases":results,
      "production_or_reference_source_mutated":False,
      "rom1a_authorized":False
    }
    pathlib.Path(a.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if measured else 2

if __name__=="__main__":
    raise SystemExit(main())
