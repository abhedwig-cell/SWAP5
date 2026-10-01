#!/usr/bin/env python3
"""F-MACRO-ALT42: automatic paired-event selector for frozen RFM-RC1 tests.

Input: JSON containing either:
- {'events': [...]} from ALT16/normalized NEON-like preprocessing; or
- a bare list of normalized event records.

Required normalized fields where available:
  profile_id
  event_id
  source_rate_cm_per_day
  duration_day
  total_input_cm
  mean_antecedent_theta
  cv_antecedent_theta
  ponded
  fragmented_group
  pf_observed

Missing optional fields reduce score or make a pair ineligible; they are never invented.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def finite(v):
    try:
        x=float(v)
        return x if math.isfinite(x) else None
    except Exception:
        return None


def normalize_event(e, idx):
    peak_mmh = finite(e.get('storm_peak_mm_per_h'))
    duration_h = finite(e.get('storm_duration_h'))
    total_mm = finite(e.get('storm_sum_mm'))

    source_cm_day = finite(e.get('source_rate_cm_per_day'))
    if source_cm_day is None and peak_mmh is not None:
        source_cm_day = peak_mmh * 2.4

    duration_day = finite(e.get('duration_day'))
    if duration_day is None and duration_h is not None:
        duration_day = duration_h / 24.0

    total_cm = finite(e.get('total_input_cm'))
    if total_cm is None and total_mm is not None:
        total_cm = total_mm / 10.0

    profile_id = (
        e.get('profile_id') or e.get('site_id') or e.get('site') or
        e.get('source_file') or 'unknown-profile'
    )
    event_id = e.get('event_id') or e.get('storm_start') or f'event-{idx:06d}'

    pf_obs = e.get('pf_observed')
    if pf_obs is None:
        nsr=e.get('nsr_pf'); vt=e.get('vt_pf_any_sensor')
        if nsr is not None or vt is not None:
            pf_obs = bool(nsr) or bool(vt)

    return {
        'profile_id': str(profile_id),
        'event_id': str(event_id),
        'source_rate_cm_per_day': source_cm_day,
        'duration_day': duration_day,
        'total_input_cm': total_cm,
        'mean_antecedent_theta': finite(e.get('mean_antecedent_theta')),
        'cv_antecedent_theta': finite(e.get('cv_antecedent_theta') or e.get('cv_antecedent_theta_across_sensors')),
        'ponded': e.get('ponded'),
        'fragmented_group': e.get('fragmented_group'),
        'pf_observed': pf_obs,
        'raw': e,
    }


def rel_diff(a,b):
    if a is None or b is None: return None
    scale=max(abs(a),abs(b),1.0e-12)
    return abs(a-b)/scale


def close_optional(a,b,abs_tol=None,rel_tol=None):
    if a is None or b is None:
        return True, 0.0, False
    if abs_tol is not None:
        d=abs(a-b)
        return d<=abs_tol, d/abs_tol if abs_tol>0 else d, True
    d=rel_diff(a,b)
    return d<=rel_tol, d/rel_tol if rel_tol and rel_tol>0 else d, True


def same_profile(a,b):
    return a['profile_id']==b['profile_id']


def antecedent_compatibility(a,b,args):
    ok_t,pen_t,used_t=close_optional(a['mean_antecedent_theta'],b['mean_antecedent_theta'],abs_tol=args.theta_abs_tol)
    ok_cv,pen_cv,used_cv=close_optional(a['cv_antecedent_theta'],b['cv_antecedent_theta'],rel_tol=args.cv_rel_tol)
    return ok_t and ok_cv, pen_t+pen_cv, used_t or used_cv


def ponding_compatible(a,b):
    pa,pb=a['ponded'],b['ponded']
    if pa is None or pb is None:
        return True, False
    return bool(pa)==bool(pb), True


def pair_score(a,b,kind,args):
    if not same_profile(a,b): return None
    if a['source_rate_cm_per_day'] is None or b['source_rate_cm_per_day'] is None: return None
    if a['duration_day'] is None or b['duration_day'] is None: return None

    ant_ok,ant_pen,ant_used=antecedent_compatibility(a,b,args)
    if not ant_ok: return None
    pond_ok,pond_used=ponding_compatible(a,b)
    if not pond_ok: return None

    r1,r2=a['source_rate_cm_per_day'],b['source_rate_cm_per_day']
    d1,d2=a['duration_day'],b['duration_day']
    intensity_rel=rel_diff(r1,r2)

    score=0.0
    notes=[]
    if kind=='short_long':
        if intensity_rel is None or intensity_rel>args.intensity_rel_tol: return None
        ratio=max(d1,d2)/max(min(d1,d2),1.0e-12)
        if ratio<args.duration_ratio_min: return None
        score=3.0*min(ratio/args.duration_ratio_min,3.0) - ant_pen
        notes.append(f'duration_ratio={ratio:.3g}')
    elif kind=='weak_intermediate':
        if not (min(r1,r2)<=args.weak_max and max(r1,r2)>=args.intermediate_min): return None
        dur_rel=rel_diff(d1,d2)
        if dur_rel is not None and dur_rel>args.duration_rel_tol: return None
        sep=max(r1,r2)/max(min(r1,r2),1.0e-12)
        score=2.5*min(sep,4.0)-ant_pen
        notes.append(f'intensity_ratio={sep:.3g}')
    elif kind=='continuous_fragmented':
        ga,gb=a['fragmented_group'],b['fragmented_group']
        if ga is None or gb is None or ga!=gb: return None
        if intensity_rel is None or intensity_rel>args.intensity_rel_tol: return None
        total_rel=rel_diff(a['total_input_cm'],b['total_input_cm'])
        if total_rel is not None and total_rel>args.total_rel_tol: return None
        score=9.0-ant_pen
        notes.append(f'fragmented_group={ga}')
    else:
        raise ValueError(kind)

    if ant_used: score += 1.0
    if pond_used: score += 0.5
    if a['pf_observed'] is not None and b['pf_observed'] is not None: score += 1.0
    return {
        'kind':kind,
        'profile_id':a['profile_id'],
        'event_a':a['event_id'],
        'event_b':b['event_id'],
        'score':score,
        'source_rates_cm_per_day':[r1,r2],
        'durations_day':[d1,d2],
        'antecedent_theta':[a['mean_antecedent_theta'],b['mean_antecedent_theta']],
        'antecedent_cv':[a['cv_antecedent_theta'],b['cv_antecedent_theta']],
        'ponded':[a['ponded'],b['ponded']],
        'pf_observed':[a['pf_observed'],b['pf_observed']],
        'notes':notes,
    }


def select_pairs(events,args):
    out={'short_long':[],'weak_intermediate':[],'continuous_fragmented':[]}
    n=len(events)
    for i in range(n):
        for j in range(i+1,n):
            for kind in out:
                p=pair_score(events[i],events[j],kind,args)
                if p is not None: out[kind].append(p)
    for kind in out:
        out[kind].sort(key=lambda x:x['score'], reverse=True)
        out[kind]=out[kind][:args.top_k]
    return out


def campaign_candidates(pairs):
    # Return a compact priority view without pretending pairs are independent.
    return {
        'pair_A_weak_short_long': pairs['short_long'][:3],
        'pair_B_weak_to_intermediate': pairs['weak_intermediate'][:3],
        'pair_C_continuous_fragmented': pairs['continuous_fragmented'][:3],
    }


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input_json')
    ap.add_argument('--top-k',type=int,default=20)
    ap.add_argument('--intensity-rel-tol',type=float,default=0.20)
    ap.add_argument('--duration-rel-tol',type=float,default=0.25)
    ap.add_argument('--duration-ratio-min',type=float,default=3.0)
    ap.add_argument('--theta-abs-tol',type=float,default=0.04)
    ap.add_argument('--cv-rel-tol',type=float,default=0.50)
    ap.add_argument('--total-rel-tol',type=float,default=0.20)
    ap.add_argument('--weak-max',type=float,default=5.0)
    ap.add_argument('--intermediate-min',type=float,default=7.0)
    args=ap.parse_args()

    payload=json.loads(Path(args.input_json).read_text(encoding='utf-8'))
    raw=payload.get('events',payload) if isinstance(payload,dict) else payload
    if not isinstance(raw,list): raise SystemExit('input must be a list or object with events list')
    events=[normalize_event(e,i) for i,e in enumerate(raw)]
    usable=[e for e in events if e['source_rate_cm_per_day'] is not None and e['duration_day'] is not None]
    pairs=select_pairs(usable,args)
    print(json.dumps({
        'schema':'swap5.f_macro_alt42.paired_event_selector.v1',
        'status':'RESEARCH_ONLY',
        'n_input_events':len(events),
        'n_usable_events':len(usable),
        'selection_parameters':vars(args),
        'pairs':pairs,
        'campaign_candidates':campaign_candidates(pairs),
        'notes':[
            'No missing antecedent or ponding values are invented.',
            'Missing compatibility fields reduce evidential strength but do not silently create matches.',
            'Selection is profile-local and does not tune any RFM parameter.',
        ],
    },indent=2,sort_keys=True))


if __name__=='__main__': main()
