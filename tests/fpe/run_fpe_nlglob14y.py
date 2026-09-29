#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]
routes=("HEAD","RUNOFF"); horizon=.80; dtop=10.; pmax=.05; rsro=.05; dz=10.0
hatm=-2.75e5

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def theta_provider(m,h):
    if h>=0.0: return m["theta_s"]
    mm=1-1/m["n"]; hcrit=-1e-2
    if h>hcrit:
        c26=m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1+(abs(m["alpha"]*hcrit))**m["n"])**mm)
        c27=(m["theta_s"]-c26)/(-hcrit)
        return min(c26+c27*(h-hcrit),m["theta_s"])
    return m["theta_r"]+(m["theta_s"]-m["theta_r"])/((1+(abs(m["alpha"]*h))**m["n"])**mm)

def kprovider(m,h):
    if h < -1e14: return 1e-10
    th=theta_provider(m,h)
    rel=(th-m["theta_r"])/(m["theta_s"]-m["theta_r"])
    if rel>1-1e-6: return m["ksat"]
    mm=1-1/m["n"]
    if rel<=0.0: return 0.0
    term=(1-rel**(1/mm))**mm
    return min(m["ksat"]*(rel**m["lambda"])*(1-term)**2,m["ksat"])

def kvg(m,h):
    if h>=0.0: return m["ksat"]
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm)
    term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

def fixture(m,r):
    h=-5.; p=.025 if r=="HEAD" else .1
    kt=kvg(m,h); kf=.5*(m["ksat"]+kt); q=-kf*((p-h)/dtop+1)
    rain=-q if r=="HEAD" else -q+(p-pmax)/rsro
    return h,p,rain

def face_fluxes(m,h):
    k=[kprovider(m,x) for x in h]
    q=[None]*17
    for j in range(1,16):
        km=.5*(k[j-1]+k[j])
        q[j+1]=-km*((h[j-1]-h[j])/dz+1.0)
    return q

def dry_top(m,h_top,demand,fixed_k_top):
    # Exact unponded branch of the current B110 dynamic-top provider,
    # conductivity-mean method 1 and SWKIMPL=0 fixed top-node K.
    katm=kprovider(m,hatm)
    k1atm=.5*(katm+fixed_k_top)
    emax=-k1atm*((hatm-h_top)/dtop+1.0)
    evap=min(demand,max(0.0,emax))
    q1=evap
    if q1>=0.0 and q1>emax:
        qtop=emax
        route="atmospheric-head"
    else:
        # With previous ponding exactly zero and dry forcing, the provider's
        # h0 test remains on the surface-flux branch for this bank.
        qtop=q1
        route="surface-flux"
    return qtop,route,emax

def sat_tail(m,h,th):
    sat=[(h[i]>=0.0 and th[i]==m["theta_s"]) for i in range(16)]
    first=16
    while first>0 and sat[first-1]:
        first-=1
    if any(sat[:first]):
        return None
    return list(range(first+1,17))  # 1-based nodes

def gauss(a,b):
    n=len(b); a=[row[:] for row in a]; b=b[:]
    for i in range(n):
        p=max(range(i,n),key=lambda r:abs(a[r][i]))
        if abs(a[p][i])<1e-18: raise ArithmeticError("singular")
        if p!=i: a[i],a[p]=a[p],a[i]; b[i],b[p]=b[p],b[i]
        piv=a[i][i]
        for r in range(i+1,n):
            f=a[r][i]/piv
            if f==0.0: continue
            for c in range(i,n): a[r][c]-=f*a[i][c]
            b[r]-=f*b[i]
    x=[0.0]*n
    for i in range(n-1,-1,-1):
        x[i]=(b[i]-sum(a[i][j]*x[j] for j in range(i+1,n)))/a[i][i]
    return x

