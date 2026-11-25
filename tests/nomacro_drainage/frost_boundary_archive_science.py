"""Independent original-byte Frost boundary budgets, native state and cold controls."""
import hashlib,io,json,math,re,struct,zipfile
from decimal import Decimal,localcontext
from analytical_hydraulic_archives import SHA
from explicit_bottom9_archive_science import ReadView
from frost_history_state_central import original_history
from original_output_files import compare

PHYSICAL=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm',
          'drainage_outward_cm','bottom_outward_cm','solute_end_mg_cm2','solute_start_mg_cm2',
          'solute_ledger_mg_cm2','uptake_terms_cm')


def read(path):return json.loads(path.read_text())
def physical(row,kind):return {key:row[key] for key in (PHYSICAL if kind=='cde' else PHYSICAL[:7])}


def budgets(folder,kind):
    rows=[json.loads(line,parse_float=Decimal) for line in (folder/'daily.jsonl').read_text().splitlines()]
    assert len(rows)==35
    water=chemical=prefix_max=Decimal(0);flows=[Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec=80
        for day,row in enumerate(rows,1):
            assert row['day']==day and row['committed'] is True
            def finite(value):
                if isinstance(value,list):return all(finite(item) for item in value)
                return value.is_finite() if isinstance(value,Decimal) else math.isfinite(value)
            assert all(finite(value) for value in physical(row,kind).values())
            before,after,flux=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm']
            error=sum(before)-sum(after)+sum(flux[:7])-sum(flux[7:]);water=max(water,abs(error))
            assert abs(error)<=Decimal('1e-10') and abs(row['kernel_residual_cm'])<=Decimal('1e-10')
            if kind=='cde':
                ledger=row['solute_ledger_mg_cm2'];start=row['solute_start_mg_cm2'];end=row['solute_end_mg_cm2']
                error=end-start-sum(ledger[2:5])+sum(ledger[5:8]);chemical=max(chemical,abs(error))
                assert abs(error)<=Decimal('1e-10') and abs(end-ledger[0])<=Decimal('1e-10')
                flows=[a+b for a,b in zip(flows,ledger[2:8])]
                error=end-rows[0]['solute_start_mg_cm2']-sum(flows[:3])+sum(flows[3:]);prefix_max=max(prefix_max,abs(error));assert abs(error)<=Decimal('1e-10')
    snow=max(row['stock_end_cm'][2] for row in rows);assert snow>0
    positive=sum(sum(row['solute_ledger_mg_cm2'][2:5]) for row in rows) if kind=='cde' else Decimal(0)
    solute=max(row['solute_end_mg_cm2'] for row in rows) if kind=='cde' else Decimal(0)
    if kind=='cde':assert positive>0 and solute>0
    witness=[list(map(float,line.split()[1:])) for line in (folder/'original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_FROST_WITNESS ')]
    assert len(witness)==36 and all(len(row)==6 and all(map(math.isfinite,row)) for row in witness)
    assert all(row[-1]==1 for row in witness[1:]);partial=sum(0<row[0]<1 for row in witness);assert partial>0
    return dict(days=35,daily_water_max_cm=str(water),daily_cde_max_mg_cm2=str(chemical),
                every_prefix_cde_max_mg_cm2=str(prefix_max),maximum_snow_stock_cm=str(snow),
                positive_chemical_input_mg_cm2=str(positive),maximum_chemical_stock_mg_cm2=str(solute),
                actual_partial_frost_output_events=partial,accumulated_water_equivalence_claimed=False)


def native(raw,meta,case):
    nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');implicit=case['implicit'];bottom=case['bottom']
    expected={('water',0):b'S5FBW001',('cde',0):b'S5FBC001',('water',1):b'S5FBW002',('cde',1):b'S5FBC002'}[(case['kind'],implicit)]
    assert raw[:8]==expected==meta['identity']['original_output']['native_codec'].encode()
    domain=struct.pack('<10i',1,nodes,0,solute,2,1,1,1,1,2);assert raw.count(domain+domain)==1
    if solute:
        n=18+nodes;header=struct.pack('<3i',1,nodes,n);assert raw.count(header+header)==1
        values=struct.unpack_from('<'+str(2*n)+'d',raw,raw.index(header+header)+24)
        assert values[:n]==values[n:] and all(map(math.isfinite,values)) and values[0]>=0
    if implicit:
        header=(4,nodes,solute,1,2,bottom,1,0);assert struct.unpack('<16i',raw[-96:-32])==header+header
        values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))


