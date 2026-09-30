#!/usr/bin/env python3
import json, math, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=Path(sys.argv[2])
data=json.loads(bank.read_text()); mats={x["id"]:x for x in data["materials"]}
dts=[0.000125,0.0000625]
routes=("HEAD","RUNOFF")
if len(sys.argv)>=5:
    routes=(sys.argv[3],)
    dts=[float(sys.argv[4])]
horizon=280.0; dtop=10.; pmax=.05; rsro=.05; dz=10.0
route_filter=sys.argv[3] if len(sys.argv)>3 else None
dt_filter=float(sys.argv[4]) if len(sys.argv)>4 else None
if route_filter is not None:
    if route_filter not in ("HEAD","RUNOFF"): raise SystemExit("invalid route filter")
    routes=(route_filter,)
if dt_filter is not None:
    if not any(math.isclose(dt_filter,x,rel_tol=0,abs_tol=1e-15) for x in dts):
        raise SystemExit("invalid dt filter")
    dts=[dt_filter]
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

def solve_interval_reduced(m,h0,th0,demand,qbot,dt,current_tail):
    if current_tail is None or not current_tail:
        return None,False,"NO_SATURATED_TAIL"
    s=int(current_tail[0])
    n=s
    if n<=1 or n>16:
        return None,False,"UNSUPPORTED_REDUCED_DIMENSION"
    upper_n=n-1
    q0=face_fluxes(m,h0)
    fixed_k_top=kprovider(m,h0[0])
    qtop0,route0,emax0=dry_top(m,h0[0],demand,fixed_k_top)

    def reconstruct(x):
        h=x[:] + [0.0]*(16-n)
        if n<16:
            kg=kprovider(m,h[n-1])
            km=.5*(kg+m["ksat"])
            if km<=0.0 or not math.isfinite(km):
                return None
            h[n]=h[n-1]+dz*(1.0+qbot/km)
            for i in range(n+1,16):
                h[i]=h[i-1]+dz*(1.0+qbot/m["ksat"])
            if any(not math.isfinite(v) for v in h[n:]):
                return None
        return h

    def endpoint(x):
        hfull=reconstruct(x)
        if hfull is None:
            return None
        th=[theta_provider(m,v) for v in hfull]
        if n<16:
            for i in range(n,16):
                if hfull[i] < 0.0 or th[i] != m["theta_s"]:
                    return None
        q=face_fluxes(m,hfull)
        qtop,route,emax=dry_top(m,hfull[0],demand,fixed_k_top)
        return hfull,th,q,qtop,route,emax

    td0=[]
    for node in range(1,17):
        if node==1:
            v=(q0[2]-qtop0)/dz
        elif node==16:
            v=(qbot-q0[16])/dz
        else:
            v=(q0[node+1]-q0[node])/dz
        td0.append(v)

    x=h0[:n]
    for i in range(upper_n):
        eps=max(1e-8,1e-5*max(1.0,abs(h0[i])))
        cap=(theta_provider(m,h0[i]+eps)-theta_provider(m,h0[i]-eps))/(2*eps)
        if cap>1e-14:
            x[i]+=dt*td0[i]/cap

    iface=n
    def residual(xv):
        ep=endpoint(xv)
        if ep is None:
            return None
        hfull,th1,q1,qtop1,route1,emax1=ep
        td1=[]
        for node in range(1,17):
            if node==1:
                v=(q1[2]-qtop1)/dz
            elif node==16:
                v=(qbot-q1[16])/dz
            else:
                v=(q1[node+1]-q1[node])/dz
            td1.append(v)
        r=[0.0]*n
        for i in range(upper_n):
            r[i]=th1[i]-th0[i]-.5*dt*(td0[i]+td1[i])
        qbar=.5*(q0[iface]+q1[iface])
        j=n-1
        r[j]=th1[j]-th0[j]-dt*((qbot-qbar)/dz)
        return r,hfull,th1,q1,qtop1,route1,emax1,qbar

    best=None
    for it in range(1,31):
        rr=residual(x)
        if rr is None:
            return best,False,"TAIL_RECONSTRUCTION"
        r,hfull,th1,q1,qtop1,route1,emax1,qbar=rr
        norm=max(abs(v) for v in r)
        best=(hfull[:],r,th1,q1,qtop0,qtop1,route0,route1,emax0,emax1,qbar,it,norm,n)
        if norm<=1e-10:
            return best,True,"CONVERGED"
        jac=[[0.0]*n for _ in range(n)]
        for j in range(n):
            eps=max(1e-7,1e-6*max(1.0,abs(x[j])))
            xp=x[:]
            xp[j]+=eps
            rp=residual(xp)
            if rp is None:
                return best,False,"TAIL_RECONSTRUCTION"
            rv=rp[0]
            for i in range(n):
                jac[i][j]=(rv[i]-r[i])/eps
        try:
            dx=gauss(jac,[-v for v in r])
        except ArithmeticError:
            return best,False,"SINGULAR"
        base=norm
        accepted=False
        for bt in range(12):
            fac=.5**bt
            trial=[x[i]+fac*dx[i] for i in range(n)]
            if not all(math.isfinite(v) and abs(v)<1e12 for v in trial):
                continue
            rt=residual(trial)
            if rt is None:
                continue
            nr=max(abs(v) for v in rt[0])
            if nr<base:
                x=trial
                accepted=True
                break
        if not accepted:
            return best,False,"NO_DESCENT"
    return best,False,"MAXIT"


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



