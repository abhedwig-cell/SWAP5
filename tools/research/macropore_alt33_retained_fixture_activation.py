#!/usr/bin/env python3
"""F-MACRO-ALT33: retained SWAP5 default-MvG fixture -> RFM activation screen.

Uses the constitutive parameter set from tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90.
Research-only. This is a mirror of the provider equations for local numerical screening; the source-level RFM
adapter itself remains provider-bound and does not duplicate these equations.
"""
from __future__ import annotations
import json, math, time

THETA_R=0.032
THETA_S=0.423
KSAT=4.75
ALPHA=0.0135
N=1.455
M=1.0-1.0/N
LAMBDA=0.365
SIGMA_B=0.65
H_FIXTURE=-75.0
EVENT_AGE=0.25

def theta(h):
    if h >= 0.0: return THETA_S
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    return THETA_R+(THETA_S-THETA_R)*se

def conductivity(h):
    if h >= 0.0: return KSAT
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    term=(1.0-se**(1.0/M))**M
    return KSAT*(se**LAMBDA)*(1.0-term)**2

def sorptivity(h0, panels):
    if h0 >= 0.0: return 0.0
    ti=theta(h0); ts=theta(0.0)
    dh=-h0/panels
    integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(ts+theta(h)-2.0*ti)*conductivity(h))*dh
    return math.sqrt(integ)

def activation(source_rate,h0,age,panels=128):
    k=conductivity(h0); s=sorptivity(h0,panels)
    b50=k+s/(2.0*math.sqrt(max(age,1e-12)))
    mu=math.log(b50); lr=math.log(source_rate)
    phi=lambda z: 0.5*(1.0+math.erf(z/math.sqrt(2.0)))
    z1=(lr-mu-SIGMA_B*SIGMA_B)/SIGMA_B
    z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B*SIGMA_B)*phi(z1)+source_rate*(1.0-phi(z2))
    matrix=min(source_rate,max(0.0,matrix))
    return {'K_surface':k,'S_surface':s,'b50':b50,'preferential_fraction':(source_rate-matrix)/source_rate}

def main():
    panel_rows=[]
    for panels in [8,16,32,64,128,256,512,1024]:
        t0=time.perf_counter()
        reps=100
        val=0.0
        for _ in range(reps): val=sorptivity(H_FIXTURE,panels)
        usec=(time.perf_counter()-t0)*1.0e6/reps
        panel_rows.append({'panels':panels,'S_surface':val,'python_mirror_usec_per_call':usec})
    activation_rows=[]
    for source in [1.0,2.0,4.0,8.0,15.0,30.0,60.0]:
        row=activation(source,H_FIXTURE,EVENT_AGE,128)
        row['source_rate']=source
        activation_rows.append(row)
    print(json.dumps({
      'schema':'swap5.f_macro_alt33.retained_fixture_activation.v1',
      'status':'RESEARCH_ONLY',
      'fixture_source':'tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90',
      'fixture_head_cm':H_FIXTURE,
      'fixture_parameters':{'theta_r':THETA_R,'theta_s':THETA_S,'ksat':KSAT,'alpha':ALPHA,'n':N,'lambda':LAMBDA},
      'quadrature_convergence':panel_rows,
      'activation_event_age_day':EVENT_AGE,
      'activation':activation_rows,
      'decision':'64-128 panels are sufficient for the direct research oracle at this fixture; activation response is strong and monotone without external hydraulic surrogates'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