def checkpoint(path,meta,case,expected,external=False):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        record=json.loads(z.read('checkpoint.json'));binding=record['binding']
        if external:binding={k:v for k,v in binding.items() if k!='external_daily'}
        assert binding==meta['binding'] and physical(record['receipt'],case['kind'])==physical(expected,case['kind'])
        assert all(SHA(z.read(name))==digest for name,digest in record['files'].items())
        raw=z.read('macro.bin');native(raw,meta,case);original_history(z.read('result.end'),case['kind'],2)
        return raw,z.read('result.end')


def compiled_controls(folder,warm,data,meta,case):
    record=read(folder/'RESULT.json')
    assert record['status']=='ACTUAL_FROST_BOUNDARY_COMPILED_NATIVE_ROOT_SNOW_AND_ACTIVE_TRANSACTIONS_PASS_NOT_ADMITTED'
    groups=[('native',record['native_refusals'])]
    assert len(groups[0][1])==(44 if case['kind']=='cde' else 39)
    if case['implicit']:
        root=record['root_refusals'];assert root['accepted_model_days']==0 and root['actual_boundary']==case['bottom'] and len(root['refusals'])==25
        groups.append(('root',root['refusals']))
    good=checkpoint(warm/'accepted-column-1-day-4.zip',meta,case,data[3])[0];count=0
    for stem,items in groups:
        for item in items:
            target=folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes()
            assert b'HYBRID_READY' not in outputs[0].read_bytes() and b'HYBRID_DAY_RETURN' not in outputs[0].read_bytes()
            assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
    for stem,recovered,start in [('snow-transactions/external','snow-transactions/recovered',4),('frost-external','frost-recovered',19)]:
        samples=[checkpoint(folder/stem/stage/f'accepted-column-1-day-{start+1}.zip',meta,case,data[start],True) for stage in ('trial-1','trial-2','')]
        assert samples[0]==samples[1]==samples[2]
        checkpoint(folder/recovered/'trial-1'/f'accepted-column-1-day-{start+2}.zip',meta,case,data[start+1],True)
    return dict(actual_compiled_refusals=count,accepted_mutant_days=0,actual_discard_replay_accept_recovery_contexts=2)


def case_audit(store,name,case):
    folder=ReadView(store,'current/'+name);profile=folder/'science';record=read(profile/'RESULT.json');warm=profile/'trajectory'
    assert record['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+case['kind'].upper()+'_SHORT_PASS_NOT_ADMITTED'
    projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[record['build_root']]
    build=ReadView(store,entry['archive_prefix']);meta=read(build/'BUILD.json');identity=meta['identity']
    assert SHA((build/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']==record['trajectory']['build_sha256']
    assert meta['project']['water_tolerance']==1e-10 and meta['project']['nodes']==34
    actual_inputs={p.relative_to(folder/'inputs').as_posix():SHA(p.read_bytes()) for p in (folder/'inputs').rglob('*') if p.is_file()}
    assert actual_inputs==record['inventory']
    text=(folder/'inputs/swap.swp').read_text(encoding='cp1252')
    for key,value in dict(SWMACRO=0,SWBOTB=case['bottom'],SWKIMPL=case['implicit'],SWSOLU=int(case['kind']=='cde'),SWHYST=2,SWINCO=2,SWFROST=1,SWSNOW=1,SWDRA=1,NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1).items():
        found=re.findall(r'(?mi)^\s*'+key+r'\s*=\s*([+-]?\d+)\s*(?:!.*)?$',text);assert len(found)==1 and int(found[0])==value
    for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for name,digest in identity['donor_objects'].items():assert SHA(store.get('original-provider-build/swap-obj/'+name))==digest
    executable='.exe' if any(p.name=='day_donor.exe' for p in build.rglob('*')) else ''
    for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+executable)).read_bytes())==digest
    publisher='restart_publish.dll' if executable else 'restart_publish.so'
    assert SHA((build/publisher).read_bytes())==identity['restart_publisher']['library_sha256']
    assert '-'+record['optimization'] in identity['donor_flags'] and '-'+record['optimization'] in identity['kernel_flags']
    science=budgets(warm,case['kind']);data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
    samples=[]
    for path in warm.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);checkpoint(path,meta,case,data[day-1]);samples.append(day)
    assert set(samples)=={2,4,19,23,30,34,35} and len(samples)==7
    assert [(item['start'],item['end']) for item in record['own']]==[(2,4),(19,23),(30,34)]
    for start,end in ((2,4),(19,23),(30,34)):
        cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
        assert [physical(row,case['kind']) for row in rows]==[physical(row,case['kind']) for row in data[start:end]]
        assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
        compare(warm/'original',cold/'original',identity['original_output'],start,end,meta['project']['start_date'])
    controls=compiled_controls(folder/'controls',warm,data,meta,case)
    return dict(case=case,actual_compiler_source=record['source'],optimization=record['optimization'],science=science,
                native_samples=7,exact_cold_windows=3,controls=controls)
