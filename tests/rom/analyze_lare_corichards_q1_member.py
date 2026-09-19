#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,math,pathlib
from collections import defaultdict

SUBSTEPS=(1,2,4,8,16)
OBS_DT=0.0008
NSTEP=1024

def fields(payload):
    out={}
    for item in payload.split("|"):
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def load_success(path,nnode,dz):
    states={}
    nodes=defaultdict(dict)
    summary={}
    for line in path.read_text(errors="replace").splitlines():
        if line.startswith("LAREDYN0R_STATE|"):
            row=fields(line.split("|",1)[1])
            states[int(row["STEP"])]={"total":float(row["TOTAL_STORAGE"]),"bflux":float(row["BOTTOM_DOWNWARD_FLUX"])}
        elif line.startswith("LAREDYN0R_NODE|"):
            row=fields(line.split("|",1)[1])
            nodes[int(row["STEP"])][int(row["NODE"])]=float(row["THETA"])
        elif line.startswith("LAREDYN0R_") and "=" in line and "|" not in line:
            k,v=line.split("=",1); summary[k]=v.strip()
    if set(states)!=set(range(1,NSTEP+1)): raise ValueError(f"incomplete states {path}: {len(states)}")
    if set(nodes)!=set(range(1,NSTEP+1)): raise ValueError(f"incomplete node steps {path}: {len(nodes)}")
    expected=set(range(1,nnode+1))
    for step,row in nodes.items():
        if set(row)!=expected: raise ValueError(f"incomplete nodes {path} step {step}")
    return states,nodes,summary

def compare(a,b,dz):
    sa,na,_=a; sb,nb,_=b
    max_layer=0.0; sum_layer=0.0; count=0; max_total=0.0; max_bflux=0.0
    for step in range(1,NSTEP+1):
        for node,thick in enumerate(dz,start=1):
            d=abs(na[step][node]*thick-nb[step][node]*thick)
            max_layer=max(max_layer,d); sum_layer+=d; count+=1
        max_total=max(max_total,abs(sa[step]["total"]-sb[step]["total"]))
        max_bflux=max(max_bflux,abs(sa[step]["bflux"]-sb[step]["bflux"]))
    return {
        "max_abs_layer_storage_cm":max_layer,
        "mean_abs_layer_storage_cm":sum_layer/count,
        "max_abs_total_storage_cm":max_total,
        "max_abs_bottom_flux_cm_per_day":max_bflux,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--evidence-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()
    pre=json.loads(args.prereg.read_text())
    manifest=json.loads((args.evidence_dir/"execution_manifest.json").read_text())
    member=manifest["member"]
    spec=next(x for x in pre["viability_ladder"] if x["id"]==member)
    dz=[float(x) for x in spec["thickness_cm"]]; nnode=len(dz)
    if abs(sum(dz)-160.0)>1e-12: raise SystemExit("profile depth drift")
    if nnode!=int(spec["dimension"]): raise SystemExit("dimension drift")

    results={}; dynamic_qualified=[]; eq_qualified=[]; outside=[]; blocked=[]; technical=[]
    max_mass=0.0; all_o_identity=True
    for case in manifest["cases"]:
        routes={}; parsed={}
        for sub in SUBSTEPS:
            row=manifest["runs"][case][str(sub)]
            status=row["status"]
            routes[str(sub)]={
                "status":status,
                "internal_dt_day":OBS_DT/sub,
                "o0_o2_status_identity":bool(row["o0_o2_status_identity"]),
                "o0_o2_scientific_trace_identity":row.get("o0_o2_scientific_trace_identity"),
            }
            all_o_identity &= bool(row["o0_o2_status_identity"])
            if status=="QUALIFIED":
                all_o_identity &= bool(row.get("o0_o2_scientific_trace_identity"))
                parsed[sub]=load_success(args.evidence_dir/row["o2_file"],nnode,dz)
                mm=float(parsed[sub][2].get("LAREDYN0R_MAX_ABS_MASS","nan"))
                routes[str(sub)]["max_abs_mass_residual_cm"]=mm
                routes[str(sub)]["fallback_count"]=int(parsed[sub][2].get("LAREDYN0R_TOTAL_FALLBACK_COUNT","0"))
                if math.isfinite(mm): max_mass=max(max_mass,abs(mm))

        pairwise={}; prev=None; monotonic=True
        for left,right in zip(SUBSTEPS[:-1],SUBSTEPS[1:]):
            if left in parsed and right in parsed:
                m=compare(parsed[left],parsed[right],dz)
                pairwise[f"{left}_vs_{right}"]=m
                if prev is not None:
                    for key in ("max_abs_layer_storage_cm","mean_abs_layer_storage_cm","max_abs_total_storage_cm","max_abs_bottom_flux_cm_per_day"):
                        tol=max(1e-15,1e-10*max(1.0,prev[key]))
                        if m[key] > prev[key]+tol: monotonic=False
                prev=m
        finest=pairwise.get("8_vs_16")
        temporal=routes["8"]["status"]=="QUALIFIED" and routes["16"]["status"]=="QUALIFIED" and finest is not None and all(math.isfinite(float(v)) for v in finest.values()) and monotonic
        forcing=case.split("_F")[-1]; is_eq=(forcing=="1")
        if temporal: (eq_qualified if is_eq else dynamic_qualified).append(case)
        else:
            statuses=[routes[str(s)]["status"] for s in SUBSTEPS]
            if "TECHNICAL_FAILURE" in statuses: technical.append(case)
            elif all(s=="OUTSIDE_QUALIFIED_DOMAIN_NEAR_SATURATION" for s in statuses): outside.append(case)
            elif not is_eq: blocked.append(case)
        results[case]={
            "forcing_kind":"EQ" if is_eq else {"2":"WET","3":"DRY","4":"WET_DRY"}[forcing],
            "temporal_qualification":"QUALIFIED" if temporal else "NOT_QUALIFIED",
            "routes":routes,
            "pairwise_refinement":pairwise,
            "refinement_monotonic":monotonic,
            "finest_successful_substeps":max((s for s in SUBSTEPS if s in parsed),default=None),
            "finest_successful_internal_dt_day":OBS_DT/max((s for s in SUBSTEPS if s in parsed),default=1) if parsed else None,
            "finest_pair_8_vs_16":finest,
        }

    payload={
        "schema":"swap5.lare.corichards.q1.member-result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-CORICHARDS-Q1",
        "member":member,"dimension":nnode,"thickness_cm":dz,
        "decision":"CORICHARDS_MEMBER_VIABILITY_MAPPED",
        "dynamic_qualified_cases":dynamic_qualified,"dynamic_qualified_count":len(dynamic_qualified),
        "equilibrium_qualified_cases":eq_qualified,"equilibrium_qualified_count":len(eq_qualified),
        "outside_domain_cases":outside,"numerically_blocked_dynamic_cases":blocked,
        "technical_failure_cases":technical,"all_O0_O2_identity":all_o_identity,
        "maximum_mass_residual_cm":max_mass,"cases":results,
        "hydrological_comparison_performed":False,
        "application_acceptance_adjudicated":False,"speed_claim_authorized":False,"production_rom_authorized":False
    }
    args.output.write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "member":member,"dimension":nnode,"dynamic_qualified_count":len(dynamic_qualified),
        "dynamic_qualified_cases":dynamic_qualified,"equilibrium_qualified_count":len(eq_qualified),
        "outside_domain_cases":outside,"numerically_blocked_dynamic_cases":blocked,
        "technical_failure_cases":technical,"all_O0_O2_identity":all_o_identity,
        "maximum_mass_residual_cm":max_mass
    },sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
