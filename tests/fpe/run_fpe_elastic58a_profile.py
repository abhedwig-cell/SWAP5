#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
H_BUDGET=0.01
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def call(exe,args,prefix):
    cp=subprocess.run([str(exe),*map(str,args)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58A_FAIL rc={cp.returncode} exe={exe}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith(prefix): row=parse(line)
    if row is None: raise SystemExit(f"F_PE_ELASTIC58A_FAIL missing {prefix}")
    return row

def sel_sem(r):
    return tuple(r.get(k) for k in ("full_status","indicator_available","indicator_binf"))

def oracle_sem(r):
    keys=("candidate_status","oracle_complete","fail_step","last_success","fail_status","fail_nonlinear",
          "fail_backtracking","fail_jacobians","fail_linear","fail_internal_retries","last_hmin","last_hmax")
    return tuple(r.get(k) for k in keys)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--selector-o0",required=True)
    ap.add_argument("--selector-o2",required=True)
    ap.add_argument("--oracle-o0",required=True)
    ap.add_argument("--oracle-o2",required=True)
    a=ap.parse_args()

    accepted=0; first=0; late=0; complete=0
    status_counts={}
    fail_steps=[]
    disc_counts={2:0,4:0,8:0,16:0,32:0}

    for h0 in HEADS:
        for delta in DELTAS:
            for regime in REGIMES:
                chosen=None
                for idx,dt in enumerate(DTS):
                    s0=call(a.selector_o0,[regime,h0,delta,dt],"ELASTIC55_BANK|")
                    s2=call(a.selector_o2,[regime,h0,delta,dt],"ELASTIC55_BANK|")
                    if sel_sem(s0)!=sel_sem(s2):
                        raise SystemExit("F_PE_ELASTIC58A_FAIL selector O0/O2 drift")
                    if int(s2["full_status"])!=1 or s2["indicator_available"]!="T": continue
                    b=float(s2["indicator_binf"])
                    if ALPHA*b <= H_BUDGET*(1+1e-15):
                        chosen=(idx,dt,b); break
                if chosen is None:
                    continue
                accepted+=1
                idx,dt,b=chosen

                o0=call(a.oracle_o0,[regime,h0,delta,dt],"ELASTIC58_ORACLE|")
                o2=call(a.oracle_o2,[regime,h0,delta,dt],"ELASTIC58_ORACLE|")
                if oracle_sem(o0)!=oracle_sem(o2):
                    raise SystemExit("F_PE_ELASTIC58A_FAIL oracle O0/O2 drift")

                oc=o2["oracle_complete"]=="T"
                fs=int(o2["fail_step"]); ls=int(o2["last_success"]); st=int(o2["fail_status"])
                if oc:
                    complete+=1
                    cls="COMPLETE"
                else:
                    if fs<=0:
                        raise SystemExit("F_PE_ELASTIC58A_FAIL incomplete oracle without fail step")
                    fail_steps.append(fs)
                    status_counts[st]=status_counts.get(st,0)+1
                    if fs==1:
                        first+=1; cls="FIRST_SUBSTEP_FAILURE"
                    else:
                        late+=1; cls="LATE_CHAIN_FAILURE"

                disc=[]
                for div in (2,4,8,16,32):
                    ddt=dt/div
                    s=call(a.selector_o2,[regime,h0,delta,ddt],"ELASTIC55_BANK|")
                    conv=int(s["full_status"])==1
                    if conv: disc_counts[div]+=1
                    disc.append(f"d{div}={'1' if conv else '0'}")

                print(
                    f"ELASTIC58A_CASE|profile={a.profile_id}|regime={regime}|h0={h0}|delta={delta}|accepted_dt={dt}"
                    f"|oracle_complete={'T' if oc else 'F'}|class={cls}|fail_step={fs}|last_success={ls}|fail_status={st}"
                    f"|fail_nonlinear={o2['fail_nonlinear']}|fail_backtracking={o2['fail_backtracking']}"
                    f"|fail_jacobians={o2['fail_jacobians']}|fail_linear={o2['fail_linear']}"
                    f"|fail_internal_retries={o2['fail_internal_retries']}|last_hmin={o2['last_hmin']}|last_hmax={o2['last_hmax']}"
                    f"|{'|'.join(disc)}"
                )

    if accepted==0: raise SystemExit("F_PE_ELASTIC58A_FAIL no accepted cases")
    print(
        f"ELASTIC58A_PROFILE_SUMMARY|profile={a.profile_id}|accepted={accepted}|complete={complete}"
        f"|first_substep={first}|late_chain={late}|min_fail_step={min(fail_steps) if fail_steps else 0}"
        f"|max_fail_step={max(fail_steps) if fail_steps else 0}"
    )
    for st,n in sorted(status_counts.items()):
        print(f"ELASTIC58A_STATUS_COUNT|profile={a.profile_id}|status={st}|count={n}")
    for div,n in disc_counts.items():
        print(f"ELASTIC58A_DISCRIMINATOR|profile={a.profile_id}|divisor={div}|single_step_converged={n}")
    print("F_PE_ELASTIC58A_PROFILE=PASS")

if __name__=="__main__":
    main()
