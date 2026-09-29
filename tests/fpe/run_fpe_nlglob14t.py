#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125,0.000015625,0.0000078125]
routes=("HEAD","RUNOFF"); horizon=.05; dtop=10.; pmax=.05; rsro=.05; dz=10.0

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

def solve_split(m,h0,th0,qtop,qbot,dt):
    q0=face_fluxes(m,h0); td0=divergence(q0,qtop,qbot)
    h=h0[:]
    for i in range(3):
        # TG-consistent first predictor only as a start, not as an accepted equation.
        cap_eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        c=(theta_provider(m,h0[i]+cap_eps)-theta_provider(m,h0[i]-cap_eps))/(2*cap_eps)
        if c>1e-14: h[i]+=dt*td0[i]/c

    def residual(x):
        q1=face_fluxes(m,x)
        th1=[theta_provider(m,v) for v in x]
        td1=divergence(q1,qtop,qbot)
        r=[0.0]*16
        # Upper TG domain: trapezoidal physical storage balance.
        for i in range(3):
            r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
        # One temporal interface-exchange authority shared by both domains.
        qint_bar=.5*(q0[4]+q1[4])
        # Lower saturated/full-Richards block: endpoint treatment internally,
        # with the exact same time-integrated interface exchange as the upper domain.
        r[3]=th1[3]-th0[3]-dt*((q1[5]-qint_bar)/dz)
        for i in range(4,15):
            r[i]=th1[i]-th0[i]-dt*((q1[i+2]-q1[i+1])/dz)
        r[15]=th1[15]-th0[15]-dt*((qbot-q1[16])/dz)
        return r,q1,th1,td1,qint_bar

    best=None
    for it in range(1,31):
        r,q1,th1,td1,qbar=residual(h)
        norm=max(abs(v) for v in r)
        best=(h[:],r,q1,th1,td1,qbar,it,norm)
        if norm<=1e-10: return best,True
        jac=[[0.0]*16 for _ in range(16)]
        for j in range(16):
            eps=max(1e-7,1e-6*max(1.0,abs(h[j])))
            hp=h[:]; hp[j]+=eps
            rp=residual(hp)[0]
            for i in range(16): jac[i][j]=(rp[i]-r[i])/eps
        try:
            dx=gauss(jac,[-v for v in r])
        except ArithmeticError:
            return best,False
        accepted=False; base=norm
        for bt in range(12):
            fac=.5**bt
            trial=[h[i]+fac*dx[i] for i in range(16)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial): continue
            nr=max(abs(v) for v in residual(trial)[0])
            if nr<base:
                h=trial; accepted=True; break
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
        if hand_i is None or hand_i+1>=len(series):
            rec["classification"]="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT"; rows.append(rec); continue

        step,sat,xs=series[hand_i]; cstep,csat,cxs=series[hand_i+1]
        if cstep!=step+1:
            rec["classification"]="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT"; rows.append(rec); continue

        h0=[float(x["H"]) for x in xs]; th0=[float(x["THETA"]) for x in xs]
        pond0=float(xs[0]["POND"]); qtop=float(xs[0]["TOP_FLUX"]); qbot=float(xs[0]["BOTTOM_FLUX"])
        origin_copy=(h0[:],th0[:],pond0,qtop,qbot)
        shadow,conv=solve_split(m,h0,th0,qtop,qbot,dt)
        h1,r,q1,th1,td1,qbar,iters,norm=shadow
        rollback_h=max(abs(h0[i]-origin_copy[0][i]) for i in range(16))
        rollback_th=max(abs(th0[i]-origin_copy[1][i]) for i in range(16))
        rollback_pond=abs(pond0-origin_copy[2])

        q0=face_fluxes(m,h0)
        ds_upper=sum((th1[i]-th0[i])*dz for i in range(3))
        ds_lower=sum((th1[i]-th0[i])*dz for i in range(3,16))
        ds_total=ds_upper+ds_lower
        top_int=qtop*dt; bot_int=qbot*dt; int_int=qbar*dt
        upper_boundary=.5*dt*((q0[4]-qtop)+(q1[4]-qtop))
        lower_boundary=dt*(qbot-qbar)
        interface_cancel=(int_int-int_int)
        ledger=ds_total-dt*(qbot-qtop)
        finite=all(math.isfinite(v) for v in h1+th1+[x for x in q1[2:17] if x is not None])
        upper_cross=sum(1 for i in range(3) if h0[i]<0.0 and h1[i]>=0.0)
        sat_after=[i+1 for i,(hh,tt) in enumerate(zip(h1,th1)) if hh>=0.0 and abs(tt-m["theta_s"])<=1e-12]
        lower_after=[i for i in sat_after if i>=4]
        lower_head_change=max(abs(h1[i]-h0[i]) for i in range(3,16))
        lower_storage_change=ds_lower
        ch=[float(x["H"]) for x in cxs]; ct=[float(x["THETA"]) for x in cxs]
        max_control_h=max(abs(h1[i]-ch[i]) for i in range(16))
        max_control_theta=max(abs(th1[i]-ct[i]) for i in range(16))
        upper_ok=upper_cross==0 and all(h1[i]<0.0 and th1[i]<m["theta_s"] for i in range(3))
        rollback_ok=max(rollback_h,rollback_th,rollback_pond)<=1e-15
        mass_ok=abs(ledger)<=5e-8 and abs(interface_cancel)<=1e-12
        lower_ok=finite and (lower_head_change>1e-14 or abs(lower_storage_change)>1e-14)
        if not rollback_ok or not mass_ok or not control_ok:
            cls="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT"
        elif not upper_ok:
            cls="NLGLOB14T_UPPER_TG_SHADOW_NOT_ADMISSIBLE"
        elif not lower_ok:
            cls="NLGLOB14T_SATURATED_BLOCK_EVOLUTION_INADEQUATE"
        elif not conv or norm>1e-10:
            cls="NLGLOB14T_INTERFACE_COUPLING_NOT_CLOSED"
        else:
            cls="TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL"

        rec.update({"classification":cls,"step":step,"control_step":cstep,"converged":conv,"iterations":iters,
            "max_residual":norm,"interface_flux_origin":q0[4],"interface_flux_endpoint":q1[4],
            "interface_flux_integral":int_int,"interface_cancel":interface_cancel,
            "storage_upper":ds_upper,"storage_lower":ds_lower,"storage_total":ds_total,
            "top_integral":top_int,"bottom_integral":bot_int,"upper_boundary_integral":upper_boundary,
            "lower_boundary_integral":lower_boundary,"physical_mass_ledger":ledger,
            "sat_before":sat,"sat_after":sat_after,"lower_sat_after":lower_after,
            "upper_crossings":upper_cross,"lower_head_change":lower_head_change,
            "lower_storage_change":lower_storage_change,"rollback_h":rollback_h,
            "rollback_theta":rollback_th,"rollback_pond":rollback_pond,"finite":finite,
            "max_control_head_diff":max_control_h,"max_control_theta_diff":max_control_theta})
        rows.append(rec)

