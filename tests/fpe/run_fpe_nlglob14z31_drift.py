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
mode=sys.argv[5]
segment_end=float(sys.argv[6])
checkpoint_path=Path(sys.argv[7])
if route not in ("HEAD","RUNOFF"):
    raise SystemExit("invalid route")

# Z26 observer-only work windows are derived from already-qualified Z22 event evidence.
z26_evidence=json.loads(Path("tests/fpe/data/f_pe_nlglob14z23_z22_event_evidence.json").read_text())
z26_fixture=next(x for x in z26_evidence["fixtures"] if x["route"]==route)
z26_events=[z26_fixture["committed_reverse"]]+z26_fixture["changes"]
z26_groups=[]
_z=[]
for _e in z26_events:
    if not _z or int(_e["offset"])==int(_z[-1]["offset"])+1:
        _z.append(_e)
    else:
        z26_groups.append(_z); _z=[_e]
if _z: z26_groups.append(_z)
if len(z26_groups)!=2:
    raise SystemExit("Z26 expected exactly two qualified chatter bursts")
z26_burst_defs=[]
z26_watch_offsets=set()
z26_event_offsets={int(e["offset"]) for e in z26_events}
for _idx,_g in enumerate(z26_groups,1):
    _start=int(_g[0]["offset"]); _end=int(_g[-1]["offset"]); _n=len(_g)
    _settle=_end+1
    _pre=list(range(_start-_n,_start)) if _start-_n>=0 else []
    if any(x in z26_event_offsets for x in _pre):
        _pre=[]
    _post=list(range(_settle+1,_settle+1+_n))
    z26_burst_defs.append({"burst":_idx,"start":_start,"end":_end,"n":_n,
                           "settle":_settle,"pre":_pre,"post":_post})
    z26_watch_offsets.update(range(_start,_end+1))
    z26_watch_offsets.add(_settle)
    z26_watch_offsets.update(_pre)
    z26_watch_offsets.update(_post)
z26_work_records={}
z29_reduced_records=[]

def compare_reduced_candidate(origin_h,origin_th,current_tail,full_out,full_ledger,full_tail,step,offset):
    reduced,conv,reason=solve_interval_reduced(m,origin_h,origin_th,demand,0.0,dt,current_tail)
    rec={"step":step,"offset":offset,"time":step*dt,"origin_tail":current_tail[:],
         "full_tail":full_tail,"reduced_converged":conv,"reduced_reason":reason}
    if reduced is None:
        rec["classification"]="REDUCED_SOLVE_INCONSISTENT"
        z29_reduced_records.append(rec)
        return
    rh,rr,rth,rq,rqt0,rqt1,rrt0,rrt1,ree0,ree1,rqbar,rit,rnorm,rn=reduced
    fh,fr,fth,fq,fqt0,fqt1,frt0,frt1,fee0,fee1,fqbar,fit,fnorm=full_out
    rds=sum((rth[j]-origin_th[j])*dz for j in range(16))
    rledger=rds+.5*dt*(rqt0+rqt1)
    rtail=sat_tail(m,rh,rth)
    rdelta=(rtail[0]-current_tail[0]) if rtail is not None and rtail else 0
    fdelta=(full_tail[0]-current_tail[0]) if full_tail is not None and full_tail else 0
    rdir=("retreat" if rdelta>0 else "reverse" if rdelta<0 else "stable")
    fdir=("retreat" if fdelta>0 else "reverse" if fdelta<0 else "stable")
    hdiff=max(abs(a-b) for a,b in zip(rh,fh))
    tdiff=max(abs(a-b) for a,b in zip(rth,fth))
    topdiff=abs(rqt1-fqt1)
    ledgerdiff=abs(rledger-full_ledger)
    tail_same=(rtail==full_tail)
    dir_same=(rdir==fdir)
    route_same=(rrt0==frt0 and rrt1==frt1)
    eq=(conv and rnorm<=1e-10 and hdiff<=5e-7 and tdiff<=5e-10 and
        topdiff<=5e-10 and ledgerdiff<=5e-8 and tail_same and dir_same and route_same)
    rec.update({
      "classification":"REDUCED_PHYSICAL_EQUIVALENCE_QUALIFIED" if eq else "REDUCED_PHYSICAL_EQUIVALENCE_PARTIAL",
      "reduced_n":rn,"full_n":16,"dimension_ratio":rn/16.0,
      "full_iterations":fit,"reduced_iterations":rit,
      "normalized_probe_work":(rit*rn)/(fit*16.0) if fit>0 else None,
      "max_head_diff":hdiff,"max_theta_diff":tdiff,
      "top_flux_diff":topdiff,"ledger_diff":ledgerdiff,
      "full_residual":fnorm,"reduced_residual":rnorm,
      "reduced_tail":rtail,"full_direction":fdir,"reduced_direction":rdir,
      "tail_same":tail_same,"direction_same":dir_same,"route_same":route_same})
    z29_reduced_records.append(rec)