def solve_interval(m,h0,th0,demand,qbot,dt,upper_n):
    if upper_n<=0 or upper_n>=16:
        return None,False,"UNSUPPORTED_GEOMETRY"
    q0=face_fluxes(m,h0)
    fixed_k_top=kprovider(m,h0[0])
    qtop0,route0,emax0=dry_top(m,h0[0],demand,fixed_k_top)
    def endpoint(x):
        th=[theta_provider(m,v) for v in x]
        q=face_fluxes(m,x)
        qtop,route,emax=dry_top(m,x[0],demand,fixed_k_top)
        return th,q,qtop,route,emax
    thx,qx,qtopx,routex,emaxx=endpoint(h0)
    td0=[]
    for node in range(1,17):
        if node==1: v=(q0[2]-qtop0)/dz
        elif node==16: v=(qbot-q0[16])/dz
        else: v=(q0[node+1]-q0[node])/dz
        td0.append(v)
    h=h0[:]
    for i in range(upper_n):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        c=(theta_provider(m,h0[i]+eps)-theta_provider(m,h0[i]-eps))/(2*eps)
        if c>1e-14: h[i]+=dt*td0[i]/c

    iface=upper_n+1  # face index in q array, e.g. upper_n=3 -> face 4
    def residual(x):
        th1,q1,qtop1,route1,emax1=endpoint(x)
        td1=[]
        for node in range(1,17):
            if node==1: v=(q1[2]-qtop1)/dz
            elif node==16: v=(qbot-q1[16])/dz
            else: v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*16
        for i in range(upper_n):
            r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
        qbar=.5*(q0[iface]+q1[iface])
        j=upper_n
        # first lower node uses the single shared time-integrated interface flux
        if j==15:
            r[j]=th1[j]-th0[j]-dt*((qbot-qbar)/dz)
        else:
            r[j]=th1[j]-th0[j]-dt*((q1[j+2]-qbar)/dz)
            for i in range(j+1,15):
                r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
            r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
        return r,th1,q1,qtop1,route1,emax1,qbar

    best=None
    for it in range(1,31):
        r,th1,q1,qtop1,route1,emax1,qbar=residual(h)
        norm=max(abs(v) for v in r)
        best=(h[:],r,th1,q1,qtop0,qtop1,route0,route1,emax0,emax1,qbar,it,norm)
        if norm<=1e-10: return best,True,"CONVERGED"
        jac=[[0.0]*16 for _ in range(16)]
        for j in range(16):
            eps=max(1e-7,1e-6*max(1.0,abs(h[j])))
            hp=h[:]; hp[j]+=eps
            rp=residual(hp)[0]
            for i in range(16): jac[i][j]=(rp[i]-r[i])/eps
        try:
            dx=gauss(jac,[-v for v in r])
        except ArithmeticError:
            return best,False,"SINGULAR"
        base=norm; accepted=False
        for bt in range(12):
            fac=.5**bt
            trial=[h[i]+fac*dx[i] for i in range(16)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial): continue
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                h=trial; accepted=True; break
        if not accepted:
            return best,False,"NO_DESCENT"
    return best,False,"MAXIT"

