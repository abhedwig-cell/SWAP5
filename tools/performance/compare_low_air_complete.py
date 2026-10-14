#!/usr/bin/env python3
"""Actual full-scope CPU A/B and cold candidate; interrupted wall stays UNKNOWN."""
import argparse, json, math, pathlib
from verify_low_air_complete import verify_complete

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--baseline',required=True,type=pathlib.Path)
    p.add_argument('--candidate',required=True,type=pathlib.Path)
    p.add_argument('--cold-candidate',required=True,type=pathlib.Path)
    p.add_argument('--output',required=True,type=pathlib.Path)
    a=p.parse_args()
    receipts={n:verify_complete(f,check_binaries=True) for n,f in [('baseline',a.baseline),('candidate',a.candidate),('cold_candidate',a.cold_candidate/'matrix')]}
    raw={n:json.loads((f/'RESULTS.json').read_text()) for n,f in [('baseline',a.baseline),('candidate',a.candidate),('cold_candidate',a.cold_candidate/'matrix')]}
    if raw['baseline']['policy']!='baseline' or any(raw[n]['policy']!='candidate' for n in ['candidate','cold_candidate']):raise ValueError('foreign A/B policy')
    if len({r['source_tree'] for r in raw.values()})!=1:raise ValueError('different functional production code')
    for opt in ['0','2']:
        for field in ['compiler','flags','extra_inputs']:
            if len({json.dumps(r['builds'][opt][field],sort_keys=True) for r in raw.values()})!=1:raise ValueError('compiler/flag/physical fixture drift')
    for run in raw['candidate']['runs']:
        stem=f"o{run['optimization']}-{run['program']}-family-{run['family']}.stdout"
        if (a.candidate/stem).read_bytes()!=(a.cold_candidate/'matrix'/stem).read_bytes():raise ValueError('repeat warm/cold science drift '+stem)
    cold=json.loads((a.cold_candidate/'RESULTS.json').read_text())
    if cold['scope']!='COMPLETE_ORIGINAL_48_LOW_AIR_COLD_PROVIDERS' or len(cold['events'])!=4 or any(e['exit'] for e in cold['events']):raise ValueError('incomplete cold phases')
    if [e['label'] for e in cold['events']]!=['providers-o0','providers-o2','full-matrix','full-verification']:raise ValueError('changed cold ordering')
    if not math.isfinite(cold['whole_wall']) or cold['whole_wall']<=sum(e['wall'] for e in cold['events'])-.01:raise ValueError('invalid cold enclosing timing')
    result={'scope':'FULL_ORIGINAL_48_LOW_AIR_288_FINE_COMPARISONS',
            'receipts':receipts,'cold_candidate':cold,
            'baseline_enclosing_total_cpu':'UNKNOWN_ORIGINAL_PARENT_INTERRUPTED',
            'baseline_parent_cpu_scope':'RECOVERY_SEGMENT_ONLY',
            'matched_native_cpu_speedup':raw['baseline']['native_cpu']/raw['candidate']['native_cpu'],
            'matched_enclosing_wall_speedup':'UNKNOWN_INTERRUPTED_BASELINE' if raw['baseline'].get('interrupted_wall') else raw['baseline']['whole_wall']/raw['candidate']['whole_wall'],
            'cold_candidate_absolute_target_seconds':1067.873,'cold_candidate_within_absolute_target':cold['whole_wall']<=1067.873,
            'historical_10678_seconds_hardware_comparability':'UNKNOWN',
            'candidate_repeat_science':'EXACT_48_PROGRAMS_WARM_COLD_O0_O2',
            'tenfold_full_wall_proved':False,'canonical_admission':False,
            'limits':['Original baseline interrupted after 20 completed children; full wall not reconstructed or inferred from CPU.',
                      'One full native CPU pair and two complete candidate matrices; earlier highest alternating repeats retain order/load sensitivity.',
                      'Cold candidate alone is not cold A/B. No multiplication of scoped speedups.']}
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['receipts','cold_candidate']},indent=2))
if __name__=='__main__':main()