m=mats["O05"]
route=sys.argv[3]
dt=float(sys.argv[4])
checkpoint_path=Path(sys.argv[5])
if route not in ("HEAD","RUNOFF"):
    raise SystemExit("invalid route")
if not math.isclose(dt,6.25e-5,rel_tol=0,abs_tol=1e-15):
    raise SystemExit("Z32 requires fine dt")

hinit,pinit,demand=fixture(m,route)
ck=json.loads(checkpoint_path.read_text())
if ck["route"]!=route or float.fromhex(ck["dt_hex"])!=dt:
    raise SystemExit("Z32 checkpoint fixture mismatch")
h=[float.fromhex(x) for x in ck["h_hex"]]
th=[float.fromhex(x) for x in ck["th_hex"]]
start_step=int(ck["state"]["final_step"])
if sat_tail(m,h,th)!=ck["final_tail"]:
    raise SystemExit("Z32 checkpoint tail mismatch")

targets=[
    ("first_post_settlement",None),
    ("day280",280.0),
    ("day320",320.0),
    ("day400",400.0),
    ("day480",480.0),
    ("day514_5",514.5),
]
captured={}
records=[]
max_step=int(round(514.55/dt))

def observe(label,step,origin_h,origin_th,full_out,full_ledger):
    reduced,conv,reason=solve_interval_reduced(m,origin_h,origin_th,demand,0.0,dt,[13,14,15,16])
    if reduced is None or not conv:
        return {"label":label,"step":step,"time":step*dt,"failure":reason}
    fh,fr,fth,fq,fqt0,fqt1,frt0,frt1,fee0,fee1,fqbar,fit,fnorm=full_out
    rh,rr,rth,rq,rqt0,rqt1,rrt0,rrt1,ree0,ree1,rqbar,rit,rnorm,rn=reduced
    q0=face_fluxes(m,origin_h)

    # q[k] is the face between nodes k-1 and k in one-based node notation.
    # Therefore q[13] = face 12/13 and q[14] = face 13/14.
    full_qin_bar=.5*(q0[13]+fq[13])
    red_qin_bar=.5*(q0[13]+rq[13])
    full_qout=fq[14]
    red_qout=rq[14]

    full_store13=fth[12]-origin_th[12]
    red_store13=rth[12]-origin_th[12]
    full_guard_res=full_store13-dt*((full_qout-full_qin_bar)/dz)
    red_local_guard_res=red_store13-dt*((red_qout-red_qin_bar)/dz)
    red_implemented_guard_res=rr[12]

    storage_component=full_store13-red_store13
    outflow_component=-dt*((full_qout-0.0)/dz)
    inflow_component=dt*((full_qin_bar-red_qin_bar)/dz)
    forcing_abs=abs(outflow_component)+abs(inflow_component)
    interface_forcing_share=(abs(outflow_component)/forcing_abs if forcing_abs>0 else 0.0)

    full_tail_store=sum((fth[i]-origin_th[i])*dz for i in range(13,16))
    red_tail_store=sum((rth[i]-origin_th[i])*dz for i in range(13,16))
    tail_storage_diff=full_tail_store-red_tail_store

    full_ds=sum((fth[i]-origin_th[i])*dz for i in range(16))
    red_ds=sum((rth[i]-origin_th[i])*dz for i in range(16))
    red_ledger=red_ds+.5*dt*(rqt0+rqt1)

    tail_nodes=[]
    for i in range(13,16):
        tail_nodes.append({
          "node":i+1,
          "full_h":fh[i],"reduced_h":rh[i],"head_diff":fh[i]-rh[i],
          "full_theta":fth[i],"reduced_theta":rth[i],
          "storage_diff_cm":(fth[i]-rth[i])*dz,
        })
    tail_flux_indices=[14,15,16]
    full_tail_flux=[fq[k] for k in tail_flux_indices]
    red_tail_flux=[rq[k] for k in tail_flux_indices]

    return {
      "label":label,"step":step,"time":step*dt,"failure":None,
      "full_iterations":fit,"reduced_iterations":rit,"reduced_n":rn,
      "full_residual":fnorm,"reduced_residual":rnorm,
      "origin_face12_13":q0[13],"origin_face13_14":q0[14],
      "full_endpoint_face12_13":fq[13],"reduced_endpoint_face12_13":rq[13],
      "full_endpoint_face13_14":full_qout,"reduced_endpoint_face13_14":red_qout,
      "full_trap_face12_13":full_qin_bar,"reduced_trap_face12_13":red_qin_bar,
      "face12_13_trap_diff":full_qin_bar-red_qin_bar,
      "face13_14_endpoint_diff":full_qout-red_qout,
      "guard13_full_storage":full_store13,
      "guard13_reduced_storage":red_store13,
      "guard13_storage_diff":storage_component,
      "guard13_full_residual":full_guard_res,
      "guard13_reduced_local_residual":red_local_guard_res,
      "guard13_reduced_implemented_residual":red_implemented_guard_res,
      "guard_equation_outflow_component":outflow_component,
      "guard_equation_inflow_component":inflow_component,
      "interface_forcing_share":interface_forcing_share,
      "tail_nodes":tail_nodes,
      "full_tail_storage_cm":full_tail_store,
      "reduced_tail_storage_cm":red_tail_store,
      "tail_storage_diff_cm":tail_storage_diff,
      "full_tail_fluxes":full_tail_flux,
      "reduced_tail_fluxes":red_tail_flux,
      "max_full_tail_flux_abs":max(abs(v) for v in full_tail_flux),
      "max_reduced_tail_flux_abs":max(abs(v) for v in red_tail_flux),
      "max_tail_head_diff":max(abs(x["head_diff"]) for x in tail_nodes),
      "full_ledger":full_ledger,"reduced_ledger":red_ledger,
      "signed_ledger_diff":red_ledger-full_ledger,
      "max_head_diff":max(abs(a-b) for a,b in zip(fh,rh)),
      "max_theta_diff":max(abs(a-b) for a,b in zip(fth,rth)),
    }

