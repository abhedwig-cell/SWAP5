"""One 32-context matrix: changed current cases plus exactly preserved science."""
import argparse,json
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from frost_implicit_plate_archive_science import case_audit
from frost_calendar_state_portable_custody import source as scientific_custody
from frost_implicit_plate_inherited_postimages import NAMES as INHERITED
from frost_boundary_state_calendar_archive_science import ReadView
R=Path(__file__).resolve().parents[2]


def audit(proof,verbose=False):
    from frost_implicit_plate_metadata import read
    contract=read('FROST_IMPLICIT_PLATE05_CONTRACT_V1.json');cases=contract['representative_cases'];results=[];provenance=[];postimages=[];failures=[]
    with ExitStack() as stack:
        for host in ['WINDOWS','UBUNTU']:
            for opt in ['O0','O2']:
                old=Archive(proof,f'FROST_IMPLICIT_PLATE05_{host}_{opt}_ORIGINAL_V1',stack)
                new=Archive(proof,f'FROST_IMPLICIT_PLATE05_{host}_{opt}_ORIGINAL_V2',stack)
                for store in [old,new]:
                    producer=store.record['actual_scientific_source'];workflow=f'.github/workflows/nomacro-frost-implicit-plate05-{host.lower()}.yml'
                    _,custody=scientific_custody(store,stack,producer,producer,workflow);provenance.append(dict(platform=host,optimization=opt,archive_sha256=store.record['sha256'],**custody))
                current=json.loads(new.get('current-inherited-postimages/RESULT.json'))
                assert current['status']=='FOUR_CURRENT_UNCHANGED_IMPLICIT_PLATE_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
                assert current['actual_source']==new.record['actual_scientific_source'] and current['model_executions']==0 and not current['object_normalization']
                assert {x['case']['name'] for x in current['contexts']}==INHERITED
                old_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));new_projection=json.loads(new.get('COMPILED_PROJECTION_V1.json'))
                for context in current['contexts']:
                    name=context['case']['name'];before=json.loads(old.get('current/'+name+'/science/RESULT.json'));old_build=ReadView(old,old_projection[before['build_root']]['archive_prefix']);new_build=ReadView(new,new_projection[context['actual_build_root']]['archive_prefix'])
                    assert SHA((old_build/'BUILD.json').read_bytes())==context['original_BUILD_sha256'] and SHA((new_build/'BUILD.json').read_bytes())==context['actual_BUILD_sha256']
                    a=json.loads((old_build/'BUILD.json').read_text())['identity'];b=json.loads((new_build/'BUILD.json').read_text())['identity']
                    for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert a[key]==b[key]
                    names={p.name for p in old_build.glob('*.o')};assert names=={p.name for p in new_build.glob('*.o')}=={x['file'] for x in context['objects']} and names
                    for obj in context['objects']:
                        raw=(new_build/obj['file']).read_bytes();assert raw==(old_build/obj['file']).read_bytes() and SHA(raw)==obj['sha256'] and len(raw)==obj['bytes']
                    postimages.append(dict(platform=host,optimization=opt,case=name,actual_source=current['actual_source'],original_source=before['source'],whole_object_count=len(names),actual_BUILD_sha256=context['actual_BUILD_sha256'],model_replays=0))
                for case in cases:
                    store=old if case['name'] in INHERITED else new;producer=store.record['actual_scientific_source']
                    result=case_audit(store,case['name'],case,store,producer,opt);results.append(dict(platform=host,original_archive_sha256=store.record['sha256'],inherited_unchanged=store is old,**result))
                    if verbose:print('INDEPENDENT_ACTUAL_IMPLICIT_PLATE_CONTEXT_PASS',host,opt,case['name'],flush=True)
                prefix='current/water-b8-i1-h1-p1-dates-r0-year-seam/science/'
                profile=json.loads(old.get(prefix+'RESULT.json'));assert profile['trajectory']['days']==12 and not profile['own']
                assert b'Inconsistent original interval date pointer' in old.get(prefix+'own-2/original/donor.stderr')
                failures.append(dict(platform=host,optimization=opt,actual_source=old.record['actual_scientific_source'],warm_days=12,cold_start_day=2,status='ORIGINAL_PENDING_DATE_NATIVE_REFUSAL_PRESERVED_NOT_QUALIFIED',archive_sha256=old.record['sha256']))
    assert len(results)==len({(x['platform'],x['optimization'],x['case']['name']) for x in results})==32
    result=dict(status='INDEPENDENT_ACTUAL32_IMPLICIT_PLATE_ORIGINAL_BUDGETS_NATIVE_COLD_CONTROLS_AND_CURRENT_WHOLE_OBJECT_CUSTODY_PASS_NOT_ADMITTED',contexts=32,full35_contexts=24,year12_contexts=8,primary_days=sum(x['case']['days'] for x in results),native_samples=sum(x['native_samples'] for x in results),exact_cold_windows=sum(x['exact_cold_windows'] for x in results),actual_compiled_refusals=sum(x.get('controls',{}).get('actual_compiled_refusals',0) for x in results),transaction_contexts=sum((len(x.get('controls',{}).get('transactions',[])) or x.get('controls',{}).get('actual_discard_replay_accept_recovery_contexts',0)) for x in results),actual_contexts=results,actual_current_inherited_compiled_postimages=postimages,actual_producer_source_and_provider_custody=provenance,original_failed_native_year_attempts=failures,compiler_executions=0,model_executions=0,canonical_admission=False,whole_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    assert result['primary_days']==936 and result['native_samples']==184 and result['exact_cold_windows']==80 and len(postimages)==16
    return result


def main():
    p=argparse.ArgumentParser();p.add_argument('--proof-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.proof_root,True);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
