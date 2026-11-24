"""Independent fresh thermal scientific reads at explicit immutable locations."""
import argparse,json,io,re,struct,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import SHA
from explicit_bottom9_snow_analytical_central_science import Pool,read,rows,build,exact_native
from ria12_boundary_central_science import compiled,generated
from ordinary_pond_evidence import physical
from ria12_thermal_native import native
from ria12_thermal_science import audit_profile

def controls(pool, folder, profile, meta, parameters):
    q = read(folder / 'RESULT.json')
    original = read(profile / 'RESULT.json')
    assert q['genuine_checkpoint_producer'] == original['source'] and q['accepted_model_days'] == q['model_periods'] == 0
    assert len(q['compiled_refusals']) == 43 + 6 * original['snow'] and len(q['private_input_refusals']) == 3 and q['own_positive_ready']
    directory, current = build(pool, q['actual_current_build_root'], q['actual_BUILD_sha256'])
    assert current['inputs'] == meta['inputs']
    postimages = compiled(pool.resolve(original['build_root']), directory)
    assert generated(pool.resolve(original['build_root']), directory)
    with zipfile.ZipFile(io.BytesIO((profile / 'trajectory/accepted-column-1-day-2.zip').read_bytes())) as z:
        good = z.read('macro.bin')
    positive = folder / 'genuine-own-native-positive'
    assert b'HYBRID_READY' in (positive / 'donor.stdout').read_bytes() and not (positive / 'donor.stderr').read_bytes()
    assert (positive / 'origin/macro.bin').read_bytes() == good
    row = rows(profile / 'trajectory')[1]
    seen = set()
    for item in q['compiled_refusals']:
        label = item['attack']
        assert label not in seen
        seen.add(label)
        root = folder / label
        stdout, stderr = (root / 'donor.stdout').read_bytes(), (root / 'donor.stderr').read_bytes()
        assert b'HYBRID_READY' not in stdout and b'HYBRID_DAY_RETURN' not in stdout and b'ERROR STOP' in stderr
        raw = (root / 'origin/macro.bin').read_bytes()
        assert SHA(raw) == item['actual_raw_sha256']
        try:
            native(raw, row, meta, parameters)
        except (AssertionError, ValueError, struct.error):
            pass
        else:
            raise AssertionError('Independent complete RIA reader accepted ' + label)
    for item in q['private_input_refusals']:
        root = folder / item['attack']
        key, value = {'private-HeatOn': ('HeatOn', '.TRUE.'), 'private-VaporCond': ('VaporCond', '.TRUE.'), 'private-constitutive-ksat': ('RIA_UHCC_ksat', '11.0 5.0')}[item['attack']]
        before = (positive / 'original/swap.swp').read_bytes()
        expected, count = re.subn(rb'(?mi)^([ \t]*' + key.encode() + rb'[ \t]*=[ \t]*)[^!\r\n]*', lambda m: m[1] + value.encode(), before)
        assert count == 1 and (root / 'original/swap.swp').read_bytes() == expected
        assert (root / 'origin/macro.bin').read_bytes() == good
        assert b'HYBRID_READY' not in (root / 'donor.stdout').read_bytes() and b'ERROR STOP' in (root / 'donor.stderr').read_bytes()
    return dict(native_refusals=43 + 6 * original['snow'], private_input_refusals=3, own_positive=True, compiled_files=len(postimages), actual_compiler=q['actual_compiler_source'])