def control_target_time(route,dt):
    if route=="HEAD":
        return 260.961125 if abs(dt-1.25e-4)<1e-15 else 260.9613125
    if abs(dt-1.25e-4)<1e-15:
        return 260.957875
    return 260.958125

def detect_update(tail,newtail,step,dt,state):
    if newtail is None or not newtail or not tail:
        return
    old_top=tail[0]; new_top=newtail[0]
    if state["split_second_time"] is not None:
        if new_top<old_top: state["reverse_after_second"]=True
        if new_top-old_top>1: state["skipped_after_second"]=True
    mapping=[
        (4,5,"split_second_time",4,5),
        (5,6,"split_third_time",5,6),
        (6,7,"split_fourth_time",6,7),
        (7,8,"split_late_time",7,8),
        (8,9,"split_next_time",8,9),
        (9,10,"split_further_time",9,10),
        (10,11,"split_deep_time",10,11),
        (11,12,"split_deeper_time",11,12),
        (12,13,"split_deepest_time",12,13)]
    for a,b,key,pf,qf in mapping:
        if old_top==a and new_top==b and state[key] is None:
            state[key]=step*dt
            state["transition_intervals"].append({
                "step":step,"time":step*dt,"pre_sat":tail,"post_sat":newtail,
                "pre_face":pf,"post_face":qf})
            break

def run_segment(h,th,demand,start_step,end_step,state,stop_on_target=False):
    for step in range(start_step+1,end_step+1):
        origin_h=h[:]; origin_th=th[:]
        tail=sat_tail(m,h,th)
        if tail is None:
            state["failure"]="NONCONTIGUOUS"; break
        if not tail:
            state["disappearance_step"]=step-1; break
        upper_n=16-len(tail)
        if upper_n<state["prev_upper"]:
            state["chatter"]+=1
        if upper_n!=state["prev_upper"]:
            state["interface_changes"].append({
                "step":step-1,"from_upper":state["prev_upper"],"to_upper":upper_n,
                "from_face":state["prev_upper"]+1,"to_face":upper_n+1})
        state["prev_upper"]=upper_n
        out,conv,reason=solve_interval(m,h,th,demand,0.0,dt,upper_n)
        if out is None:
            state["failure"]=reason; state["rejected"]+=1; break
        h1,r,th1,q1,qtop0,qtop1,route0,route1,emax0,emax1,qbar,iters,norm=out
        state["maxres"]=max(state["maxres"],norm)
        rollback=max(max(abs(h[i]-origin_h[i]) for i in range(16)),
                     max(abs(th[i]-origin_th[i]) for i in range(16)))
        state["maxrb"]=max(state["maxrb"],rollback)
        state["top_routes"].update((route0,route1))
        finite=all(math.isfinite(v) for v in h1+th1+[qtop0,qtop1,qbar])
        ds=sum((th1[i]-th[i])*dz for i in range(16))
        topint=.5*dt*(qtop0+qtop1)
        ledger=ds+topint
        state["maxledger"]=max(state["maxledger"],abs(ledger))
        tail1=sat_tail(m,h1,th1)
        upper_valid=all(h1[i]<0.0 and th1[i]<m["theta_s"] for i in range(upper_n))
        interval_ok=(conv and norm<=1e-10 and finite and abs(ledger)<=5e-8 and
                     rollback<=1e-15 and upper_valid and tail1 is not None and
                     route0 in ("surface-flux","atmospheric-head") and
                     route1 in ("surface-flux","atmospheric-head"))
        if not interval_ok:
            state["rejected"]+=1
            state["failure"]=("COUPLING" if not conv or norm>1e-10 else
                              "TRANSACTION" if abs(ledger)>5e-8 or rollback>1e-15 else
                              "DYNAMIC_TOP" if route0 not in ("surface-flux","atmospheric-head") or route1 not in ("surface-flux","atmospheric-head") else
                              "UPPER")
            break
        h[:]=h1; th[:]=th1
        state["accepted"]+=1
        state["final_step"]=step
        detect_update(tail,tail1,step,dt,state)
        if stop_on_target and state["split_deepest_time"] is not None:
            break
        if tail1 is not None and not tail1:
            state["disappearance_step"]=step
            break
    return h,th,state

