#!/usr/bin/env python3
"""F-MACRO-ALT40: duration signature for 4% A9 direct entry vs RFM activation."""
from __future__ import annotations
import json, math

THETA_R=0.02; THETA_S=0.427494; KSAT=31.225016; ALPHA=0.021659; N=1.734737
M=1.0-1.0/N; LAMBDA=0.98087; SIGMA_B=0.65; A_MP=0.04; H=-100.0

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
    ti=theta(h0); dh=-h0/panels; integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(THETA_S+theta(h)-2*ti)*conductivity(h))*dh
    return math.sqrt(integ)
S=sorptivity(H); K=conductivity(H)

def pref_rate(R,age):
    b=K+S/(2*math.sqrt(max(age,1e-12)))
    mu=math.log(b); lr=math.log(R)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+R*(1-cdf(z2))
    matrix=max(0,min(R,matrix))
    return R-matrix
def cumulative_fraction(R,duration,dt=1e-4):
    n=max(1,round(duration/dt)); dt=duration/n; total=R*duration; pref=0.0
    for i in range(n):
        age=(i+0.5)*dt
        pref += pref_rate(R,age)*dt
    return pref/total
def solve_duration(R,target=A_MP):
    lo=1e-5; hi=10.0
    if cumulative_fraction(R,hi) < target: return None
    for _ in range(80):
        mid=math.sqrt(lo*hi)
        if cumulative_fraction(R,mid) < target: lo=mid
        else: hi=mid
    return math.sqrt(lo*hi)

def main():
    rows=[]
    durations=[0.01,0.05,0.1,0.25,0.5,1.0,2.0]
    for R in (2.0,4.0,5.0,6.0,8.0,15.0):
        rows.append({
          'source_rate_cm_per_day':R,
          'duration_crossover_day':solve_duration(R),
          'duration_rows':[{'duration_day':d,'rfm_cumulative_fraction':cumulative_fraction(R,d),'reference_fraction':A_MP} for d in durations]
        })
    print(json.dumps({
      'schema':'swap5.f_macro_alt40.duration_signature.v1',
      'status':'RESEARCH_ONLY',
      'head_cm':H,'K_surface':K,'S_surface':S,'reference_fraction':A_MP,
      'rows':rows,
      'interpretation':'A9 direct fraction is duration-invariant at 4%; RFM cumulative preferential fraction grows with event duration and may cross 4% only after a source-dependent duration.'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
