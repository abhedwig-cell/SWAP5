#!/usr/bin/env python3
"""F-MACRO-ALT37: paired A9 source-faithful legacy top-entry vs frozen RFM activation.

Uses only values from canonical A9/F-SI04 fixtures.
"""
from __future__ import annotations
import json, math

# A9/F-SI04 fixture
DZ_TOP=0.50
STATIC_VOLUME_TOP=0.50
DIRECT_RATE=1.25
LATERAL_RATE=0.10
H=-100.0
DT=1.0e-3

# A9 constitutive fixture
THETA_R=0.02; THETA_S=0.427494; KSAT=31.225016; ALPHA=0.021659; N=1.734737
M=1.0-1.0/N; LAMBDA=0.98087; SIGMA_B=0.65

def cdf(x): return 0.5*(1.0+math.erf(x/math.sqrt(2.0)))
def theta(h):
    if h>=0.0: return THETA_S
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    return THETA_R+(THETA_S-THETA_R)*se
def conductivity(h):
    if h>=0.0: return KSAT
    se=(1.0+abs(ALPHA*h)**N)**(-M)
    term=(1.0-se**(1.0/M))**M
    return KSAT*se**LAMBDA*(1.0-term)**2
def sorptivity(h0,panels=512):
    ti=theta(h0); ts=theta(0.0); dh=-h0/panels; integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(ts+theta(h)-2.0*ti)*conductivity(h))*dh
    return math.sqrt(integ)
def rfm_pref_fraction(source,age):
    k=conductivity(H); s=sorptivity(H)
    b50=k+s/(2.0*math.sqrt(max(age,1e-12)))
    mu=math.log(b50); lr=math.log(source)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+source*(1.0-cdf(z2))
    matrix=max(0.0,min(source,matrix))
    return (source-matrix)/source,b50

def main():
    top_area_fraction=STATIC_VOLUME_TOP/DZ_TOP
    legacy_vertical_rate=top_area_fraction*DIRECT_RATE
    legacy_vertical_amount=legacy_vertical_rate*DT
    legacy_lateral_amount=LATERAL_RATE*DT
    rows=[]
    for age in [0.5*DT,DT,0.01,0.1,0.25,1.0]:
        frac,b50=rfm_pref_fraction(DIRECT_RATE,age)
        rate=frac*DIRECT_RATE
        rows.append({
          'event_age_day':age,'b50':b50,'rfm_preferential_fraction':frac,
          'rfm_vertical_preferential_rate_cm_per_day':rate,
          'delta_vs_legacy_vertical_rate_cm_per_day':rate-legacy_vertical_rate
        })
    print(json.dumps({
      'schema':'swap5.f_macro_alt37.a9_paired_shadow.v1',
      'status':'RESEARCH_ONLY',
      'reference':{
        'top_area_fraction':top_area_fraction,
        'direct_source_rate_cm_per_day':DIRECT_RATE,
        'legacy_vertical_macro_rate_cm_per_day':legacy_vertical_rate,
        'legacy_vertical_amount_per_dt_cm':legacy_vertical_amount,
        'lateral_macro_amount_per_dt_cm':legacy_lateral_amount
      },
      'hydraulics':{'head_cm':H,'K_surface':conductivity(H),'S_surface':sorptivity(H)},
      'rfm_rows':rows,
      'interpretation':'A9 reference top entry is area-proportional and equals 100% of direct source in this fixture; frozen RFM is capacity-limited and predicts effectively zero weak-source preferential entry at event start.'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
