#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]

def invoke(args):
    cp=subprocess.run(args,text=True,capture_output=True)
    if cp.returncode!=0:
        print(cp.stdout); print(cp.stderr,file=sys.stderr); raise SystemExit(cp.returncode)
    return cp.stdout

def payload(out,prefix):
    line=next((x for x in out.splitlines() if x.startswith(prefix+"=")),None)
    if line is None: raise SystemExit("missing "+prefix)
    return json.loads(line.split("=",1)[1])

sout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_timeint16c.py"),str(smooth),str(be),str(bank)])
dout=invoke([sys.executable,str(root/"tests/fpe/run_fpe_nlglob09.py"),str(dynamic),str(bank)])
ss=payload(sout,"F_PE_TIMEINT16C_SUMMARY")
ds=payload(dout,"F_PE_NLGLOB09_SUMMARY")
dr=payload(dout,"F_PE_NLGLOB09_RECORDS")
headspace_fail=sum(str(x.get("terminal_reason","")).startswith("HEADSPACE_PREDICTOR_") for x in dr)
pred_domain_fail=sum(x.get("terminal_reason")=="PREDICTED_RETENTION_DOMAIN_FAILED" for x in dr)

smooth_ok=bool(ss.get("advance") and ss.get("complete") and ss.get("median_refined_top_head_order",0)>=1.6 and
               ss.get("median_refined_top_theta_order",0)>=1.6 and ss.get("head_cases_order_ge_1p5",0)>=3 and
               ss.get("ledger_ok") and ss.get("roundtrip_ok") and ss.get("native_balance_ok") and
               ss.get("median_work_ratio_vs_klag_be",999)<=1.15)
dynamic_ok=bool(ds.get("case_count")==96 and ds.get("process_failures",999)==0 and
                headspace_fail==0 and pred_domain_fail==0 and
                ds.get("recovery_fraction",0)>=.80 and set(ds.get("completed_modes",[]))=={"TG","KLAG"} and
                set(ds.get("completed_routes",[]))=={"FLUX","HEAD","RUNOFF"} and len(ds.get("completed_materials",[]))>=3 and
                ds.get("max_ledger",999)<=5e-8 and ds.get("max_cumulative_ledger",999)<=5e-8 and
                ds.get("finite_ok") and ds.get("all_completed_have_replay_diagnostic"))

if smooth_ok and dynamic_ok:
    cls="QUALIFIED_TG_HEADSPACE_ENDPOINT_STAGE_RESEARCH"
elif not smooth_ok:
    cls="CLOSED_TG_HEADSPACE_STAGE_ORDER_REGRESSION"
elif headspace_fail>0 or pred_domain_fail>0 or ds.get("recovery_fraction",0)<.80:
    cls="CLOSED_TG_HEADSPACE_STAGE_ROBUSTNESS_FAILED"
else:
    cls="CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED"

summary={"classification":cls,"smooth_ok":smooth_ok,"dynamic_ok":dynamic_ok,
         "smooth_median_head_order":ss.get("median_refined_top_head_order"),
         "smooth_median_theta_order":ss.get("median_refined_top_theta_order"),
         "smooth_head_cases_order_ge_1p5":ss.get("head_cases_order_ge_1p5"),
         "smooth_work_ratio":ss.get("median_work_ratio_vs_klag_be"),
         "dynamic_recovery_fraction":ds.get("recovery_fraction"),
         "dynamic_complete_cases":ds.get("complete_cases"),
         "dynamic_process_failures":ds.get("process_failures"),
         "headspace_predictor_failures":headspace_fail,
         "legacy_predictor_domain_failures":pred_domain_fail,
         "dynamic_max_ledger":ds.get("max_ledger"),
         "dynamic_max_cumulative_ledger":ds.get("max_cumulative_ledger")}
print("F_PE_NLGLOB11A_SMOOTH="+json.dumps(ss,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11A_DYNAMIC_RECORDS="+json.dumps(dr,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11A_DYNAMIC="+json.dumps(ds,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11A_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB11A=PASS")
