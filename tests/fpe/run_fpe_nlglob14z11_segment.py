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
horizon=60.0; dtop=10.; pmax=.05; rsro=.05; dz=10.0
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
if abs(dt-6.25e-5)>1e-15:
    raise SystemExit("segmented Z8 is frozen to fine dt=6.25e-5")

def control_target_time(route,dt):
    if route=="HEAD":
        return 53.994375 if abs(dt-1.25e-4)<1e-15 else 53.9945
    return 53.99125 if abs(dt-1.25e-4)<1e-15 else 53.9913125

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
        (10,11,"split_deep_time",10,11)]
    for a,b,key,pf,qf in mapping:
        if old_top==a and new_top==b and state[key] is None:
            state[key]=step*dt
            state["transition_intervals"].append({
                "step":step,"time":step*dt,"pre_sat":tail,"post_sat":newtail,
                "pre_face":pf,"post_face":qf})
            break

def run_segment(h,th,demand,start_step,end_step,state):
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
      "transition_intervals":[],"prev_upper":3,"final_step":0}

hinit,pinit,demand=fixture(m,route)

if mode=="first":
    cp=subprocess.run([str(exe),"O05","TG",route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
        str(m["ksat"]),str(m["lambda"]),str(hinit),str(pinit),str(demand),str(dt),str(segment_end)],
        text=True,capture_output=True)
    states=[fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_NLGLOB14F_STATE|")]
    result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
    bystep={}
    for x in states: bystep.setdefault(int(x["STEP"]),[]).append(x)
    series={}; ordered=[]
    for step in sorted(bystep):
        xs=sorted(bystep[step],key=lambda q:int(q["NODE"]))
        if len(xs)!=16: continue
        sat=[int(x["NODE"]) for x in xs if int(x["SAT_H"])==1 and int(x["SAT_THETA"])==1]
        series[step]=(sat,xs); ordered.append(step)
    start=None
    for a,b in zip(ordered[:-1],ordered[1:]):
        sa,_=series[a]; sb,_=series[b]
        if len(sa)==14 and sb==list(range(4,17)) and 3 in sa and 3 not in sb and b>a:
            start=b; break
    control_ok=bool(result and result["TERMINAL_REASON"]=="COMPLETE_SAME_ROUTE" and int(result["ELIGIBLE"])==1 and
                    abs(float(result["MAX_LEDGER"]))<=5e-8 and abs(float(result["CUM_LEDGER"]))<=5e-8)
    if start is None or not control_ok:
        raise SystemExit("Z11 segment A control origin invalid")
    sat0,xs0=series[start]
    h=[float(x["H"]) for x in xs0]; th=[float(x["THETA"]) for x in xs0]
    if abs(float(xs0[0]["POND"]))>1e-12:
        raise SystemExit("Z11 segment A ponding invalid")
    st=fresh_state(); st["final_step"]=start
    h,th,st=run_segment(h,th,demand,start,int(round(segment_end/dt)),st)
    final_tail=sat_tail(m,h,th)
    ok=(st["failure"] is None and st["maxledger"]<=5e-8 and st["maxres"]<=1e-10 and
        st["maxrb"]<=1e-15 and not st["reverse_after_second"] and
        not st["skipped_after_second"] and st["chatter"]==0 and
        st["final_step"]==int(round(segment_end/dt)) and final_tail==list(range(10,17)))
    if not ok:
        raise SystemExit("Z11 segment A failed frozen continuity gates")
    st["prev_upper"]=16-len(final_tail)
    ck={
      "route":route,"dt_hex":dt.hex(),"segment_end_hex":segment_end.hex(),
      "h_hex":[x.hex() for x in h],"th_hex":[x.hex() for x in th],
      "start_step":start,"state":{k:(sorted(v) if isinstance(v,set) else v) for k,v in st.items()},
      "final_tail":final_tail,"control_deep_time":control_target_time(route,dt)}
    checkpoint_path.write_text(json.dumps(ck,separators=(",",":"),sort_keys=True))
    rt=json.loads(checkpoint_path.read_text())
    rh=[float.fromhex(x) for x in rt["h_hex"]]; rth=[float.fromhex(x) for x in rt["th_hex"]]
    roundtrip=(all(a.hex()==b.hex() for a,b in zip(h,rh)) and
               all(a.hex()==b.hex() for a,b in zip(th,rth)))
    print("F_PE_NLGLOB14Z11_SEGMENT_A="+json.dumps({
      "route":route,"dt":dt,"classification":"SEGMENT_A_CHECKPOINT_VALID",
      "final_time":segment_end,"final_tail":final_tail,"roundtrip_exact":roundtrip,
      "accepted":st["accepted"],"max_ledger":st["maxledger"],
      "max_residual":st["maxres"],"max_rollback":st["maxrb"]},
      separators=(",",":"),sort_keys=True))
    if not roundtrip: raise SystemExit("Z11 checkpoint roundtrip failed")
    print("F_PE_NLGLOB14Z11_SEGMENT=PASS")
elif mode=="resume":
    ck=json.loads(checkpoint_path.read_text())
    if ck["route"]!=route or float.fromhex(ck["dt_hex"])!=dt:
        raise SystemExit("Z11 checkpoint fixture mismatch")
    h=[float.fromhex(x) for x in ck["h_hex"]]
    th=[float.fromhex(x) for x in ck["th_hex"]]
    if [x.hex() for x in h]!=ck["h_hex"] or [x.hex() for x in th]!=ck["th_hex"]:
        raise SystemExit("Z11 checkpoint state not exact")
    st=ck["state"]
    st["top_routes"]=set(st["top_routes"])
    start_step=int(st["final_step"])
    expected_tail=ck["final_tail"]
    actual_tail=sat_tail(m,h,th)
    if actual_tail!=expected_tail or st["prev_upper"]!=16-len(actual_tail):
        raise SystemExit("Z11 checkpoint ownership continuity failed")
    h,th,st=run_segment(h,th,demand,start_step,int(round(segment_end/dt)),st)
    final_tail=sat_tail(m,h,th)
    reached=st["final_step"]==int(round(segment_end/dt))
    cls=("SPLIT_RETREAT_10_TO_11_TRANSITION_VALID"
         if reached and st["split_deep_time"] is not None and st["failure"] is None and
            st["maxledger"]<=5e-8 and st["maxres"]<=1e-10 and st["maxrb"]<=1e-15 and
            st["chatter"]==0 and not st["reverse_after_second"] and not st["skipped_after_second"]
         else "NLGLOB14Z11_SEGMENTED_NOT_QUALIFIED")
    rec={
      "route":route,"dt":dt,"classification":cls,"final_time":st["final_step"]*dt,
      "final_sat_nodes":final_tail,"accepted_intervals":st["accepted"],
      "rejected_intervals":st["rejected"],"interface_changes":st["interface_changes"],
      "interface_change_count":len(st["interface_changes"]),"chatter_count":st["chatter"],
      "max_abs_mass_ledger":st["maxledger"],"max_residual":st["maxres"],
      "max_rollback":st["maxrb"],"failure":st["failure"],
      "reverse_after_second":st["reverse_after_second"],"skipped_after_second":st["skipped_after_second"],
      "split_deep_time":st["split_deep_time"],
      "control_deep_time":ck["control_deep_time"],
      "deep_difference":None if st["split_deep_time"] is None else st["split_deep_time"]-ck["control_deep_time"],
      "checkpoint_roundtrip_exact":True,"checkpoint_tail":expected_tail,
      "top_routes":sorted(st["top_routes"])}
    print("F_PE_NLGLOB14Z11_SEGMENT_B="+json.dumps(rec,separators=(",",":"),sort_keys=True))
    if cls!="SPLIT_RETREAT_10_TO_11_TRANSITION_VALID":
        raise SystemExit("Z11 segmented fixture did not qualify")
    print("F_PE_NLGLOB14Z11_SEGMENT=PASS")
else:
    raise SystemExit("mode must be first or resume")
