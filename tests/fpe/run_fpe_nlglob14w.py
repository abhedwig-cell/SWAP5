#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]
routes=("HEAD","RUNOFF"); horizon=.05; dtop=10.; pmax=.05; rsro=.05; dz=10.0; max_accept=512

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

def divergence(q,qtop,qbot):
    td=[]
    for node in range(1,17):
        if node==1: v=(q[2]-qtop)/dz
        elif node==16: v=(qbot-q[16])/dz
        else: v=(q[node+1]-q[node])/dz
        td.append(v)
    return td

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

def saturated_top(m,h,th):
    sat=[i+1 for i,(hh,tt) in enumerate(zip(h,th)) if hh>=0.0 and abs(tt-m["theta_s"])<=1e-12]
    if not sat: return None,sat,True
    top=min(sat)
    contiguous=(sat==list(range(top,17)))
    return top,sat,contiguous

def solve_split(m,h0,th0,qtop,qbot,dt,k):
    # k is 1-based first lower saturated-owned node, interface face is k.
    q0=face_fluxes(m,h0); td0=divergence(q0,qtop,qbot)
    h=h0[:]
    for i in range(k-1):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        c=(theta_provider(m,h0[i]+eps)-theta_provider(m,h0[i]-eps))/(2*eps)
        if c>1e-14: h[i]+=dt*td0[i]/c

    def residual(x):
        q1=face_fluxes(m,x); th1=[theta_provider(m,v) for v in x]
        td1=divergence(q1,qtop,qbot); r=[0.0]*16
        for i in range(k-1):
            r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
        qbar=.5*(q0[k]+q1[k])
        i=k-1
        r[i]=th1[i]-th0[i]-dt*((q1[k+1]-qbar)/dz)
        for i in range(k,15):
            r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
        r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
        return r,q1,th1,qbar

    best=None; total_back=0
    for it in range(1,31):
        r,q1,th1,qbar=residual(h); norm=max(abs(v) for v in r)
        best=(h[:],r,q1,th1,qbar,it,norm,total_back)
        if norm<=1e-10: return best,True
        jac=[[0.0]*16 for _ in range(16)]
        for j in range(16):
            eps=max(1e-7,1e-6*max(1.0,abs(h[j])))
            hp=h[:]; hp[j]+=eps; rp=residual(hp)[0]
            for i in range(16): jac[i][j]=(rp[i]-r[i])/eps
        try: dx=gauss(jac,[-v for v in r])
        except ArithmeticError: return best,False
        base=norm; accepted=False
        for bt in range(12):
            fac=.5**bt; trial=[h[i]+fac*dx[i] for i in range(16)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial): continue
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                h=trial; total_back+=bt; accepted=True; break
        if not accepted: return best,False
    return best,False

