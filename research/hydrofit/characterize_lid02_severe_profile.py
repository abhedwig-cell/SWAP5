#!/usr/bin/env python3
"""P-LID02 frozen-grid characterization of BHR000000378532 0.65-0.75 m."""
from __future__ import annotations
import numpy as np,sys
sys.path.insert(0,"research/hydrofit")
from bro_bhrp_fetch import fetch,DEFAULT_BASE
from compare_conditional_lambda_priors import parse_object,solve
GRID=[-25,-20,-15,-10,-7.5,-5,-3,-2,-1,0,.5,1,2,5,10.]
def cc(c):
 if not np.isfinite(c) or c>=1e8:return "SEVERE"
 if c>=1e6:return "POOR"
 if c>=1e4:return "MODERATE"
 return "WELL_CONDITIONED"
def main():
 bid="BHR000000378532";st,ct,b=fetch(DEFAULT_BASE+"/objects/"+bid)
 if st//100!=2:raise SystemExit(st)
 z=parse_object(b)[("0.65","0.75")]
 print(f"BRO_LID02_CASE|BRO={bid}|DEPTH=0.65:0.75|HORIZON={z['horizon']}|NOBS={z['n_obs']}|HSPAN={z['h_span']:.9g}|THETASPAN={z['theta_span']:.9g}|LOGKSPAN={z['logk_span']:.9g}")
 for l in GRID:
  j,blocks,c=solve(z["obs"],z["src"],l)
  print(f"BRO_LID02_PROFILE|L={l:.9g}|J={j:.9g}|BLOCKS={','.join(blocks) or 'NONE'}|COND={c:.9g}|CLASS={cc(c)}")
if __name__=="__main__":main()