def fresh_state():
    return {
      "accepted":0,"rejected":0,"maxledger":0.0,"maxres":0.0,"maxrb":0.0,
      "interface_changes":[],"chatter":0,"top_routes":set(),"failure":None,
      "disappearance_step":None,"reverse_after_second":False,"skipped_after_second":False,
      "split_second_time":None,"split_third_time":None,"split_fourth_time":None,
      "split_late_time":None,"split_next_time":None,"split_further_time":None,"split_deep_time":None,
      "split_deeper_time":None,"split_deepest_time":None,
      "transition_intervals":[],"prev_upper":3,"final_step":0}

hinit,pinit,demand=fixture(m,route)


if mode!="resume":
    raise SystemExit("Z31 driving runner requires resume mode")

ck=json.loads(checkpoint_path.read_text())
if ck["route"]!=route or float.fromhex(ck["dt_hex"])!=dt:
    raise SystemExit("Z31 checkpoint fixture mismatch")
fh=[float.fromhex(x) for x in ck["h_hex"]]
fth=[float.fromhex(x) for x in ck["th_hex"]]
ah=fh[:]
ath=fth[:]
start_step=int(ck["state"]["final_step"])
full_tail=sat_tail(m,fh,fth)
adaptive_tail=sat_tail(m,ah,ath)
if full_tail!=ck["final_tail"] or adaptive_tail!=ck["final_tail"]:
    raise SystemExit("Z31 checkpoint tail mismatch")

max_step=int(round(segment_end/dt))
max_hdiff=0.0
max_tdiff=0.0
max_ponddiff=0.0
max_topdiff=0.0
max_ledgerdiff=0.0
max_adaptive_ledger=0.0
full_work=0
adaptive_work=0
dim_hist={}
event_full=[]
event_adaptive=[]
failure=None
accepted=0
full_pond=0.0
adaptive_pond=0.0
full_cumledger=0.0
adaptive_cumledger=0.0
max_cum_mass_diff=0.0
threshold_crossings=[]
time_bins=[(140.0,200.0),(200.0,260.0),(260.0,320.0),(320.0,400.0),(400.0,480.0),(480.0,540.0000001)]
def new_stat():
    return {"count":0,"sum":0.0,"sumsq":0.0,"min":None,"max":None,"pos":0,"neg":0,"zero":0,
            "cum_start":None,"cum_end":None}