for step in range(start_step+1,max_step+1):
    origin_h=h[:]
    origin_th=th[:]
    tail=sat_tail(m,h,th)
    if tail is None or not tail:
        raise SystemExit("Z32 full trajectory lost contiguous tail")
    upper_n=16-len(tail)
    out,conv,reason=solve_interval(m,h,th,demand,0.0,dt,upper_n)
    if out is None or not conv:
        raise SystemExit("Z32 full solve failed: "+str(reason))
    h1,r,th1,q1,qtop0,qtop1,route0,route1,emax0,emax1,qbar,iters,norm=out
    tail1=sat_tail(m,h1,th1)
    ds=sum((th1[i]-th[i])*dz for i in range(16))
    ledger=ds+.5*dt*(qtop0+qtop1)
    stable13=(tail==[13,14,15,16] and tail1==[13,14,15,16])

    if stable13:
        if "first_post_settlement" not in captured and step*dt>260.9:
            rec=observe("first_post_settlement",step,origin_h,origin_th,out,ledger)
            records.append(rec); captured["first_post_settlement"]=step
        for label,target in targets[1:]:
            if label not in captured and step*dt>=target:
                rec=observe(label,step,origin_h,origin_th,out,ledger)
                records.append(rec); captured[label]=step

    h=h1; th=th1

coverage=sum(1 for x in records if x.get("failure") is None)
shares=[x["interface_forcing_share"] for x in records if x.get("failure") is None]
outflows=[abs(x["face13_14_endpoint_diff"]) for x in records if x.get("failure") is None]
tailstores=[abs(x["tail_storage_diff_cm"]) for x in records if x.get("failure") is None]
classification="Z32_ATTRIBUTION_COVERAGE_FAILED" if coverage<4 else "Z32_ATTRIBUTION_CHARACTERIZED"
summary={
  "route":route,"dt":dt,"classification":classification,
  "coverage":coverage,"requested":len(targets),"captured":captured,
  "min_interface_forcing_share":min(shares) if shares else None,
  "max_interface_forcing_share":max(shares) if shares else None,
  "max_face13_14_endpoint_diff":max(outflows) if outflows else None,
  "max_tail_storage_diff_cm":max(tailstores) if tailstores else None,
  "records":records,
}
print("F_PE_NLGLOB14Z32_RESULT="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z32=PASS")
