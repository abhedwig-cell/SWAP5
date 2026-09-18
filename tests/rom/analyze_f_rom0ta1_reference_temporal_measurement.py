#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

EXPECTED={(m,c,dt) for m in ("B01","B14") for c in ("TOP_PLUS","TOP_MINUS") for dt in (0.0016,0.0008)}

def parse_value(v):
    try:
        if v.strip() in ("0","1"):
            return int(v)
        return float(v)
    except ValueError:
        return v.strip()

def parse_rows(text):
    rows=[]
    for line in text.splitlines():
        if not line.startswith("F_ROM0TA1_ROW|"):
            continue
        fields={}
        for item in line.split("|")[1:]:
            if "=" not in item:
                continue
            k,v=item.split("=",1)
            fields[k]=parse_value(v)
        rows.append(fields)
    return rows

def finite_number(x):
    return isinstance(x,(int,float)) and math.isfinite(float(x))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    text=pathlib.Path(args.input).read_text()
    rows=parse_rows(text)
    required=("MATERIAL","CASE","FULL_DT","HALF_DT","BINF_FULL","BINF_HALF1","BINF_HALF2",
              "DH","DTHETA","DSTORAGE","DQTOP","DQBOT","MASS_FULL","MASS_TWO_HALF",
              "FULL_NL","HALF_NL","FULL_BT","HALF_BT","FULL_LINEAR","HALF_LINEAR",
              "RATIO_BINF_DH","CONSERVATIVE")
    malformed=[]; keys=set(); under=[]; cons=[]
    for i,r in enumerate(rows):
        missing=[k for k in required if k not in r]
        nums=[k for k in required if k not in ("MATERIAL","CASE") and k in r]
        nonfinite=[k for k in nums if not finite_number(r[k])]
        if missing or nonfinite:
            malformed.append({"row":i,"missing":missing,"nonfinite":nonfinite})
            continue
        key=(str(r["MATERIAL"]),str(r["CASE"]),round(float(r["FULL_DT"]),10))
        keys.add(key)
        (cons if int(r["CONSERVATIVE"])==1 else under).append(key)

    missing_matrix=sorted(EXPECTED-keys)
    extra_matrix=sorted(keys-EXPECTED)
    grouped={}
    for r in rows:
        if not all(k in r for k in required):
            continue
        grouped.setdefault((str(r["MATERIAL"]),str(r["CASE"])),[]).append(r)
    refinement=[]
    for g,rr in sorted(grouped.items()):
        rr=sorted(rr,key=lambda x:float(x["FULL_DT"]),reverse=True)
        if len(rr)==2:
            refinement.append({
                "material":g[0],"case":g[1],
                "coarse_full_dt_day":float(rr[0]["FULL_DT"]),
                "fine_full_dt_day":float(rr[1]["FULL_DT"]),
                "coarse_actual_head_difference_cm":float(rr[0]["DH"]),
                "fine_actual_head_difference_cm":float(rr[1]["DH"]),
                "coarse_B_inf_cm":float(rr[0]["BINF_FULL"]),
                "fine_B_inf_cm":float(rr[1]["BINF_FULL"]),
                "actual_head_difference_decreases_with_refinement":float(rr[1]["DH"]) <= float(rr[0]["DH"]),
                "B_inf_decreases_with_refinement":float(rr[1]["BINF_FULL"]) <= float(rr[0]["BINF_FULL"])
            })

    complete=(len(rows)==8 and not malformed and not missing_matrix and not extra_matrix and
              "F_ROM0TA1_GATE=PASS" in text)
    if not complete:
        decision="CERTIFICATE_NONINFORMATIVE_OR_EXECUTION_INCOMPLETE"
    elif under:
        decision="CERTIFICATE_EMPIRICALLY_UNDERESTIMATES_LOCAL"
    else:
        decision="CERTIFICATE_EMPIRICALLY_CONSERVATIVE_LOCAL"

    valid=[r for r in rows if all(k in r for k in required) and
           all(finite_number(r[k]) for k in required if k not in ("MATERIAL","CASE"))]
    result={
        "schema":"swap5.f-rom0ta1.measurement-result.v1",
        "work_unit":"F-ROM0TA1",
        "matrix_complete":complete,
        "row_count":len(rows),
        "expected_row_count":8,
        "missing_matrix_rows":[list(x) for x in missing_matrix],
        "extra_matrix_rows":[list(x) for x in extra_matrix],
        "malformed_rows":malformed,
        "empirically_conservative_rows":len(cons),
        "empirically_underestimating_rows":len(under),
        "underestimating_row_keys":[list(x) for x in under],
        "max_actual_head_difference_cm":max((float(r["DH"]) for r in valid),default=None),
        "max_B_inf_cm":max((float(r["BINF_FULL"]) for r in valid),default=None),
        "min_B_inf_to_actual_head_ratio":min((float(r["RATIO_BINF_DH"]) for r in valid),default=None),
        "max_B_inf_to_actual_head_ratio":max((float(r["RATIO_BINF_DH"]) for r in valid),default=None),
        "refinement_pairs":refinement,
        "decision":decision,
        "formal_bound_claim":False,
        "head_budget_selected":False,
        "rom1a_authorized":False,
        "interpretation_guard":"Finite preregistered matrix only. Empirical conservatism does not establish a mathematical upper bound or an application accuracy budget."
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result,sort_keys=True))
    if not complete:
        raise SystemExit(1)

if __name__=="__main__":
    main()