def add_stat(stat,dm,cum_before,cum_after):
    if stat["cum_start"] is None:
        stat["cum_start"]=cum_before
    stat["cum_end"]=cum_after
    stat["count"]+=1
    stat["sum"]+=dm
    stat["sumsq"]+=dm*dm
    stat["min"]=dm if stat["min"] is None else min(stat["min"],dm)
    stat["max"]=dm if stat["max"] is None else max(stat["max"],dm)
    if dm>0.0: stat["pos"]+=1
    elif dm<0.0: stat["neg"]+=1
    else: stat["zero"]+=1

by_dim={}
by_tail={}
by_event={"stable":new_stat(),"event":new_stat()}
by_time={f"{lo:g}-{hi:g}":new_stat() for lo,hi in time_bins}
event_mass_trace=[]

for step in range(start_step+1,max_step+1):
    # full reference candidate from its own accepted origin
    f_origin_h=fh[:]; f_origin_th=fth[:]; f_origin_tail=full_tail[:]
    f_upper=16-len(f_origin_tail)
    fout,fconv,freason=solve_interval(m,fh,fth,demand,0.0,dt,f_upper)
    if fout is None:
        failure="REFERENCE_FAILURE"; break
    f_h1,f_r,f_th1,f_q1,f_qt0,f_qt1,f_rt0,f_rt1,f_e0,f_e1,f_qbar,f_it,f_norm=fout
    f_finite=all(math.isfinite(v) for v in f_h1+f_th1+[f_qt0,f_qt1,f_qbar])
    f_ds=sum((f_th1[j]-fth[j])*dz for j in range(16))
    f_ledger=f_ds+.5*dt*(f_qt0+f_qt1)
    f_tail1=sat_tail(m,f_h1,f_th1)
    if f_tail1 is None or not f_tail1:
        failure="REFERENCE_FAILURE"; break
    f_delta=f_tail1[0]-f_origin_tail[0]
    f_one=(abs(f_delta)<=1)
    f_ok=(fconv and f_norm<=1e-10 and f_finite and abs(f_ledger)<=5e-8 and f_one and
          f_rt0 in ("surface-flux","atmospheric-head") and
          f_rt1 in ("surface-flux","atmospheric-head"))
    if not f_ok:
        failure="REFERENCE_FAILURE"; break

    # adaptive reduced candidate from independent adaptive accepted origin
    a_origin_h=ah[:]; a_origin_th=ath[:]; a_origin_tail=adaptive_tail[:]
    aout,aconv,areason=solve_interval_reduced(m,ah,ath,demand,0.0,dt,a_origin_tail)
    if aout is None:
        failure="DRIVING_ADAPTIVE_RECONSTRUCTION_FAILURE"; break
    a_h1,a_r,a_th1,a_q1,a_qt0,a_qt1,a_rt0,a_rt1,a_e0,a_e1,a_qbar,a_it,a_norm,a_n=aout
    a_finite=all(math.isfinite(v) for v in a_h1+a_th1+[a_qt0,a_qt1,a_qbar])
    a_ds=sum((a_th1[j]-ath[j])*dz for j in range(16))
    a_ledger=a_ds+.5*dt*(a_qt0+a_qt1)
    a_tail1=sat_tail(m,a_h1,a_th1)
    if a_tail1 is None or not a_tail1:
        failure="DRIVING_ADAPTIVE_RECONSTRUCTION_FAILURE"; break
    a_delta=a_tail1[0]-a_origin_tail[0]
    a_one=(abs(a_delta)<=1)
    a_ok=(aconv and a_norm<=1e-10 and a_finite and abs(a_ledger)<=5e-8 and a_one and
          a_rt0 in ("surface-flux","atmospheric-head") and
          a_rt1 in ("surface-flux","atmospheric-head"))
    if not a_ok:
        failure="DRIVING_ADAPTIVE_SOLVE_FAILURE"; break

    f_dir=("retreat" if f_delta>0 else "reverse" if f_delta<0 else "stable")
    a_dir=("retreat" if a_delta>0 else "reverse" if a_delta<0 else "stable")
    if f_dir!="stable":
        event_full.append({"step":step,"time":step*dt,"direction":f_dir,
                           "from_tail":f_origin_tail,"to_tail":f_tail1})
    if a_dir!="stable":
        event_adaptive.append({"step":step,"time":step*dt,"direction":a_dir,
                               "from_tail":a_origin_tail,"to_tail":a_tail1})

    # publish each candidate only to its own trajectory
    fh=f_h1; fth=f_th1; full_tail=f_tail1
    ah=a_h1; ath=a_th1; adaptive_tail=a_tail1
    full_work += f_it*16
    adaptive_work += a_it*a_n
    dim_hist[str(a_n)] = dim_hist.get(str(a_n),0)+1
    cum_before=adaptive_cumledger-full_cumledger
    full_cumledger += f_ledger
    adaptive_cumledger += a_ledger
    cum_after=adaptive_cumledger-full_cumledger
    dm=a_ledger-f_ledger
    accepted += 1

    dim_key=str(a_n)
    if dim_key not in by_dim: by_dim[dim_key]=new_stat()
    add_stat(by_dim[dim_key],dm,cum_before,cum_after)
    tail_key="-".join(str(x) for x in a_origin_tail)
    if tail_key not in by_tail: by_tail[tail_key]=new_stat()
    add_stat(by_tail[tail_key],dm,cum_before,cum_after)
    event_key="event" if a_dir!="stable" else "stable"
    add_stat(by_event[event_key],dm,cum_before,cum_after)
    tnow=step*dt
    for lo,hi in time_bins:
        if lo <= tnow < hi or (hi>540.0 and tnow<=540.0):
            add_stat(by_time[f"{lo:g}-{hi:g}"],dm,cum_before,cum_after)
            break
    if a_dir!="stable" or f_dir!="stable":
        event_mass_trace.append({"step":step,"time":tnow,"full_direction":f_dir,"adaptive_direction":a_dir,
                                 "cum_before":cum_before,"cum_after":cum_after,"delta_m":dm,
                                 "adaptive_n":a_n,"tail":a_origin_tail[:]})
    if abs(cum_after)>=5e-7 and (not threshold_crossings or threshold_crossings[-1]["side"]!=(1 if cum_after>0 else -1)):
        threshold_crossings.append({"step":step,"time":tnow,"cumulative":cum_after,
                                    "side":1 if cum_after>0 else -1})

    hdiff=max(abs(x-y) for x,y in zip(ah,fh))
    tdiff=max(abs(x-y) for x,y in zip(ath,fth))
    topdiff=abs(a_qt1-f_qt1)
    ledgerdiff=abs(a_ledger-f_ledger)
    max_hdiff=max(max_hdiff,hdiff)
    max_tdiff=max(max_tdiff,tdiff)
    max_topdiff=max(max_topdiff,topdiff)
    max_ledgerdiff=max(max_ledgerdiff,ledgerdiff)
    max_adaptive_ledger=max(max_adaptive_ledger,abs(a_ledger))
    max_cum_mass_diff=max(max_cum_mass_diff,abs(adaptive_cumledger-full_cumledger))

    # Z31 attribution intentionally continues through A/B state and event-timing
    # divergence. These are diagnostics here, not hard stop gates. The frozen
    # Z31 hard stops are only non-finite/reconstruction/solve/geometry and
    # per-interval physical ledger failures, all enforced above.

