"""Fresh actual current bottom5 source/object bytes; no compiler or model replay."""
from contextlib import ExitStack
import json,subprocess
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_calendar_state_portable_custody import source as scientific_custody
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'
DISPATCH=b'    from frost_boundary_terminal_trial import apply_build as plate_terminal_build\n    patched=plate_terminal_build(output,project,patched)\n'


def audit(proof):
    baseline=json.loads((P/'FROST_BOUNDARY_STATE_CALENDAR04_BOTTOM5_PHYSICAL_POSTIMAGE_BASELINES_V1.json').read_text())
    results=[];provenance=[]
    def compare(store,prefix,meta,host,opt,case,producer):
        original=baseline['records'][host+'/'+opt+'/'+case]
        assert {k:meta['identity'][k] for k in original['compiler']}==original['compiler']
        assert set(meta['identity']['donor_generated'])==set(original['generated'])
        actual_host=subprocess.check_output(['git','show',producer+':app/hybrid_water/daily_host.py'],cwd=R)
        assert actual_host.count(DISPATCH)==1
        assert actual_host.replace(DISPATCH,b'',1)==subprocess.check_output(['git','show','3feb51229a980331bc12be2d1d265bef7ae6691a:app/hybrid_water/daily_host.py'],cwd=R)
        assert not subprocess.check_output(['git','diff',producer,'HEAD','--','app','src','tools','reference'],cwd=R)
        sources={};objects={}
        for file,item in original['generated'].items():
            raw=store.get(prefix+file);assert SHA(raw)==meta['identity']['donor_generated'][file]
            normalized=SHA(raw.replace(b'\r\n',b'\n'));assert normalized==item['original_LF_sha256']
            object_raw=store.get(prefix+item['object_file']);assert SHA(object_raw)==item['original_object_sha256']
            sources[file]=dict(actual_raw_sha256=SHA(raw),actual_LF_sha256=normalized,original_LF_sha256=item['original_LF_sha256'])
            objects[item['object_file']]=dict(actual_sha256=SHA(object_raw),original_sha256=item['original_object_sha256'])
        results.append(dict(platform=host,optimization=opt,case=case,actual_compiler_source=producer,actual_BUILD_sha256=SHA(store.get(prefix+'BUILD.json')),generated=sources,compiled=objects))
    with ExitStack() as stack:
        local=Archive(proof,'FROST_BOUNDARY_STATE_CALENDAR04_CURRENT_LOCAL_POSTIMAGE_RAW_V4',stack)
        for member in local.names:local.get(member)
        for opt in ('O0','O2'):
            case='water-b5-i0-h0-p1-regular-r0'
            folder='frost-boundary-state-calendar04-current-local-water-postimage-v4/'+opt
            report=json.loads(local.get(folder+'/RESULT.json'));assert report['status']=='FAILED_ACTUAL_BOTTOM5_POSTIMAGE_PRESERVATION_NOT_ADMITTED'
            assert len(report['contexts'])==1 and report['contexts'][0]['returncode']==0 and report['model_executions']==0
            prefix='frost-boundary-state-calendar04-current-water-postimage-'+opt+'-v4/'+case+'/bundle/'
            meta=json.loads(local.get(prefix+'BUILD.json'))
            for name,digest in meta['inputs'].items():assert SHA(local.get(folder+'/'+case+'/inputs/'+name))==digest
            compare(local,prefix,meta,'WINDOWS',opt,case,report['source'])
    for host in ('UBUNTU','WINDOWS'):
        for opt in ('O0','O2'):
            for version in (2,3):
                with ExitStack() as stack:
                    stem=f'FROST_BOUNDARY_STATE_CALENDAR04_{host}_{opt}_POSTIMAGES_ORIGINAL_V{version}'
                    store=Archive(proof,stem,stack)
                    for member in store.names:store.get(member)
                    producer={2:'85916d054cc0da21baa054ac3a50d40950be49ad',3:'f640d61b63734117e561f0e5240eec83a2996ad7'}[version]
                    workflow=f'.github/workflows/nomacro-frost-boundary-state-calendar04-postimages-{host.lower()}.yml'
                    with ExitStack() as source_stack:_,identity=scientific_custody(store,source_stack,producer,producer,workflow)
                    provenance.append(dict(archive=stem,**identity))
                    q=json.loads(store.get('current/RESULT.json'));assert q['source']==producer and q['model_executions']==0
                    if version==2:assert q['status']=='FAILED_ACTUAL_BOTTOM5_POSTIMAGE_PRESERVATION_NOT_ADMITTED' and len(q['contexts'])==1
                    else:assert q['status']=='ACTUAL_SELECTED_BOTTOM5_PHYSICAL_BRANCHES_PUBLIC_GENERATED_AND_COMPILED_POSTIMAGES_EXACT_NO_MODEL_REPLAY_NOT_ADMITTED' and len(q['contexts'])==(3 if host=='UBUNTU' else 2)
                    for item in q['contexts']:
                        assert item['returncode']==0 and item['model_executions']==0 and '--build-only' in item['command']
                        case=item['case'];prefix='compiled/'+case+'/bundle/';meta=json.loads(store.get(prefix+'BUILD.json'))
                        for name,digest in meta['inputs'].items():assert SHA(store.get('current/'+case+'/inputs/'+name))==digest
                        compare(store,prefix,meta,host,opt,case,producer)
    assert len(results)==len({(x['platform'],x['optimization'],x['case']) for x in results})==16
    count=sum(len(x['compiled']) for x in results);assert count==432
    return dict(status='ALL16_CURRENT_BOTTOM5_WHOLE_GENERATED_AND_432_COMPILED_OBJECT_POSTIMAGES_EXACT_SAME_ORIGINAL_COMPILERS_ZERO_MODELS',contexts=results,compiled_object_comparisons=count,actual_source_controller_and_provider_custody=provenance,original_failed_read_only_identity_guards_retained=True,compiler_executions=0,model_executions=0)
