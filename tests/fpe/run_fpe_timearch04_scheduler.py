#!/usr/bin/env python3
import json, math, statistics

DTMIN_USER=0.001
GROW=2.0
HORIZON=7.0
DTMAX_GRID=[0.02,0.05,0.10,0.25,1.00]
OUTPUT_GRID=[1.0,1.0/24.0,1.0/48.0,1.0/96.0]
TOL=1e-12

def next_multiple(t,cadence):
    n=math.floor((t+TOL)/cadence)+1
    return n*cadence

def at_day_boundary(t):
    return t>0 and abs(t-round(t))<=1e-10 and t < HORIZON-TOL

def simulate(user_max,output_cadence,mode):
    if mode=="CURRENT_COUPLED":
        num_max=min(user_max,output_cadence)
        num_min=min(DTMIN_USER,0.1*num_max)
        output_hard=True
    elif mode in ("SCHEDULER_ONLY_OUTPUT","OUTPUT_DECOUPLED_SHADOW"):
        num_max=user_max
        num_min=DTMIN_USER
        output_hard=(mode=="SCHEDULER_ONLY_OUTPUT")
    else:
        raise ValueError(mode)

    dt=math.sqrt(num_min*num_max)
    t=0.0
    steps=0
    event_clips=0
    day_resets=0
    dts=[]

    while t < HORIZON-TOL:
        if at_day_boundary(t):
            floor=math.sqrt(num_min*num_max)
            if dt < floor-TOL:
                dt=floor
                day_resets+=1

        day_event=min(HORIZON, math.floor(t+TOL)+1.0)
        event=day_event
        if output_hard:
            event=min(event,next_multiple(t,output_cadence))
        remaining=HORIZON-t
        exec_dt=min(dt,event-t,remaining)
        if exec_dt <= TOL:
            raise RuntimeError((mode,user_max,output_cadence,t,dt,event))
        if exec_dt < dt-TOL:
            event_clips+=1

        dts.append(exec_dt)
        steps+=1
        t+=exec_dt
        if abs(t-round(t))<=1e-12:
            t=float(round(t))
        dt=min(exec_dt*GROW,num_max)

        if steps>100000:
            raise RuntimeError("step limit")

    return {
        "steps":steps,
        "event_clips":event_clips,
        "day_resets":day_resets,
        "mean_dt":statistics.mean(dts),
        "median_dt":statistics.median(dts),
        "numerical_min":num_min,
        "numerical_max":num_max,
    }

rows=[]
for user_max in DTMAX_GRID:
    for out in OUTPUT_GRID:
        a=simulate(user_max,out,"CURRENT_COUPLED")
        b=simulate(user_max,out,"SCHEDULER_ONLY_OUTPUT")
        c=simulate(user_max,out,"OUTPUT_DECOUPLED_SHADOW")
        rows.append({
            "user_dtmax":user_max,
            "output_cadence":out,
            "current":a,
            "scheduler_only":b,
            "output_decoupled_shadow":c,
            "scheduler_step_ratio":b["steps"]/a["steps"],
            "decoupled_step_ratio":c["steps"]/a["steps"],
            "scheduler_material":abs(b["steps"]/a["steps"]-1.0)>=0.10,
            "decoupled_material":c["steps"]/a["steps"]<=0.90,
        })

sched_ratios=[x["scheduler_step_ratio"] for x in rows]
dec_ratios=[x["decoupled_step_ratio"] for x in rows]
fine=[x for x in rows if x["output_cadence"]<=1.0/24.0+TOL]
summary={
    "grid_points":len(rows),
    "scheduler_material_points":sum(x["scheduler_material"] for x in rows),
    "decoupled_material_points":sum(x["decoupled_material"] for x in rows),
    "median_scheduler_step_ratio":statistics.median(sched_ratios),
    "min_scheduler_step_ratio":min(sched_ratios),
    "max_scheduler_step_ratio":max(sched_ratios),
    "median_decoupled_step_ratio":statistics.median(dec_ratios),
    "min_decoupled_step_ratio":min(dec_ratios),
    "fine_output_median_decoupled_ratio":statistics.median(x["decoupled_step_ratio"] for x in fine),
}

print("F_PE_TIMEARCH04_ROWS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH04_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_TIMEARCH04=PASS")
