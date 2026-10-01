#!/usr/bin/env python3
"""F-MACRO-ALT41: minimal empirical campaign ranking for A9 vs RFM discrimination."""
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
def sorptivity(h0,panels=384):
    ti=theta(h0); dh=-h0/panels; integ=0.0
    for i in range(panels):
        h=h0+(i+0.5)*dh
        integ += max(0.0,(THETA_S+theta(h)-2*ti)*conductivity(h))*dh
    return math.sqrt(integ)
def pref_rate(h,R,age):
    s=sorptivity(h); k=conductivity(h)
    b=k+s/(2*math.sqrt(max(age,1e-12)))
    mu=math.log(b); lr=math.log(R)
    z1=(lr-mu-SIGMA_B**2)/SIGMA_B; z2=(lr-mu)/SIGMA_B
    matrix=math.exp(mu+0.5*SIGMA_B**2)*cdf(z1)+R*(1-cdf(z2))
    matrix=max(0,min(R,matrix))
    return R-matrix
def cumulative_fraction(h,R,duration,dt=2e-4):
    n=max(1,round(duration/dt)); dt=duration/n; pref=0.0
    for i in range(n): pref += pref_rate(h,R,(i+0.5)*dt)*dt
    return pref/(R*duration)
def fragmented_fraction(h,R,total_duration,gap=0.25,dt=2e-4):
    half=0.5*total_duration
    # same total source duration, split into two pulses; event age resets at second pulse
    pref=0.0
    for pulse in range(2):
        n=max(1,round(half/dt)); local=half/n
        for i in range(n): pref += pref_rate(h,R,(i+0.5)*local)*local
    return pref/(R*total_duration)

def main():
    heads=(-50.0,-100.0)
    intensities=(2.0,4.0,5.0,6.0,8.0,15.0)
    durations=(0.05,0.10,0.25,0.50,1.0)
    cells=[]
    for R in intensities:
        for d in durations:
            fs=[cumulative_fraction(h,R,d) for h in heads]
            seps=[abs(f-A_MP) for f in fs]
            cells.append({
              'source_rate_cm_per_day':R,'duration_day':d,
              'rfm_fraction_hm50':fs[0],'rfm_fraction_hm100':fs[1],
              'robust_abs_fraction_separation':min(seps),
              'mean_abs_fraction_separation':sum(seps)/len(seps)
            })
    cells=sorted(cells,key=lambda x:(x['robust_abs_fraction_separation'],x['mean_abs_fraction_separation']),reverse=True)

    duration_pairs=[]
    for R in intensities:
        short=0.05; long=0.50
        ds=[]
        for h in heads:
            fs=cumulative_fraction(h,R,short)
            fl=cumulative_fraction(h,R,long)
            ds.append(abs(fl-fs))
        duration_pairs.append({
          'source_rate_cm_per_day':R,'short_day':short,'long_day':long,
          'robust_rfm_duration_change':min(ds),'mean_rfm_duration_change':sum(ds)/2
        })
    duration_pairs=sorted(duration_pairs,key=lambda x:x['robust_rfm_duration_change'],reverse=True)

    fragmentation=[]
    for R in (4.0,6.0,8.0,15.0):
        total=0.50; diffs=[]
        for h in heads:
            cont=cumulative_fraction(h,R,total)
            frag=fragmented_fraction(h,R,total)
            diffs.append(cont-frag)
        fragmentation.append({
          'source_rate_cm_per_day':R,'total_source_duration_day':total,
          'robust_continuous_minus_fragmented_fraction':min(diffs),
          'mean_continuous_minus_fragmented_fraction':sum(diffs)/2
        })
    fragmentation=sorted(fragmentation,key=lambda x:x['robust_continuous_minus_fragmented_fraction'],reverse=True)

    print(json.dumps({
      'schema':'swap5.f_macro_alt41.minimal_empirical_campaign.v1',
      'status':'RESEARCH_ONLY',
      'reference_fraction':A_MP,
      'hydraulic_states_cm':heads,
      'top_ranked_single_events':cells[:12],
      'same_intensity_short_long_pairs':duration_pairs,
      'continuous_vs_fragmented_pairs':fragmentation,
      'recommended_minimal_campaign':{
        'pair_A':'R=4 cm/day, short vs long: weak-source discriminator with low ponding risk',
        'pair_B':'R=8 cm/day, short vs long: crosses into activation regime and gives strong duration signature',
        'pair_C':'R=8 cm/day, one continuous vs two equal separated pulses with same total source duration',
        'optional_anchor':'R=15 cm/day long event as strong-source overlap/upper-regime anchor'
      }
    },indent=2,sort_keys=True))

if __name__=='__main__': main()
