"""Fresh scientific reads from explicit original archive locations; no replay."""
import argparse,io,json,re,struct,zipfile
from contextlib import ExitStack
from pathlib import Path
from explicit_bottom9_snow_analytical_central_science import Pool,read,rows,build,exact_native
from analytical_hydraulic_archives import SHA
from ria12_water_polish_science import audit as full_audit
from ria12_corrected_science import original_samples
from ria12_corrected_native import native
from ria12_boundary_central_science import compiled,generated
from ordinary_pond_evidence import physical
from implicit_conductivity_forensics import water
from original_output_files import compare

def setup(pool,platform,opt):
    if platform=='Ubuntu':
        name='RIA12_WATER_POLISH_UBUNTU_'+opt+'_ORIGINAL_V1'
        for actual,prefix in [('/home/runner/work/_temp/proof/current','current'),('/home/runner/work/_temp/builds','compiled'),('/home/runner/work/_temp/provider/build','original-provider-build')]:pool.add(actual,name,prefix)
        pool.store(name)
    else:
        name='RIA12_WATER_POLISH_WINDOWS_RAW_V1'
        for parent in ('RIA12_WINDOWS_RAW_V1','RIA12_CORRECTED_WINDOWS_RAW_V1',name):
            store=pool.store(parent)
            for actual,item in json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(actual,parent,item['prefix'])
    return name

def transaction(folder,data,meta,parameters):
    stages=[('external/trial-1',5),('external/trial-2',5),('external',5),('recovered/trial-1',6)]
    for stage,day in stages:
        with zipfile.ZipFile(io.BytesIO((folder/stage/f'accepted-column-1-day-{day}.zip').read_bytes())) as z:
            q=json.loads(z.read('checkpoint.json'));binding=q['binding']
            assert {k:v for k,v in binding.items() if k!='external_daily'}==meta['binding']
            assert physical([{k:v for k,v in q['receipt'].items() if k!='coupling'}])==physical([data[day-1]])
            assert all(SHA(z.read(name))==digest for name,digest in q['files'].items())
            native(z.read('macro.bin'),data[day-1],meta,parameters)
            if stage=='external':
                coupling=q['receipt']['coupling'];assert coupling['id']=='original-output' and coupling['revision']==1 and coupling['origin_day']==4
    exact_native(folder/'external/trial-1/accepted-column-1-day-5.zip',folder/'external/trial-2/accepted-column-1-day-5.zip')
    exact_native(folder/'external/trial-2/accepted-column-1-day-5.zip',folder/'external/accepted-column-1-day-5.zip')
    return dict(discard_replay_commit_recover_exact=True,prepares=3,commits=1)