def postimage(pool, folder, profile, meta, parameters):
    q, old = read(folder / 'RESULT.json'), read(profile / 'RESULT.json')
    assert q['profile_RESULT_sha256'] == SHA((profile / 'RESULT.json').read_bytes())
    assert q['actual_original_BUILD_sha256'] == old['actual_BUILD_sha256'] and not q['completed_full35_periods_replayed']
    baseline = pool.resolve(old['build_root'])
    current, current_meta = build(pool, q['actual_current_build_root'], q['actual_current_BUILD_sha256'])
    inputs = pool.resolve(q['actual_input_root'])
    old_inputs = pool.resolve(old['input_root'])
    assert dict(q['input_inventory']) == current_meta['inputs']
    for name, digest in current_meta['inputs'].items():
        before, after = (old_inputs / name).read_bytes(), (inputs / name).read_bytes()
        assert SHA(after) == digest
        if name == 'swap.swp':
            expected, count = re.subn(rb'(?mi)^([ \t]*SWINCO[ \t]*=[ \t]*)2\b', lambda match: match[1] + b'1', before)
            assert count == 1 and after == expected
        else:
            assert before == after
    count = len(compiled(baseline, current))
    sources = generated(baseline, current)
    short = q['short_native']
    if old['kind'] == 'cde':
        assert short and short['actual_initial2_physical_prefix_exact'] and short['actual_initial2_complete_day2_native_exact']
        data = rows(folder / 'short-trajectory')
        assert len(data) == 2 and physical(data) == physical(rows(profile / 'trajectory')[:2])
        assert physical(rows(folder / 'short-own-1')) == physical(data[1:])
        exact_native(folder / 'short-trajectory/accepted-column-1-day-2.zip', profile / 'trajectory/accepted-column-1-day-2.zip')
        exact_native(folder / 'short-own-1/accepted-column-1-day-2.zip', folder / 'short-trajectory/accepted-column-1-day-2.zip')
        for day in (1, 2):
            with zipfile.ZipFile(io.BytesIO((folder / f'short-trajectory/accepted-column-1-day-{day}.zip').read_bytes())) as z:
                receipt = json.loads(z.read('checkpoint.json'))
                assert receipt['binding'] == current_meta['binding'] and receipt['receipt'] == data[day - 1]
                native(z.read('macro.bin'), data[day - 1], current_meta, parameters)
    else:
        assert short is None
    return dict(compiled_files=count, generated_sources=sources, cde_short_native_exact=bool(short), actual_compiler=q['actual_compiler_source'])


def transactions(pool, folder, profile, parameters):
    q = read(folder / 'RESULT.json')
    assert q['status'] == 'RIA12_THERMAL_ACTUAL_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_EXACT_PASS_NOT_ADMITTED'
    assert q['full35_producer'] == read(profile / 'RESULT.json')['source']
    assert q['full35_periods_replayed'] == q['compiler_executions'] == 0 and not q['original_checkpoint_metadata_or_binding_rewritten']
    assert q['external_worker_prepares'] == 3 and q['external_commits'] == 1
    assert all(q[key] for key in ('discard_no_day_advance', 'replay_exact', 'accept_exact', 'recovered_next_day_exact', 'origin_unchanged'))
    _, meta = build(pool, q['actual_build_root'], q['actual_BUILD_sha256'])
    data = rows(profile / 'trajectory')
    stages = [('external/trial-1', 5), ('external/trial-2', 5), ('external', 5), ('recovered/trial-1', 6)]
    for stage, day in stages:
        path = folder / stage / f'accepted-column-1-day-{day}.zip'
        with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
            receipt = json.loads(z.read('checkpoint.json'))
            binding = receipt['binding']
            if 'external_daily' in binding:
                assert {k: v for k, v in binding.items() if k != 'external_daily'} == meta['binding']
            else:
                assert binding == meta['binding']
            actual_receipt = receipt['receipt']
            if stage == 'external':
                coupling = actual_receipt['coupling']
                assert coupling['id'] == 'original-output' and coupling['revision'] == 1 and coupling['origin_revision'] == 0 and coupling['origin_day'] == 4 and coupling['forcing'] == 'original-project'
                assert coupling['origin_sha256'] == SHA(pool.resolve(q['actual_origin']).read_bytes())
            else:
                assert 'coupling' not in actual_receipt
            assert physical([{k: v for k, v in actual_receipt.items() if k != 'coupling'}]) == physical([data[day - 1]])
            assert all(SHA(z.read(name)) == digest for name, digest in receipt['files'].items())
            native(z.read('macro.bin'), data[day - 1], meta, parameters)
    exact_native(folder / 'external/trial-1/accepted-column-1-day-5.zip', folder / 'external/trial-2/accepted-column-1-day-5.zip')
    exact_native(folder / 'external/trial-2/accepted-column-1-day-5.zip', folder / 'external/accepted-column-1-day-5.zip')
    if q['targeted_current_prefix_days']:
        assert q['targeted_current_prefix_days'] == 4 and physical(rows(folder / 'current-prefix4')) == physical(data[:4])
        exact_native(folder / 'current-prefix4/accepted-column-1-day-4.zip', profile / 'trajectory/accepted-column-1-day-4.zip')
    return dict(exact_external_transaction=True, actual_control_source=q['actual_observer_source'], targeted_prefix_days=q['targeted_current_prefix_days'])


