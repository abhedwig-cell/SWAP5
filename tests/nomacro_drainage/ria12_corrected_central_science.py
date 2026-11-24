"""Independent fresh corrected NoHeat scientific reads at explicit immutable locations."""
import argparse,json,io,re,struct,zipfile,math
from pathlib import Path
from contextlib import ExitStack
from decimal import Decimal,localcontext
from analytical_hydraulic_archives import SHA
from explicit_bottom9_snow_analytical_central_science import Pool,read,rows,build,exact_native
from ria12_boundary_central_science import compiled,generated
from ordinary_pond_evidence import physical
from ria12_corrected_native import native
from ria12_corrected_science import audit_profile

def controls(pool, folder, profile, meta, parameters):
    q = read(folder / 'RESULT.json')
    original = read(profile / 'RESULT.json')
    assert q['genuine_checkpoint_producer'] == original['source'] and q['accepted_model_days'] == q['model_periods'] == 0
    assert len(q['compiled_refusals']) == 43 and len(q['private_input_refusals']) == 3 and q['own_positive_ready']
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
    return dict(native_refusals=43, private_input_refusals=3, own_positive=True, compiled_files=len(postimages), actual_compiler=q['actual_compiler_source'])


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
    return dict(compiled_files=count, generated_sources=sources, cde_short_native_exact=bool(short), actual_compiler=q['actual_compiler_source'], actual_original_compiler=old['actual_compiler_source'], actual_original_model_producer=old['source'], retained_original_observer_compiler_field=q['original_compiler_source'], original_observer_field_is_model_producer=q['original_compiler_source']==old['source'])


def transactions(pool, folder, profile, parameters):
    q = read(folder / 'RESULT.json')
    assert q['status'] == 'RIA12_CORRECTED_ACTUAL_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_EXACT_PASS_NOT_ADMITTED'
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



def audit(platform, optimization):
    assert platform in ('Windows','Ubuntu') and optimization in ('O0','O2')
    with ExitStack() as stack:
        pool=Pool(stack)
        if platform=='Ubuntu':
            name='RIA12_CORRECTED_UBUNTU_'+optimization+'_ORIGINAL_V1'
            for actual,prefix in [('/home/runner/work/_temp/proof/current','current'),('/home/runner/work/_temp/builds','compiled'),('/home/runner/work/_temp/provider/build','original-provider-build')]:pool.add(actual,name,prefix)
            pool.store(name)
        else:
            name='RIA12_CORRECTED_WINDOWS_RAW_V1'
            store=pool.store(name)
            for actual,item in json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(actual,name,item['prefix'])
            # Complete original constitutive executables remain in their accepted
            # central parent archive; never duplicate or recompile their models.
            parent=pool.store('RIA12_WINDOWS_RAW_V1')
            for actual,item in json.loads(parent.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(actual,'RIA12_WINDOWS_RAW_V1',item['prefix'])
        result=[]
        for label,kind in [('water-primary-dry','water'),('cde-primary-dry','cde'),('water-boundary5','water'),('cde-wet8-d1','cde')]:
            if platform=='Ubuntu':
                profile=pool.view(name,'current/'+label);sample=pool.view(name,'current/'+label+'-original-samples');original=read(pool.view(name,'current/'+label+'-INDEPENDENT.json'))
                control=pool.view(name,'current/'+label+'-controls');post=pool.view(name,'current/'+label+'-opposite-initial');tx=pool.view(name,'current/'+label+'-transactions')
            else:
                base='ria12-corrected-'+label+'-Windows-'+optimization+'-full35-v1'
                profile=pool.view(name,'evidence/'+base);sample=pool.view(name,'evidence/'+base+'-original-samples');original=read(pool.view(name,'evidence/'+base+'-SCIENCE.json'))
                base='evidence/ria12-corrected-'+label+'-'+optimization
                control=pool.view(name,base+'-native-controls-v1');post=pool.view(name,base+'-opposite-initial-v1');tx=pool.view(name,base+'-external-v1')
            actual=audit_profile(profile,sample,pool.resolve);observer=original.pop('actual_observer_source');actual.pop('actual_observer_source');assert actual==original
            q=read(profile/'RESULT.json');_,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);parameters=(sample/'original-parameters.bin').read_bytes()
            result.append(dict(case=label,kind=kind,optimization=optimization,actual_model_producer=q['source'],actual_compiler=q['actual_compiler_source'],actual_original_observer=observer,independent=actual,native_controls=controls(pool,control,profile,meta,parameters),opposite_initial=postimage(pool,post,profile,meta,parameters),external=transactions(pool,tx,profile,parameters)))
        return dict(status='FOUR_ORIGINAL_CORRECTED_NOHEAT_CENTRAL_GLOBAL_ORIGINAL_RIA_NATIVE_COLD_COMPILED_AND_EXTERNAL_PASS_NOT_ADMITTED',platform=platform,optimization=optimization,contexts=result,full35_periods=4,model_executions=0,compiler_executions=0,source_or_metadata_views_faked=False,canonical_admission=False,extra_wet_primary_stress_inherited_PASS=False)

