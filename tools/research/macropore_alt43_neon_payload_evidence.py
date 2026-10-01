#!/usr/bin/env python3
"""F-MACRO-ALT43: direct NEON HydroShare PF payload evidence screen.

Reads the HydroShare bag ZIP directly; no extraction or third-party packages required.
Research-only. Does not fit RFM parameters.
"""
from __future__ import annotations
import csv, io, json, math, os, statistics, sys, zipfile
from math import comb

def f(x):
    try:
        y=float(x); return y if math.isfinite(y) else None
    except Exception: return None

def b(x):
    s=str(x).strip().lower()
    if s in ('true','1','yes'): return True
    if s in ('false','0','no'): return False
    return None

def rd(a,b): return abs(a-b)/max(abs(a),abs(b),1e-12)

def event(row):
    ants=[]; flags=[]
    for k,v in row.items():
        if k.startswith('smBeforePrecip_'):
            q=f(v)
            if q is not None: ants.append(q)
        elif k.startswith('PF_velocity_metric_'):
            q=b(v)
            if q is not None: flags.append(q)
    mt=statistics.mean(ants) if ants else None
    cv=statistics.pstdev(ants)/abs(mt) if len(ants)>1 and mt not in (None,0) else None
    peak=f(row.get('stormPeakIntensity')); dur=f(row.get('stormDuration')); total=f(row.get('stormSum'))
    return {
      'id':row.get('stormStartTime'),
      'rate_cm_per_day':peak*14.4 if peak is not None else None,
      'duration_day':dur/24.0 if dur is not None else None,
      'total_input_cm':total/10.0 if total is not None else None,
      'theta':mt,'cv_theta':cv,
      'pf':(row.get('flowTypes')=='nonSequentialFlow') or any(flags),
      'flow_type':row.get('flowTypes')
    }

def compatible(a,bv):
    if a['theta'] is not None and bv['theta'] is not None and abs(a['theta']-bv['theta'])>0.04: return False
    if a['cv_theta'] is not None and bv['cv_theta'] is not None and rd(a['cv_theta'],bv['cv_theta'])>0.5: return False
    return True

def exact_mcnemar(count01,count10):
    n=count01+count10
    if not n: return 1.0
    k=min(count01,count10)
    return min(1.0,2.0*sum(comb(n,i) for i in range(k+1))/(2**n))

def choose_duration_pairs(profiles):
    selected=[]
    for prof,es in profiles.items():
        short=[e for e in es if e['rate_cm_per_day'] is not None and 6<=e['rate_cm_per_day']<=10 and e['duration_day'] is not None and 0.02<=e['duration_day']<=0.10]
        long=[e for e in es if e['rate_cm_per_day'] is not None and 6<=e['rate_cm_per_day']<=10 and e['duration_day'] is not None and 0.25<=e['duration_day']<=1.0]
        cand=[]
        for a in short:
            for c in long:
                if rd(a['rate_cm_per_day'],c['rate_cm_per_day'])>0.20 or not compatible(a,c): continue
                dt=abs(a['theta']-c['theta'])/0.04 if a['theta'] is not None and c['theta'] is not None else 1.0
                dc=rd(a['cv_theta'],c['cv_theta'])/0.5 if a['cv_theta'] is not None and c['cv_theta'] is not None else 1.0
                di=rd(a['rate_cm_per_day'],c['rate_cm_per_day'])/0.20
                ratio=c['duration_day']/a['duration_day']
                cost=2*di+dt+dc-0.1*min(ratio,10.0)
                cand.append((cost,a,c))
        if cand:
            cand.sort(key=lambda x:x[0]); selected.append((prof,cand[0][1],cand[0][2]))
    return selected

def choose_intensity_pairs(profiles):
    selected=[]
    for prof,es in profiles.items():
        weak=[e for e in es if e['rate_cm_per_day'] is not None and 1<=e['rate_cm_per_day']<=5 and e['duration_day'] is not None]
        inter=[e for e in es if e['rate_cm_per_day'] is not None and 7<=e['rate_cm_per_day']<=15 and e['duration_day'] is not None]
        cand=[]
        for a in weak:
            for c in inter:
                if rd(a['duration_day'],c['duration_day'])>0.25 or not compatible(a,c): continue
                dt=abs(a['theta']-c['theta'])/0.04 if a['theta'] is not None and c['theta'] is not None else 1.0
                dc=rd(a['cv_theta'],c['cv_theta'])/0.5 if a['cv_theta'] is not None and c['cv_theta'] is not None else 1.0
                dd=rd(a['duration_day'],c['duration_day'])/0.25
                target=abs(a['rate_cm_per_day']-4)/4 + abs(c['rate_cm_per_day']-8)/8
                cand.append((2*dd+dt+dc+target,a,c))
        if cand:
            cand.sort(key=lambda x:x[0]); selected.append((prof,cand[0][1],cand[0][2]))
    return selected

def summarize_pairs(pairs):
    counts={'00':0,'01':0,'10':0,'11':0}
    for _,a,c in pairs: counts[f"{int(a['pf'])}{int(c['pf'])}"]+=1
    n=len(pairs); first=sum(int(a['pf']) for _,a,_ in pairs); second=sum(int(c['pf']) for _,_,c in pairs)
    return {'n_profiles':n,'counts':counts,'first_pf_fraction':first/n if n else None,'second_pf_fraction':second/n if n else None,'mcnemar_exact_p':exact_mcnemar(counts['01'],counts['10'])}

def main(path):
    profiles={}
    with zipfile.ZipFile(path) as z:
        csvs=[n for n in z.namelist() if '/pf_database_v1.1/' in n and n.endswith('.csv')]
        for name in csvs:
            prof=os.path.basename(name).replace('_beta.csv','')
            with z.open(name) as bf:
                profiles[prof]=[event(row) for row in csv.DictReader(io.TextIOWrapper(bf,'utf-8-sig',newline=''))]
    all_events=[e for es in profiles.values() for e in es]
    duration=choose_duration_pairs(profiles)
    intensity=choose_intensity_pairs(profiles)
    low_short=sum(1 for e in all_events if e['rate_cm_per_day'] is not None and 1<=e['rate_cm_per_day']<=5 and e['duration_day'] is not None and 0.02<=e['duration_day']<=0.10)
    print(json.dumps({
      'schema':'swap5.f_macro_alt43.neon_payload_evidence.v1',
      'profiles':len(profiles),'events':len(all_events),
      'pf_events':sum(int(e['pf']) for e in all_events),
      'weak_1_5_cm_day_short_event_count':low_short,
      'duration_pairs_6_10_cm_day':summarize_pairs(duration),
      'intensity_pairs_weak_to_intermediate':summarize_pairs(intensity),
      'constitutive_parameter_status':'PF payload contains Ksat/texture/porosity but no profile-level van Genuchten alpha/n/theta_r/theta_s required for provider-consistent RFM sigma_B fitting',
    },indent=2,sort_keys=True))

if __name__=='__main__':
    if len(sys.argv)!=2: raise SystemExit('usage: macropore_alt43_neon_payload_evidence.py HYDROSHARE.zip')
    main(sys.argv[1])