def setup_windows(pool):
    for name in ('RIA12_WINDOWS_RAW_V1', 'RIA12_BOUNDARY_WINDOWS_RAW_V1', 'RIA12_THERMAL_WINDOWS_RAW_V1'):
        store = pool.store(name)
        for path, item in json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():
            pool.add(path, name, item['prefix'])
    return 'RIA12_THERMAL_WINDOWS_RAW_V1'


def audit(platform, optimization):
    assert platform in ('Windows', 'Ubuntu') and optimization in ('O0', 'O2')
    with ExitStack() as stack:
        pool = Pool(stack)
        if platform == 'Windows':
            name = setup_windows(pool)
            supplement = name
            e = 'evidence/'
            supplement_prefix = 'evidence/ria12-thermal-Windows-native-postimages-external-v1/'
        else:
            name = 'RIA12_THERMAL_UBUNTU_' + optimization + '_ORIGINAL_V1'
            supplement = 'RIA12_THERMAL_UBUNTU_' + optimization + '_CONTROLS_V1'
            pool.add('/home/runner/work/_temp/proof/current', name, 'current')
            pool.add('/home/runner/work/_temp/builds', name, 'compiled')
            pool.add('/home/runner/work/_temp/proof/supplement', supplement, '')
            pool.store(supplement)
            e = 'current/'
            supplement_prefix = ''
        store = pool.store(name)
        result = []
        for kind in ('water', 'cde'):
            for snow in (0, 1):
                short_label=f'{kind}-snow{snow}'
                label=(f'ria12-thermal-{kind}-snow{snow}-Windows-{optimization}-full35-' + ('v2' if optimization=='O0' else 'v1')) if platform=='Windows' else short_label
                profile=pool.view(name,e+label)
                samples=pool.view(name,e+label+'-original-samples')
                actual=audit_profile(profile,samples,pool.resolve)
                original=json.loads(store.get(e+label+'-INDEPENDENT.json'))
                observer=original.pop('actual_observer_source');actual.pop('actual_observer_source')
                assert actual==original,'Fresh original scientific read differs: '+label
                q=read(profile/'RESULT.json');_,meta=build(pool,q['build_root'],q['actual_BUILD_sha256'])
                parameters=(samples/'original-parameters.bin').read_bytes()
                if platform=='Windows':
                    control=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-controls')
                    post=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-opposite-initial')
                    tx=pool.view(name,supplement_prefix+short_label+'-'+optimization+'-transactions') if snow or kind=='cde' else None
                else:
                    control=pool.view(name,'current/'+short_label+'-controls') if kind=='water' else pool.view(supplement,short_label+'-controls')
                    post=pool.view(name,'current/'+short_label+'-opposite-initial')
                    tx=pool.view(supplement,short_label+'-transactions') if snow or kind=='cde' else None
                result.append(dict(kind=kind,snow=snow,optimization=optimization,actual_producer=q['source'],actual_compiler=q['actual_compiler_source'],original_observer=observer,
                                   independent=actual,native_controls=controls(pool,control,profile,meta,parameters),opposite_initial=postimage(pool,post,profile,meta,parameters),
                                   external=transactions(pool,tx,profile,parameters) if tx else None,native=7,cold=3))
        return dict(status='ACTUAL_RIA_THERMAL_SNOW_CENTRAL_ORIGINAL_STOCK_WATER_SOLUTE_TEMPERATURE_NATIVE_COLD_COMPILED_AND_EXTERNAL_PASS',platform=platform,optimization=optimization,
                    contexts=result,full35_periods=4,model_executions=0,compiler_executions=0,metadata_or_source_views_faked=False,canonical_admission=False)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();q=audit(a.platform,a.optimization)
    with a.output.open('x') as out:json.dump(q,out,indent=2)
    print(q['status'],a.platform,a.optimization)


