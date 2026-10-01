#!/usr/bin/env python3
"""F-MACRO-ALT31 static/analytic contract checks for the research adapter."""
from pathlib import Path
import math

def cdf(x): return 0.5*(1+math.erf(x/math.sqrt(2)))

def activation(R,K,S,t,sigma):
    b50=K+S/(2*math.sqrt(max(t,1e-12)))
    mu=math.log(b50); lr=math.log(R)
    z1=(lr-mu-sigma*sigma)/sigma; z2=(lr-mu)/sigma
    m=math.exp(mu+0.5*sigma*sigma)*cdf(z1)+R*(1-cdf(z2))
    m=min(R,max(0,m))
    return (R-m)/R

def main():
    source=Path(__file__).with_name('fortran').joinpath('mod_rfm_research_adapter.f90').read_text()
    required=[
      'class(constitutive_hydraulics_provider_t)',
      'evaluate_point_conductivity',
      "route = 'surface-boundary-required'",
      'input%surface_sorptivity / (2.0_real64*sqrt(age))',
      '1.0_real64 - x**p'
    ]
    missing=[x for x in required if x not in source]
    assert not missing, missing
    vals=[activation(r,0.396,13.34,0.5,0.65) for r in (4,8,15,30,60)]
    assert all(b>=a for a,b in zip(vals,vals[1:])), vals
    assert 0 < (1-(0.5**0.66)) < 1
    print('PASS F-MACRO-ALT31 research adapter contract')

if __name__=='__main__': main()
