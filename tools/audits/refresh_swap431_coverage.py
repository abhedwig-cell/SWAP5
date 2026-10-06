#!/usr/bin/env python3
"""Refresh derived counts, dependency depths, queue and Markdown; never infer dispositions."""
import json,collections
from pathlib import Path
R=Path(__file__).resolve().parents[2];A=R/'integration/audits';P=A/'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json';l=json.loads(P.read_text())
E={e['capability_id']:e for e in l['capabilities']}
active=[e for e in l['capabilities'] if e['current_disposition']=='ACTIVE_MIGRATION']
depths={}
def depth(cid, trail=frozenset()):
 assert cid not in trail, 'dependency cycle'
 if cid not in depths:
  assert all(E[d]['current_disposition']=='ACTIVE_MIGRATION' for d in E[cid]['remaining_dependency']), 'closed/dangling blocker'
  depths[cid]=max((depth(d,trail|{cid})+1 for d in E[cid]['remaining_dependency']),default=0)
 return depths[cid]
for e in l['capabilities']:e['migration_priority']['dependency_depth']=depth(e['capability_id'])
l['remaining_queue']=[{'capability_id':e['capability_id'],'work_unit':e['active_workunit'],'dependencies':e['remaining_dependency'],'why_open':e['production_reachability']['claim'],'priority':e['migration_priority'],'implementation_absence_proven':e.get('implementation_absence_proven',False)} for e in active]
l['remaining_queue'].sort(key=lambda q:tuple(q['priority'][k] for k in ['dependency_depth','functional_relevance','implementation_extent','physical_risk','regression_risk'])+(q['capability_id'],))
s=l['summary'];s.update(capabilities=len(l['capabilities']),dispositions=dict(collections.Counter(e['current_disposition'] for e in l['capabilities'])),open_capabilities=len(active),open_workunits=len({e['active_workunit'] for e in active}),confirmed_missing_production_entries=sum(e.get('implementation_absence_proven',False) for e in active))
s['other_unresolved_source_admission_reviews']=len(active)-s['confirmed_missing_production_entries']
wP=A/'SWAP431_REMAINING_WORKUNITS.json';w=json.loads(wP.read_text())
for u in w['new_workunits']:
 caps=set(u['capabilities']);assert all(E[c]['current_disposition']=='ACTIVE_MIGRATION' for c in caps), 'closed capability in open workunit'
 deps={d for cid in caps for d in E[cid]['remaining_dependency']};u['dependencies']=sorted(deps-caps);u['internal_sequence_dependencies']=sorted(deps&caps);u['closed_foundation_authorities']=sorted({d for cid in caps for d in E[cid].get('closed_foundation_authorities',[])})
P.write_text(json.dumps(l,indent=2)+'\n');wP.write_text(json.dumps(w,indent=2)+'\n')
groups=collections.defaultdict(list)
for q in l['remaining_queue']:groups[q['work_unit']].append(q)
text=['# SWAP431 functional coverage master: recoverable review','',f"Baseline: `{l['canonical_head']}`. Status: IN_PROGRESS. **Coverage is not closed; the denominator is not yet declared exhaustive.**",'',f"The ledger currently contains {l['summary']['capabilities']} entries: {l['summary']['dispositions']['ADMITTED']} bounded ADMITTED, {l['summary']['dispositions']['SUPERSEDED']} SUPERSEDED, {l['summary']['dispositions'].get('REJECTED',0)} REJECTED, {l['summary']['dispositions']['NOT_APPLICABLE']} NOT_APPLICABLE and {l['summary']['open_capabilities']} ACTIVE_MIGRATION entries across {l['summary']['open_workunits']} review/migration workunits.",'',f"Only {l['summary']['confirmed_missing_production_entries']} entries are currently marked as proven missing production implementation/binding. The other {l['summary']['other_unresolved_source_admission_reviews']} are unresolved source/admission/replacement reviews. Neither number is a final exhaustive missing-functionality count. Review registration is not implementation or admission.",'','Admitted SWAP5 replacement foundations are listed separately and do not count as proof of literal B1.11 branch coverage.','', 'The machine authority is `integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json`.','The exact source bundle and input-reader census are in `integration/audits/evidence/`.','The source findings and exclusion reasoning are in `SWAP431_SOURCE_REVIEW.md`.','', '## Confirmed production gaps traced so far','', '| Capability | Meaning | Workunit | Dependencies |','|---|---|---|---|']
E={e['capability_id']:e for e in l['capabilities']}
for q in l['remaining_queue']:
 if q['implementation_absence_proven']:
  e=E[q['capability_id']];text.append(f"| {e['capability_id']} | {e['meaning']} | {q['work_unit']} | {', '.join(q['dependencies']) or 'None'} |")
