"""Fresh complete bounded calendar cohort from original independent platform bytes."""
import argparse,json,subprocess
from pathlib import Path
from frost_calendar_state_archive_science import audit as ubuntu
from frost_calendar_state_windows_ci_science import audit as windows_ci
from frost_calendar_state_windows_local_science import audit as windows_local

ROOT=Path(__file__).resolve().parents[2]
PHYSICAL='a6823044669a113bfb3b5329c36377ed5941155b'


def audit(proof):
    rows=[]
    for opt in ('O0','O2'):
        q=ubuntu(proof,opt)
        for item in q['contexts']:rows.append(dict(platform='Ubuntu',optimization=opt,**item))
        q=windows_ci(proof,opt)
        for item in q['contexts']:rows.append(dict(platform='Windows',optimization=opt,**item))
    local=windows_local(proof)
    for item in local['contexts']:rows.append(dict(platform='Windows',**item))
    contract=json.loads((ROOT/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_CONTRACT_V1.json').read_text())
    expected={(platform,opt,case['name']) for platform in ('Windows','Ubuntu') for opt in ('O0','O2') for case in contract['representative_cases']}
    keys=[(item['platform'],item['optimization'],item['case']['name']) for item in rows]
    assert len(keys)==len(set(keys))==28 and set(keys)==expected
    sources={item.get('actual_source',item.get('actual_compiler_source')) for item in rows}
    for source in sources:
        assert not subprocess.check_output(['git','diff',source,PHYSICAL,'--','app','src','tools','reference'],cwd=ROOT)
    q=dict(status='ALL_ACTUAL28_SELECTED_CALENDAR_CONTEXTS_FRESH_SOURCE_BUDGET_NATIVE_COLD_CONTROLS_PASS_NOT_ADMITTED',contexts=28,
        full35_contexts=sum(item['case']['days']==35 for item in rows),short8_12_contexts=sum(item['case']['days']<35 for item in rows),
        primary_accepted_model_days=sum(item['case']['days'] for item in rows),native_samples=sum(item['native_samples'] for item in rows),
        exact_cold_windows=sum(item['exact_cold_windows'] for item in rows),
        actual_compiled_native_refusals=sum(item.get('controls',{}).get('actual_compiled_refusals',0) for item in rows),
        actual_unchanged_dense_generated_compiled_postimages=4,actual_scientific_sources=sorted(sources),
        source_app_src_tools_reference_exact_to=PHYSICAL,contexts_original=rows,canonical_admission=False,
        functional_completion='PARTIAL',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    assert (q['full35_contexts'],q['short8_12_contexts'],q['primary_accepted_model_days'],q['native_samples'],q['exact_cold_windows'],q['actual_compiled_native_refusals'])==(16,12,672,140,64,1328)
    assert len(local['current_dense_preservation'])==4
    return q


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    assert not a.output.exists();q=audit(a.proof);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'])
