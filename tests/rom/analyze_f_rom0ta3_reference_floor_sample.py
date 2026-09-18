#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

MATERIALS=("B01","B14")
CASES=("TOP_PLUS","TOP_MINUS")
DTS=(0.0016,0.0008,0.0004)
EXPECTED={(m,c,dt) for m in MATERIALS for c in CASES for dt in DTS}
EXPECTED_STEPS={0.0016:8,0.0008:16,0.0004:32}

def num(v):
    try:
        return float(v)
    except ValueError:
        return v

def fields(line):
    out={}
    for x in line.split("|")[1:]:
        if "=" in x:
            k,v=x.split("=",1)
            out[k]=num(v)
    return out

def key3(r):
    return (str(r["MATERIAL"]),str(r["CASE"]),round(float(r["DT"]),10))

def tkey(x):
    return round(float(x),10)

def parse(text):
    passes={}
    fails=[]
    points={}
    nodes={}
    samples=[]
    for line in text.splitlines():
        if line.startswith("F_ROM0TA3_TRAJECTORY_PASS|"):
            r=fields(line); passes[key3(r)]=r
        elif line.startswith("F_ROM0TA3_TRAJECTORY_FAIL|"):
            r=fields(line); fails.append(r)
        elif line.startswith("F_ROM0TA3_POINT|"):
            r=fields(line); points[(key3(r),tkey(r["TREL"]))]=r
        elif line.startswith("F_ROM0TA3_NODE|"):
            r=fields(line); nodes[(key3(r),tkey(r["TREL"]),int(r["NODE"]))]=r
        elif line.startswith("F_ROM0TA3_SAMPLE_ACCEPT|"):
            samples.append(fields(line))
    return passes,fails,points,nodes,samples

def finite_values(row,names):
    return all(name in row and isinstance(row[name],(int,float)) and math.isfinite(float(row[name])) for name in names)

def compare_pair(points,nodes,m,c,coarse,fine):
    ck=(m,c,round(coarse,10)); fk=(m,c,round(fine,10))
    common=sorted({t for (k,t) in points if k==ck} & {t for (k,t) in points if k==fk})
    metrics={"TOTAL":0.0,"UPPER":0.0,"LOWER":0.0,"TOP_EXCHANGE":0.0,"BOTTOM_OUTWARD_EXCHANGE":0.0,
             "H_PROFILE_INF":0.0,"THETA_PROFILE_INF":0.0}
    for t in common:
        a=points[(ck,t)]; b=points[(fk,t)]
        for q in ("TOTAL","UPPER","LOWER","TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE"):
            metrics[q]=max(metrics[q],abs(float(a[q])-float(b[q])))
        dh=0.0; dth=0.0
        for node in range(1,17):
            aa=nodes[(ck,t,node)]; bb=nodes[(fk,t,node)]
            dh=max(dh,abs(float(aa["H"])-float(bb["H"])))
            dth=max(dth,abs(float(aa["THETA"])-float(bb["THETA"])))
        metrics["H_PROFILE_INF"]=max(metrics["H_PROFILE_INF"],dh)
        metrics["THETA_PROFILE_INF"]=max(metrics["THETA_PROFILE_INF"],dth)
    return {
        "material":m,"case":c,"coarse_dt_day":coarse,"fine_dt_day":fine,
        "common_time_count":len(common),
        "max_abs_difference":metrics
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    text=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    passes,fails,points,nodes,samples=parse(text)

    missing=sorted(EXPECTED-set(passes))
    extra=sorted(set(passes)-EXPECTED)
    counts={}
    node_counts={}
    malformed=[]
    for key in EXPECTED:
        n=sum(1 for (k,t) in points if k==key)
        nn=sum(1 for (k,t,node) in nodes if k==key)
        counts[str(key)]=n
        node_counts[str(key)]=nn
        if key in passes:
            expected=EXPECTED_STEPS[key[2]]
            if n!=expected or nn!=expected*16:
                malformed.append({"key":list(key),"point_count":n,"node_count":nn,"expected_points":expected})
    required_point=("TOTAL","UPPER","LOWER","TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE")
    for (k,t),r in points.items():
        if not finite_values(r,required_point):
            malformed.append({"key":list(k),"time":t,"reason":"nonfinite_or_missing_point_metric"})

    sample_invariants={
        "sample_accept_count":len(samples),
        "all_exact_one_advance":all(int(s.get("PHYSICAL_ADVANCES",-1))==1 for s in samples),
        "all_zero_internal_retries":all(int(s.get("INTERNAL_RETRIES",-1))==0 for s in samples),
        "all_mass_within_gate":all(abs(float(s.get("MASS_RES",math.inf)))<=1e-12 for s in samples),
    }
    repeat_identity=(text==repeat)
    complete=(not missing and not extra and not fails and not malformed and len(passes)==12 and
              "F_ROM0TA3_EXECUTION_COMPLETE=PASS" in text and repeat_identity and
              all(sample_invariants[k] for k in ("all_exact_one_advance","all_zero_internal_retries","all_mass_within_gate")))

    comparisons=[]
    missing_comparisons=[]
    pair_specs=((0.0016,0.0008,8),(0.0008,0.0004,16))
    for m in MATERIALS:
        for c in CASES:
            for coarse,fine,expected_common_count in pair_specs:
                ck=(m,c,round(coarse,10)); fk=(m,c,round(fine,10))
                if ck in passes and fk in passes:
                    item=compare_pair(points,nodes,m,c,coarse,fine)
                    item["expected_common_time_count"]=expected_common_count
                    comparisons.append(item)
                else:
                    missing_comparisons.append([m,c,coarse,fine])

    comparison_coverage=(len(comparisons)==8 and not missing_comparisons and
                         all(x["common_time_count"]==x["expected_common_time_count"] for x in comparisons))
    if complete and comparison_coverage:
        decision="REFERENCE_FLOOR_SAMPLE_CAPABILITY_QUALIFIED"
    elif fails:
        decision="REFERENCE_FIXED_RESOLUTION_TRAJECTORY_NO_GO"
    else:
        decision="REFERENCE_FLOOR_SAMPLE_CAPABILITY_IMPLEMENTATION_BLOCKED"

    maxima={q:max((x["max_abs_difference"][q] for x in comparisons),default=None)
            for q in ("TOTAL","UPPER","LOWER","TOP_EXCHANGE","BOTTOM_OUTWARD_EXCHANGE","H_PROFILE_INF","THETA_PROFILE_INF")}
    result={
        "schema":"swap5.f-rom0ta3.result.v1",
        "work_unit":"F-ROM0TA3",
        "decision":decision,
        "matrix_complete":complete,
        "trajectory_pass_count":len(passes),
        "trajectory_fail_count":len(fails),
        "missing_trajectories":[list(x) for x in missing],
        "extra_trajectories":[list(x) for x in extra],
        "malformed_evidence":malformed,
        "repeat_output_bitwise_identity":repeat_identity,
        "sample_invariants":sample_invariants,
        "comparison_coverage_complete":comparison_coverage,
        "available_cross_resolution_comparison_count":len(comparisons),
        "missing_cross_resolution_comparisons":missing_comparisons,
        "cross_resolution_comparisons":comparisons,
        "max_cross_resolution_difference":maxima,
        "temporal_accuracy_claim":False,
        "application_budget_used":False,
        "automatic_retry_or_subdivision":False,
        "rom1a_authorized":False,
        "production_application_admission":False
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))

if __name__=="__main__":
    main()