text+=['','## Registered review queue','', 'These are individual capability decisions, not admitted implementation plans. Dependency depth orders prerequisites first; independent qualification reviews can reduce the queue before new physics work.','', '| Workunit | Open entries | Next action |','|---|---:|---|']
for u,qs in sorted(groups.items(),key=lambda pair:(min(q['priority']['dependency_depth'] for q in pair[1]),pair[0])):text.append(f'| {u} | {len(qs)} | Source/admission adjudication for the exact IDs below |')
for u,qs in sorted(groups.items()):
 text+=['',f'### {u}','', '| Capability | Meaning | Why unresolved | Dependencies |','|---|---|---|---|']
 for q in qs:
  e=E[q['capability_id']];text.append(f"| {e['capability_id']} | {e['meaning']} | {q['why_open']} | {', '.join(q['dependencies']) or 'None'} |")
text+=['','## Closure gate','','Run `python tools/audits/check_swap431_coverage.py` for structural/source integrity.','Run `python tools/audits/check_swap431_coverage.py --require-closed` for a closure assertion.','The latter intentionally fails while the source denominator is incomplete or any ACTIVE_MIGRATION remains.','Neither command scientifically qualifies a process. Owning source/runtime gates and canonical admission remain required.','', 'No final global rejection has been invented to shrink the queue. No historical research PR is a blocker merely because it is open. The complete paginated snapshot records 114 open PRs and 55 merges since 2026-10-05; migration proposal reconciliation is explicit. The earlier 100-item snapshot is retained as historical evidence.']
text[-1] = text[-1].replace('The complete paginated snapshot records', 'The historical complete paginated snapshot records')
text += ['', '## Latest resolved-input and owner review', '',
         'SWRAIN2 WET duration and SWRAIN3 interval amounts are SUPERSEDED as input representations by admitted immutable precipitation spans. No legacy parser or new snow/interception composition is claimed.', '',
         'Macropore static geometry and SWPOWM, the B1.11 N-demand policy, companion potential RELMF, primary/secondary routing and the common-secondary-store multilevel limiter now have explicit MIGRATE decisions and bounded contracts.', '',
         'Details: [resolved input and owner review](SWAP431_RESOLVED_INPUT_AND_OWNER_REVIEW.md). The literal rain mapping and N-demand discrimination probes passed O0/O2. Production source remains unchanged.', '',
         '## Surface, crop and solute follow-up', '',
         'Eight further owner reviews now have concrete MIGRATE contracts: pond-derived macro input, runon composition, time-varying rapid-drain basis, fixed sprinkler and scheduled surface routing, consistent CO2 response, crop rotation and the ordinary infiltration cap.', '',
         'The four existing-code entries have explicit source/runtime qualification gates: Ernst, Youngs, classic annual crop and IDSL1. No absent-evaluator claim is made for those entries.', '',
         'The literal SWBR aquifer block fails bounds checks at numnod+1 in all eight O0/O2 probes. Its intended physical capability remains open with a reference-correction prerequisite. Soil phase-change absence is distinguished from the admitted snow liquid-retention and melting terms.', '',
         'Details: [surface and crop owner review](SWAP431_SURFACE_AND_CROP_OWNER_REVIEW.md).']
(A/'SWAP431_FUNCTIONAL_COVERAGE_MASTER.md').write_text('\n'.join(text)+'\n')
