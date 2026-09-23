#!/usr/bin/env python3
from __future__ import annotations
import argparse,importlib.util,json,math,pathlib,re,sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
FACTORS=(8,16,32); NOBS=1024; OBS_DT=0.0008; MASS_GATE=1.0e-12; TOL=1.0e-12

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None: raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec); sys.modules[name]=mod; spec.loader.exec_module(mod); return mod

p4=load_module("rom_purpose_p4_frontier_analysis",HERE/"analyze_rom_purpose_p4_candidates.py")
SURF_H=p4.SURF_H; GW_H=p4.GW_H; RUNGS=p4.RUNGS

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def parse_mass(line):
    for pat in (r"LAREDYN0R_MAX_ABS_MASS=([^\s]+)",r"LAREGW1_MAX_ABS_MASS=([^\s]+)"):
        m=re.search(pat,line)
        if m: return abs(float(m.group(1)))
    return None

def parse_route(path,purpose,factor,bounds):
    histories=SURF_H if purpose=="SURF_P" else GW_H
    state_prefix="LAREDYN0R_STATE|" if purpose=="SURF_P" else "LAREGW1_STATE|"
    hkey="CASE" if purpose=="SURF_P" else "HISTORY"
    node_purpose="surface" if purpose=="SURF_P" else "gw"
    states={h:{} for h in histories}; nodes={h:{} for h in histories}; maxmass=0.0
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith(state_prefix):
            r=fields(line); h=r.get(hkey)
            if h in states:
                states[h][int(r["STEP"])]=r
                if "MASS" in r: maxmass=max(maxmass,abs(float(r["MASS"])))
        elif line.startswith("ROMPURP_P1_COARSE_NODE|"):
            r=fields(line)
            if r.get("PURPOSE")!=node_purpose: continue
            h=r.get(hkey)
            if h in nodes:
                nodes[h].setdefault(int(r["OBS_STEP"]),{})[int(r["NODE"])]=float(r["THETA"])
        else:
            x=parse_mass(line)
            if x is not None: maxmass=max(maxmass,x)
    dz=np.diff(np.asarray(bounds,float)); nn=len(dz); out={}
    for h in histories:
        expected=NOBS*factor
        if sorted(states[h])!=list(range(1,expected+1)):
            raise RuntimeError(f"{path}: state coverage {h} {len(states[h])}/{expected}")
        if sorted(nodes[h])!=list(range(1,NOBS+1)):
            raise RuntimeError(f"{path}: observation coverage {h} {len(nodes[h])}/{NOBS}")
        storage=[]; total=[]; cum=[]; q=[]; cx=0.0
        for obs in range(1,NOBS+1):
            row=nodes[h][obs]
            if sorted(row)!=list(range(1,nn+1)):
                raise RuntimeError(f"{path}: node coverage {h} obs={obs}")
            th=np.asarray([row[i] for i in range(1,nn+1)],float); st=th*dz; storage.append(st)
            final=states[h][obs*factor]; total.append(float(final["TOTAL_STORAGE"]))
            if purpose=="GW_LB":
                rs=[states[h][k] for k in range((obs-1)*factor+1,obs*factor+1)]
                ex=sum(float(x["BOTTOM_OUTWARD_EXCHANGE"]) for x in rs); cx+=ex; cum.append(cx); q.append(ex/OBS_DT)
        storage=np.asarray(storage,float)
        if purpose=="SURF_P":
            out[h]={
              "total_storage_cm":list(map(float,total)),
              "surface_0_20_storage_cm":[p4.p3.base.integrated_storage(x,bounds,0.0,20.0) for x in storage],
              "root_zone_0_40_storage_cm":[p4.p3.base.integrated_storage(x,bounds,0.0,40.0) for x in storage],
              "upper_0_80_storage_cm":[p4.p3.base.integrated_storage(x,bounds,0.0,80.0) for x in storage],
              "theta_10cm":[p4.p3.base.map_piecewise_to_10cm(x,bounds) for x in storage]
            }
        else:
            out[h]={
              "total_storage_cm":list(map(float,total)),
              "cumulative_bottom_downward_cm":list(map(float,cum)),
              "interval_average_bottom_downward_flux_cm_per_day":list(map(float,q))
            }
    return {"histories":out,"max_abs_mass_cm":maxmass}

def metric_vector(left,right,purpose):
    cand={"status":"QUALIFIED","histories":left}
    if purpose=="SURF_P":
        ref={"histories":{}}
        for h in SURF_H:
            x=right[h]
            ref["histories"][h]={
              "surface":np.asarray(x["surface_0_20_storage_cm"],float),
              "root":np.asarray(x["root_zone_0_40_storage_cm"],float),
              "upper":np.asarray(x["upper_0_80_storage_cm"],float),
              "theta":np.asarray(x["theta_10cm"],float),
              "total":np.asarray(x["total_storage_cm"],float)}
    else:
        ref={"histories":{}}
        for h in GW_H:
            x=right[h]
            ref["histories"][h]={
              "cum":np.asarray(x["cumulative_bottom_downward_cm"],float),
              "q":np.asarray(x["interval_average_bottom_downward_flux_cm_per_day"],float),
              "total":np.asarray(x["total_storage_cm"],float)}
    ans=p4.p3.candidate_metrics(purpose,cand,ref)
    if ans is None: raise RuntimeError("matched Richards metrics missing")
    return ans

