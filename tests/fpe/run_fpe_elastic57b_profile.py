#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess
from collections import defaultdict

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)
EPS=1.0e-12

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC57B_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"):
            return parse(line)
    raise SystemExit("F_PE_ELASTIC57B_FAIL missing bank row")

def semantic(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect",
          "full_nonlinear","half1_nonlinear","half2_nonlinear")
    return tuple(r.get(k) for k in keys)

def available(r):
    return int(r["full_status"])==1 and r["indicator_available"]=="T"

def err(r):
    return ALPHA*float(r["indicator_binf"])

def budgets(seq):
    vals=sorted(set(err(r) for r in seq if available(r) and err(r)>0.0))
    if not vals: return []
    out=[vals[0]*0.5]
    out.extend(math.sqrt(a*b) for a,b in zip(vals,vals[1:]))
    out.append(vals[-1]*2.0)
    return out

def is_nonmonotone(seq):
    a=[r for r in seq if available(r)]
    if len(a)<3: return False
    return any(err(nxt)>err(prev)*(1.0+EPS) for prev,nxt in zip(a,a[1:]))

def run_controller(seq,budget,kind):
    attempts=0; unavailable=0; nonlinear=0; indicators=0
    prev_e=None
    max_attempts=9 if kind=="C-BOUNDED" else len(seq)
    for r in seq:
        if attempts>=max_attempts: break
        attempts += 1
        try: nonlinear += int(r.get("full_nonlinear","0"))
        except ValueError: pass
        if not available(r):
            unavailable += 1
            continue
        indicators += 1
        e=err(r)
        if kind=="C-NAIVE" and prev_e is not None and e>prev_e*(1.0+EPS):
            return dict(decision="NONMONOTONE_ABORT",dt=math.nan,attempts=attempts,
                        retries=max(0,attempts-1),unavailable=unavailable,
                        nonlinear=nonlinear,indicators=indicators,paired=False,envelope=True)
        if e<=budget:
            paired=(r["all_converged"]=="T" and float(r["dh_inf"])>0.0)
            envelope=(not paired) or float(r["dh_inf"])<=ALPHA*float(r["indicator_binf"])*(1.0+EPS)
            return dict(decision="ACCEPT",dt=float(r["dt"]),attempts=attempts,
                        retries=max(0,attempts-1),unavailable=unavailable,
                        nonlinear=nonlinear,indicators=indicators,paired=paired,envelope=envelope)
        prev_e=e
    return dict(decision="EXHAUSTED",dt=math.nan,attempts=attempts,
                retries=max(0,attempts-1),unavailable=unavailable,
                nonlinear=nonlinear,indicators=indicators,paired=False,envelope=True)

def acc_new():
    return defaultdict(int)

def add(a,res):
    a["tests"]+=1
    a["accept"] += res["decision"]=="ACCEPT"
    a["exhausted"] += res["decision"]=="EXHAUSTED"
    a["abort"] += res["decision"]=="NONMONOTONE_ABORT"
    a["attempts"] += res["attempts"]
    a["retries"] += res["retries"]
    a["unavailable"] += res["unavailable"]
    a["nonlinear"] += res["nonlinear"]
    a["indicators"] += res["indicators"]
    a["paired_accepts"] += res["paired"]
    a["envelope_fail"] += not res["envelope"]

def emit_metric(profile,scope,regime,controller,a):
    work=a["nonlinear"]+a["indicators"]
    print("ELASTIC57B_METRIC|"+
          f"profile={profile}|scope={scope}|regime={regime}|controller={controller}|"+
          f"tests={a['tests']}|accept={a['accept']}|exhausted={a['exhausted']}|abort={a['abort']}|"+
          f"attempts={a['attempts']}|retries={a['retries']}|unavailable={a['unavailable']}|"+
          f"nonlinear={a['nonlinear']}|indicator_solves={a['indicators']}|work_units={work}|"+
          f"paired_accepts={a['paired_accepts']}|envelope_fail={a['envelope_fail']}|headcalc_calls=NA")

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for idx,dt in enumerate(DTS):
                        r=execute(exe,reg,h,d,dt); r["_retry"]=idx; rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC57B_FAIL key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC57B_FAIL O0/O2 {k}")

    seqs={}
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=sorted([r for r in rows["O2"] if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                           key=lambda r:r["_retry"])
                if len([r for r in seq if available(r)])>=3:
                    seqs[(h,d,reg)]=seq

    violating={k for k,s in seqs.items() if is_nonmonotone(s)}
    monotone=set(seqs)-violating

    controls={}
    for vk in sorted(violating):
        h,d,reg=vk
        cand=[k for k in monotone if k[0]==h and k[2]==reg]
        if not cand:
            raise SystemExit(f"F_PE_ELASTIC57B_FAIL no control for {vk}")
        same_abs_opp=[k for k in cand if abs(abs(k[1])-abs(d))<=1e-15 and k[1]*d<0.0]
        if same_abs_opp:
            ck=sorted(same_abs_opp,key=lambda k:k[1])[0]
        else:
            ck=sorted(cand,key=lambda k:(abs(k[1]-d),k[1]))[0]
        controls[vk]=ck
        print(f"ELASTIC57B_CONTROL|profile={a.profile_id}|vh0={h}|vdelta={d}|vregime={reg}|"+
              f"ch0={ck[0]}|cdelta={ck[1]}|cregime={ck[2]}")

    control_keys=set(controls.values())
    controllers=("C-NAIVE","C-SAFE","C-BOUNDED")
    metrics={}
    def bucket(scope,reg,ctl):
        return metrics.setdefault((scope,reg,ctl),acc_new())

    safe_bounded_mismatch=0
    chatter=0
    for sk,seq in seqs.items():
        h,d,reg=sk
        scopes=["ALL"]
        if sk in violating: scopes.append("VIOLATING")
        if sk in control_keys: scopes.append("CONTROL")
        for budget in budgets(seq):
            results={ctl:run_controller(seq,budget,ctl) for ctl in controllers}
            s=results["C-SAFE"]; b=results["C-BOUNDED"]
            same_dec=s["decision"]==b["decision"]
            same_dt=(s["decision"]!="ACCEPT") or abs(s["dt"]-b["dt"])<=1e-18
            if not (same_dec and same_dt): safe_bounded_mismatch+=1
            # All controllers only move forward over the frozen unique ladder.
            chatter += 0
            for ctl,res in results.items():
                if ctl in ("C-SAFE","C-BOUNDED"):
                    if res["decision"]=="ACCEPT" and not res["envelope"]:
                        raise SystemExit("F_PE_ELASTIC57B_FAIL envelope")
                for scope in scopes:
                    add(bucket(scope,reg,ctl),res)
                    add(bucket(scope,"ALL",ctl),res)

    for (scope,reg,ctl),m in sorted(metrics.items()):
        emit_metric(a.profile_id,scope,reg,ctl,m)

    print(f"ELASTIC57B_PROFILE|profile={a.profile_id}|eligible={len(seqs)}|violating={len(violating)}|"+
          f"controls={len(control_keys)}|safe_bounded_mismatch={safe_bounded_mismatch}|chatter={chatter}")
    if safe_bounded_mismatch:
        raise SystemExit("F_PE_ELASTIC57B_FAIL safe/bounded mismatch")
    print("F_PE_ELASTIC57B_PROFILE=PASS")

if __name__=="__main__":
    main()
