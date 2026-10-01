#!/usr/bin/env python3
"""F-MACRO-ALT39: realistic 4% structural-area crossover on canonical A9 hydraulics."""
from __future__ import annotations
import json, math

THETA_R=0.02; THETA_S=0.427494; KSAT=31.225016; ALPHA=0.021659; N=1.734737
M=1.0-1.0/N; LAMBDA=0.98087; SIGMA_B=0.65; A_MP=0.04

def cdf(x): return 0.5*(1+math.erf(x/math.sqrt(2)))
def theta(h):
    if h>=0: return THETA_S
    se=(1+abs(ALPHA*h)**N)**(-M)
    return THETA_R+(THETA_S-THETA_R)*se
def conductivity(h):
    if h>=0: return KSAT
    se=(1+abs(ALPHA*h)**N)**(-M)
    term=(1-se**(1/M))**M
    return KSAT*se**LAMBDA*(1-term)**2
def sorptivity(h0,panels=512):
    if h0>=0: return 0.0
    ti=theta(h0); dh=-h0/panels; integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(THETA_S+theta(h)-2*ti)*conductivity(h))*dh
    return math.sqrt(integ)
def frac(h,R,age):
    b=conductivity(h)+sorptivity(h)/(2*math.sqrt(max(age,1e-12)))
    mu=math.log(b); lr=math.log(R)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+R*(1-cdf(z2))
    matrix=max(0,min(R,matrix))
    return (R-matrix)/R
def solve_R(h,age,target=A_MP):
    lo,hi=1e-5,1e4
    if frac(h,hi,age)<target: return None
    for _ in range(120):
        mid=math.sqrt(lo*hi)
        if frac(h,mid,age)<target: lo=mid
        else: hi=mid
    return math.sqrt(lo*hi)

def main():
    rows=[]
    for h in (-10.0,-50.0,-100.0,-300.0):
        for age in (0.01,0.1,0.25,0.5,1.0):
            r=solve_R(h,age)
            rows.append({
              'pressure_head_cm':h,'event_age_day':age,
              'K_surface':conductivity(h),'S_surface':sorptivity(h),
              'reference_direct_fraction':A_MP,
              'source_rate_crossover_cm_per_day':r
            })
    print(json.dumps({
      'schema':'swap5.f_macro_alt39.andelst_area_crossover.v1',
      'status':'RESEARCH_ONLY',
      'structural_reference':{'VLMPSTSS':0.04,'PPICSS':0.5,'A_mp_static':A_MP},
      'hydraulic_anchor':'canonical A9 default-MvG fixture',
      'rows':rows,
      'interpretation':'Below crossover RFM predicts less direct preferential entry than the 4% area-proportional reference; above crossover it predicts more.'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