def main():
    p=argparse.ArgumentParser();p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.platform,a.optimization)
    with a.output.open('x') as out:json.dump(q,out,indent=2)
    print(q['status'],a.platform,a.optimization)


def setup(pool,platform,opt):
    if platform=='Windows':
        name='RIA12_CORRECTED_WINDOWS_RAW_V1';store=pool.store(name)
        for actual,item in json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(actual,name,item['prefix'])
    else:
        name='RIA12_CORRECTED_UBUNTU_'+opt+'_ORIGINAL_V1'
        for actual,prefix in [('/home/runner/work/_temp/proof/current','current'),('/home/runner/work/_temp/builds','compiled')]:pool.add(actual,name,prefix)
    return name

def original_outputs():
    from implicit_conductivity_forensics import output_records,output_continuation
    result=[]
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            with ExitStack() as stack:
                pool=Pool(stack);name=setup(pool,platform,opt)
                for label in ('water-primary-dry','cde-primary-dry','water-boundary5','cde-wet8-d1'):
                    prefix='evidence/ria12-corrected-'+label+'-Windows-'+opt+'-full35-v1' if platform=='Windows' else 'current/'+label
                    profile=pool.view(name,prefix);q=read(profile/'RESULT.json');_,meta=build(pool,q['build_root'],q['actual_BUILD_sha256'])
                    def outputs(root):return {p.name:output_records(p.read_bytes(),p.name) for p in (root/'original').glob('result_output.*') if p.suffix in ('.csv','.bin')}
                    warm=outputs(profile/'trajectory');cold=[]
                    for item in q['cold']:
                        low,high=item['start'],item['end'];proof=output_continuation(warm,outputs(profile/f'own-{low}'),meta['identity']['original_output'],low,high,meta['project']['start_date']);assert proof==item['exact_user_output'];cold.append(dict(low=low,high=high,exact=proof))
                    result.append(dict(platform=platform,optimization=opt,case=label,cold=cold))
    assert len(result)==16 and sum(len(x['cold']) for x in result)==48
    return dict(status='ACTUAL_CORRECTED_NOHEAT_ALL16_ORIGINAL_USER_OUTPUTS_ALL48_COLD_FRESH_EXACT_PASS',contexts=result,model_executions=0,compiler_executions=0)

