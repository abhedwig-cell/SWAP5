#!/usr/bin/env python3
"""Compare TRACER01-D timestep refinement outputs."""
from pathlib import Path
import json, sys

def load(p): return json.loads(Path(p).read_text())

def l1(a,b,input_mass):
    return sum(abs(x-y) for x,y in zip(a,b))/input_mass

def main(a,b,c):
    r120,r60,r30=map(load,(a,b,c))
    inp=r30['tracer_input_mass']
    d1=l1(r120['final_tracer_profile'],r60['final_tracer_profile'],inp)
    d2=l1(r60['final_tracer_profile'],r30['final_tracer_profile'],inp)
    closure=max(abs(r['global_tracer_residual']) for r in (r120,r60,r30))
    bottom=max(r['max_observer_bottom_flux_residual'] for r in (r120,r60,r30))
    passed=(closure<1e-10 and d2<=d1+1e-14 and d2<=0.02)
    out={
      'schema':'swap5.f_macro_tracer01d.refinement.v1',
      'status':'PASS' if passed else 'FAIL',
      'L1_120_60':d1,'L1_60_30':d2,
      'max_global_tracer_residual':closure,
      'max_bottom_flux_residual':bottom,
      'accepted_packets':{
         '120s':r120['accepted_packets'],'60s':r60['accepted_packets'],'30s':r30['accepted_packets']},
      'decision':'qualified' if passed else 'refinement gate failed'
    }
    print(json.dumps(out,indent=2,sort_keys=True))
    if not passed: raise SystemExit(2)

if __name__=='__main__': main(*sys.argv[1:4])
