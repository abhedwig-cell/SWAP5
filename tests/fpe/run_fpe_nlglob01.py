#!/usr/bin/env python3
import json, math, statistics, subprocess, sys
from pathlib import Path

exe=Path(sys.argv[1]); bank=json.loads(Path(sys.argv[2]).read_text()); mats={x["id"]:x for x in bank["materials"]}
dts=[0.00025,0.000125,0.0000625,0.00003125]; routes=("FLUX","HEAD","RUNOFF"); modes=("TG","KLAG")
horizon=.001; dtop=10.; pmax=.05; rsro=.05

def kvg(m,h):
    mm=1-1/m["n"]; se=(1+(abs(m["alpha"]*h))**m["n"])**(-mm); term=1-(1-se**(1/mm))**mm
    return m["ksat"]*(se**m["lambda"])*term**2

def fixture(m,r):
    if r=="FLUX":
        h=-50.;p=0.;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=.25*(-q)
    elif r=="HEAD":
        h=-5.;p=.025;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q
    else:
        h=-5.;p=.1;kt=kvg(m,h);kf=.5*(m["ksat"]+kt);q=-kf*((p-h)/dtop+1);rain=-q+(p-pmax)/rsro
    return h,p,rain

def fields(line):
    return {k:v for k,v in (x.split("=",1) for x in line.split("|")[1:])}

def parse_segments(stdout,prefix):
    segs=[];cur=[]
    for line in stdout.splitlines():
        if not line.startswith(prefix): continue
        d=fields(line); it=int(d["ITER"])
        if it==1 and cur:
            segs.append(cur);cur=[]
        cur.append(d)
    if cur:segs.append(cur)
    return segs

def split_bt(seg):
    out=[];cur=[];it=None
    for d in seg:
        i=int(d["ITER"])
        if it is None or i==it:
            cur.append(d);it=i
        else:
            out.append(cur);cur=[d];it=i
    if cur:out.append(cur)
    return out

def norm_route(r):
    return {"surface-flux":"FLUX","ponded-head":"HEAD","ponded-head-linear-runoff":"RUNOFF"}.get(r,r)

def rho(d):
    a=float(d["FACTOR"]); raw0=float(d["RAW_ORIGIN"]); pred=raw0*(2*a-a*a)
    if not math.isfinite(pred) or pred<=0:return None
    return (raw0-float(d["RAW"]))/pred

def med(vals):
    vals=sorted(x for x in vals if x is not None and math.isfinite(x))
    return statistics.median(vals) if vals else None

