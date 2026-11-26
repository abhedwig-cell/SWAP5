"""Independent 64-context science and 32 unchanged whole-object postimages."""
import argparse,json
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_implicit_hys2_archive_science import case_audit
from frost_calendar_state_portable_custody import source as scientific_custody
from explicit_bottom9_archive_science import ReadView
from frost_implicit_hys2_inherited_postimages import NAMES as ORIGINAL_V1


def audit(proof,verbose=False):
    from frost_implicit_hys2_metadata import read
    from frost_implicit_plate_metadata import read as read_parent
    cases=read('FROST_IMPLICIT_HYS2_YEAR06_CONTRACT_V1.json')['representative_cases']
    parent_cases={x['name']:x for x in read_parent('FROST_IMPLICIT_PLATE05_CONTRACT_V1.json')['representative_cases']}
    assert len(cases)==16 and len(parent_cases)==8
    results=[];provenance=[];postimages=[]
    with ExitStack() as stack:
        for host in ('WINDOWS','UBUNTU'):
            for opt in ('O0','O2'):
                current=Archive(proof,f'FROST_IMPLICIT_HYS2_YEAR06_{host}_{opt}_ORIGINAL_V1',stack)
                producer=current.record['actual_scientific_source']
                workflow=f'.github/workflows/nomacro-frost-implicit-hys2-year06-{host.lower()}.yml'
                _,custody=scientific_custody(current,stack,producer,producer,workflow)
                provenance.append(dict(platform=host,optimization=opt,archive_sha256=current.record['sha256'],**custody))
                cohort=json.loads(current.get('current/RESULT.json'))
                assert cohort['status']=='ACTUAL_SELECTED_IMPLICIT_HYS2_BOUNDARY_PERIODS_NATIVE_COLD_AND_CONTROLS_PASS_NOT_ADMITTED'
                assert cohort['source']==producer and {x['case']['name'] for x in cohort['contexts']}=={x['name'] for x in cases}
                for case in cases:
                    result=case_audit(current,case['name'],case,current,producer,opt)
                    results.append(dict(platform=host,original_archive_sha256=current.record['sha256'],**result))
                    if verbose:print('INDEPENDENT_ACTUAL_IMPLICIT_HYS2_CONTEXT_PASS',host,opt,case['name'],flush=True)
                inherited=json.loads(current.get('current-inherited-postimages/RESULT.json'))
                assert inherited['status']=='EIGHT_CURRENT_UNCHANGED_IMPLICIT_PLATE_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
                assert inherited['actual_source']==producer and inherited['model_executions']==0 and inherited['object_normalization'] is False
                assert {x['case']['name'] for x in inherited['contexts']}==set(parent_cases)
                old={v:Archive(proof,f'FROST_IMPLICIT_PLATE05_{host}_{opt}_ORIGINAL_V{v}',stack) for v in (1,2)}
                projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'))
                for context in inherited['contexts']:
                    name=context['case']['name'];assert context['case']==parent_cases[name]
                    baseline=old[1 if name in ORIGINAL_V1 else 2]
                    assert context['original_archive_sha256']==baseline.record['sha256']
                    prior=json.loads(baseline.get('current/'+name+'/science/RESULT.json'))
                    assert prior['source']==context['original_source']==baseline.record['actual_scientific_source']
                    previous_projection=json.loads(baseline.get('COMPILED_PROJECTION_V1.json'))
                    before=ReadView(baseline,previous_projection[prior['build_root']]['archive_prefix'])
                    after=ReadView(current,projection[context['actual_build_root']]['archive_prefix'])
                    assert SHA((before/'BUILD.json').read_bytes())==context['original_BUILD_sha256']
                    assert SHA((after/'BUILD.json').read_bytes())==context['actual_BUILD_sha256']
                    a=json.loads((before/'BUILD.json').read_text());b=json.loads((after/'BUILD.json').read_text())
                    for key in ('compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library'):
                        assert a['identity'][key]==b['identity'][key],(name,key)
                    assert a['inputs']==b['inputs']
                    names={p.name for p in before.glob('*.o')}
                    assert names=={p.name for p in after.glob('*.o')}=={x['file'] for x in context['objects']} and names
                    for item in context['objects']:
                        raw=(after/item['file']).read_bytes()
                        assert raw==(before/item['file']).read_bytes() and len(raw)==item['bytes'] and SHA(raw)==item['sha256']
                    postimages.append(dict(platform=host,optimization=opt,case=name,actual_source=producer,original_source=prior['source'],whole_object_count=len(names),actual_BUILD_sha256=context['actual_BUILD_sha256'],model_replays=0))
    assert len(results)==len({(x['platform'],x['optimization'],x['case']['name']) for x in results})==64
    assert sum(x['case']['days'] for x in results)==1872 and len(postimages)==32
    return dict(status='INDEPENDENT_ACTUAL64_IMPLICIT_HYS2_BOUNDARY_ORIGINAL_BUDGETS_NATIVE_COLD_CONTROLS_AND_CURRENT32_WHOLE_OBJECT_POSTIMAGES_PASS_NOT_ADMITTED',
        contexts=64,new_contexts=48,requalified_implicit5_contexts=16,full35_contexts=48,year12_contexts=16,
        primary_days=1872,native_samples=sum(x['native_samples'] for x in results),exact_cold_windows=sum(x['exact_cold_windows'] for x in results),
        actual_compiled_refusals=sum(x.get('controls',{}).get('actual_compiled_refusals',0) for x in results),
        transaction_contexts=sum((len(x.get('controls',{}).get('transactions',[])) or x.get('controls',{}).get('actual_discard_replay_accept_recovery_contexts',0)) for x in results),
        actual_contexts=results,actual_current_inherited_compiled_postimages=postimages,actual_producer_source_and_provider_custody=provenance,
        compiler_executions=0,model_executions=0,canonical_admission=False,whole_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--proof-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=audit(a.proof_root,True);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
