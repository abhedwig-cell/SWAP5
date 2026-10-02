#!/usr/bin/env python3
"""Independent eventwise layer comparison with preregistered budgets."""
from __future__ import annotations
import argparse, collections, hashlib, json
from pathlib import Path

WIDTHS=[0.5,0.5,1.0,1.0]
KEYS=['mode','L','R','m','ns','wet','mean','analytic']

def key(c):return tuple(c[k] for k in KEYS)

def parse(record):
    events={};analytical=None;stop=None;layer={}
    for line in record['stdout'].splitlines():
        x=line.split()
        if not x:continue
        if x[0]=='EVENT':
            v=list(map(float,x[2:-1]))
            assert len(v)==17
            events[int(x[1])]=dict(top=v[0],bottom=v[1],base_storage=v[2],layer_storage=v[3],pond=v[4],
                                  mass=v[5],solver_mass=v[6],interface=v[7],stage=v[8],theta=v[9:13],head=v[13:17])
        elif x[0]=='ANALYTIC':analytical=list(map(float,x[1:]))
        elif x[0]=='LAYER':layer[int(x[1])]=dict(zip(['min_head','max_head','min_K_relative','max_K_relative'],map(float,x[2:])))
        elif x[0]=='STOP':stop=dict(event=int(x[1]),substep=int(x[2]),status=int(x[3]),iterations=int(x[4]),route=x[5])
    return dict(case=record['case'],events=events,layer=layer,complete='COMPLETE' in record['stdout'],stop=stop,analytic=analytical)

def diff(a,b):
    return dict(top=abs(a['top']-b['top']),bottom=abs(a['bottom']-b['bottom']),interface=abs(a['interface']-b['interface']),
                water_l1=sum(w*abs(x-y) for w,x,y in zip(WIDTHS,a['theta'],b['theta'])),
                head_inf=max(abs(x-y) for x,y in zip(a['head'],b['head'])))

