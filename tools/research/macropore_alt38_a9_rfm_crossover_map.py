#!/usr/bin/env python3
"""F-MACRO-ALT38: A9-vs-RFM crossover regime map."""
from __future__ import annotations
import json, math

THETA_R=0.02; THETA_S=0.427494; KSAT=31.225016; ALPHA=0.021659; N=1.734737
M=1.0-1.0/N; LAMBDA=0.98087; SIGMA_B=0.65; EVENT_AGE=0.25

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
def rfm_fraction(h,R):
    b=conductivity(h)+sorptivity(h)/(2*math.sqrt(EVENT_AGE))
    mu=math.log(b); lr=math.log(R)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+R*(1-cdf(z2))
    matrix=max(0,min(R,matrix))
    return (R-matrix)/R

def main():
    rows=[]
    for h in (-10.0,-50.0,-100.0,-300.0):
        for R in (1.0,2.0,4.0,8.0,15.0,30.0,60.0):
            f=rfm_fraction(h,R)
            rows.append({
              'pressure_head_cm':h,'source_rate_cm_per_day':R,
              'K_surface':conductivity(h),'S_surface':sorptivity(h),
              'rfm_preferential_fraction':f,
              'a9_crossover_top_area_fraction':f
            })
    print(json.dumps({
      'schema':'swap5.f_macro_alt38.a9_rfm_crossover_map.v1',
      'status':'RESEARCH_ONLY',
      'event_age_day':EVENT_AGE,
      'rows':rows,
      'identity':'A9 direct fraction=A_mp; equality occurs where A_mp=RFM preferential fraction',
      'decision':'weak-source experiments with nonzero A_mp maximize discrimination; high-intensity events can move RFM into the same direct-entry fraction range as plausible A9 geometry'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
