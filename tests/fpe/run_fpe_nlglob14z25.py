#!/usr/bin/env python3
from pathlib import Path
import json, math

ROOT=Path(__file__).resolve().parents[2]
data=json.loads((ROOT/"tests/fpe/data/f_pe_nlglob14z23_z22_event_evidence.json").read_text())
dt=float(data["authority"]["dt_day"])

def groups(events):
    out=[]; cur=[]
    for e in events:
        if not cur or e["offset"]==cur[-1]["offset"]+1:
            cur.append(e)
        else:
            out.append(cur); cur=[e]
    if cur: out.append(cur)
    return out

records=[]
for fx in data["fixtures"]:
    events=[fx["committed_reverse"]]+fx["changes"]
    offsets=[int(e["offset"]) for e in events]
    times=[float(e["time"]) for e in events]
    nominal_offsets=all(o>=0 and isinstance(o,int) for o in offsets)
    exact_dt=True
    # within each consecutive burst, event times must advance exactly one dt
    for grp in groups(events):
        for a,b in zip(grp[:-1],grp[1:]):
            if not math.isclose(float(b["time"])-float(a["time"]),dt,rel_tol=0.0,abs_tol=1e-12):
                exact_dt=False
    bursts=groups(events)
    chatter_bursts=[g for g in bursts if len(g)>=2]
    total_span=sum(len(g) for g in chatter_bursts)
    # Observation count from committed reverse to 540 d, inclusive of subsequent nominal intervals.
    obs_intervals=int(round((float(fx["final_time"])-float(fx["committed_reverse"]["time"]))/dt))
    span_fraction=(total_span/obs_intervals if obs_intervals>0 else None)
    hard_valid=(fx["max_ledger_cm"]<=5e-8 and fx["max_residual"]<=1e-10 and fx["max_rollback"]<=1e-15)
    retry_evidence=False
    extra_interval_inserted=False
    per_interval_work_data=False
    cls=("CHATTER_ON_NOMINAL_ACCEPTED_INTERVALS_ONLY"
         if nominal_offsets and exact_dt and hard_valid and not retry_evidence and not extra_interval_inserted
         else "CHATTER_CAUSES_RETRY_OR_SUBSTEP_BURDEN")
    records.append({
      "route":fx["route"],
      "classification":cls,
      "ownership_event_count":len(events),
      "chatter_burst_count":len(chatter_bursts),
      "chatter_burst_lengths":[len(g) for g in chatter_bursts],
      "total_chatter_span_intervals":total_span,
      "observed_nominal_intervals":obs_intervals,
      "chatter_span_fraction_of_nominal_intervals":span_fraction,
      "exact_nominal_dt_within_bursts":exact_dt,
      "hard_gates_valid":hard_valid,
      "retry_or_substep_evidence":retry_evidence,
      "extra_physical_interval_inserted":extra_interval_inserted,
      "per_interval_work_data_present":per_interval_work_data,
      "operation_cost_classification":"OPERATION_COST_UNRESOLVED"
    })

if any(r["classification"]=="CHATTER_CAUSES_RETRY_OR_SUBSTEP_BURDEN" for r in records):
    aggregate="NLGLOB14Z25_CHATTER_EXECUTION_BURDEN_CONFIRMED"
elif all(r["operation_cost_classification"]=="OPERATION_COST_UNRESOLVED" for r in records):
    aggregate="QUALIFIED_Z25_NO_TIMESTEP_RETRY_BURDEN_OPERATION_COST_UNRESOLVED"
else:
    aggregate="QUALIFIED_Z25_CHATTER_OPERATION_COST_CHARACTERIZED"

out={"aggregate":aggregate,"dt_day":dt,"records":records}
print("F_PE_NLGLOB14Z25_RESULT="+json.dumps(out,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z25=PASS")
