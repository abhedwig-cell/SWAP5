"""Seal the coherent actual Windows paired-boundary campaign, including failures."""
import argparse,json,subprocess
from pathlib import Path
from analytical_hydraulic_archives import SHA
from explicit_bottom9_source_inverse import ROOT,BASE,CORE,PRE_CLOCK,CLOCK_ONLY,complete_inverse,git
from initial_profile_frost_preserve import seal


def windows(ev,work,staging):
    complete_inverse();head=git('rev-parse','HEAD').decode().strip()
    assert not git('status','--porcelain','--','app','src','tools/solute','tools/vq','reference','tests/nomacro_drainage')
    assert staging.is_dir() and not any(staging.iterdir())
    files={};projection={};roles=[];post_by_primary={};inventory=[]
    def tree(path,prefix):
        assert path.is_dir() and not path.is_symlink()
        for item in sorted(path.rglob('*')):
            assert not item.is_symlink()
            if item.is_file():
                key=prefix+'/'+item.relative_to(path).as_posix();assert key not in files;files[key]=item
    def evpath(actual):
        path=Path(actual);relative=path.relative_to(ev);key='profiles/'+relative.as_posix()
        assert key in files or any(k.startswith(key+'/') for k in files)
        return key
    for path in sorted(ev.iterdir()):
        if not path.name.lower().startswith(('explicit-bottom9','explicit_bottom9','original-bottom9')):continue
        if path.is_dir():
            tree(path,'profiles/'+path.name)
            result=path/'RESULT.json'
            if result.is_file():
                q=json.loads(result.read_text(encoding='utf-8'))
                for field in ('initial1_profile','reference_profile'):
                    if field in q and q.get('model_executions')==0:
                        assert q[field] not in post_by_primary;post_by_primary[q[field]]=path
        elif path.is_file():files['observations/'+path.name]=path
    for path in sorted(work.iterdir()):
        if path==staging or not path.is_dir() or not path.name.startswith('explicit-bottom9'):continue
        tree(path,'compiled/'+path.name)
        meta=path/'bundle/BUILD.json'
        if meta.is_file():projection[str(meta.parent)]=dict(archive_prefix='compiled/'+path.name+'/bundle',actual_BUILD_sha256=SHA(meta.read_bytes()))
        inventory.append(dict(actual_path=str(path),archive_prefix='compiled/'+path.name))
    intermediate=json.loads((ev/'EXPLICIT_BOTTOM9_ALL24_PRECLOCK_PERIODS_CURRENT_SOURCE_COMPILED_INHERITANCE_V2.json').read_text())
    clock=json.loads((ev/'EXPLICIT_BOTTOM9_ACTUAL_CURRENT_CLOCK_EIGHT_V2.json').read_text())
    assert len(intermediate['observations'])==24 and len(clock['contexts'])==8
    primaries=[i['prior_profile'] for i in intermediate['observations']]+[i['profile'] for i in clock['contexts']]
    assert len(set(primaries))==32
    for actual in primaries:
        path=Path(actual);q=json.loads((path/'RESULT.json').read_text());post=post_by_primary[actual];p=json.loads((post/'RESULT.json').read_text())
        assert q['status']=='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
        assert q['build_root'] in projection and p['build_root'] in projection
        role=dict(profile=evpath(actual),original_profile_path=actual,inputs=evpath(q['input_root']),postimage=evpath(str(post)),counter_inputs=evpath(p['input_root']),kind=q['kind'],case=q['case'],optimization=q['optimization'],producer=q['source'],distributed_drain='distributed-drain' in q['case'])
        roles.append(role)
    controls=[]
    for case in ('hydrostatic','unitgradient'):
        for opt in ('O0','O2'):
            path=ev/('explicit-bottom9-'+case+'-'+opt+('-v2' if opt=='O0' else '-v3'));q=json.loads((path/'RESULT.json').read_text())
            assert q['build_root'] in projection
            item=dict(profile=evpath(str(path)),original_profile_path=str(path),inputs=evpath(q['input_root']),case=case,optimization=opt,producer=q['source'])
            if opt=='O0':item['native_campaign']=evpath(str(ev/('explicit-bottom9-'+case+'-O0-native-campaign-v1')))
            controls.append(item)
    epochs=sorted({i['producer'] for i in roles+controls}|{BASE,PRE_CLOCK,CLOCK_ONLY,CORE,intermediate['source'],head})
    extra={}
    # These are exact committed blobs, explicitly separate from the actual raw
    # producer capsules already retained in profiles and observations.
    paths=('app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/experimental_project.py','app/hybrid_water/original_output.py','app/hybrid_water/prescribed_head_flux_boundary.py')
    for epoch in epochs:
        for path in paths:
            if epoch==BASE and path.endswith('/prescribed_head_flux_boundary.py'):continue
            extra['committed-source-history/'+epoch+'/'+path]=git('show',epoch+':'+path)
    custody=dict(sealer_source=head,actual_runtime_sources=sorted({i['producer'] for i in roles+controls}),actual_intermediate_compiled_source=intermediate['source'],intermediate_physical_core=CLOCK_ONLY,final_physical_core=CORE,original_provider_archive='HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',original_provider_sha256='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a',actual_profile_and_BUILD_metadata_rewritten=False,compiled_allocation_closure=inventory,source_history_role='Exact committed Git blobs; actual working source bytes remain separately captured by their original source capsules.')
    for key,value in [('COMPILED_PROJECTION_V1.json',projection),('SOURCE_CUSTODY_V1.json',custody)]:extra[key]=(json.dumps(value,indent=2)+'\n').encode()
    print('PRESERVING_ACTUAL_WINDOWS_RAW',len(files),'files',len(projection),'completed_builds',flush=True)
    name='EXPLICIT_BOTTOM9_WINDOWS_RAW_V1'
    seal(staging/(name+'.zip'),name,files,extra,dict(status='ACTUAL_WINDOWS_EXPLICIT9_COHERENT_RAW_COMPILED_INPUT_SOURCE_FAILURE_CLOSURE_PRESERVED_NOT_ADMITTED',roles=roles,water_controls=controls,short35_contexts=36,native_checkpoints=252,exact_cold_windows=108,compiler_counterparts=32,intermediate_inheritance_compiled_contexts=24,sealer_source=head,canonical_admission=False))


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ('evidence','work','staging'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();windows(a.evidence,a.work,a.staging)
