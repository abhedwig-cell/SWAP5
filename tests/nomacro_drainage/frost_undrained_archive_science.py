"""Independent read-only audit of original undrained Frost scientific bytes."""
import argparse,io,json,math,re,struct,subprocess,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_archive_science import physical
from frost_calendar_state_probe import budgets
from frost_history_state_central import original_history
from frost_calendar_state_portable_custody import source as captured_source
from original_output_files import compare
from frost_boundary_convergence import require_convergence

R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'
PRODUCER='127af752c5519e7f9d9a6894c61137f0ee7f3920'
LOCAL='656cd3ed25c91dc6ab8de12f2525fd30be8e358f'
BASE='df00f9393ac552b0a6cab8ee84f8b8d8c06ac26c'
def read(path):return json.loads(path.read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=R)

def native(raw,meta,case):
    nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');hys=case['hysteresis']
    magic={('water',0):b'S5UDW001',('cde',0):b'S5UDC001',('water',1):b'S5UDW002',('cde',1):b'S5UDC002'}[(case['kind'],case['implicit'])]
    assert raw[:8]==magic==meta['identity']['original_output']['native_codec'].encode()
    thermal=struct.pack('<10i',1,nodes,0,solute,hys,1,1,0,1,2);assert raw.count(thermal+thermal)==1
    header=struct.pack('<4i',1,nodes,solute,7);assert raw.count(header+header)==1
    values=struct.unpack_from('<7d',raw,raw.index(header+header)+32);assert all(math.isfinite(x) and x>=0 for x in values)
    if solute:
        n=20+nodes;header=struct.pack('<3i',2,nodes,n);assert raw.count(header+header)==1
        values=struct.unpack_from('<'+str(2*n)+'d',raw,raw.index(header+header)+24)
        assert values[:n]==values[n:] and all(map(math.isfinite,values))
    if case['implicit']:
        header=(5,nodes,solute,1,hys,case['bottom'],1,0);assert struct.unpack('<16i',raw[-96:-32])==header+header
        values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))

def checkpoint(path,meta,case,expected,external=False):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        q=json.loads(z.read('checkpoint.json'));binding=q['binding']
        if external:binding={k:v for k,v in binding.items() if k!='external_daily'}
        assert binding==meta['binding'] and physical(q['receipt'],case['kind'])==physical(expected,case['kind'])
        assert all(SHA(z.read(n))==v for n,v in q['files'].items())
        raw=z.read('macro.bin');native(raw,meta,case);end=z.read('result.end');original_history(end,case['kind'],case['hysteresis'])
        return raw,end

def active_temperature(end,nodes,limit):
    records=[];offset=0
    while offset<len(end):
        count=struct.unpack_from('<i',end,offset)[0]
        assert 0<=count<=len(end)-offset-8 and struct.unpack_from('<i',end,offset+4+count)[0]==count
        records.append(end[offset+4:offset+4+count]);offset+=count+8
    values=iter(records)
    def take(fmt):return struct.unpack('<'+fmt,next(values))
    integer=lambda:take('i')[0]
    assert integer()==1 and integer()==0 and integer()==nodes
    take(str(nodes)+'d');take('d');assert integer()==1;take('d');take('d')
    evaporation=integer();assert evaporation in (0,1,2)
    for _ in range(evaporation):take('d')
    mode=integer();assert mode in (0,1,2)
    if mode:
        take(str(nodes)+'i')
        for _ in range(3):take(str(nodes)+'d')
    assert integer()==1;temperature=take(str(nodes)+'d');assert all(map(math.isfinite,temperature)) and min(temperature)<limit
    return dict(original_temperature_min_C=min(temperature),original_temperature_max_C=max(temperature),actual_TFROSTSTA_C=limit,actual_original_Frost_active=True)