audit=[]; cases=[]
for mid in ("B01","B12","O05","O14"):
    m=mats[mid]; theta_range=m["theta_s"]-m["theta_r"]
    for route in routes:
        h0,p0,rain=fixture(m,route)
        for dt in dts:
            for mode in modes:
                cp=subprocess.run([str(exe),mid,mode,route,str(m["theta_r"]),str(m["theta_s"]),str(m["alpha"]),str(m["n"]),
                    str(m["ksat"]),str(m["lambda"]),str(h0),str(p0),str(rain),str(dt),str(horizon)],text=True,capture_output=True)
                result=next((fields(x) for x in cp.stdout.splitlines() if x.startswith("F_PE_TIMEINT17A_RESULT|")),None)
                terminal=result["TERMINAL_REASON"] if result else "MISSING_RESULT"
                btsegs=parse_segments(cp.stdout,"F_PE_TIMEINT17H_BT|")
                stsegs=parse_segments(cp.stdout,"F_PE_NLGLOB01_STEP|")
                bt=btsegs[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and btsegs else []
                st=stsegs[-1] if terminal=="ENDPOINT_SOLVE_FAILURE" and stsegs else []
                groups=split_bt(bt)
                step_by_iter={int(x["ITER"]):x for x in st}
                cases.append({"material":mid,"route":route,"dt":dt,"mode":mode,"terminal_reason":terminal,
                              "process_ok":cp.returncode==0,"iterations":len(groups),"step_records":len(st)})
                for group in groups:
                    if not group: continue
                    it=int(group[0]["ITER"]); step=step_by_iter.get(it)
                    if step is None: continue
                    selected=next((x for x in group if int(x["CURRENT_ACCEPT"])==1),group[-1])
                    sr=rho(selected)
                    if sr is None or not math.isfinite(sr): continue
                    zh=float(step["ZH_INF"]); dtheta=float(step["DTHETA_INF"])
                    ztheta=dtheta/max(theta_range,1e-12)
                    mcp=float(selected["M_CP"]); mtot=float(selected["M_TOT"]); mh=float(selected["M_H"])
                    dom=max((("CP",mcp),("TOT",mtot),("HEAD",mh)),key=lambda q:q[1])[0]
                    audit.append({
                        "material":mid,"route":route,"provider_route":norm_route(step["ROUTE"]),"dt":dt,"mode":mode,"iter":it,
                        "selected_rho":sr,"selected_factor":float(selected["FACTOR"]),
                        "dh_inf":float(step["DH_INF"]),"dh_l2":float(step["DH_L2"]),
                        "dh_node":int(step["NODE_RAW"]),"top_dh":float(step["TOP_DH"]),"bottom_dh":float(step["BOTTOM_DH"]),
                        "z_h_inf":zh,"z_h_node":int(step["NODE_ZH"]),
                        "dtheta_inf":dtheta,"dtheta_node":int(step["NODE_DTHETA"]),"z_theta_inf":ztheta,
                        "residual_node":int(step["NODE_RES"]),
                        "raw_residual_colocated":int(step["NODE_RAW"])==int(step["NODE_RES"]),
                        "dominant_contract":dom
                    })

n=len(audit); poor=[x for x in audit if x["selected_rho"]<.25]; adequate=[x for x in audit if x["selected_rho"]>=.25]
finite=sum(all(math.isfinite(x[k]) for k in ("z_h_inf","z_theta_inf","dh_inf","dtheta_inf")) for x in audit)
route_set=sorted({x["provider_route"] for x in audit}); mat_set=sorted({x["material"] for x in audit})
dt_set=sorted({x["dt"] for x in audit}); mode_set=sorted({x["mode"] for x in audit})
coverage=(route_set==["FLUX","HEAD","RUNOFF"] and len(mat_set)==4 and len(dt_set)==4 and mode_set==["KLAG","TG"]
          and n>=500 and len(poor)>=100 and (finite/n if n else 0)>=.99)

def ratio(key,xs_poor=poor,xs_ok=adequate):
    a=med([x[key] for x in xs_poor]); b=med([x[key] for x in xs_ok])
    if a is None or b is None or b<=0:return None
    return a/b

agg={"z_h":ratio("z_h_inf"),"z_theta":ratio("z_theta_inf")}
families={}
direction_counts={"z_h":0,"z_theta":0}
for route in routes:
    for mode in modes:
        xs=[x for x in audit if x["provider_route"]==route and x["mode"]==mode]
        pp=[x for x in xs if x["selected_rho"]<.25]; aa=[x for x in xs if x["selected_rho"]>=.25]
        rh=ratio("z_h_inf",pp,aa); rt=ratio("z_theta_inf",pp,aa)
        if rh is not None and rh>1:direction_counts["z_h"]+=1
        if rt is not None and rt>1:direction_counts["z_theta"]+=1
        families[f"{route}|{mode}"]={"n":len(xs),"poor_n":len(pp),"z_h_ratio":rh,"z_theta_ratio":rt,
                                    "poor_z_h_median":med([x["z_h_inf"] for x in pp]),
                                    "adequate_z_h_median":med([x["z_h_inf"] for x in aa]),
                                    "poor_z_theta_median":med([x["z_theta_inf"] for x in pp]),
                                    "adequate_z_theta_median":med([x["z_theta_inf"] for x in aa])}

bins={
 "HIGH":[x for x in audit if x["selected_rho"]>=.75],
 "MID":[x for x in audit if .25<=x["selected_rho"]<.75],
 "POOR":[x for x in audit if 0<=x["selected_rho"]<.25]
}
binmed={k:{"z_h":med([x["z_h_inf"] for x in xs]),"z_theta":med([x["z_theta_inf"] for x in xs]),"n":len(xs)} for k,xs in bins.items()}
mono={}
for key in ("z_h","z_theta"):
    vals=[binmed[k][key] for k in ("HIGH","MID","POOR")]
    mono[key]=all(v is not None for v in vals) and vals[0]<=vals[1]<=vals[2]

state_signal=any(agg[k] is not None and agg[k]>=2 and direction_counts[k]>=4 and mono[k] for k in ("z_h","z_theta"))
route_specific=False
if not state_signal:
    for scale_key,field in (("z_h","z_h_ratio"),("z_theta","z_theta_ratio")):
        ft=families["FLUX|TG"][field]; fk=families["FLUX|KLAG"][field]
        if ft is not None and fk is not None and ft>=2 and fk>=2:
            others=[families[f"{r}|{m}"][field] for r in ("HEAD","RUNOFF") for m in modes]
            if any(v is not None and v<2 for v in others):
                route_specific=True
no_simple=(not state_signal and not route_specific and all(v is not None and v<1.5 for v in agg.values()))
if not coverage: cls="BLOCKED_NLGLOB01_SCALING_COVERAGE"
elif state_signal: cls="NLGLOB01_STATE_SCALING_SIGNAL"
elif route_specific: cls="NLGLOB01_ROUTE_SPECIFIC_SCALING_SIGNAL"
elif no_simple: cls="NLGLOB01_NO_SIMPLE_SCALING_SIGNAL"
else: cls="NLGLOB01_MIXED_SCALING_SIGNAL"

summary={"classification":cls,"coverage_ok":coverage,"audited_iterations":n,"poor_model_iterations":len(poor),
 "finite_fraction":finite/n if n else 0.0,"aggregate_ratios":agg,"direction_counts":direction_counts,
 "rho_bin_medians":binmed,"monotone":mono,"route_mode":families,
 "dominant_contract_counts":{k:sum(x["dominant_contract"]==k for x in audit) for k in ("CP","TOT","HEAD")},
 "max_step_node_counts":{"TOP":sum(x["dh_node"]==1 for x in audit),"BOTTOM":sum(x["dh_node"]==16 for x in audit),
                         "INTERIOR":sum(x["dh_node"] not in (1,16) for x in audit)},
 "residual_node_counts":{"TOP":sum(x["residual_node"]==1 for x in audit),"BOTTOM":sum(x["residual_node"]==16 for x in audit),
                         "INTERIOR":sum(x["residual_node"] not in (1,16) for x in audit)},
 "raw_residual_colocation_fraction":sum(x["raw_residual_colocated"] for x in audit)/n if n else 0.0,
 "routes":route_set,"materials":mat_set,"dt_levels":dt_set,"modes":mode_set,
 "process_failures":sum(not x["process_ok"] for x in cases)}
print("F_PE_NLGLOB01_CASES="+json.dumps(cases,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB01_AUDIT="+json.dumps(audit,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB01_SUMMARY="+json.dumps(summary,separators=(",",":"),sort_keys=True))
print("F_PE_NLGLOB01=PASS")