def controls(pool,folder,profile,parameters,current=None):
    q=read(folder/'RESULT.json');assert q['status']=='RIA_POLISH_COMPILED_NATIVE_POLICY_BINDING_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
    assert q['accepted_mutant_model_days']==0 and len(q['compiled_refusals'])==37 and len(q['policy_refusals'])==3 and len(q['input_scope_refusals'])==8
    original=read(profile/'RESULT.json');build_path=read(current/'RESULT.json')['actual_build_root'] if current else original['build_root']
    directory,meta=build(pool,build_path,q['actual_BUILD_sha256']);data=rows(profile/'trajectory')
    positive=folder/'own-positive';good=(positive/'origin/macro.bin').read_bytes()
    assert b'HYBRID_READY' in (positive/'donor.stdout').read_bytes() and not (positive/'donor.stderr').read_bytes()
    native(good,data[1],meta,parameters)
    seen=set()
    for item in q['compiled_refusals']:
        label=item['attack'];assert label not in seen;seen.add(label);root=folder/label
        stdout,stderr=(root/'donor.stdout').read_bytes(),(root/'donor.stderr').read_bytes()
        assert b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout and b'ERROR STOP' in stderr
        raw=(root/'origin/macro.bin').read_bytes();assert SHA(raw)==item['mutant_sha256']
        try:native(raw,data[1],meta,parameters)
        except (ValueError,AssertionError,struct.error):pass
        else:raise AssertionError('Independent reader accepted actual mutant '+label)
    assert {item['field'] for item in q['policy_refusals']}=={'water_polish_policy','time_step_policy','ria12_water_polish_source'}
    assert all(item['refused_before_extraction'] for item in q['policy_refusals'])
    original_input=(pool.resolve(original['input_root'])/'swap.swp').read_bytes()
    values=dict(SWDRA='0',SWBOTB='5',IHWCKMODEL='1 1',SWHYST='1',SWHEA='1',SWSOLU='2',FLPRINTDT='.TRUE.',SWMACRO='1')
    assert {item['selector'] for item in q['input_scope_refusals']}==set(values)
    for item in q['input_scope_refusals']:
        key=item['selector'];expected,n=re.subn(rb'(?mi)^([ \t]*'+key.encode()+rb'[ \t]*=[ \t]*)[^!\r\n]*',lambda m:m[1]+values[key].encode(),original_input)
        assert n==1 and item['diagnostic'] and (folder/('invalid-input-'+key)/'swap.swp').read_bytes()==expected
    tx=transaction(folder,data,meta,parameters)
    result=dict(native_refusals=37,foreign_bindings=3,scope_refusals=8,actual_compiler=q['actual_compiler_source'],transaction=tx)
    if current:
        post=read(current/'RESULT.json');assert post['status']=='CURRENT_RIA_POLISH_ALL_GENERATED_COMPILED_NATIVE_PREFIX_COLD_EXTERNAL_PASS_NOT_ADMITTED'
        assert post['original_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and post['full35_periods_replayed']==0
        old=pool.resolve(original['build_root']);result['generated_sources']=generated(old,directory);result['compiled_files']=len(compiled(old,directory))
        assert physical(rows(current/'prefix6'))==physical(data[:6])
        for day in (2,4):exact_native(current/f'prefix6/accepted-column-1-day-{day}.zip',profile/f'trajectory/accepted-column-1-day-{day}.zip')
        exact_native(current/'own-2/accepted-column-1-day-4.zip',current/'prefix6/accepted-column-1-day-4.zip')
        assert physical(rows(current/'own-2'))==physical(data[2:4])
    return result

def dry(pool,folder,samples):
    q=read(folder/'RESULT.json');assert q['status']=='ACTUAL_RIA_ADDITIONAL_WATER_POLISH3_GLOBAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    _,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);data=rows(folder/'trajectory');assert len(data)==3
    sample=read(samples/'RESULT.json');assert sample['profile_RESULT_sha256']==SHA((folder/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((folder/'trajectory/daily.jsonl').read_bytes())
    assert sample['model_periods']==0 and sample['maximum_original_theta_stock_difference_cm']<=1e-10
    component=pool.resolve(sample['component_root']);assert read(component/'COMPONENT.json')==sample['component']
    assert SHA((component/sample['component']['executable']).read_bytes())==sample['component']['executable_sha256']
    original_samples(samples,component,sample,pool.resolve(q['input_root']),data)
    parameters=(samples/'original-parameters.bin').read_bytes();assert SHA(parameters)==sample['original_parameter_bytes_sha256']
    for path in (folder/'trajectory').glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1])
        with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:native(z.read('macro.bin'),data[day-1],meta,parameters)
    cold=rows(folder/'own-1');assert physical(cold)==physical(data[1:])
    exact_native(folder/'own-1/accepted-column-1-day-3.zip',folder/'trajectory/accepted-column-1-day-3.zip')
    output=compare(folder/'trajectory/original',folder/'own-1/original',meta['identity']['original_output'],1,3,meta['project']['start_date'])
    return dict(days=3,water=water(data),cold_water=water(cold),exact_original_output=output,original_observations=sum(len(x) for x in sample['observations_by_layer'].values()))

def audit(platform,opt):
    assert platform in ('Windows','Ubuntu') and opt in ('O0','O2')
    with ExitStack() as stack:
        pool=Pool(stack);name=setup(pool,platform,opt);result=[]
        for kind in ('water','cde'):
            current=None
            if platform=='Ubuntu':
                prefix='current/'+kind+'-wet-primary';profile=pool.view(name,prefix+'-full35');samples=pool.view(name,prefix+'-original-samples');independent=read(pool.view(name,prefix+'-INDEPENDENT.json'));control=pool.view(name,prefix+'-controls')
                dry_profile=pool.view(name,'current/'+kind+'-dry-short3');dry_samples=pool.view(name,'current/'+kind+'-dry-original-samples')
            else:
                base=f'ria12-water-polish-water-wet-full35-{opt}-v1' if kind=='water' else f'ria12-water-polish-cde-wet-primary-{opt}-full35-'+('v2' if opt=='O0' else 'v1')
                profile=pool.view(name,'evidence/'+base)
                samples=pool.view(name,f'evidence/ria12-water-polish-'+('water-' if kind=='water' else '')+f'full35-{opt}-original-component-v1')
                independent=read(pool.view(name,f'evidence/RIA12_WATER_POLISH_'+('WATER_' if kind=='water' else '')+opt+'_FULL35_INDEPENDENT_V1.json'))
                control=pool.view(name,f'evidence/ria12-water-polish-{kind}-{opt}-controls-v1')
                dry_profile=pool.view(name,f'evidence/ria12-water-polish-{kind}-dry-short3-{opt}-v1');dry_samples=pool.view(name,f'evidence/ria12-water-polish-{kind}-dry-{opt}-original-component-v1')
                if kind=='cde':current=pool.view(name,f'evidence/ria12-water-polish-cde-current-{opt}-v1')
            fresh=full_audit(profile,samples,pool.resolve);fresh.pop('actual_observer_source');observer=independent.pop('actual_observer_source');assert fresh==independent
            params=(samples/'original-parameters.bin').read_bytes()
            result.append(dict(kind=kind,optimization=opt,science=fresh,original_observer=observer,controls=controls(pool,control,profile,params,current),dry_seam=dry(pool,dry_profile,dry_samples)))
        return dict(status='CENTRAL_ORIGINAL_RIA_POLISH_FULL_GLOBAL_NATIVE_COLD_DRY_POLICY_AND_EXTERNAL_PASS_NOT_ADMITTED',platform=platform,optimization=opt,contexts=result,full35_periods=2,exact_cold_windows=6,dry_short3_contexts=2,native_refusals=74,foreign_bindings=6,out_of_scope_inputs=16,model_executions=0,compiler_executions=0,canonical_admission=False)

def defaults():
    with ExitStack() as stack:
        pool=Pool(stack);name=setup(pool,'Windows','O0');folder=pool.view(name,'evidence/ria12-water-polish-default-preservation-v1');q=read(folder/'RESULT.json')
        assert q['status']=='ACTUAL_ADMITTED_AND_CURRENT_SAME_ROOT_DEFAULT_ALL_GENERATED_COMPILED_POSTIMAGES_PASS_NO_MODEL_REPLAY'
        assert q['admitted_source']=='e252e995eeece63d8f05531a10b746674c070685' and q['model_executions']==0 and not q['simulated_repository_views']
        result=[]
        for kind,opt in [('water','O0'),('cde','O2')]:
            items=[next(c for c in q['cases'] if c['epoch']==epoch and c['kind']==kind and c['optimization']==opt) for epoch in ('admitted','current')]
            roots=[]
            for item in items:
                assert item['returncode']==0 and item['actual_compiler_source']==item['actual_completion_head']
                root,meta=build(pool,item['build_root'],item['actual_BUILD_sha256']);roots.append(root)
                assert meta['identity']['water_polish_policy']=='strict-water-always-polish-v1' and meta['identity']['time_step_policy']=='original-adaptive-day-seed-v1' and 'ria12_water_polish_source' not in meta['identity']
            result.append(dict(kind=kind,optimization=opt,generated_sources=generated(*roots),compiled_files=len(compiled(*roots))))
        return dict(status='ACTUAL_SAME_ROOT_ADMITTED_CURRENT_DEFAULT_ALL_GENERATED_COMPILED_EXACT_NO_MODEL_REPLAY',contexts=result,model_executions=0,compiler_executions=0)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.platform,a.optimization)
    with a.output.open('x') as stream:json.dump(q,stream,indent=2)
    print(q['status'],a.platform,a.optimization)