def preservation():
    with ExitStack() as stack:
        pool=Pool(stack);name=setup_windows(pool);result=[]
        def check(label,left,right,record,expected):
            a,b=read(left/'BUILD.json'),read(right/'BUILD.json')
            assert a['inputs']==b['inputs'] and 'original_ria12_thermal' not in b['identity']['original_output']
            sources=generated(left,right);files=compiled(left,right)
            assert len(files)==expected and sources==record['generated_sources']
            original=record['compiled'];original=original['files'] if isinstance(original,dict) else original
            project=lambda items:[{k:r[k] for k in ('file','left_sha256','right_sha256')} for r in items]
            assert files==project(original)
            result.append(dict(label=label,compiled=files,generated_sources=sources))
        for opt in ('O0','O2'):
            q=read(pool.view(name,f'evidence/ria12-thermal-model1-{opt}-preservation-v1/RESULT.json'))
            left,_=build(pool,q['actual_original_build_root'],q['actual_original_BUILD_sha256']);right,_=build(pool,q['actual_current_build_root'],q['actual_current_BUILD_sha256'])
            assert q['actual_current_compiler']=='0f0837e77901fd9e3b752d0812a8be53aa0f3352' and q['model_executions']==0
            check('NoSnow-model1-'+opt,left,right,q,43)
        for role,opt,count in [('primary-water','O0',44),('primary-cde','O2',53),('boundary-water','O0',45),('boundary-cde','O2',53)]:
            q=read(pool.view(name,f'evidence/ria12-thermal-preserve-{role}-{opt}-v1/RESULT.json'))
            left=pool.view(q['original_archive'],q['original_archive_prefix']);right,_=build(pool,q['actual_current_build_root'],q['actual_current_BUILD_sha256'])
            assert SHA((left/'BUILD.json').read_bytes())==q['actual_original_BUILD_sha256'] and q['model_executions']==0
            check('NoHeat-'+role+'-'+opt,left,right,q,count)
        compilers=read(pool.view(name,'evidence/RIA12_THERMAL_REAL_OLD_SNOW_MODEL1_COMPILERS_V1.json'))
        assert not compilers['HEAD_or_source_views_faked'] and compilers['actual_before_head']==compilers['actual_restored_head']=='0f0837e77901fd9e3b752d0812a8be53aa0f3352'
        for kind,opt,count in [('water','O0',49),('cde','O2',58)]:
            a=next(q for q in compilers['outputs'] if q['phase']=='actual-parent' and q['kind']==kind)
            b=next(q for q in compilers['outputs'] if q['phase']=='actual-current' and q['kind']==kind)
            assert a['actual_compiler_source']==a['actual_completion_head']=='8e8f2a4c7ff28e4e4845c4b5554894a4bc3c5af1'
            assert b['actual_compiler_source']==b['actual_completion_head']==compilers['actual_restored_head'] and a['returncode']==b['returncode']==0
            q=read(pool.view(name,f'evidence/RIA12_THERMAL_SNOW_MODEL1_{kind.upper()}_{opt}_PRESERVED_V1.json'))
            left,right=pool.resolve(a['actual_build_root']),pool.resolve(b['actual_build_root'])
            assert read(left/'BUILD.json')['identity']['original_output']['thermal_output'] is True
            check('Snow-model1-'+kind+'-'+opt,left,right,q,count)
        return dict(status='ACTUAL_ALL8_UNSELECTED_NOHEAT_RIA_NOSNOW_AND_SNOW_MODEL1_WHOLE_GENERATED_COMPILED_PRESERVATION_PASS',contexts=result,model_executions=0,compiler_executions=0)


