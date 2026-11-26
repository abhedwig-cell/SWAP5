"""Read original periods and current whole objects with distinct genuine sources."""
import argparse,json
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from frost_calendar_state_portable_custody import source as captured_source
from frost_analytical_boundary_archive_science import R,P,git,read,case_audit

CURRENT='45bb6146f5800f4050e95feb5d1912ddfdd23d4d'
PHYSICAL='b24cebc3993b0f350c7aef7fb773a177d00425ce'
FIRST='b4ffcc914453225562ffe0e847faa21a765432ce'
CONTINUATION='9d53d55a0ae5aa7567ee62bfcbc60fece1629905'
CHANGED=[3,5,7,8,10,12,14,15]
UNCHANGED=[0,1,2,4,6,9,11,13]


def postimages(store,originals,contract,opt):
    q=json.loads(store.get('current-unaffected-postimages/RESULT.json'))
    assert q['status']=='EIGHT_CURRENT_UNAFFECTED_BOUNDARY_COMPLETE_GENERATED_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY'
    assert q['actual_source']==CURRENT and q['optimization']==opt and q['model_executions']==0
    assert [x['index'] for x in q['contexts']]==UNCHANGED
    projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));result=[]
    for item in q['contexts']:
        index=item['index'];case=contract['representative_cases'][index];phase='FIRST' if index<7 else 'CONTINUATION'
        producer=FIRST if phase=='FIRST' else CONTINUATION;old=originals[phase]
        assert item['case']==case and item['original_source']==producer and item['original_phase']==phase
        assert item['original_archive_sha256']==old.record['sha256'] and item['model_executions']==0
        prior=json.loads(old.get('current/'+case['name']+'/science/RESULT.json'))
        parent=ReadView(old,json.loads(old.get('COMPILED_PROJECTION_V1.json'))[prior['build_root']]['archive_prefix'])
        build=ReadView(store,projection[item['actual_build_root']]['archive_prefix']);meta=read(build/'BUILD.json');before=read(parent/'BUILD.json')
        assert prior['source']==prior['actual_controller_source']==producer
        assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'] and SHA((parent/'BUILD.json').read_bytes())==item['original_BUILD_sha256']
        for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:
            assert meta['identity'][key]==before['identity'][key]
        assert meta['inputs']==before['inputs']
        for name,digest in meta['identity']['donor_generated'].items():
            assert (build/name).read_bytes()==(parent/name).read_bytes() and SHA((build/name).read_bytes())==digest
        objects={p.name for p in build.glob('*.o')}
        assert objects=={p.name for p in parent.glob('*.o')}=={o['file'] for o in item['objects']} and objects
        for obj in item['objects']:
            raw=(build/obj['file']).read_bytes();assert raw==(parent/obj['file']).read_bytes() and len(raw)==obj['bytes'] and SHA(raw)==obj['sha256']
        result.append(dict(index=index,case=case['name'],original_scientific_source=producer,current_compiler_source=CURRENT,whole_objects=len(objects),model_replays=0))
    return result


def composite(proof,platform,opt,verbose=False):
    with ExitStack() as stack:
        suffix=f'{platform.upper()}_{opt}_ORIGINAL_V1'
        store=Archive(proof,'FROST_ANALYTICAL_BOUNDARY10_SEARCH_'+suffix,stack)
        _,custody=captured_source(store,stack,CURRENT,PHYSICAL,f'.github/workflows/nomacro-frost-analytical-boundary10-{platform.lower()}.yml')
        originals={phase:Archive(proof,'FROST_ANALYTICAL_BOUNDARY10_'+phase+'_'+suffix,stack) for phase in ['FIRST','CONTINUATION']}
        original_custody={}
        for phase,producer in [('FIRST',FIRST),('CONTINUATION',CONTINUATION)]:
            _,original_custody[phase]=captured_source(originals[phase],stack,producer,FIRST,f'.github/workflows/nomacro-frost-analytical-boundary10-{platform.lower()}.yml')
        contract=json.loads(git('show',CURRENT+':'+P+'FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json'))
        assert json.loads(store.get('actual-input-contract.json'))==contract
        q=json.loads(store.get('current/RESULT.json'))
        assert q['status']=='EIGHT_ACTUAL_CHANGED_ANALYTICAL_ZERO_FLUX6_FROST_SEARCH_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
        assert q['source']==CURRENT and q['optimization']==opt and q['platform']==platform and not q['refusals']
        assert q['selected_case_indices']==CHANGED and [c['case'] for c in q['contexts']]==[contract['representative_cases'][i] for i in CHANGED]
        retained=postimages(store,originals,contract,opt);contexts=[]
        for index,case in enumerate(contract['representative_cases']):
            phase='FIRST' if index<7 else 'CONTINUATION'
            archive=store if index in CHANGED else originals[phase]
            producer=CURRENT if index in CHANGED else (FIRST if phase=='FIRST' else CONTINUATION)
            context=case_audit(archive,'current/'+case['name'],case,archive,producer,opt)
            context.update(index=index,current_source_custody=CURRENT,current_postimage_required=index in UNCHANGED,period_replayed_by_observer=False)
            contexts.append(context)
            if verbose:print('INDEPENDENT_COMPOSITE_CONTEXT_PASS',platform,opt,index,case['name'],producer,flush=True)
        totals=dict(contexts=len(contexts),primary_days=sum(c['case']['days'] for c in contexts),native_samples=sum(c['native_samples'] for c in contexts),exact_cold_windows=sum(c['exact_cold_windows'] for c in contexts),compiled_refusals=sum(c['controls']['actual_compiled_refusals'] for c in contexts),transactions=sum(len(c['controls']['transactions']) for c in contexts))
        assert totals==dict(contexts=16,primary_days=468,native_samples=100,exact_cold_windows=44,compiled_refusals=461,transactions=22)
        return dict(status='INDEPENDENT_COMPOSITE16_ORIGINAL_BUDGETS_NATIVE_COLD_REFUSALS_TRANSACTIONS_AND_CURRENT_UNAFFECTED_WHOLE_OBJECTS_PASS_NOT_ADMITTED',current_source=custody,original_source_custody=original_custody,platform=platform,optimization=opt,contexts=contexts,unaffected_postimages=retained,totals=totals,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    head=git('rev-parse','HEAD').decode().strip();q=dict(status='RUNNING_INDEPENDENT_COMPOSITE_AUDIT',actual_observer=head)
    try:
        q['audit']=composite(GitArchiveSource(R,head),a.platform,a.optimization,True);q['status']=q['audit']['status']
    except Exception as error:q.update(status='FAILED_INDEPENDENT_COMPOSITE_AUDIT',error=repr(error));raise
    finally:
        assert git('rev-parse','HEAD').decode().strip()==head
        with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