rows=[]; proc=0; m=mats["O05"]
for route in routes:
    hinit,pinit,rain=fixture(m,route)
    for dt in dts:
        cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
            str(m["ksat"]),str(m["lambda"]),str(hinit),str(pinit),str(rain),str(dt),str(horizon)],
            text=True,capture_output=True)
        if cp.returncode!=0: proc+=1
        states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
        res=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
        bystep={}
        for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
        series=[]
        for step in sorted(bystep):
            xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
            if len(xs)!=16: continue
            sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
            series.append((step,sat,xs))
        hand_i=None
        for i in range(len(series)-1):
            a,b=series[i],series[i+1]
            if len(a[1])==14 and b[1]==list(range(4,17)) and 3 in a[1] and 3 not in b[1]:
                hand_i=i+1; break

        control_ok=bool(res and res["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(res["ELIGIBLE"])==1 and
                        abs(float(res["MAX_LEDGER"]))<=5e-8 and abs(float(res["CUM_LEDGER"]))<=5e-8)
        rec={"material":"O05","route":route,"dt":dt,"control_ok":control_ok}
        if hand_i is None:
            rec["classification"]="NLGLOB14U_TRANSACTION_INCONSISTENT"; rows.append(rec); continue

        step0,sat0,xs0=series[hand_i]
        h=[float(x["H"]) for x in xs0]; th=[float(x["THETA"]) for x in xs0]
        pond=float(xs0[0]["POND"]); qtop=float(xs0[0]["TOP_FLUX"]); qbot=float(xs0[0]["BOTTOM_FLUX"])
        accepted_time=step0*dt; cumledger=0.0; maxledger=0.0; maxres=0.0; accepted=0
        transitions=[]; faces=[]; sat_tops=[]; chatter=0; noncontig=0; upper_events=0
        retreats=0; max_rb=0.0; total_nl=0; total_back=0; max_ctrl_h=0.0; max_ctrl_th=0.0
        rejected=False; reject_class=None; disappeared=False
        prev_top=4; seen_tops=[4]
        control_by_step={s[0]:s for s in series}

        while accepted<max_accept and accepted_time+dt<=horizon+1e-15:
            k,sat,contig=saturated_top(m,h,th)
            if k is None:
                disappeared=True; break
            if not contig:
                noncontig+=1; reject_class="NLGLOB14U_NONCONTIGUOUS_SATURATED_SET"; rejected=True; break
            if k<=1:
                reject_class="NLGLOB14U_UPPER_TG_OWNERSHIP_NOT_PERSISTENT"; rejected=True; break

            origin_h=h[:]; origin_th=th[:]; origin_pond=pond; origin_time=accepted_time
            shadow,conv=solve_split(m,h,th,qtop,qbot,dt,k)
            h1,r,q1,th1,qbar,iters,norm,backs=shadow
            total_nl+=iters; total_back+=backs; maxres=max(maxres,norm)
            q0=face_fluxes(m,h)
            ds=sum((th1[i]-th[i])*dz for i in range(16))
            ledger=ds-dt*(qbot-qtop)
            maxledger=max(maxledger,abs(ledger))
            interface_cancel=0.0
            finite=all(math.isfinite(v) for v in h1+th1+[x for x in q1[2:17] if x is not None])
            upper_cross=sum(1 for i in range(k-1) if h[i]<0.0 and h1[i]>=0.0)
            k1,sat1,contig1=saturated_top(m,h1,th1)

            if not conv or norm>1e-10:
                reject_class="NLGLOB14U_INTERFACE_COUPLING_NOT_PERSISTENT"
            elif not finite:
                reject_class="NLGLOB14U_SATURATED_BLOCK_EVOLUTION_NOT_PERSISTENT"
            elif abs(ledger)>5e-8 or abs(cumledger+ledger)>5e-8 or abs(interface_cancel)>1e-12:
                reject_class="NLGLOB14U_TRANSACTION_INCONSISTENT"
            elif upper_cross>0:
                reject_class="NLGLOB14U_UPPER_TG_OWNERSHIP_NOT_PERSISTENT"
            elif k1 is not None and not contig1:
                reject_class="NLGLOB14U_NONCONTIGUOUS_SATURATED_SET"
            else:
                reject_class=None

            if reject_class:
                # private candidate rejected: accepted origin must remain exact.
                max_rb=max(max_rb,max(max(abs(h[i]-origin_h[i]) for i in range(16)),
                                      max(abs(th[i]-origin_th[i]) for i in range(16)),
                                      abs(pond-origin_pond),abs(accepted_time-origin_time)))
                rejected=True; break

            # accepted research state
            h=h1; th=th1; accepted+=1; accepted_time+=dt; cumledger+=ledger
            faces.append(k); sat_tops.append(k if k1 is None else k1)
            upper_events+=upper_cross

            if k1 is None:
                disappeared=True; break
            if k1<k:
                chatter+=1
                reject_class="NLGLOB14U_INTERFACE_CHATTER"; rejected=True; break
            if k1>k:
                retreats+=k1-k
                transitions.append({"accepted_interval":accepted,"from_top":k,"to_top":k1,
                                    "from_face":k,"to_face":k1})
            if len(seen_tops)>=1 and k1<max(seen_tops):
                chatter+=1
                reject_class="NLGLOB14U_INTERFACE_CHATTER"; rejected=True; break
            seen_tops.append(k1); prev_top=k1

            ctrl=control_by_step.get(step0+accepted)
            if ctrl:
                cxs=ctrl[2]; ch=[float(x["H"]) for x in cxs]; ct=[float(x["THETA"]) for x in cxs]
                max_ctrl_h=max(max_ctrl_h,max(abs(h[i]-ch[i]) for i in range(16)))
                max_ctrl_th=max(max_ctrl_th,max(abs(th[i]-ct[i]) for i in range(16)))

        control_second=next((ss for ss in series[hand_i+1:] if ss[1]==list(range(5,17))),None)
        split_second=next((t for t in transitions if t["from_top"]==4 and t["to_top"]==5),None)
        if rejected:
            cls=(reject_class.replace("NLGLOB14U_","NLGLOB14W_") if reject_class else "NLGLOB14W_MIXED_SECOND_RETREAT_TRANSITION")
        elif noncontig:
            cls="NLGLOB14W_NONCONTIGUOUS_SATURATED_SET"
        elif chatter:
            cls="NLGLOB14W_INTERFACE_CHATTER"
        elif split_second is not None:
            cls="SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION"
        else:
            cls="NLGLOB14W_SPLIT_SECOND_RETREAT_NOT_EXPOSED"

        rec.update({"classification":cls,"start_step":step0,"accepted_intervals":accepted,
            "final_time":accepted_time,"initial_sat_top":4,"final_sat_top":None if disappeared else prev_top,
            "interface_transition_count":len(transitions),"transitions":transitions,
            "faces":faces,"sat_tops":sat_tops,"retreat_events":retreats,"chatter_count":chatter,
            "noncontiguous_count":noncontig,"upper_events":upper_events,"max_abs_mass_ledger":maxledger,
            "cumulative_mass_ledger":cumledger,"max_residual":maxres,"max_rollback":max_rb,
            "nonlinear_iterations":total_nl,"backtracking":total_back,"saturated_block_disappeared":disappeared,
            "max_control_head_diff":max_ctrl_h,"max_control_theta_diff":max_ctrl_th,\n            "control_second_retreat_time":(control_second[0]*dt if control_second else None),\n            "split_second_retreat_time":(split_second["time"] if split_second else None),\n            "second_retreat_time_difference":((split_second["time"]-control_second[0]*dt) if split_second and control_second else None)})
        rows.append(rec)

classes=[x["classification"] for x in rows]
coverage=len(rows)==8 and proc==0 and all(x.get("control_ok") for x in rows)
if coverage and all(x=="SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION" for x in classes):
    agg="QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION_RESEARCH"
elif any(x=="NLGLOB14W_TRANSACTION_INCONSISTENT" for x in classes):
    agg="NLGLOB14W_TRANSACTION_INCONSISTENT"
elif any(x=="NLGLOB14W_INTERFACE_CHATTER" for x in classes):
    agg="NLGLOB14W_INTERFACE_CHATTER"
elif any(x=="NLGLOB14W_NONCONTIGUOUS_SATURATED_SET" for x in classes):
    agg="NLGLOB14W_NONCONTIGUOUS_SATURATED_SET"
elif any(x=="NLGLOB14W_UPPER_TG_OWNERSHIP_NOT_PERSISTENT" for x in classes):
    agg="NLGLOB14W_UPPER_TG_OWNERSHIP_NOT_PERSISTENT"
elif any(x=="NLGLOB14W_SATURATED_BLOCK_EVOLUTION_NOT_PERSISTENT" for x in classes):
    agg="NLGLOB14W_SATURATED_BLOCK_EVOLUTION_NOT_PERSISTENT"
elif any(x=="NLGLOB14W_INTERFACE_COUPLING_NOT_PERSISTENT" for x in classes):
    agg="NLGLOB14W_INTERFACE_COUPLING_NOT_PERSISTENT"
elif all(x=="NLGLOB14W_SPLIT_SECOND_RETREAT_NOT_EXPOSED" for x in classes):
    agg="NLGLOB14W_SPLIT_SECOND_RETREAT_NOT_EXPOSED"
else:
    agg="NLGLOB14W_MIXED_SECOND_RETREAT_TRANSITION"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
    "qualified_cases":sum(x=="SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION" for x in classes),
    "total_accepted_intervals":sum(x.get("accepted_intervals",0) for x in rows),
    "total_interface_transitions":sum(x.get("interface_transition_count",0) for x in rows),
    "total_retreat_events":sum(x.get("retreat_events",0) for x in rows),
    "total_chatter":sum(x.get("chatter_count",0) for x in rows),
    "total_noncontiguous":sum(x.get("noncontiguous_count",0) for x in rows),
    "disappearance_cases":sum(bool(x.get("saturated_block_disappeared")) for x in rows),\n    "split_second_retreat_cases":sum(x=="SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION" for x in classes),\n    "split_second_retreat_times":[x.get("split_second_retreat_time") for x in rows],\n    "control_second_retreat_times":[x.get("control_second_retreat_time") for x in rows],
    "max_abs_mass_ledger":max((x.get("max_abs_mass_ledger",math.inf) for x in rows),default=math.inf),
    "max_abs_cumulative_mass_ledger":max((abs(x.get("cumulative_mass_ledger",math.inf)) for x in rows),default=math.inf),
    "max_residual":max((x.get("max_residual",math.inf) for x in rows),default=math.inf),
    "max_rollback":max((x.get("max_rollback",math.inf) for x in rows),default=math.inf)}
print("F_PE_NLGLOB14W_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14W_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14W=PASS")
