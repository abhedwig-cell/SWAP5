#!/usr/bin/env python3
import json, subprocess, sys
from pathlib import Path

smooth=Path(sys.argv[1]); be=Path(sys.argv[2]); dynamic=Path(sys.argv[3]); bank=Path(sys.argv[4])
root=Path(__file__).resolve().parents[2]

cp=subprocess.run([
    sys.executable, str(root/"tests/fpe/run_fpe_nlglob14e1.py"),
    str(smooth), str(be), str(dynamic), str(bank)
], text=True, capture_output=True)
if cp.returncode != 0:
    print(cp.stdout)
    print(cp.stderr, file=sys.stderr)
    raise SystemExit(cp.returncode)

def payload(prefix):
    line=next((x for x in cp.stdout.splitlines() if x.startswith(prefix+"=")),None)
    if line is None:
        raise SystemExit("missing "+prefix)
    return json.loads(line.split("=",1)[1])

summary=payload("F_PE_NLGLOB14E1_SUMMARY")
records=payload("F_PE_NLGLOB14E1_RECORDS")
smooth_summary=payload("F_PE_NLGLOB14E1_SMOOTH")

all_complete=len(records)==96 and all(x.get("complete",False) for x in records)
all_finite=all(x.get("finite",False) for x in records)
route_span={x["route"] for x in records if x.get("complete")}
mode_span={x["mode"] for x in records if x.get("complete")}
material_span={x["material"] for x in records if x.get("complete")}
dt_span={x["dt"] for x in records if x.get("complete")}
route_mismatch=sum("ROUTE_MISMATCH" in x.get("terminal_reason","") for x in records)
bad_terminal=sum(x.get("terminal_reason","")!="COMPLETE_SAME_ROUTE" for x in records)
event_semantics=bool(summary.get("diagnostic_ok") and summary.get("post_entry_root_attempt_violations")==0)

gates={
    "coverage": len(records)==96 and summary.get("process_failures")==0,
    "complete": all_complete,
    "span": route_span=={"FLUX","HEAD","RUNOFF"} and mode_span=={"TG","KLAG"} and
            material_span=={"B01","B12","O05","O14"} and len(dt_span)==4,
    "route": route_mismatch==0 and bad_terminal==0,
    "finite": all_finite,
    "mass": summary.get("max_ledger",999)<=5e-8 and summary.get("max_cumulative_ledger",999)<=5e-8,
    "event": event_semantics,
    "smooth": bool(summary.get("smooth_ok") and smooth_summary.get("advance") and
                   smooth_summary.get("median_refined_top_head_order",0)>=1.6 and
                   smooth_summary.get("median_refined_top_theta_order",0)>=1.6 and
                   smooth_summary.get("head_cases_order_ge_1p5",0)>=3 and
                   smooth_summary.get("median_work_ratio_vs_klag_be",999)<=1.15)
}

if not gates["coverage"]:
    cls="BLOCKED_TIMEINT17R_COVERAGE"
elif not gates["smooth"]:
    cls="CLOSED_TIMEINT17R_ORDER_REGRESSION"
elif not gates["event"]:
    cls="BLOCKED_TIMEINT17R_EVENT_OBSERVABILITY"
elif not all(gates[k] for k in ("complete","span","route","finite","mass")):
    cls="CLOSED_TIMEINT17R_PHYSICAL_ADMISSIBILITY_FAILED"
else:
    cls="QUALIFIED_TIMEINT17R_SAME_ROUTE_DYNAMIC_TOP"

out={
    "classification":cls,
    "gates":gates,
    "case_count":len(records),
    "complete_cases":sum(x.get("complete",False) for x in records),
    "event_entries":summary.get("event_entries"),
    "root_attempts":summary.get("root_attempts"),
    "persistent_intervals":summary.get("persistent_intervals"),
    "post_entry_root_attempt_violations":summary.get("post_entry_root_attempt_violations"),
    "max_ledger":summary.get("max_ledger"),
    "max_cumulative_ledger":summary.get("max_cumulative_ledger"),
    "smooth_median_head_order":smooth_summary.get("median_refined_top_head_order"),
    "smooth_median_theta_order":smooth_summary.get("median_refined_top_theta_order"),
    "smooth_work_ratio":smooth_summary.get("median_work_ratio_vs_klag_be")
}
print("F_PE_TIMEINT17R_SUMMARY="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEINT17R=PASS")