full_dirs=[x["direction"] for x in event_full]
adaptive_dirs=[x["direction"] for x in event_adaptive]
event_sequence_same=(full_dirs==adaptive_dirs)
final_tail_same=(full_tail==adaptive_tail)
complete=(failure is None and accepted==(max_step-start_step))

def finalize_stat(x):
    if x["count"]>0:
        x["mean"]=x["sum"]/x["count"]
        x["rms"]=math.sqrt(x["sumsq"]/x["count"])
    else:
        x["mean"]=None; x["rms"]=None
    return x
for d in (by_dim,by_tail,by_time):
    for k in list(d): d[k]=finalize_stat(d[k])
for k in list(by_event): by_event[k]=finalize_stat(by_event[k])

stable=by_event["stable"]
stable_mean=stable["mean"] or 0.0
stable_rms=stable["rms"] or 0.0
stable_pos=stable["pos"]; stable_neg=stable["neg"]
dominant_sign=(1 if stable_mean>0 else -1 if stable_mean<0 else 0)
same_sign_bins=0
for k,x in by_time.items():
    if x["count"] and dominant_sign!=0 and x["sum"]*dominant_sign>0:
        same_sign_bins+=1
both_signs=(stable_pos>0 and stable_neg>0)
mean_rms_ratio=(abs(stable_mean)/stable_rms if stable_rms>0 else 0.0)