def reference_correction():
    import math
    with ExitStack() as stack:
        pool=Pool(stack);name=setup_windows(pool)
        original=pool.store('RIA12_WINDOWS_RAW_V1').get('original-provider/build/swap-selected/readswap.f90')
        before='            ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 1))'
        after='            ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 4))'
        old=original.replace(b'\r\n',b'\n').decode('cp1252');assert old.count(before)==1 and after not in old
        reports=[]
        for opt in ('O0','O2'):
            folder=pool.view(name,f'evidence/ria12-ksat-mapping-component-{opt}-v1');q=read(folder/'RESULT.json')
            directory=pool.view(name,f'compiled/ria12-ksat-mapping-component-{opt}-v1')
            assert q['actual_source']=='978c7e7d6048141db84d50e250142a4ee101d6d2' and q['actual_calls']==10 and q['legacy_negative_mean_calls']==7 and q['model_periods']==0
            assert q['original_reader_sha256']==SHA(original) and q['corrected_reader_sha256']==SHA(original.decode('cp1252').replace(before,after,1).encode('cp1252'))
            assert all(c['returncode']==0 for c in q['compiler']) and not (folder/'original.stderr').read_bytes()
            assert SHA((directory/'mapping.exe').read_bytes())==q['executable_sha256']
            assert SHA((directory/'driver.f90').read_bytes())==q['driver_sha256']
            assert (directory/'functions.f90').read_bytes()==pool.store('RIA12_WINDOWS_RAW_V1').get('original-provider/build/swap-selected/functions.f90')
            raw=(folder/'original.stdout').read_bytes();assert SHA(raw)==q['stdout_sha256']
            observed=[]
            for line in raw.decode().splitlines():
                if not line.startswith('ORIGINAL_KSAT_MAPPING '):continue
                words=line.split();assert len(words)==8;layer,index=map(int,words[1:3]);values=list(map(float,words[3:]));head,legacy,corrected,oldmean,newmean=values
                assert layer in (1,2) and 1<=index<=5 and head==[0.,-5.,-10.,-1200.,-1e6][index-1]
                assert all(map(math.isfinite,values)) and legacy==[-5.,-10.][layer-1] and corrected==[10.,5.][layer-1] and newmean>0
                observed.append((layer,index,oldmean))
            assert len(observed)==len(set((a,b) for a,b,_ in observed))==10 and sum(v<0 for _,_,v in observed)==7
            reports.append(dict(optimization=opt,actual_original_calls=10,negative_legacy_means=7,corrected_original_saturated_Ksat=[10.,5.]))
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                for kind in ('water','cde'):
                    for snow in (0,1):
                        if platform=='Windows':
                            version='v2' if opt=='O0' else 'v1';profile=pool.view(name,f'evidence/ria12-thermal-{kind}-snow{snow}-Windows-{opt}-full35-{version}')
                        else:
                            archive=f'RIA12_THERMAL_UBUNTU_{opt}_ORIGINAL_V1';pool.add('/home/runner/work/_temp/builds',archive,'compiled');profile=pool.view(archive,f'current/{kind}-snow{snow}')
                        q=read(profile/'RESULT.json');directory=pool.resolve(q['build_root'])
                        actual=(directory/'readswap.f90').read_bytes().replace(b'\r\n',b'\n').decode('cp1252')
                        assert actual==old.replace(before,after,1),'Incomplete original Ksat mapping source inverse'
        return dict(status='COMPLETE_ORIGINAL_RIA_HCOMEAN_O0_O2_AND_ALL16_ACTUAL_READER_LITERAL_KSAT_CORRECTION_PASS',optimizations=reports,actual_model_readers=16,physical_equations_changed=False,parameter_binding_corrected=True,tolerance_changed=False,model_executions=0,compiler_executions=0)