def finite_vector(x): return all(math.isfinite(float(v)) and float(v)>=0 for v in x.values())

def qualify(routes,statuses,purpose):
    execution=all(statuses[f]["return_code_o0"]==0 and statuses[f]["return_code_o2"]==0
                  and statuses[f]["scientific_trace_identity"] and statuses[f]["trace_complete"] for f in FACTORS)
    if not execution:
        return {"qualified":False,"reason":"EXECUTION_OUTSIDE_FROZEN_QUALIFIED_DOMAIN",
                "execution_status":{f"T{f}":statuses[f] for f in FACTORS}}
    coarse=metric_vector(routes[8]["histories"],routes[16]["histories"],purpose)
    fine=metric_vector(routes[16]["histories"],routes[32]["histories"],purpose)
    finite=finite_vector(coarse) and finite_vector(fine)
    noninc=finite and all(float(fine[k])<=float(coarse[k])+TOL for k in coarse)
    mass={f"T{f}":float(routes[f]["max_abs_mass_cm"]) for f in FACTORS}
    masspass=all(v<=MASS_GATE for v in mass.values())
    return {"qualified":bool(noninc and masspass),"reason":("QUALIFIED" if noninc and masspass else "TEMPORAL_VECTOR_OR_MASS_QUALIFICATION_FAILED"),
            "execution_status":{f"T{f}":statuses[f] for f in FACTORS},
            "T8_vs_T16":coarse,"T16_vs_T32":fine,"componentwise_nonincreasing":bool(noninc),
            "finite_complete_vector":bool(finite),"max_abs_transaction_mass_cm":mass,
            "mass_gate_cm":MASS_GATE,"mass_gate_pass":bool(masspass)}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--route-root",required=True,type=pathlib.Path)
    ap.add_argument("--reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text()); rr=json.loads(a.reference_result.read_text()); ladder=json.loads(a.representation_ladder.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P4_REFERENCE_LAYER_ROM_OR_MATCHED_RICHARDS_RESPONSE"
    assert rr["status"]=="P4_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED" and rr["candidate_response_authorized"] is True
    refs,comparators=p4.p3.reference_bundle(a.reference_root)
    cases={}; decisions={}; summary={}
    for purpose in ("SURF_P","GW_LB"):
        cases[purpose]={}; decisions[purpose]={}
        for material in ("B01","B14"):
            cases[purpose][material]={}; first=None
            for member in RUNGS[purpose]:
                bounds=[float(x) for x in ladder[purpose]["family"][member]["boundaries_cm"]]
                statuses={}; routes={}
                for factor in FACTORS:
                    sp=a.route_root/f"execution_{purpose}_{material}_{member}_T{factor}.json"
                    statuses[factor]=json.loads(sp.read_text())
                    if statuses[factor]["return_code_o0"]==0 and statuses[factor]["return_code_o2"]==0 and statuses[factor]["scientific_trace_identity"]:
                        rp=a.route_root/f"richards_{purpose}_{material}_{member}_T{factor}_o0.txt"
                        routes[factor]=parse_route(rp,purpose,factor,bounds)
                nq=qualify(routes,statuses,purpose)
                metrics=None; relation=None; reaches=False
                if nq["qualified"]:
                    cand={"status":"QUALIFIED","histories":routes[32]["histories"]}
                    metrics=p4.p3.candidate_metrics(purpose,cand,refs[purpose][material])
                    reaches,relation=p4.p3.base.crosses(metrics,comparators[purpose][material],TOL)
                    if reaches and first is None: first=member
                cases[purpose][material][member]={
                  "numerical_qualification":nq,"metrics_against_R2048_T32":metrics,
                  "comparator_relation":relation,"comparator_reached":bool(reaches),
                  "boundaries_cm":bounds,"dimension":len(bounds)-1}
            decisions[purpose][material]={
              "minimum_tested_matched_richards_member":first,
              "minimum_tested_matched_richards_state_count":None if first is None else int(first[1:]),
              "frontier_status":("MATCHED_RICHARDS_FRONTIER_IDENTIFIED" if first else "MATCHED_RICHARDS_FRONTIER_NOT_REACHED")}
        vals=[decisions[purpose][m]["minimum_tested_matched_richards_state_count"] for m in ("B01","B14")]
        summary[purpose]={"both_materials_reach_comparator":all(v is not None for v in vals),
                          "material_minima":{m:decisions[purpose][m]["minimum_tested_matched_richards_state_count"] for m in ("B01","B14")}}
    out={"schema":"swap5.rom-purpose.p4.matched-richards-frontier-result.v1","workstream":"ROM-PURPOSE",
         "work_unit":"ROM-PURPOSE-P4-MATCHED-RICHARDS","cases":cases,"decisions":decisions,"purpose_summary":summary,
         "scientific_firewall":{"only_frozen_rungs_analyzed":True,"numerical_policy_relaxed":False,
                                "application_acceptance_adjudicated":False,"production_rom_authorized":False}}
    a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"purpose_summary":summary},sort_keys=True))

if __name__=="__main__": main()