def thermal_preservation():
    from ria12_pe_bytes import publisher_equivalence
    result=[]
    with ExitStack() as stack:
        pool=Pool(stack);name=setup(pool,'Windows','O0');new=pool.store(name);old=pool.store('RIA12_THERMAL_WINDOWS_RAW_V1')
        for opt in ('O0','O2'):
            for kind in ('water','cde'):
                for snow in (0,1):
                    label=f'ria12-corrected-preserve-thermal-{kind}-snow{snow}-{opt}-v1';q=read(pool.view(name,'evidence/'+label+'/RESULT.json'));directory,meta=build(pool,q['actual_build_root'],q['actual_BUILD_sha256']);prefix=q['original_bundle_archive_prefix'];oldmeta=json.loads(old.get(prefix+'/BUILD.json'))
                    assert meta['inputs']==oldmeta['inputs'] and 'original_ria12_thermal' in meta['identity']['original_output'] and 'original_ria12_corrected' not in meta['identity']['original_output'] and q['model_executions']==0 and not q['original_metadata_rewritten']
                    files=[]
                    for item in q['files']:
                        before=old.get(prefix+'/'+item['file']);after=(directory/item['file']).read_bytes();assert SHA(before)==item['original_sha256'] and SHA(after)==item['current_sha256'] and len(after)==item['bytes']
                        if before!=after:assert publisher_equivalence(before,after)==item['PE']
                        files.append(item['file'])
                    assert {'day_donor.exe','day_kernel.exe','restart_publish.dll'}<=set(files)
                    result.append(dict(kind=kind,snow=snow,optimization=opt,actual_compiler=q['actual_compiler_source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],generated_and_compiled_files=len(files)))
    assert len(result)==8
    return dict(status='ACTUAL_CORRECTED_NOHEAT_SOURCE_ALL8_THERMAL_GENERATED_AND_COMPILED_PRESERVED',contexts=result,model_executions=0,compiler_executions=0)



def short_proofs():
    from ria12_corrected_science import original_samples,standard_cde_daily
    from implicit_conductivity_forensics import water
    with ExitStack() as stack:
        pool=Pool(stack);name=setup(pool,'Windows','O0')
        parent=pool.store('RIA12_WINDOWS_RAW_V1')
        for actual,item in json.loads(parent.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')).items():pool.add(actual,'RIA12_WINDOWS_RAW_V1',item['prefix'])
        E=pool.view(name,'evidence')
        observed=[]
        cases=[(kind,drain,bottom,f'ria12-corrected-{kind}-d{drain}-b{bottom}-O0-short-v1') for kind in ('water','cde') for drain,bottom in ((1,6),(0,5),(0,6),(0,8),(1,5),(1,8))]
        cases += [(kind,1,6,f'ria12-corrected-{kind}-wet-primary-top-O0-short-v1') for kind in ('water','cde')]
        cases += [(kind,drain,8,f'ria12-corrected-{kind}-wet8-d{drain}-O0-short-v1') for kind,drain in (('water',0),('cde',1))]
        for kind,drain,bottom,label in cases:
          root=E/label;sample_root=E/(label+'-original-samples');q=json.loads((root/'RESULT.json').read_text());sample=json.loads((sample_root/'RESULT.json').read_text());bundle=pool.resolve(q['build_root']);meta=json.loads((bundle/'BUILD.json').read_text());inputs=pool.resolve(q['input_root']);parameters=(sample_root/'original-parameters.bin').read_bytes()
          assert q['days']==2 and q['status']=='ACTUAL_RIA12_CORRECTED_TWO_DAY_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['source']==q['actual_completion_head']==q['build']['actual_completion_head'] and q['source'] in ('aa8580218dff2de7f245e5596d2a5a71ee204c13','8d67858c5c28f9e73a8c1b62dd8aeab1fa59e549')
          assert SHA((bundle/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and meta['identity']['original_output']['original_ria12_corrected']['drainage']==drain and meta['identity']['original_output']['original_ria12_corrected']['bottom']==bottom
          assert sample['profile_RESULT_sha256']==SHA((root/'RESULT.json').read_bytes()) and sample['daily_sha256']==SHA((root/'trajectory/daily.jsonl').read_bytes()) and sample['original_parameter_bytes_sha256']==SHA(parameters)
          rows=lambda p:[json.loads(line) for line in (p/'daily.jsonl').read_text().splitlines()]
          data=rows(root/'trajectory');cold=rows(root/'own-1');assert len(data)==2 and physical(cold)==physical(data[1:])
          original_samples(sample_root,pool.resolve(sample['component_root']),sample,inputs,data)
          proofs=[]
          for folder,actual in ((root/'trajectory',data),(root/'own-1',cold)):
           try:
            proof=water(actual)
           except ValueError as error:
            assert '-wet-primary-top-' in label and str(error)=='Whole actual implicit water inventory does not close'
            daily=[water([row]) for row in actual]
            assert all(actual[i]['stock_start_cm']==actual[i-1]['stock_end_cm'] for i in range(1,len(actual)))
            total=math.fsum([*actual[0]['stock_start_cm'],*(-v for v in actual[-1]['stock_end_cm']),*(v for row in actual for v in row['external_flux_cm'][:7]),*(-v for row in actual for v in row['external_flux_cm'][7:])])
            assert abs(total)>1e-10
            proof=dict(status='EXPECTED_EXTRA_WET_PRIMARY_GLOBAL_INVENTORY_REFUSAL_NOT_ADMITTED',error=str(error),whole_water_residual_cm=total,unchanged_water_limit_cm=1e-10,daily=daily)
           native_days=[]
           for path in folder.glob('accepted-column-1-day-*.zip'):
            day=int(path.stem.rsplit('-',1)[1]);row=next(r for r in actual if r['day']==day)
            with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
             receipt=json.loads(z.read('checkpoint.json'));assert receipt['binding']==meta['binding'] and receipt['receipt']==row and all(SHA(z.read(n))==s for n,s in receipt['files'].items());native(z.read('macro.bin'),row,meta,parameters)
            native_days.append(day)
           chemical=None
           if kind=='cde':
            from groundwater_snow_forensics import clock
            chemical=dict(unchanged_ledger=clock.ledger(actual,len(actual)),actual_daily=standard_cde_daily(folder,actual,meta['project']['start_date']))
           proofs.append(dict(water=proof,solute=chemical,native_days=sorted(native_days)))
          with zipfile.ZipFile(io.BytesIO((root/'trajectory/accepted-column-1-day-2.zip').read_bytes())) as warm_zip,zipfile.ZipFile(io.BytesIO((root/'own-1/accepted-column-1-day-2.zip').read_bytes())) as cold_zip:assert all(warm_zip.read(n)==cold_zip.read(n) for n in ('macro.bin','result.end'))
          peak=Decimal(0)
          with localcontext() as c:
           c.prec=60
           for row in data:
            d=lambda v:Decimal(str(v));residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']));assert abs(residual)<=Decimal('1e-10');peak=max(peak,abs(residual))
          observed.append(dict(case=label,classification='NUMERICAL_FAILURE' if '-wet-primary-top-' in label else 'QUALIFIED_SHORT_NOT_ADMITTED',actual_producer=q['source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],decimal_global_peak_cm=str(peak),original_theta_stock_peak_cm=sample['maximum_original_theta_stock_difference_cm'],warm_cold=proofs))
        assert len(observed)==16 and sum(x['classification']=='NUMERICAL_FAILURE' for x in observed)==2
        assert all(any(p['water'].get('status')=='EXPECTED_EXTRA_WET_PRIMARY_GLOBAL_INVENTORY_REFUSAL_NOT_ADMITTED' for p in x['warm_cold']) for x in observed if x['classification']=='NUMERICAL_FAILURE')
        record=dict(status='FOURTEEN_ORIGINAL_DOMAIN_SHORTS_PASS_TWO_EXTRA_WET_PRIMARY_GLOBAL_REFUSALS_RETAINED_NOT_ADMITTED',qualified_original_short_contexts=14,extra_wet_primary_global_refusals=2,contexts=observed,model_executions=0,compiler_executions=0,full35_periods_replayed=0,canonical_admission=False,whole_scope='PARTIAL / NOT_QUALIFIED')
        return record



def reference_correction():
    from ria12_thermal_central_science import reference_correction as qualified_original_component
    original=qualified_original_component();reports=[]
    with ExitStack() as stack:
        pool=Pool(stack);parent=pool.store('RIA12_WINDOWS_RAW_V1');before=parent.get('original-provider/build/swap-selected/readswap.f90').replace(b'\r\n',b'\n')
        old=b'ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 1))';new=b'ksatfit(1:numlay)       = dble(UHCCpars(1:numlay, 4))';assert before.count(old)==1
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                name=setup(pool,platform,opt)
                for label in ('water-primary-dry','cde-primary-dry','water-boundary5','cde-wet8-d1'):
                    prefix='evidence/ria12-corrected-'+label+'-Windows-'+opt+'-full35-v1' if platform=='Windows' else 'current/'+label
                    q=read(pool.view(name,prefix+'/RESULT.json'));directory,meta=build(pool,q['build_root'],q['actual_BUILD_sha256']);actual=(directory/'readswap.f90').read_bytes().replace(b'\r\n',b'\n')
                    expected=before.replace(old,new,1)
                    selected=meta['identity']['original_output']['original_ria12_corrected']
                    if selected['bottom']==5:
                        # This unchanged inherited native-calendar start guard is
                        # separate from the new constitutive Ksat column correction.
                        from datetime import date
                        epoch=(date.fromisoformat(meta['project']['start_date'])-date(1900,1,1)).days+1
                        anchor=b"call checkdate(ifnd,dates,tend,tstart,'date5 ','readswap//swbotb=5      ')"
                        rebound=b"call checkdate(ifnd,dates,tend,"+str(epoch).encode()+b"d0,'date5 ','readswap//swbotb=5      ')"
                        assert expected.count(anchor)==1;expected=expected.replace(anchor,rebound,1)
                    assert actual==expected
                    assert meta['identity']['original_output']['original_ria12_corrected']['parameter_binding_corrected'] is True
                    reports.append(dict(platform=platform,optimization=opt,case=label,actual_compiler=q['actual_compiler_source'],actual_readswap_sha256=SHA(actual)))
    assert len(reports)==16
    return dict(status='COMPLETE_ORIGINAL_QUALIFIED_RIA_HCOMEAN_AND_ALL16_CORRECTED_NOHEAT_READER_LITERAL_INVERSES_PASS',original_component=original,current_readers=reports,physical_equations_changed=False,tolerance_changed=False,model_executions=0,compiler_executions=0)

if __name__=='__main__':main()