def transactions(folder,warm,data,meta,case,frost_start,limit,require_active):
    result=[]
    for stem,start in [('snow-transactions',4),('frost-calendar-transactions',frost_start)]:
        actual=[];base=folder/stem/'external'
        for stage in ('trial-1','trial-2',''):
            actual.append(checkpoint(base/stage/f'accepted-column-1-day-{start+1}.zip',meta,case,data[start],True))
        assert actual[0]==actual[1]==actual[2]
        checkpoint(folder/stem/'recovered/trial-1'/f'accepted-column-1-day-{start+2}.zip',meta,case,data[start+1],True)
        if stem=='snow-transactions':assert max(data[start]['stock_start_cm'][2],data[start]['stock_end_cm'][2])>0
        item=dict(start=start,discard_replay_accept_exact=True,recovered_next_day_exact=True)
        if stem=='frost-calendar-transactions' and require_active:
            end=checkpoint(warm/f'accepted-column-1-day-{start}.zip',meta,case,data[start-1])[1]
            item['actual_active_frost_start']=active_temperature(end,meta['project']['nodes'],limit)
        result.append(item)
    return result

def controls(folder,warm,data,meta,case,producer,limit,legacy_local=False):
    q=read(folder/'RESULT.json')
    assert q['status']=='ACTUAL_UNDRAINED_FROST_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and q['accepted_mutant_model_days']==0
    assert q['actual_controller_source']==q['actual_compiler_source']==producer
    assert q['actual_BUILD_sha256']==SHA((meta['_build']/'BUILD.json').read_bytes())
    groups=[('native',q['existing_calendar_thermal_refusals']),('extra-native',q['new_snow_private_and_codec_refusals'])]
    assert len(groups[0][1])==(44 if case['kind']=='cde' else 39) and len(groups[1][1])==(43 if case['kind']=='cde' else 39)
    if case['implicit']:
        assert q['root']['accepted_model_days']==0 and len(q['root']['refusals'])==25;groups.append(('root',q['root']['refusals']))
    good=checkpoint(warm/'accepted-column-1-day-4.zip',meta,case,data[3])[0];count=0
    for stem,items in groups:
        assert len({item['attack'] for item in items})==len(items)
        for item in items:
            target=folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes()
            text=outputs[0].read_bytes();assert b'HYBRID_READY' not in text and b'HYBRID_DAY_RETURN' not in text
            assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
    start=4 if legacy_local else (30 if case.get('start') and case['start'][5:7]=='12' else 19)
    tx=transactions(folder,warm,data,meta,case,start,limit,not legacy_local)
    if not legacy_local:assert tx[1]['actual_active_frost_start']==q['actual_active_frost_start'] and q['frost_calendar_transaction']['start_day']==start
    assert q['snow_transaction']['start_day']==4
    return dict(actual_compiled_refusals=count,accepted_mutant_days=0,transactions=tx)

def source_and_build(build,provider,case,opt):
    meta=read(build/'BUILD.json');identity=meta['identity']
    assert meta['project']['water_tolerance']==1e-10 and meta['project']['nodes']==34
    assert all('-'+opt in identity[k] and '-ffp-contract=off' in identity[k] for k in ['donor_flags','kernel_flags'])
    for n,digest in identity['donor_generated'].items():assert SHA((build/n).read_bytes())==digest
    for key,folder in [('donor_objects','swap-obj'),('donor_modules','swap-obj'),('ttutil_modules','ttutil-obj')]:
        for n,digest in identity[key].items():assert SHA(provider.get('original-provider-build/'+folder+'/'+n))==digest
    assert SHA(provider.get('original-provider-build/ttutil-obj/libttutil.a'))==identity['ttutil_library']
    suffix='.exe' if (build/'day_donor.exe').is_file() else ''
    for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+suffix)).read_bytes())==digest
    publisher='restart_publish.dll' if suffix else 'restart_publish.so';assert SHA((build/publisher).read_bytes())==identity['restart_publisher']['library_sha256']
    undrained=identity['frost_drainage_composition']
    assert undrained['fixed_SWDRA']==0 and undrained['fixed_SWDIVD'] is None and undrained['correction']=='NONE_NO_DIVDRA_CALL_WITH_SWDRA0'
    assert undrained['boundary_composition']['requires_divdra'] is False
    assert undrained['physical_equations_changed'] is False and undrained['divdra_source_changed'] is False and 'divdra.f90' not in identity['donor_generated']
    from frost_undrained_terminal_water import source as terminal
    expected=terminal()
    if case['implicit']:
        from frost_boundary_terminal_trial import receipt_source,original_head_source
        from implicit_frost_surface_conductivity import restore
        from implicit_frost_source_guard import TERMINAL_PARTS,qualified_water_headcalc
        source=restore(original_head_source((build/'headcalc.f90').read_text(encoding='cp1252'),case['bottom']))
        for part in TERMINAL_PARTS:assert source.count(part)==1;source=source.replace(part,'',1)
        qualified_water_headcalc(source,case['bottom'])
    if case['implicit'] or case['bottom']==8:
        from frost_boundary_terminal_trial import receipt_source,original_head_source
        if not case['implicit']:original_head_source((build/'headcalc.f90').read_text(encoding='cp1252'),case['bottom'])
        expected=receipt_source(expected)
    assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==expected
    from time_event_closure import source as event_time
    clock=event_time(provider.get('original-provider-build/swap-selected/timecontrol.f90')).decode('cp1252').replace('\r\n','\n')
    if case['implicit']:
        from implicit_conductivity_retry import time_source as retry_time
        from implicit_pond_event import time_source as pond_time
        clock=pond_time(retry_time(clock))
    assert (build/'timecontrol.f90').read_text(encoding='cp1252')==clock
    return meta

