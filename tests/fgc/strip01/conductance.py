"""Frozen physical sensitivity, same unchanged head and mass limits."""
import argparse
import json
from pathlib import Path
import flopy
import numpy as np
from oracle import discrete
from run_standalone import build, rate, HEAD_LIMIT_M, RATE_LIMIT_M3_D


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--mf6",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args(); rows=[]
    for c in [10.,100.,1000.]:
        heads,budgets=build(flopy,a.output/f"c{c}",a.mf6.resolve(),.5,conductance=c)
        t=heads.get_times()[-1]; h=heads.get_data(totim=t).ravel()
        expected,total=discrete(50,1,1,.001,.5,-5,-10,c)
        error=float(np.max(np.abs(h-expected)))
        residual=rate(budgets,"DRN",t)+rate(budgets,"RCHA",t)
        assert error<=HEAD_LIMIT_M and abs(residual)<=RATE_LIMIT_M3_D
        assert abs(h[0]+5-total/c)<=HEAD_LIMIT_M
        rows.append(dict(conductance_m2_per_day=c,drain_head_m=float(h[0]),
                         midpoint_head_m=float(h[-1]),head_error_m=error,
                         budget_residual_m3_per_day=residual))
    a.output.mkdir(parents=True,exist_ok=True)
    (a.output/"conductance_result.json").write_text(json.dumps(rows,indent=2)+"\n")
    print("STRIP01_NATIVE_DRAIN_CONDUCTANCE_SENSITIVITY=PASS")


if __name__=="__main__":
    main()
