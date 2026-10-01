#!/usr/bin/env python3
"""F-MACRO-ALT29: derive lateral exchange length from measurable structure."""
from __future__ import annotations
import json, math

def ell_from_radius_fraction(r_m, w_f):
    if r_m <= 0: raise ValueError('r_m must be > 0')
    if not (0 < w_f < 1): raise ValueError('0 < w_f < 1 required')
    return r_m / w_f

def bounds(rel_r, rel_w):
    lo=(1-rel_r)/(1+rel_w); hi=(1+rel_r)/(1-rel_w)
    return {
      'ell_relative_min':lo,'ell_relative_max':hi,
      'philip_scale_min':1/hi,'philip_scale_max':1/lo,
      'darcy_scale_min':1/(hi*hi),'darcy_scale_max':1/(lo*lo)
    }

def rss(rel_r, rel_w): return math.sqrt(rel_r*rel_r + rel_w*rel_w)

def mixed_dpol(d_pf, holes, area_h):
    inv=0.0
    if d_pf is not None: inv += 1.0/d_pf
    inv += math.pi*sum(n*d for n,d in holes)/(4.0*area_h)
    return 1.0/inv

def main():
    u={}
    for rel in (0.05,0.10,0.20,0.30):
        u[f'{int(rel*100)}pct_each']={'rss_sigma_ell':rss(rel,rel),**bounds(rel,rel)}
    dm=mixed_dpol(20.0,[(4.0,0.4),(8.0,0.2)],100.0)
    print(json.dumps({
      'schema':'swap5.f_macro_alt29.exchange_length_from_structure.v1',
      'status':'RESEARCH_ONLY',
      'cylindrical_relation':{
        'd_pol':'2*r_m/w_f',
        'ell_ex':'0.5*d_pol = r_m/w_f',
        'example':{'r_m_cm':0.15,'w_f':0.01,'ell_ex_cm':ell_from_radius_fraction(0.15,0.01)}
      },
      'uncertainty_cases':u,
      'mixed_geometry':{
        'formula':'1/d_pol = 1/d_pf + pi*sum(N_i*d_i)/(4*A_h)',
        'example_d_pol_cm':dm,'example_ell_ex_cm':0.5*dm
      },
      'decision':'ell_ex should be derived from measured structure by default; propagate uncertainty because Darcy exchange scales as ell_ex^-2'
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