def case_audit(store,prefix,case,provider,producer,opt,legacy_local=False):
    folder=ReadView(store,prefix);profile=folder/'science';q=read(profile/'RESULT.json');warm=profile/'trajectory'
    projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[q['build_root']];build=ReadView(store,entry['archive_prefix']);meta=source_and_build(build,provider,case,opt)
    assert SHA((build/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']==q['trajectory']['build_sha256']
    assert q['source']==q['actual_controller_source']==producer and q['kind']==case['kind'] and meta['project']['start_date']==(case['start'] or '2002-01-01')
    assert q['status']=='ACTUAL_UNDRAINED_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and q['duration_days']==case['days']
    selected=q['selection'];assert selected['undrained_frost'] and selected['drainage']==0 and not selected['requires_divdra']
    assert all(selected[k]==case[k] for k in ('kind','bottom','implicit','hysteresis','initial'))
    for n,digest in meta['inputs'].items():assert SHA((folder/'inputs'/n).read_bytes())==digest
    from experimental_project import switches
    text=(folder/'inputs/swap.swp').read_text(encoding='cp1252');values=switches(text)
    expected=dict(SWMACRO=0,SWDRA=0,SWBOTB=case['bottom'],SWKIMPL=case['implicit'],SWHYST=case['hysteresis'],SWINCO=case['initial'],SWSOLU=int(case['kind']=='cde'),SWFROST=1,SWSNOW=1,SWCALT=2)
    assert all(values[k]==v for k,v in expected.items())
    limits=re.findall(r'(?mi)^[ \t]*TFROSTSTA[ \t]*=[ \t]*([^!\r\n]+)',text);assert len(limits)==1;limit=float(limits[0].strip().replace('D','e').replace('d','e'));assert math.isfinite(limit)
    convergence=require_convergence(profile);scientific=budgets(warm,case['kind'],case['days']);assert scientific==q['independent_original_budgets']
    data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
    windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
    if case.get('start') and case['start'][5:7]=='12':windows.append((15,19) if case['days']==35 else (5,9))
    assert [(x['start'],x['end']) for x in q['own']]==windows
    cuts={case['days']}|{d for pair in windows for d in pair}
    assert {int(p.stem.rsplit('-',1)[1]) for p in warm.glob('accepted-column-1-day-*.zip')}==cuts
    for day in cuts:checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
    for start,end in windows:
        cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
        assert [physical(row,case['kind']) for row in rows]==[physical(row,case['kind']) for row in data[start:end]]
        assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
        compare(warm/'original',cold/'original',meta['identity']['original_output'],start,end,meta['project']['start_date'])
    result=dict(case=case,actual_compiler_source=producer,actual_controller_source=q['actual_controller_source'],compiler=meta['identity']['compiler'],optimization=opt,science=scientific,native_samples=len(cuts),exact_cold_windows=len(windows),convergence=convergence,BUILD_sha256=SHA((build/'BUILD.json').read_bytes()))
    if case['days']==35:
        meta['_build']=build;result['controls']=controls(folder/'controls',warm,data,meta,case,producer,limit,legacy_local)
    return result

def inherited(store,old,producer,opt):
    q=json.loads(store.get('current-inherited-postimages/RESULT.json'))
    assert q['actual_source']==producer and q['optimization']==opt and q['model_executions']==0 and len(q['contexts'])==8
    assert q['status']=='EIGHT_CURRENT_UNCHANGED_DRAINED_FROST_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
    current_projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));result=[]
    from frost_undrained_inherited_postimages import NAMES
    assert {c['case']['name'] for c in q['contexts']}==NAMES
    for item in q['contexts']:
        name=item['case']['name'];prior=json.loads(old.get('current/'+name+'/science/RESULT.json'))
        parent=ReadView(old,old_projection[prior['build_root']]['archive_prefix']);build=ReadView(store,current_projection[item['actual_build_root']]['archive_prefix'])
        meta=read(build/'BUILD.json');before=read(parent/'BUILD.json')
        assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'] and SHA((parent/'BUILD.json').read_bytes())==item['original_BUILD_sha256']
        assert item['original_source']==prior['source'] and item['original_archive_sha256']==old.record['sha256'] and item['model_executions']==0
        for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert meta['identity'][key]==before['identity'][key]
        assert meta['inputs']==before['inputs']
        for n,digest in meta['identity']['donor_generated'].items():assert (build/n).read_bytes()==(parent/n).read_bytes() and SHA((build/n).read_bytes())==digest
        objects={p.name for p in build.glob('*.o')};assert objects=={p.name for p in parent.glob('*.o')}=={o['file'] for o in item['objects']} and objects
        for obj in item['objects']:
            raw=(build/obj['file']).read_bytes();assert raw==(parent/obj['file']).read_bytes() and len(raw)==obj['bytes'] and SHA(raw)==obj['sha256']
        result.append(dict(case=name,whole_objects=len(objects),actual_compiled_source=producer,original_compiled_source=prior['source'],model_replays=0))
    return result

