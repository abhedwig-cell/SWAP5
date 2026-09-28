#!/usr/bin/env python3
import json, math, statistics

DTMIN=0.001
GROW=2.0
DECREASE=0.5
NUMBIT_CRIT=4
MAXIT=8
TOL=1e-12

def decision(base, dtmax, numbit):
    x=base
    if numbit<=NUMBIT_CRIT:
        x=min(x*GROW,dtmax)
    if numbit>=MAXIT:
        x=max(x*DECREASE,DTMIN)
    return max(x,DTMIN)

def sequence(dtmax,event_cadence,numbits,horizon=1.0):
    actual=math.sqrt(DTMIN*dtmax)
    retain=actual
    evidence=actual
    prev_event=False
    t=0.0
    rows=[]
    k=0
    while t<horizon-TOL:
        numbit=numbits[k%len(numbits)]
        next_event=(math.floor((t+TOL)/event_cadence)+1)*event_cadence
        exec_dt=min(actual,next_event-t,horizon-t)
        clamped=exec_dt<actual-TOL

        actual_next=decision(exec_dt,dtmax,numbit)
        if not rows:
            retain_next=actual_next
            evidence_next=actual_next
        elif prev_event:
            retain_next=retain
            evidence_next=decision(evidence,dtmax,numbit)
        else:
            retain_next=actual_next
            evidence_next=actual_next

        rows.append({
            "step":k,"t0":t,"executed_dt":exec_dt,"event_clamped":clamped,
            "numbit":numbit,"actual_next":actual_next,
            "retain_next":retain_next,"evidence_next":evidence_next,
        })
        t+=exec_dt
        actual=actual_next
        retain=retain_next
        evidence=evidence_next
        prev_event=clamped
        k+=1
        if k>10000:
            raise RuntimeError("step limit")
    return rows

scenarios=[]
for dtmax in (0.02,0.05,0.10,0.25):
    for cadence in (1/24,1/48,1/96):
        for name,numbits in [
            ("easy",[3]),
            ("mixed",[3,5,3,5]),
            ("hard_after_event",[3,8,3,5]),
        ]:
            rows=sequence(dtmax,cadence,numbits)
            clamped=[r for r in rows if r["event_clamped"]]
            divergent=[r for r in rows if abs(r["retain_next"]-r["actual_next"])>TOL or abs(r["evidence_next"]-r["actual_next"])>TOL]
            scenarios.append({
                "dtmax":dtmax,"cadence":cadence,"pattern":name,
                "steps":len(rows),"event_clips":len(clamped),
                "divergent_steps":len(divergent),
                "max_retain_actual_ratio":max((r["retain_next"]/r["actual_next"] for r in rows if r["actual_next"]>0),default=1),
                "max_evidence_actual_ratio":max((r["evidence_next"]/r["actual_next"] for r in rows if r["actual_next"]>0),default=1),
            })

summary={
    "scenarios":len(scenarios),
    "scenarios_with_event_clips":sum(x["event_clips"]>0 for x in scenarios),
    "scenarios_with_persistent_divergence":sum(x["divergent_steps"]>0 for x in scenarios),
    "median_divergent_steps":statistics.median(x["divergent_steps"] for x in scenarios),
    "max_retain_actual_ratio":max(x["max_retain_actual_ratio"] for x in scenarios),
    "max_evidence_actual_ratio":max(x["max_evidence_actual_ratio"] for x in scenarios),
}
summary["advances"]=summary["scenarios_with_persistent_divergence"]>0

print("F_PE_TIMEARCH08_SHADOW_SCENARIOS="+json.dumps(scenarios,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH08_SHADOW_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
if not summary["advances"]:
    raise SystemExit("no persistent memory divergence observed")
print("F_PE_TIMEARCH08_SHADOW=PASS")
