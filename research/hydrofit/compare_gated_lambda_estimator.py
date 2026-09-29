#!/usr/bin/env python3
"""P-LSAFE01 preregistered gated soft-lambda estimator."""
from __future__ import annotations
import argparse, json, math, sys
import numpy as np
sys.path.insert(0, "research/hydrofit")

from compare_conditional_lambda_priors import predict, solve
from compare_lambda_shrinkage import shrink, cclass
from hydro_record_binding import bind_corpus_rows


GRID = [-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]


def decorate(rows):
    for r in rows:
        bd=float(r["begin_depth"]); ed=float(r["end_depth"])
        r["mid"]=.5*(bd+ed)
        r["ln_n"]=math.log10(max(r["n_obs"],1))
        r["ln_h"]=math.log10(max(r["h_span"],1))
    return rows


def summarize(label, cases):
    ratios=np.array([c["ratio"] for c in cases], float)
    prim=sum(c["stage"]=="PRIMARY" for c in cases)
    fb=sum(c["stage"]=="FALLBACK" for c in cases)
    unq=sum(c["final_unqualified"] for c in cases)
    boundary=sum(bool(c["final_blocks"]) for c in cases)
    classes={}
    for c in cases:
        classes[c["final_class"]]=classes.get(c["final_class"],0)+1
    print(
        f"BRO_LSAFE_SUMMARY|SUBSET={label}|N={len(cases)}|PRIMARY_ACCEPTED={prim}|"
        f"FALLBACK_USED={fb}|FINAL_UNQUALIFIED={unq}|BOUND_BLOCKED={boundary}|"
        f"MEDIAN_RATIO={np.median(ratios):.9g}|MEAN_RATIO={ratios.mean():.9g}|"
        f"MAX_RATIO={ratios.max():.9g}|CLASSES={json.dumps(classes,sort_keys=True)}"
    )


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True)
    a=ap.parse_args()
    corp=json.load(open(a.corpus))
    rows=decorate(bind_corpus_rows(corp["intervals"]))

    targets={}
    for i,t in enumerate(rows):
        train=[r for r in rows if r["bro_id"]!=t["bro_id"]]
        targets[i]=predict(train,t,"LOO_MEDIAN")

    deterministic=set(np.linspace(0,len(rows)-1,min(12,len(rows))).round().astype(int))
    cases=[]
    for i,r in enumerate(rows):
        best=min(solve(r["obs"],r["src"],g)[0] for g in GRID)
        target=targets[i]

        j,l,blocks_h,cond_h,cond_p = shrink(r["obs"],r["src"],target,1.5)
        primary_class=cclass(cond_h)
        trigger=(primary_class=="SEVERE") or bool(blocks_h)

        if not trigger:
            final_j=j
            final_blocks=blocks_h
            final_cond=cond_h
            final_class=primary_class
            stage="PRIMARY"
        else:
            final_j, final_blocks, final_cond = solve(r["obs"],r["src"],target)
            final_class=cclass(final_cond)
            stage="FALLBACK"

        final_unqualified=(final_class=="SEVERE") or bool(final_blocks)
        ratio=final_j/best
        subset="DETERMINISTIC12" if i in deterministic else "COMPLEMENT19"
        case={
            "i":i,"subset":subset,"bro":r["bro_id"],"begin":r["begin_depth"],"end":r["end_depth"],
            "hash":r["hyd_sha256"],"target":target,"stage":stage,"primary_l":l,
            "primary_cond":cond_h,"primary_class":primary_class,"primary_blocks":blocks_h,
            "final_j":final_j,"best":best,"ratio":ratio,"final_cond":final_cond,
            "final_class":final_class,"final_blocks":final_blocks,"final_unqualified":final_unqualified,
        }
        cases.append(case)
        print(
            f"BRO_LSAFE|SUBSET={subset}|BRO={r['bro_id']}|DEPTH={r['begin_depth']}:{r['end_depth']}|"
            f"HASH={r['hyd_sha256']}|LTARGET={target:.9g}|PRIMARY_L={l:.9g}|"
            f"PRIMARY_CLASS={primary_class}|PRIMARY_COND={cond_h:.9g}|"
            f"PRIMARY_BLOCKS={','.join(blocks_h) or 'NONE'}|STAGE={stage}|"
            f"FINAL_CLASS={final_class}|FINAL_COND={final_cond:.9g}|"
            f"FINAL_BLOCKS={','.join(final_blocks) or 'NONE'}|RATIO={ratio:.9g}|"
            f"FINAL_UNQUALIFIED={int(final_unqualified)}"
        )

    summarize("DETERMINISTIC12",[c for c in cases if c["subset"]=="DETERMINISTIC12"])
    summarize("COMPLEMENT19",[c for c in cases if c["subset"]=="COMPLEMENT19"])
    summarize("ALL31",cases)


if __name__=="__main__":
    main()