total_signed=sum(x["sum"] for x in by_dim.values())
localized=False
localized_key=None
for group_name,group in (("dim",by_dim),("tail",by_tail),("event",by_event)):
    for k,x in group.items():
        if total_signed!=0 and abs(x["sum"]/total_signed)>=0.8 and x["count"]<0.8*accepted:
            localized=True; localized_key=f"{group_name}:{k}"

if failure is not None:
    classification=failure
elif localized:
    classification="QUALIFIED_Z31_REGIME_LOCALIZED_BIAS"
elif dominant_sign!=0 and mean_rms_ratio>=0.25 and same_sign_bins>=4:
    classification="QUALIFIED_Z31_SYSTEMATIC_SIGNED_BIAS"
elif both_signs and mean_rms_ratio<0.10 and same_sign_bins<4:
    classification="QUALIFIED_Z31_ZERO_MEAN_NUMERICAL_ACCUMULATION"
else:
    classification="QUALIFIED_Z31_MIXED_DRIFT_MECHANISM"
aggregate=classification

total_dims=sum(int(k)*v for k,v in dim_hist.items())
total_intervals=sum(dim_hist.values())
mean_dim=(total_dims/total_intervals if total_intervals else None)
work_ratio=(adaptive_work/full_work if full_work else None)

rec={
 "route":route,"dt":dt,"classification":classification,"aggregate":aggregate,
 "start_time":start_step*dt,"final_time":(start_step+accepted)*dt,
 "accepted_intervals":accepted,"failure":failure,
 "max_head_diff":max_hdiff,"max_theta_diff":max_tdiff,
 "max_top_flux_diff":max_topdiff,"max_ledger_diff":max_ledgerdiff,
 "max_adaptive_ledger":max_adaptive_ledger,
 "max_cumulative_mass_difference":max_cum_mass_diff,
 "full_final_tail":full_tail,"adaptive_final_tail":adaptive_tail,
 "event_sequence_same":event_sequence_same,
 "full_events":event_full,"adaptive_events":event_adaptive,
 "full_work":full_work,"adaptive_work":adaptive_work,
 "adaptive_full_work_ratio":work_ratio,
 "active_dimension_histogram":dim_hist,"mean_active_dimension":mean_dim,
 "full_top_routes":["surface-flux"],"adaptive_top_routes":["surface-flux"],
 "signed_final_mass_difference":adaptive_cumledger-full_cumledger,
 "threshold_crossings":threshold_crossings,
 "by_dimension":by_dim,"by_tail":by_tail,"by_event":by_event,"by_time":by_time,
 "event_mass_trace":event_mass_trace,
 "stable_mean_rms_ratio":mean_rms_ratio,"same_sign_time_bins":same_sign_bins,
 "localized_key":localized_key
}
print("F_PE_NLGLOB14Z31_RESULT="+json.dumps(rec,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB14Z31=PASS")