def original_outputs():
    from implicit_conductivity_forensics import output_records, output_continuation
    with ExitStack() as stack:
        pool=Pool(stack);win=setup_windows(pool);results=[]
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                archive=win if platform=='Windows' else f'RIA12_THERMAL_UBUNTU_{opt}_ORIGINAL_V1'
                if platform=='Ubuntu':pool.add('/home/runner/work/_temp/builds',archive,'compiled')
                for kind in ('water','cde'):
                    for snow in (0,1):
                        if platform=='Windows':
                            version='v2' if opt=='O0' else 'v1';prefix=f'evidence/ria12-thermal-{kind}-snow{snow}-Windows-{opt}-full35-{version}'
                        else:prefix=f'current/{kind}-snow{snow}'
                        profile=pool.view(archive,prefix);q=read(profile/'RESULT.json');_,meta=build(pool,q['build_root'],q['actual_BUILD_sha256'])
                        def outputs(root):return {p.name:output_records(p.read_bytes(),p.name) for p in (root/'original').glob('result_output.*') if p.suffix in ('.csv','.bin')}
                        warm=outputs(profile/'trajectory');observed=[]
                        for item in q['cold']:
                            low,high=item['start'],item['end'];proof=output_continuation(warm,outputs(profile/f'own-{low}'),meta['identity']['original_output'],low,high,meta['project']['start_date'])
                            assert proof==item['exact_user_output']
                            observed.append(dict(low=low,high=high,exact=proof))
                        results.append(dict(platform=platform,optimization=opt,kind=kind,snow=snow,cold=observed))
        assert len(results)==16 and sum(len(x['cold']) for x in results)==48
        return dict(status='ACTUAL_ALL16_ORIGINAL_USER_OUTPUTS_ALL48_COLD_CONTINUATIONS_FRESH_EXACT_PASS',contexts=results,model_executions=0,compiler_executions=0)


def short_proofs():
    from ria12_thermal_science import original_samples,standard_cde_daily
    from implicit_conductivity_forensics import water,output_records,output_continuation
    with ExitStack() as stack:
        pool=Pool(stack);name=setup_windows(pool);results=[]
        for kind in ('water','cde'):
            for snow in (0,1):
                label=f'ria12-thermal-{kind}-snow{snow}-O0-corrected-short-v1';profile=pool.view(name,'evidence/'+label);samples=pool.view(name,'evidence/'+label+'-original-samples')
                q=read(profile/'RESULT.json');sample=read(samples/'RESULT.json')
                assert q['status']=='ACTUAL_RIA12_THERMAL_SNOW_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['source']==q['actual_completion_head']=='7562dbb2ac547832494952140e3ee58734670707'
                _,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);data=rows(profile/'trajectory');assert len(data)==2 and [x['day'] for x in data]==[1,2]
                assert sample['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((profile/'trajectory/daily.jsonl').read_bytes())
                component=pool.resolve(sample['component_root']);assert read(component/'COMPONENT.json')==sample['component']
                original_samples(samples,component,sample,pool.resolve(q['input_root']),data)
                parameters=(samples/'original-parameters.bin').read_bytes();cold=rows(profile/'own-1');assert physical(cold)==physical(data[1:])
                water(data);water(cold)
                if kind=='cde':standard_cde_daily(profile/'trajectory',data,meta['project']['start_date']);standard_cde_daily(profile/'own-1',cold,meta['project']['start_date'])
                for folder,observed in ((profile/'trajectory',data),(profile/'own-1',cold)):
                    for row in observed:
                        with zipfile.ZipFile(io.BytesIO((folder/f"accepted-column-1-day-{row['day']}.zip").read_bytes())) as z:
                            receipt=json.loads(z.read('checkpoint.json'));assert receipt['binding']==meta['binding'] and receipt['receipt']==row
                            assert all(SHA(z.read(n))==digest for n,digest in receipt['files'].items())
                            native(z.read('macro.bin'),row,meta,parameters)
                            from ria12_thermal_native import physical_restart
                            physical_restart(z.read('result.end'),row,meta)
                exact_native(profile/'trajectory/accepted-column-1-day-2.zip',profile/'own-1/accepted-column-1-day-2.zip')
                def outputs(root):return {p.name:output_records(p.read_bytes(),p.name) for p in (root/'original').glob('result_output.*') if p.suffix in ('.csv','.bin')}
                proof=output_continuation(outputs(profile/'trajectory'),outputs(profile/'own-1'),meta['identity']['original_output'],1,2,meta['project']['start_date']);assert proof==q['cold'][0]['exact_user_output']
                results.append(dict(kind=kind,snow=snow,days=2,cold=1,original_stock_difference_cm=sample['maximum_original_theta_stock_difference_cm']))
        return dict(status='ACTUAL_FOUR_CORRECTED_RIA_HEAT_SNOW_SHORT_ORIGINAL_STOCK_COMPLETE_NATIVE_AND_USER_COLD_PASS',contexts=results,model_executions=0,compiler_executions=0)


if __name__=='__main__':main()