rows=[]; proc=0; m=mats["O05"]
for route in routes:
    hinit,pinit,demand=fixture(m,route)
    for dt in dts:
        cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(hinit),str(pinit),str(demand),str(dt),str(horizon)],
            text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
        result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        bystep={}
        for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
        series={}
        ordered=[]
        for step in sorted(bystep):
            xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
            if len(xs)!=16: continue
            sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
            series[step]=(sat,xs); ordered.append(step)
        start=None
        for a,b in zip(ordered[:-1],ordered[1:]):
            sa,_=series[a]; sb,_=series[b]
            if len(sa)==14 and sb==list(range(4,17)) and 3 in sa and 3 not in sb and b==a+1:
                start=b; break
        control_ok=bool(result and result["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(result["ELIGIBLE"])==1 and
                        abs(float(result["MAX_LEDGER"]))<=5e-8 and abs(float(result["CUM_LEDGER"]))<=5e-8)
        rec={"material":"O05","route":route,"dt":dt,"control_ok":control_ok,"start_step":start}
        if start is None:
            rec["classification"]="NLGLOB14Y_ACCEPTED_STATE_TRANSACTION_INCONSISTENT"; rows.append(rec); continue
        sat0,xs0=series[start]
        h=[float(x["H"]) for x in xs0]; th=[float(x["THETA"]) for x in xs0]
        pond=float(xs0[0]["POND"])
        if abs(pond)>1e-12:
            rec["classification"]="NLGLOB14Y_DYNAMIC_TOP_NOT_PRESERVED"; rows.append(rec); continue
        accepted=0; rejected=0; maxledger=0.0; maxres=0.0; maxrb=0.0
        max_hdiff=0.0; max_tdiff=0.0; interface_changes=[]; chatter=0
        top_routes=set(); disappearance=None; failure=None
        split_second_time=None; split_third_time=None; split_fourth_time=None
        transition_intervals=[]; reverse_after_second=False; skipped_after_second=False
        control_second_time=None; control_third_time=None; control_fourth_time=None
        for sstep in sorted(series):
            ssat,_=series[sstep]
            if sstep<=start: continue
            if control_second_time is None and ssat==list(range(5,17)):
                control_second_time=sstep*dt
            if control_third_time is None and ssat==list(range(6,17)):
                control_third_time=sstep*dt
            if control_fourth_time is None and ssat==list(range(7,17)):
                control_fourth_time=sstep*dt
        sat_nodes=sat0[:]; prev_upper=3
        final_step=start
        for step in range(start+1,int(round(horizon/dt))+1):
            origin_h=h[:]; origin_th=th[:]
            tail=sat_tail(m,h,th)
            if tail is None:
                failure="NONCONTIGUOUS"; break
            if not tail:
                disappearance=step-1; break
            upper_n=16-len(tail)
            if upper_n<prev_upper:
                chatter+=1
            if upper_n!=prev_upper:
                interface_changes.append({"step":step-1,"from_upper":prev_upper,"to_upper":upper_n,
                                          "from_face":prev_upper+1,"to_face":upper_n+1})
            prev_upper=upper_n
            out,conv,reason=solve_interval(m,h,th,demand,0.0,dt,upper_n)
            if out is None:
                failure=reason; rejected+=1; break
            h1,r,th1,q1,qtop0,qtop1,route0,route1,emax0,emax1,qbar,iters,norm=out
            maxres=max(maxres,norm)
            rollback=max(max(abs(h[i]-origin_h[i]) for i in range(16)),
                         max(abs(th[i]-origin_th[i]) for i in range(16)))
            maxrb=max(maxrb,rollback)
            top_routes.update((route0,route1))
            finite=all(math.isfinite(v) for v in h1+th1+[qtop0,qtop1,qbar])
            ds=sum((th1[i]-th[i])*dz for i in range(16))
            topint=.5*dt*(qtop0+qtop1)
            ledger=ds-dt*0.0+topint
            maxledger=max(maxledger,abs(ledger))
            tail1=sat_tail(m,h1,th1)
            upper_valid=all(h1[i]<0.0 and th1[i]<m["theta_s"] for i in range(upper_n))
            interval_ok=(conv and norm<=1e-10 and finite and abs(ledger)<=5e-8 and
                         rollback<=1e-15 and upper_valid and tail1 is not None and
                         route0 in ("surface-flux","atmospheric-head") and
                         route1 in ("surface-flux","atmospheric-head"))
            if not interval_ok:
                rejected+=1; failure=("COUPLING" if not conv or norm>1e-10 else
                                      "TRANSACTION" if abs(ledger)>5e-8 or rollback>1e-15 else
                                      "DYNAMIC_TOP" if route0 not in ("surface-flux","atmospheric-head") or route1 not in ("surface-flux","atmospheric-head") else
                                      "UPPER")
                # rejected candidate is not committed
                if max(max(abs(h[i]-origin_h[i]) for i in range(16)),
                           max(abs(th[i]-origin_th[i]) for i in range(16)))>1e-15:
                    failure="TRANSACTION"
                break
            h=h1; th=th1; accepted+=1; final_step=step
            if step in series:
                _,cxs=series[step]
                ch=[float(x["H"]) for x in cxs]; ct=[float(x["THETA"]) for x in cxs]
                max_hdiff=max(max_hdiff,max(abs(h[i]-ch[i]) for i in range(16)))
                max_tdiff=max(max_tdiff,max(abs(th[i]-ct[i]) for i in range(16)))
            newtail=sat_tail(m,h,th)
            if newtail is not None:
                if len(newtail)>0 and len(tail)>0:
                    old_top=tail[0]; new_top=newtail[0]
                    if split_second_time is not None:
                        if new_top<old_top:
                            reverse_after_second=True
                        if new_top-old_top>1:
                            skipped_after_second=True
                    if old_top==4 and new_top==5 and split_second_time is None:
                        split_second_time=step*dt
                        transition_intervals.append({"step":step,"time":step*dt,"pre_sat":tail,"post_sat":newtail,
                                                     "pre_face":4,"post_face":5})
                    elif old_top==5 and new_top==6 and split_third_time is None:
                        split_third_time=step*dt
                        transition_intervals.append({"step":step,"time":step*dt,"pre_sat":tail,"post_sat":newtail,
                                                     "pre_face":5,"post_face":6})
                    elif old_top==6 and new_top==7 and split_fourth_time is None:
                        split_fourth_time=step*dt
                        transition_intervals.append({"step":step,"time":step*dt,"pre_sat":tail,"post_sat":newtail,
                                                     "pre_face":6,"post_face":7})
            if newtail is not None and not newtail:
                disappearance=step; break
        final_tail=sat_tail(m,h,th)
        reached=(final_step>=int(round(horizon/dt)) or disappearance is not None)
        if not control_ok or maxledger>5e-8 or maxrb>1e-15:
            cls="NLGLOB14Y_MULTI_RETREAT_TRANSACTION_INCONSISTENT"
        elif failure=="DYNAMIC_TOP":
            cls="NLGLOB14Y_DYNAMIC_TOP_NOT_PRESERVED"
        elif chatter>0 or reverse_after_second:
            cls="NLGLOB14Y_MULTI_RETREAT_INTERFACE_CHATTER"
        elif failure=="NONCONTIGUOUS" or skipped_after_second:
            cls="NLGLOB14Y_MULTI_RETREAT_GEOMETRY_INCONSISTENT"
        elif failure is not None:
            cls="NLGLOB14Y_MULTI_RETREAT_COUPLING_NOT_CLOSED"
        elif reached and split_third_time is not None and split_fourth_time is not None:
            cls="SPLIT_MULTI_RETREAT_SEQUENCE_VALID"
        elif reached:
            cls="NLGLOB14Y_SPLIT_RETREAT_SEQUENCE_NOT_COMPLETE"
        else:
            cls="NLGLOB14Y_MULTI_RETREAT_COUPLING_NOT_CLOSED"
        rec.update({"classification":cls,"accepted_intervals":accepted,"rejected_intervals":rejected,
                    "final_step":final_step,"final_time":final_step*dt,"final_sat_nodes":final_tail,
                    "interface_changes":interface_changes,"interface_change_count":len(interface_changes),
                    "chatter_count":chatter,"disappearance_step":disappearance,
                    "max_abs_mass_ledger":maxledger,"max_residual":maxres,"max_rollback":maxrb,
                    "max_control_head_diff":max_hdiff,"max_control_theta_diff":max_tdiff,
                    "top_routes":sorted(top_routes),"failure":failure,
                    "split_second_time":split_second_time,"split_third_time":split_third_time,"split_fourth_time":split_fourth_time,
                    "control_second_time":control_second_time,"control_third_time":control_third_time,"control_fourth_time":control_fourth_time,
                    "second_difference":None if split_second_time is None or control_second_time is None else split_second_time-control_second_time,
                    "third_difference":None if split_third_time is None or control_third_time is None else split_third_time-control_third_time,
                    "fourth_difference":None if split_fourth_time is None or control_fourth_time is None else split_fourth_time-control_fourth_time,
                    "transition_intervals":transition_intervals,"reverse_after_second":reverse_after_second,
                    "skipped_after_second":skipped_after_second})
        rows.append(rec)

classes=[x["classification"] for x in rows]
coverage=len(rows)==8 and proc==0 and all(x.get("control_ok") for x in rows)
valid=coverage and all(x=="SPLIT_MULTI_RETREAT_SEQUENCE_VALID" for x in classes)
if valid:
    agg="QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE"
elif any(x=="NLGLOB14Y_MULTI_RETREAT_TRANSACTION_INCONSISTENT" for x in classes):
    agg="NLGLOB14Y_MULTI_RETREAT_TRANSACTION_INCONSISTENT"
elif any(x=="NLGLOB14Y_DYNAMIC_TOP_NOT_PRESERVED" for x in classes):
    agg="NLGLOB14Y_DYNAMIC_TOP_NOT_PRESERVED"
elif any(x=="NLGLOB14Y_MULTI_RETREAT_INTERFACE_CHATTER" for x in classes):
    agg="NLGLOB14Y_MULTI_RETREAT_INTERFACE_CHATTER"
elif any(x=="NLGLOB14Y_MULTI_RETREAT_GEOMETRY_INCONSISTENT" for x in classes):
    agg="NLGLOB14Y_MULTI_RETREAT_GEOMETRY_INCONSISTENT"
elif any(x=="NLGLOB14Y_MULTI_RETREAT_COUPLING_NOT_CLOSED" for x in classes):
    agg="NLGLOB14Y_MULTI_RETREAT_COUPLING_NOT_CLOSED"
elif all(x in ("SPLIT_MULTI_RETREAT_SEQUENCE_VALID","NLGLOB14Y_SPLIT_RETREAT_SEQUENCE_NOT_COMPLETE") for x in classes):
    agg="NLGLOB14Y_SPLIT_RETREAT_SEQUENCE_NOT_COMPLETE" if not any(x=="SPLIT_MULTI_RETREAT_SEQUENCE_VALID" for x in classes) else "NLGLOB14Y_MIXED_MULTI_RETREAT_SEQUENCE"
else:
    agg="NLGLOB14Y_MIXED_MULTI_RETREAT_SEQUENCE"
summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
         "qualified_cases":sum(x=="SPLIT_MULTI_RETREAT_SEQUENCE_VALID" for x in classes),
         "incomplete_cases":sum(x=="NLGLOB14Y_SPLIT_RETREAT_SEQUENCE_NOT_COMPLETE" for x in classes),
         "total_accepted_intervals":sum(x.get("accepted_intervals",0) for x in rows),
         "total_interface_changes":sum(x.get("interface_change_count",0) for x in rows),
         "total_chatter":sum(x.get("chatter_count",0) for x in rows),
         "reverse_cases":sum(bool(x.get("reverse_after_second")) for x in rows),
         "skipped_cases":sum(bool(x.get("skipped_after_second")) for x in rows),
         "max_abs_mass_ledger":max((x.get("max_abs_mass_ledger",math.inf) for x in rows),default=math.inf),
         "max_residual":max((x.get("max_residual",math.inf) for x in rows),default=math.inf),
         "max_rollback":max((x.get("max_rollback",math.inf) for x in rows),default=math.inf),
         "event_times":[{"route":x["route"],"dt":x["dt"],
                         "split_third":x.get("split_third_time"),"control_third":x.get("control_third_time"),"third_diff":x.get("third_difference"),
                         "split_fourth":x.get("split_fourth_time"),"control_fourth":x.get("control_fourth_time"),"fourth_diff":x.get("fourth_difference")} for x in rows]}
print("F_PE_NLGLOB14Y_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Y_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Y=PASS")
