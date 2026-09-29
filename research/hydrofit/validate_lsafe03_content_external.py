#!/usr/bin/env python3
"""P-LSAFE03 frozen estimator validation on content-defined independent BRO records."""
from __future__ import annotations

import argparse
import json
import sys
import numpy as np

sys.path.insert(0, "research/hydrofit")

from compare_conditional_lambda_priors import solve
from compare_lambda_shrinkage import shrink, cclass
from hydro_record_binding import bind_corpus_rows

CENTER = -1.51057
SIGMA = 1.5
GRID = [-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
MAX_RATIO_GUARD = 4.13247088


def purpose_class(purposes):
    p=set(purposes or [])
    if "hydrologischOnderzoek" in p: return "PURPOSE_HYDROLOGISCH"
    if "onbekend" in p: return "PURPOSE_ONBEKEND"
    return "PURPOSE_OTHER"


def obs_bin(n):
    if n <= 20: return "NOBS_1_20"
    if n <= 100: return "NOBS_21_100"
    return "NOBS_GT100"


def span_bin(x):
    if x < 1e3: return "HSPAN_LT1E3"
    if x < 1e4: return "HSPAN_1E3_1E4"
    return "HSPAN_GE1E4"


def lambda_sign(x):
    if x < 0: return "LAMBDA_NEG"
    if x > 0: return "LAMBDA_POS"
    return "LAMBDA_ZERO"


def summarize(label, cases):
    if not cases:
        print(f"BRO_LSAFE03_STRATUM|NAME={label}|N=0")
        return
    ratios=np.array([c["ratio"] for c in cases],float)
    fb=sum(c["stage"]=="FALLBACK" for c in cases)
    unq=sum(c["final_unqualified"] for c in cases)
    classes={}
    for c in cases:
        classes[c["final_class"]]=classes.get(c["final_class"],0)+1
    print(
        f"BRO_LSAFE03_STRATUM|NAME={label}|N={len(cases)}|FALLBACK={fb}|"
        f"UNQUALIFIED={unq}|MEDIAN_RATIO={np.median(ratios):.9g}|"
        f"MEAN_RATIO={ratios.mean():.9g}|MAX_RATIO={ratios.max():.9g}|"
        f"CLASSES={json.dumps(classes,sort_keys=True)}"
    )


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--corpus",required=True)
    a=ap.parse_args()

    corpus=json.load(open(a.corpus))
    rows=bind_corpus_rows(corpus["intervals"])

    cases=[]
    for r in rows:
        best=min(solve(r["obs"],r["src"],g)[0] for g in GRID)
        j,l,blocks_h,cond_h,cond_p=shrink(r["obs"],r["src"],CENTER,SIGMA)
        primary_class=cclass(cond_h)
        trigger=(primary_class=="SEVERE") or bool(blocks_h)
        if trigger:
            final_j,final_blocks,final_cond=solve(r["obs"],r["src"],CENTER)
            final_class=cclass(final_cond)
            stage="FALLBACK"
        else:
            final_j=j
            final_blocks=blocks_h
            final_cond=cond_h
            final_class=primary_class
            stage="PRIMARY"
        ratio=final_j/best
        final_unqualified=(final_class=="SEVERE") or bool(final_blocks)
        c={
            "bro_id":r["bro_id"],
            "hash":r["hyd_sha256"],
            "purposes":r.get("survey_purposes",[]),
            "source_lambda":float(r["lambda"]),
            "n_obs":int(r["n_obs"]),
            "h_span":float(r["h_span"]),
            "stage":stage,
            "primary_l":float(l),
            "primary_cond":float(cond_h),
            "primary_class":primary_class,
            "primary_blocks":list(blocks_h),
            "final_cond":float(final_cond),
            "final_class":final_class,
            "final_blocks":list(final_blocks),
            "ratio":float(ratio),
            "final_unqualified":bool(final_unqualified),
        }
        cases.append(c)
        print(
            f"BRO_LSAFE03|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|"
            f"HASH={r['hyd_sha256']}|PURPOSE={purpose_class(r.get('survey_purposes',[]))}|"
            f"LTARGET={CENTER:.9g}|PRIMARY_L={l:.9g}|PRIMARY_CLASS={primary_class}|"
            f"PRIMARY_COND={cond_h:.9g}|PRIMARY_BLOCKS={','.join(blocks_h) or 'NONE'}|"
            f"STAGE={stage}|FINAL_CLASS={final_class}|FINAL_COND={final_cond:.9g}|"
            f"FINAL_BLOCKS={','.join(final_blocks) or 'NONE'}|RATIO={ratio:.9g}|"
            f"FINAL_UNQUALIFIED={int(final_unqualified)}"
        )

    n=len(cases)
    objects=len({c["bro_id"] for c in cases})
    fallback=sum(c["stage"]=="FALLBACK" for c in cases)
    unqualified=sum(c["final_unqualified"] for c in cases)
    boundary=sum(bool(c["final_blocks"]) for c in cases)
    ratios=np.array([c["ratio"] for c in cases],float) if cases else np.array([],float)

    acquisition_incomplete=bool(corpus.get("fetch_failures"))
    if acquisition_incomplete:
        disposition="ACQUISITION_INCOMPLETE"
    elif n < 30 or objects < 5:
        disposition="INSUFFICIENT_CONTENT_DEFINED_INDEPENDENT_EVIDENCE"
    elif unqualified==0 and boundary==0 and float(ratios.max()) <= MAX_RATIO_GUARD:
        disposition="EXTERNALLY_RESEARCH_REPLICATED_CONTENT_DEFINED"
    else:
        disposition="NOT_EXTERNALLY_REPLICATED_CONTENT_DEFINED"

    if cases:
        print(
            f"BRO_LSAFE03_SUMMARY|N={n}|OBJECTS={objects}|PRIMARY_ACCEPTED={n-fallback}|"
            f"FALLBACK_USED={fallback}|FINAL_UNQUALIFIED={unqualified}|BOUND_BLOCKED={boundary}|"
            f"MEDIAN_RATIO={np.median(ratios):.9g}|MEAN_RATIO={ratios.mean():.9g}|"
            f"MAX_RATIO={ratios.max():.9g}|ACQUISITION_INCOMPLETE={int(acquisition_incomplete)}|"
            f"DISPOSITION={disposition}"
        )
    else:
        print(
            f"BRO_LSAFE03_SUMMARY|N=0|OBJECTS=0|PRIMARY_ACCEPTED=0|FALLBACK_USED=0|"
            f"FINAL_UNQUALIFIED=0|BOUND_BLOCKED=0|ACQUISITION_INCOMPLETE="
            f"{int(acquisition_incomplete)}|DISPOSITION={disposition}"
        )

    for key in ("PURPOSE_HYDROLOGISCH","PURPOSE_ONBEKEND","PURPOSE_OTHER"):
        summarize(key,[c for c in cases if purpose_class(c["purposes"])==key])
    for key in ("NOBS_1_20","NOBS_21_100","NOBS_GT100"):
        summarize(key,[c for c in cases if obs_bin(c["n_obs"])==key])
    for key in ("HSPAN_LT1E3","HSPAN_1E3_1E4","HSPAN_GE1E4"):
        summarize(key,[c for c in cases if span_bin(c["h_span"])==key])
    for key in ("LAMBDA_NEG","LAMBDA_ZERO","LAMBDA_POS"):
        summarize(key,[c for c in cases if lambda_sign(c["source_lambda"])==key])


if __name__=="__main__":
    main()
