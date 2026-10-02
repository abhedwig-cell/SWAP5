#!/usr/bin/env python3
"""Fixed-budget algebraic-layer factorial, with independent reference readiness."""
from __future__ import annotations
import argparse, collections, hashlib, json
from pathlib import Path
from analyze_sw_rib_top03_explicit_layer import parse, key, diff, reference_ready


def analyze(build, source, canonical, previous, primary, audited):
    raw=(build/'o0/records.json').read_bytes()
    assert raw==(build/'o2/records.json').read_bytes(), 'O0/O2 mismatch'
    records=json.loads(raw); rows={key(r['case']):parse(r) for r in records}
    old={key(r['case']):r for r in json.loads((previous/'o0/records.json').read_bytes())}
    def strip(record, prefixes):
        return dict(record,stdout='\n'.join(x for x in record['stdout'].splitlines() if not any(x.startswith(p) for p in prefixes))+'\n')
    for earlier,prefixes in [(primary,['AUDIT','FROZEN_AUDIT']),(audited,['FROZEN_AUDIT'])]:
        for opt in [0,2]:
            prior=json.loads((earlier/f'o{opt}/records.json').read_bytes())
            current=json.loads((build/f'o{opt}/records.json').read_bytes())
            assert len(prior)==len(current)
            assert [strip(r,prefixes) for r in current]==prior,'diagnostic instrumentation changed trajectories'
    inherited=[];audits=[]
    for r in records:
        for line in r['stdout'].splitlines():
            x=line.split()
            if x and x[0] in ['AUDIT','FROZEN_AUDIT']:
                audits.append(dict(kind=x[0],case=r['case'],event=int(x[1]),local_integrated_residual_cm=float(x[2]),
                                   local_rate_residual_cm_day=float(x[3]),interface_input_cm=float(x[4]),
                                   interface_ledger_error_cm=float(x[5])))
    for r in records:
        if r['case']['analytic'] or r['case']['mode'] not in [1,2]:continue
        assert key(r['case']) in old
        clean=strip(r,['AUDIT','FROZEN_AUDIT'])
        assert clean==old[key(r['case'])], ('inherited trajectory changed',r['case'])
        inherited.append(r['case'])
    controls=[r for r in rows.values() if r['case']['analytic']]
    assert len(controls)==30
    assert all(r['complete'] and r['analytic'][1]<=1e-9 and r['analytic'][2]<=1e-10 for r in controls)
    current_audits=[a for a in audits if a['kind']=='AUDIT']
    frozen_audits=[a for a in audits if a['kind']=='FROZEN_AUDIT']
    audit_map={(key(a['case']),a['event']):a for a in current_audits}
    diagnostics=[]
    for R in [0.5,1.0]:
        for wet in [0,1]:
            for a,b,question in [(1,3,'stationary_closure_equivalence'),(1,5,'conductivity_with_storage'),
                                 (3,4,'conductivity_without_storage'),(4,2,'matched_face_vs_old_contact'),
                                 (1,2,'previous_constant_R')]:
                ca=dict(mode=a,L=0.2,R=R,m=32,ns=512,wet=wet,mean=6,analytic=0)
                cb=dict(ca,mode=b,wet=0 if b==2 else wet)
                for event in range(1,7):
                    ar=reference_ready(rows,ca,event,True);br=reference_ready(rows,cb,event,True)
                    aa=rows[key(ca)]['events'].get(event);bb=rows[key(cb)]['events'].get(event)
                    item=dict(R_day=R,prewetted=bool(wet),event=event,question=question,
                              reference_mode=a,comparison_mode=b,reference_ready=ar,comparison_ready=br,
                              within_fixed_physical_budgets=None)
                    if aa is not None and bb is not None:
                        d=diff(aa,bb);budget={k:0.005+0.02*abs(aa[k]) for k in ['top','bottom','interface']}
                        budget.update(water_l1=0.005,head_inf=0.5)
                        within={k:d[k]<=budget[k] for k in budget}
                        item.update(reference=aa,comparison=bb,difference=d,budget=budget,within=within,
                                    signed_shift={k:bb[k]-aa[k] for k in ['top','bottom','interface','layer_storage']})
                        provisional=all(within.values()) if ar['ready'] and br['ready'] else None
                        item['provisional_pre_audit_budget_verdict']=provisional
                        audit_results=[audit_map.get((key(c),event)) for c in [ca,cb] if c['mode']!=2]
                        current_ready=all(x is not None and x['local_integrated_residual_cm']<=1e-10 and
                                          abs(x['interface_ledger_error_cm'])<=1e-10 for x in audit_results)
                        item['current_head_contact_prerequisite_ready']=current_ready
                        if current_ready:item['within_fixed_physical_budgets']=provisional
                        else:item['classification_blocker']='Current-head stationary face/ledger audit failed; source SWKIMPL=0 freezes interior K.'
                    diagnostics.append(item)
    assert frozen_audits and max(a['local_integrated_residual_cm'] for a in frozen_audits)<=1e-10, 'origin-K local layer mass gate'
    assert max(abs(a['interface_ledger_error_cm']) for a in frozen_audits)<=1e-10, 'origin-K interface ledger gate'
    massless=[r for r in rows.values() if r['case']['mode'] in [3,4]]
    assert all(e['layer_storage']==0 for r in massless for e in r['events'].values())
    summaries={q:dict(collections.Counter(str(d['within_fixed_physical_budgets']) for d in diagnostics if d['question']==q))
               for q in sorted({d['question'] for d in diagnostics})}
    return dict(schema='swap5.sw_rib_top03.stationary_layer.v1',date='2026-10-02',
                status='STATIONARY_CONTACT_ORACLE_BLOCKED_BY_ORIGIN_FROZEN_INTERIOR_K__NO_PRODUCTION_ADMISSION',
                source_postimage=source,canonical_inspected=canonical,production_code_changed=False,production_admission=False,
                records_per_build=len(records),O0_O2_exact_output=True,raw_sha256=hashlib.sha256(raw).hexdigest(),
                inherited_trajectories_exact=len(inherited),analytical_controls=len(controls),
                diagnostic_only_replay_preserved=True,
                independent_face_audit={kind:dict(max_local_integrated_residual_cm=max(a['local_integrated_residual_cm'] for a in group),
                   max_local_rate_residual_cm_day=max(a['local_rate_residual_cm_day'] for a in group),
                   max_interface_ledger_error_cm=max(abs(a['interface_ledger_error_cm']) for a in group),
                   passed=max(a['local_integrated_residual_cm'] for a in group)<=1e-10 and
                          max(abs(a['interface_ledger_error_cm']) for a in group)<=1e-10)
                   for kind,group in [('candidate_K',current_audits),('origin_K_source_scheme',frozen_audits)]},
                analytical_max_head_error_cm=max(r['analytic'][1] for r in controls),
                analytical_max_flux_error_cm_day=max(r['analytic'][2] for r in controls),
                max_mass_error_cm=max(abs(e[k]) for r in rows.values() for e in r['events'].values() for k in ['mass','solver_mass']),
                trajectory_counts=[dict(mode=k[0],wet=k[1],complete=k[2],count=v) for k,v in sorted(collections.Counter(
                    (r['case']['mode'],r['case']['wet'],r['complete']) for r in rows.values() if not r['case']['analytic']).items())],
                verdict_counts=summaries,
                provisional_pre_audit_counts={q:dict(collections.Counter(str(d.get('provisional_pre_audit_budget_verdict')) for d in diagnostics if d['question']==q)) for q in summaries},
                comparisons=diagnostics,
                layer_diagnostics=[dict(case=r['case'],layer=r['layer']) for r in rows.values() if not r['case']['analytic']],
                stopped_cases=[dict(case=r['case'],stop=r['stop']) for r in rows.values() if r['stop']],
                scope='Discrete stationary-layer oracle retains algebraic layer heads; no boundary-only elimination, no physical zero-storage material or production transaction qualification.')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('build',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--source',required=True);ap.add_argument('--canonical',required=True);ap.add_argument('--previous',type=Path,required=True)
    ap.add_argument('--primary',type=Path,required=True);ap.add_argument('--audit',type=Path,required=True)
    a=ap.parse_args();r=analyze(a.build,a.source,a.canonical,a.previous,a.primary,a.audit)
    a.output.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k not in ['comparisons','stopped_cases','layer_diagnostics']},indent=2))
    for d in r['comparisons']:
        if d['event']==6:print(json.dumps({k:d.get(k) for k in ['R_day','prewetted','question','within_fixed_physical_budgets','difference','signed_shift']}))

if __name__=='__main__':main()