def portable(proof,platform,opt):
    with ExitStack() as stack:
        store=Archive(proof,f'FROST_UNDRAINED_STATE08_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        _,custody=captured_source(store,stack,PRODUCER,PRODUCER,f'.github/workflows/nomacro-frost-undrained-state08-{platform.lower()}.yml')
        contract=json.loads(git('show',PRODUCER+':integration/f-ci/nomacro-complete01/FROST_UNDRAINED_STATE08_INPUT_CONTRACT_V1.json'))
        assert json.loads(store.get('actual-input-contract.json'))==contract
        q=json.loads(store.get('current/RESULT.json'));assert q['source']==PRODUCER and q['optimization']==opt and q['platform']==platform and len(q['contexts'])==16
        cases=contract['representative_cases'];assert [c['case'] for c in q['contexts']]==cases
        observations=[]
        for case in cases:
            observations.append(case_audit(store,'current/'+case['name'],case,store,PRODUCER,opt))
            print('ORIGINAL_UNDRAINED_ARCHIVE_SCIENCE_PASS',platform,opt,case['name'],flush=True)
        old=Archive(GitArchiveSource(R,BASE),f'FROST_IMPLICIT_HYS2_YEAR06_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        postimages=inherited(store,old,PRODUCER,opt)
        return dict(status='INDEPENDENT_ORIGINAL_UNDRAINED_SCIENCE_NATIVE_COLD_REFUSALS_ACTIVE_TRANSACTIONS_AND_DRAINED_POSTIMAGES_PASS_NOT_ADMITTED',source=custody,platform=platform,optimization=opt,contexts=observations,inherited_postimages=postimages,compiler_executions=0,model_executions=0,canonical_admission=False)

def main():
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=P);p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    observer=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain','--untracked-files=all')
    q=dict(status='RUNNING_INDEPENDENT_ORIGINAL_UNDRAINED_SCIENCE_NOT_ADMITTED',actual_observer=observer)
    try:q['audit']=portable(a.proof,a.platform,a.optimization);q['status']=q['audit']['status']
    except Exception as exc:q.update(status='FAILED_INDEPENDENT_ORIGINAL_UNDRAINED_SCIENCE_NOT_ADMITTED',error=repr(exc));raise
    finally:
        assert git('rev-parse','HEAD').decode().strip()==observer
        with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)

if __name__=='__main__':main()
