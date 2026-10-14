#!/usr/bin/env python3
"""Require complete alternating scientific sample set before summarizing."""
import argparse,json,statistics
from pathlib import Path

def summarize(report):
    if 'baseline' in report:
        return summarize_adoption(report)
    rows=report['records']
    if report.get('status')!='PASS':raise ValueError('nonterminal benchmark')
    if len(rows)!=54:raise ValueError('expected three complete rounds / three cases / O0,O2 / original,cold,warm')
    result={}
    for case in ['mvg','boesten','accepted_heat']:
        selected=[r for r in rows if r['case']==case]
        if len({r['stdout_sha256'] for r in selected})!=1:raise ValueError('scientific/O0/O2 identity drift '+case)
        statistics_by_route={}
        for route,build in [('original_process_leg','cold'),('focused','cold'),('focused','warm_same_transaction')]:
            subset=[r for r in selected if r['route']==route and r['build']==build]
            samples=[]
            for round_index in range(3):
                pair=[r for r in subset if r['round']==round_index]
                if len(pair)!=2 or {r['optimization'] for r in pair}!={0,2}:raise ValueError('incomplete sample '+case)
                samples.append({key:sum(r[key] for r in pair) for key in ['compile_seconds','link_seconds','execution_seconds','total_seconds','validation_seconds','compiler_requests','reused_compilations']})
            statistics_by_route[route+'/'+build]={'samples':samples,'medians':{key:statistics.median(s[key] for s in samples) for key in samples[0]}}
        result[case]={'science_sha256':selected[0]['stdout_sha256'],'routes':statistics_by_route,
                      'executable_identity_per_optimization':{str(opt):len({r['executable_sha256'] for r in selected if r['optimization']==opt})==1 for opt in [0,2]}}
    return {'head':report['head'],'status':'COMPLETE_LOCAL_PROCESS_COMPARISON','cases':result,
            'claim_ceiling':'Three process/state-driver legs on one shared host; not equal full qualification suites or a portable speed guarantee.'}

def summarize_adoption(report):
    rows=report['records']
    if report.get('status')!='PASS':raise ValueError('nonterminal adoption benchmark')
    cases=['boesten','root_oxygen','root_contract','drainage','assimilation']
    rounds=sorted({r['round'] for r in rows})
    if len(rounds)<3 or rounds!=list(range(len(rounds))):raise ValueError('incomplete alternating rounds')
    if len(rows)!=len(rounds)*len(cases)*6:raise ValueError('incomplete adoption sample count')
    policies=[('independent','cold'),('shared','cold'),('shared','warm_same_transaction')]
    keys=['compile_seconds','link_seconds','execution_seconds','validation_seconds',
          'scientific_validation_seconds','total_seconds','compiler_requests','reused_compilations']
    result={'head':report['head'],'status':'COMPLETE_LOCAL_ADOPTION_COMPARISON',
            'baseline':report['baseline'],'candidate':report['candidate'],'rounds':len(rounds),'policies':{},'cases':{},
            'claim_ceiling':'Same five direct drivers on one host. Native includes driver assertions/IO; physics-only, portable and full-preservation speedup UNKNOWN.'}
    for case in cases:
        selected=[r for r in rows if r['case']==case]
        if len({r['stdout_sha256'] for r in selected})!=1:raise ValueError('science/O0/O2 identity drift '+case)
        identity={str(opt):len({r['executable_sha256'] for r in selected if r['optimization']==opt})==1 for opt in [0,2]}
        if not all(identity.values()):raise ValueError('executable identity drift '+case)
        result['cases'][case]={'providers':len(selected[0]['sources'])-1,'science_sha256':selected[0]['stdout_sha256'],
                              'executable_identity_per_optimization':identity,'pair_median_by_policy':{}}
        for policy,build in policies:
            samples=[]
            for index in rounds:
                pair=[r for r in selected if (r['policy'],r['build'],r['round'])==(policy,build,index)]
                if len(pair)!=2 or {r['optimization'] for r in pair}!={0,2}:raise ValueError('incomplete O0/O2 pair '+case)
                samples.append(sum(r['total_seconds'] for r in pair))
            result['cases'][case]['pair_median_by_policy'][policy+'/'+build]=statistics.median(samples)
    for policy,build in policies:
        samples=[]
        for index in rounds:
            selected=[r for r in rows if (r['policy'],r['build'],r['round'])==(policy,build,index)]
            samples.append({key:sum(r[key] for r in selected) for key in keys})
        result['policies'][policy+'/'+build]={'samples':samples,'medians':{key:statistics.median(s[key] for s in samples) for key in keys}}
    return result

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('report');ap.add_argument('output');args=ap.parse_args()
    result=summarize(json.loads(Path(args.report).read_text()));Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('COMPLETE_MODULAR_SAMPLE_SET=PASS')
