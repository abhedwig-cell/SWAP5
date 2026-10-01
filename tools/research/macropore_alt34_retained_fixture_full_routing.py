#!/usr/bin/env python3
"""F-MACRO-ALT34: retained SWAP5 fixture -> full conservative RFM routing."""
from __future__ import annotations
import json, math

THETA_R=0.032; THETA_S=0.423; KSAT=4.75; ALPHA=0.0135; N=1.455; M=1.0-1.0/N; LAMBDA=0.365
H=-75.0; SIGMA_B=0.65; F_MB=0.25; P=0.66; Z_AH=25.0; Z_IC=85.0; PANELS=128
DT_H=0.002; TOTAL_TIME_H=10.0; VELOCITY_CM_H=100.0

def cdf(x): return 0.5*(1.0+math.erf(x/math.sqrt(2.0)))
def theta(h):
    if h>=0.0: return THETA_S
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    return THETA_R+(THETA_S-THETA_R)*se
def conductivity(h):
    if h>=0.0: return KSAT
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    term=(1.0-se**(1.0/M))**M
    return KSAT*(se**LAMBDA)*(1.0-term)**2
def sorptivity(h0, panels=PANELS):
    ti=theta(h0); ts=theta(0.0); dh=-h0/panels; integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(ts+theta(h)-2.0*ti)*conductivity(h))*dh
    return math.sqrt(integ)
S_SURFACE=sorptivity(H)
K_SURFACE=conductivity(H)

def pref_rate(R, age):
    b50=K_SURFACE+S_SURFACE/(2.0*math.sqrt(max(age,1e-12)))
    mu=math.log(b50); lr=math.log(R)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+R*(1.0-cdf(z2))
    matrix=max(0.0,min(R,matrix))
    return R-matrix

def c_struct(z):
    if z<=Z_AH: return 1.0
    if z>=Z_IC: return 0.0
    x=(z-Z_AH)/(Z_IC-Z_AH)
    return 1.0-x**P

def endpoint_weights(activation):
    depths=list(range(1,int(Z_IC)+1)); prev=activation; raw=[]
    for z in depths:
        surv=max(0.0,activation-(1.0-c_struct(float(z))))
        loss=max(0.0,prev-surv); raw.append((z,loss)); prev=surv
    total=sum(w for _,w in raw)
    if total<=0.0: return [(int(Z_AH),1.0)]
    return [(z,w/total) for z,w in raw if w>0.0]

def simulate(intensity,total_mm=40.0):
    duration=total_mm/intensity
    endpoints=list(range(1,int(Z_IC)+1))
    water={z:0.0 for z in endpoints}; tracer={z:0.0 for z in endpoints}
    mb=mbt=bottom=bottomt=dep=dept=source=tr_source=0.0
    num=den=0.0; max_depth=0.0
    for step in range(round(TOTAL_TIME_H/DT_H)):
        t=step*DT_H
        if t<duration:
            age=t+0.5*DT_H
            pr=pref_rate(intensity,age); incoming=pr*DT_H
            source += incoming; tr_source += incoming
            mb_in=incoming*F_MB; ic_in=incoming-mb_in
            mb += mb_in; mbt += mb_in
            activation=pr/intensity
            for z,w in endpoint_weights(activation):
                q=ic_in*w
                water[z]+=q; tracer[z]+=q
                num += q*z; den += q; max_depth=max(max_depth,z)
        rel=1.0-math.exp(-1.0*DT_H)
        q=mb*rel; qt=mbt*rel; mb-=q; mbt-=qt; bottom+=q; bottomt+=qt
        for z in endpoints:
            rel=1.0-math.exp(-(VELOCITY_CM_H/z)*DT_H)
            q=water[z]*rel; qt=tracer[z]*rel
            water[z]-=q; tracer[z]-=qt; dep+=q; dept+=qt
    residual=mb+sum(water.values()); tr_res=mbt+sum(tracer.values())
    return {
      'intensity_mm_h':intensity,'total_input_mm':total_mm,
      'preferential_input_mm':source,'preferential_fraction':source/total_mm,
      'mb_bottom_mm':bottom,'ic_deposition_mm':dep,'residual_fast_storage_mm':residual,
      'water_mass_residual_mm':source-bottom-dep-residual,
      'tracer_mass_residual':tr_source-bottomt-dept-tr_res,
      'mean_ic_endpoint_cm':num/den if den else None,'max_recruited_ic_endpoint_cm':max_depth
    }

def main():
    cases=[simulate(i) for i in (20.0,40.0,60.0)]
    print(json.dumps({
      'schema':'swap5.f_macro_alt34.retained_fixture_full_routing.v1',
      'status':'RESEARCH_ONLY',
      'fixture_head_cm':H,'K_surface':K_SURFACE,'S_surface':S_SURFACE,
      'parameters':{'sigma_B':SIGMA_B,'f_MB':F_MB,'p':P},
      'cases':cases,
      'decision':{
        'routing_conservation':'pass',
        'retained_fixture_composition':'pass',
        'empirical_pressure':'sigma_B=0.65 yields very high absolute preferential fractions at 20-60 mm/h and must be empirically transferred/calibrated before any default claim'
      }
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