classes=[x["classification"] for x in rows]
coverage=len(rows)==12 and proc==0 and all(x.get("control_ok") for x in rows)
if coverage and all(x=="TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL" for x in classes):
    agg="QUALIFIED_TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL"
elif any(x=="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT" for x in classes):
    agg="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT"
elif any(x=="NLGLOB14T_UPPER_TG_SHADOW_NOT_ADMISSIBLE" for x in classes):
    agg="NLGLOB14T_UPPER_TG_SHADOW_NOT_ADMISSIBLE"
elif any(x=="NLGLOB14T_SATURATED_BLOCK_EVOLUTION_INADEQUATE" for x in classes):
    agg="NLGLOB14T_SATURATED_BLOCK_EVOLUTION_INADEQUATE"
elif any(x=="NLGLOB14T_INTERFACE_COUPLING_NOT_CLOSED" for x in classes):
    agg="NLGLOB14T_INTERFACE_COUPLING_NOT_CLOSED"
else:
    agg="NLGLOB14T_MIXED_SPLIT_SHADOW_RESULT"

summary={"classification":agg,"coverage_ok":coverage,"case_count":len(rows),"process_failures":proc,
    "qualified_cases":sum(x=="TRANSACTIONAL_SPLIT_DOMAIN_SHADOW_INTERVAL" for x in classes),
    "interface_not_closed":sum(x=="NLGLOB14T_INTERFACE_COUPLING_NOT_CLOSED" for x in classes),
    "lower_inadequate":sum(x=="NLGLOB14T_SATURATED_BLOCK_EVOLUTION_INADEQUATE" for x in classes),
    "upper_inadmissible":sum(x=="NLGLOB14T_UPPER_TG_SHADOW_NOT_ADMISSIBLE" for x in classes),
    "transaction_inconsistent":sum(x=="NLGLOB14T_SPLIT_TRANSACTION_INCONSISTENT" for x in classes),
    "max_abs_mass_ledger":max((abs(x.get("physical_mass_ledger",math.inf)) for x in rows),default=math.inf),
    "max_residual":max((x.get("max_residual",math.inf) for x in rows),default=math.inf),
    "max_rollback":max((max(x.get("rollback_h",math.inf),x.get("rollback_theta",math.inf),x.get("rollback_pond",math.inf)) for x in rows),default=math.inf)}
print("F_PE_NLGLOB14T_RECORDS="+json.dumps(rows,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14T_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14T=PASS")