def reference_ready(rows,c,event,extended=False):
    axes={};ready=True
    axes_levels=[('ns',[128,256,512]),('m',[8,16,32])] if extended else [('ns',[16,32,64]),('m',[2,4,8])]
    for axis,levels in axes_levels:
        series=[]
        for level in levels:
            k=c.copy();k[axis]=level
            row=rows.get(key(k));series.append(None if row is None else row['events'].get(event))
        if any(x is None for x in series):
            axes[axis]=dict(ready=False,reason='incomplete refinement trajectory');ready=False;continue
        d0=diff(series[0],series[1]);d1=diff(series[1],series[2])
        contracting={k:(d1[k]<=1e-10 or d1[k]<d0[k]) for k in ['top','bottom','water_l1']}
        budget={k:0.001+0.005*abs(series[-1][k]) for k in ['top','bottom']}
        budget.update(water_l1=0.001,head_inf=0.1)
        within={k:d1[k]<=budget[k] for k in budget}
        ok=all(contracting.values()) and all(within.values());ready &= ok
        axes[axis]=dict(ready=ok,coarse_pair=d0,fine_pair=d1,contracting=contracting,within=within,budget=budget)
    return dict(ready=ready,axes=axes)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('build',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--source',required=True);ap.add_argument('--canonical',required=True)
    ap.add_argument('--extension',type=Path)
    args=ap.parse_args()
    raw0=(args.build/'o0/records.json').read_bytes();raw2=(args.build/'o2/records.json').read_bytes()
    assert raw0==raw2,'O0/O2 mismatch'
    allrows=[parse(r) for r in json.loads(raw0)];rows={key(r['case']):r for r in allrows}
    extension_metadata=None
    if args.extension:
        x0=(args.extension/'o0/records.json').read_bytes();x2=(args.extension/'o2/records.json').read_bytes()
        assert x0==x2,'extension O0/O2 mismatch'
        extra=[parse(r) for r in json.loads(x0)]
        rows.update({key(r['case']):r for r in extra})
        extension_metadata=dict(records_per_build=len(extra),raw_O0_sha256=hashlib.sha256(x0).hexdigest(),
                                raw_O2_sha256=hashlib.sha256(x2).hexdigest())
    harmonic=[r for r in allrows if r['case']['analytic'] and r['case']['mean']==6]
    assert len(harmonic)==48 and all(r['complete'] and r['analytic'][1]<=1e-9 and r['analytic'][2]<=1e-10 for r in harmonic)
    comparisons=[]
    for L in [0.02,0.2]:
        for R in [0.05,0.5,1.0]:
            for wet in [0,1]:
                use_extended=bool(args.extension) and R>=0.5
                a=dict(mode=1,L=L,R=R,m=32 if use_extended else 8,ns=512 if use_extended else 64,wet=wet,mean=6,analytic=0)
                b=dict(a,mode=2,wet=0)
                for event in [1,2,3,4,5,6]:
                    ar=reference_ready(rows,a,event,use_extended);br=reference_ready(rows,b,event,use_extended)
                    aa=rows[key(a)]['events'].get(event);bb=rows[key(b)]['events'].get(event)
                    item=dict(L_cm=L,R_day=R,layer_prewetted=bool(wet),event=event,
                              explicit_reference=ar,reduced_reference=br,physical_equivalence=None)
                    item['explicit_layer']=rows[key(a)]['layer'].get(event)
                    if aa is not None and bb is not None:
                        d=diff(aa,bb);budget={k:0.005+0.02*abs(aa[k]) for k in ['top','bottom','interface']}
                        budget.update(water_l1=0.005,head_inf=0.5)
                        within={k:d[k]<=budget[k] for k in budget}
                        item.update(difference=d,budget=budget,within=within,explicit=aa,reduced=bb)
                        if ar['ready'] and br['ready']:item['physical_equivalence']=all(within.values())
                    comparisons.append(item)
    counts=collections.Counter((r['case']['mode'],r['case']['wet'],r['complete']) for r in allrows if not r['case']['analytic'])
    arithmetic=[r for r in allrows if r['case']['analytic'] and r['case']['mean']==1]
    verdicts=collections.Counter(str(c['physical_equivalence']) for c in comparisons)
    result=dict(schema='swap5.sw_rib_top03.explicit_layer.v1',date='2026-10-02',
        source_postimage=args.source,canonical_inspected=args.canonical,production_code_changed=False,production_admission=False,
        O0_O2_exact_output=True,records_per_build=len(allrows),raw_O0_sha256=hashlib.sha256(raw0).hexdigest(),
        extension=extension_metadata,unique_cases=len(rows),
        raw_O2_sha256=hashlib.sha256(raw2).hexdigest(),analytical_harmonic_controls=len(harmonic),
        analytical_max_head_error_cm=max(r['analytic'][1] for r in harmonic),
        analytical_max_flux_error_cm_day=max(r['analytic'][2] for r in harmonic),
        arithmetic_max_flux_error_cm_day=max(r['analytic'][2] for r in arithmetic),
        max_independent_mass_error_cm=max(abs(e['mass']) for r in allrows for e in r['events'].values()),
        max_solver_mass_error_cm=max(abs(e['solver_mass']) for r in allrows for e in r['events'].values()),
        trajectory_counts=[dict(mode=k[0],wet=k[1],complete=k[2],count=v) for k,v in sorted(counts.items())],
        verdict_counts=dict(verdicts),comparisons=comparisons,
        stopped_cases=[dict(case=r['case'],stop=r['stop']) for r in allrows if r['stop']],
        evidence_scope='Real Richards, synthetic retention/layers and original free-drainage dry soil; analytical controls separately use mode5. No BASE acceptance/receipt/commit qualification.')
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['comparisons','stopped_cases']},indent=2))
    for c in comparisons:
        if c['event'] in [1,6]:
            print(json.dumps({k:c.get(k) for k in ['L_cm','R_day','layer_prewetted','event','physical_equivalence','difference','within']}))

if __name__=='__main__':main()
