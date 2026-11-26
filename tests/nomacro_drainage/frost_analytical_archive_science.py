"""Independent read-only audit of original analytical Frost scientific bytes."""
import argparse,io,json,math,re,struct,subprocess,tarfile,zipfile
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
from frost_undrained_archive_science import source_and_build,active_temperature

R=Path(__file__).resolve().parents[2]
P='integration/f-ci/nomacro-complete01/'
PRODUCER='a2df828cf19dea76a9012c7cb13f14db0cdbbe08'
BASE='f3faeaa540e7fd81686802414d53ff6686f3ce7b'
LOCAL='23dd30d6a2bbf062a8b6a23ea2089399526db6a4'

def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def read(path):return json.loads(path.read_text())


def native(raw,meta,case):
    nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');models=case['models']
    if len(models)==1:models=models*2
    assert len(models)==2 and case['implicit']==case['hysteresis']==case['drainage']==0
    magic=b'S5UAC001' if solute else b'S5UAW001'
    assert raw[:8]==magic==meta['identity']['original_output']['native_codec'].encode()
    header=struct.pack('<7i',2,nodes,2,solute,case['bottom'],*models)
    assert raw.count(header+header)==1
    thermal=struct.pack('<10i',1,nodes,0,solute,0,1,1,0,1,2);assert raw.count(thermal+thermal)==1
    header=struct.pack('<4i',1,nodes,solute,7);assert raw.count(header+header)==1
    values=struct.unpack_from('<7d',raw,raw.index(header+header)+32)
    assert all(math.isfinite(x) and x>=0 for x in values)
    if solute:
        n=20+nodes;header=struct.pack('<3i',2,nodes,n);assert raw.count(header+header)==1
        values=struct.unpack_from('<'+str(2*n)+'d',raw,raw.index(header+header)+24)
        assert values[:n]==values[n:] and all(map(math.isfinite,values))


def checkpoint(path,meta,case,expected,external=False):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        q=json.loads(z.read('checkpoint.json'));binding=q['binding']
        if external:binding={k:v for k,v in binding.items() if k!='external_daily'}
        assert binding==meta['binding'] and physical(q['receipt'],case['kind'])==physical(expected,case['kind'])
        assert all(SHA(z.read(n))==v for n,v in q['files'].items())
        raw=z.read('macro.bin');native(raw,meta,case);end=z.read('result.end')
        original_history(end,case['kind'],0)
        return raw,end


def controls(folder,warm,data,meta,case,producer,limit):
    q=read(folder/'RESULT.json')
    assert q['status']=='ACTUAL_ANALYTICAL_FROST_COMPILED_NATIVE_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
    assert q['accepted_mutant_model_days']==0 and q['actual_controller_source']==q['actual_compiler_source']==producer
    assert q['actual_BUILD_sha256']==SHA((meta['_build']/'BUILD.json').read_bytes())
    groups=[('calendar-native',q['calendar_thermal_refusals']),('extra-native',q['snow_private_codec_refusals']),('model-native',q['analytical_model_refusals'])]
    assert [len(items) for _,items in groups]==([44,45,14] if case['kind']=='cde' else [39,41,14])
    good=checkpoint(warm/'accepted-column-1-day-2.zip',meta,case,data[1])[0];count=0
    for stem,items in groups:
        assert len({item['attack'] for item in items})==len(items)
        for item in items:
            target=folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes()
            text=outputs[0].read_bytes();assert b'HYBRID_READY' not in text and b'HYBRID_DAY_RETURN' not in text
            assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
    transactions=[]
    for stem,start in [('snow-transaction',2)]+([('active-frost-transaction',19)] if case['days']==35 else []):
        actual=[];base=folder/stem/'external'
        for stage in ['trial-1','trial-2','']:
            actual.append(checkpoint(base/stage/f'accepted-column-1-day-{start+1}.zip',meta,case,data[start],True))
        assert actual[0]==actual[1]==actual[2]
        checkpoint(folder/stem/'recovered/trial-1'/f'accepted-column-1-day-{start+2}.zip',meta,case,data[start+1],True)
        item=dict(start=start,discard_replay_accept_complete_native_exact=True,recovered_next_day_physical_exact=True)
        if stem=='snow-transaction':assert max(data[start]['stock_start_cm'][2],data[start]['stock_end_cm'][2])>0
        else:
            end=checkpoint(warm/f'accepted-column-1-day-{start}.zip',meta,case,data[start-1])[1]
            item['actual_active_frost_start']=active_temperature(end,meta['project']['nodes'],limit)
            assert item['actual_active_frost_start']==q['actual_active_frost_start']
        transactions.append(item)
    return dict(actual_compiled_refusals=count,accepted_mutant_model_days=0,transactions=transactions)


def case_audit(store,prefix,case,provider,producer,opt,with_controls=True):
    folder=ReadView(store,prefix);profile=folder/'science';q=read(profile/'RESULT.json');warm=profile/'trajectory'
    projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[q['build_root']]
    build=ReadView(store,entry['archive_prefix']);meta=source_and_build(build,provider,case,opt)
    assert SHA((build/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']==q['trajectory']['build_sha256']
    assert q['source']==q['actual_controller_source']==producer and q['kind']==case['kind']
    assert meta['project']['start_date']==(case['start'] or '2002-01-01')
    assert q['status']=='ACTUAL_ANALYTICAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_MODEL_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
    assert q['duration_days']==case['days']
    selected=q['selection'];models=case['models'] if len(case['models'])==2 else case['models']*2
    assert selected['analytical_frost_models']==models and selected['undrained_frost'] and not selected['requires_divdra']
    assert all(selected[k]==case[k] for k in ['kind','bottom','implicit','hysteresis','initial','drainage'])
    for n,digest in meta['inputs'].items():assert SHA((folder/'inputs'/n).read_bytes())==digest
    from experimental_project import switches
    text=(folder/'inputs/swap.swp').read_text(encoding='cp1252');values=switches(text)
    expected=dict(SWMACRO=0,SWDRA=0,SWBOTB=case['bottom'],SWKIMPL=0,SWHYST=0,SWINCO=case['initial'],SWSOLU=int(case['kind']=='cde'),SWFROST=1,SWSNOW=1,SWCALT=2)
    assert all(values[k]==v for k,v in expected.items())
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^!\r\n]+)',text)
    assert len(rows)==1 and list(map(int,rows[0].split()))==case['models']
    if 3 in models:
        for crop in (folder/'inputs').glob('*.crp'):
            oxygen=re.findall(r'(?mi)^[ \t]*SWOXYGEN[ \t]*=[ \t]*([^!\r\n]+)',crop.read_text(encoding='cp1252'))
            assert len(oxygen)==1 and oxygen[0].strip()=='1'
    limits=re.findall(r'(?mi)^[ \t]*TFROSTSTA[ \t]*=[ \t]*([^!\r\n]+)',text);assert len(limits)==1
    limit=float(limits[0].strip().replace('D','e').replace('d','e'));assert math.isfinite(limit)
    convergence=require_convergence(profile);scientific=budgets(warm,case['kind'],case['days'])
    assert scientific==q['independent_original_budgets']
    data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()];assert len(data)==case['days']
    windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
    if case['start']:windows.append((5,9))
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
    if with_controls:
        meta['_build']=build;result['controls']=controls(folder/'controls',warm,data,meta,case,producer,limit)
    else:result['controls']='NOT_SELECTED_ORIGINAL_LOCAL_SCIENCE_PRECEDES_COMPILED_CONTROLS'
    return result


def inherited(store,old,opt):
    q=json.loads(store.get('current-inherited-postimages/RESULT.json'))
    assert q['actual_source']==PRODUCER and q['optimization']==opt and q['model_executions']==0 and len(q['contexts'])==8
    assert q['status']=='EIGHT_CURRENT_UNCHANGED_MODEL1_FROST_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
    current_projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));result=[]
    from frost_analytical_inherited_postimages import NAMES
    assert {c['case']['name'] for c in q['contexts']}==NAMES
    for item in q['contexts']:
        name=item['case']['name'];prior=json.loads(old.get('current/'+name+'/science/RESULT.json'))
        parent=ReadView(old,old_projection[prior['build_root']]['archive_prefix'])
        build=ReadView(store,current_projection[item['actual_build_root']]['archive_prefix']);meta=read(build/'BUILD.json');before=read(parent/'BUILD.json')
        assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'] and SHA((parent/'BUILD.json').read_bytes())==item['original_BUILD_sha256']
        assert item['original_source']==prior['source'] and item['original_archive_sha256']==old.record['sha256'] and item['model_executions']==0
        for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert meta['identity'][key]==before['identity'][key]
        assert meta['inputs']==before['inputs']
        for n,digest in meta['identity']['donor_generated'].items():assert (build/n).read_bytes()==(parent/n).read_bytes() and SHA((build/n).read_bytes())==digest
        objects={p.name for p in build.glob('*.o')};assert objects=={p.name for p in parent.glob('*.o')}=={o['file'] for o in item['objects']} and objects
        for obj in item['objects']:
            raw=(build/obj['file']).read_bytes();assert raw==(parent/obj['file']).read_bytes() and len(raw)==obj['bytes'] and SHA(raw)==obj['sha256']
        result.append(dict(case=name,whole_objects=len(objects),actual_compiled_source=PRODUCER,original_compiled_source=prior['source'],model_replays=0))
    return result


def portable(proof,platform,opt,verbose=False):
    with ExitStack() as stack:
        store=Archive(proof,f'FROST_ANALYTICAL_COMPOSITION09_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        _,custody=captured_source(store,stack,PRODUCER,PRODUCER,f'.github/workflows/nomacro-frost-analytical-composition09-{platform.lower()}.yml')
        contract=json.loads(git('show',PRODUCER+':'+P+'FROST_ANALYTICAL_COMPOSITION09_INPUT_CONTRACT_V1.json'))
        assert json.loads(store.get('actual-input-contract.json'))==contract
        q=json.loads(store.get('current/RESULT.json'))
        assert q['status']=='TWELVE_ACTUAL_ANALYTICAL_FROST_PORTABLE_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
        assert q['source']==PRODUCER and q['optimization']==opt and q['platform']==platform and len(q['contexts'])==12
        assert [c['case'] for c in q['contexts']]==contract['representative_cases']
        contexts=[]
        for case in contract['representative_cases']:
            contexts.append(case_audit(store,'current/'+case['name'],case,store,PRODUCER,opt))
            if verbose:print('INDEPENDENT_ANALYTICAL_FROST_CONTEXT_PASS',platform,opt,case['name'],flush=True)
        old=Archive(GitArchiveSource(R,BASE),f'FROST_UNDRAINED_STATE08_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        return dict(status='INDEPENDENT_TWELVE_ANALYTICAL_FROST_SCIENCE_NATIVE_COLD_REFUSALS_TRANSACTIONS_AND_MODEL1_POSTIMAGES_PASS_NOT_ADMITTED',source=custody,platform=platform,optimization=opt,contexts=contexts,inherited_postimages=inherited(store,old,opt),compiler_executions=0,model_executions=0,canonical_admission=False)


def local_source(store,stack,producer,version):
    """Check original local capsules at their actual, explicitly recorded paths."""
    expected={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',producer).decode().splitlines()}
    def check(name,value,item):
        assert len(value)==item['bytes'] and SHA(value)==item['sha256']
        blob=lambda v:hashlib.sha1(b'blob '+str(len(v)).encode()+b'\0'+v).hexdigest()
        assert expected[name]==item['git_blob'] and expected[name] in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    captured=json.loads(store.get('source/RESULT.json'));raw=store.get('source/actual-producer-source.zip')
    assert captured['producer_head']==producer and len(raw)==captured['bytes'] and SHA(raw)==captured['sha256']
    z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));absent={n for n,item in captured['members'].items() if item.get('checkout')=='ABSENT'}
    assert all(n.startswith('reference/swap-4.3.1/') for n in absent) and set(z.namelist())==set(captured['members'])-absent
    for n,item in captured['members'].items():
        if n in absent:assert item==dict(git_blob=expected[n],checkout='ABSENT')
        else:check(n,z.read(n),item)
    ctl=json.loads(store.get('controllers/FROST_ANALYTICAL_COMPOSITION09_CONTROLLER_SOURCE_'+version+'.json'));raw=store.get('controllers/FROST_ANALYTICAL_COMPOSITION09_CONTROLLER_SOURCE_'+version+'.tar')
    assert ctl['producer_head']==producer and len(raw)==ctl['bytes'] and SHA(raw)==ctl['sha256']
    t=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)));assert {m.name for m in t.getmembers()}==set(ctl['members'])
    for n,item in ctl['members'].items():check(n,t.extractfile(n).read(),item)
    return dict(actual_local_producer=producer,actual_controller_producer=producer,source_sha256=captured['sha256'],controller_sha256=ctl['sha256'],source_members=len(captured['members']),controller_members=len(ctl['members']))

def local(proof,verbose=False):
    result=[];custody=[]
    with ExitStack() as stack:
        for version,producer,models,stem in [
            ('V1','dd7596685c91074789ab56e9a3ecb3d4a4ef4b4c',[7,7],'model7-7-cde-b8-p1'),
            ('V3','bc4b57be42e198a100e3e2b4cce725c1fa600642',[11],'model11-scalar-water-b8-p2-dates-r0-year'),
            ('V4',LOCAL,None,None)]:
            store=Archive(proof,'FROST_ANALYTICAL_COMPOSITION09_LOCAL_WINDOWS_O0_O2_RAW_'+version,stack)
            custody.append(local_source(store,stack,producer,version))
            dependency=json.loads(store.get('LOCAL_PROVIDER_DEPENDENCY_V1.json'))
            provider=Archive(GitArchiveSource(R,dependency['actual_data_revision']),dependency['archive'],stack)
            assert provider.record['sha256']==dependency['sha256']
            for n,item in dependency['actual_required_files'].items():
                raw=provider.get(n);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
            if version=='V4':
                entries=[(item['optimization'],item['archive_prefix'],item['case']) for item in store.record['contexts']]
                assert len(entries)==4
            else:
                entries=[]
                for opt in ['O0','O2']:
                    prefix='current/'+opt+'-'+stem
                    case=dict(read(ReadView(store,prefix)/'RESULT.json')['case'],models=models,name=stem)
                    entries.append((opt,prefix,case))
            for opt,prefix,case in entries:
                result.append(case_audit(store,prefix,case,provider,producer,opt,version=='V4'))
                if verbose:print('INDEPENDENT_LOCAL_ANALYTICAL_FROST_CONTEXT_PASS',version,opt,case['name'],flush=True)
        assert len(result)==8 and sum(x['case']['days'] for x in result)==188
        assert sum(x['native_samples'] for x in result)==44 and sum(x['exact_cold_windows'] for x in result)==20
        assert sum(x['controls']['actual_compiled_refusals'] for x in result if isinstance(x['controls'],dict))==394
        assert len({x['actual_compiler_source'] for x in result})==3
        return dict(status='INDEPENDENT_EIGHT_LOCAL_ANALYTICAL_FROST_ORIGINAL_BUDGETS_NATIVE_COLD_AND_FOUR_COMPILED_CONTROL_CONTEXTS_PASS_NOT_ADMITTED',source=custody,contexts=result,original_scientific_producers_rebound=False,compiler_executions=0,model_executions=0,canonical_admission=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path)
    p.add_argument('--platform',choices=['Windows','Ubuntu']);p.add_argument('--optimization',choices=['O0','O2'])
    p.add_argument('--local',action='store_true')
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    assert (a.local and not a.platform and not a.optimization) or (not a.local and a.platform and a.optimization)
    observer=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain','--untracked-files=all')
    proof=a.proof if a.proof is not None else GitArchiveSource(R,observer)
    q=dict(status='RUNNING_INDEPENDENT_ANALYTICAL_FROST_SCIENCE_NOT_QUALIFIED',actual_observer=observer)
    try:q['audit']=local(proof,True) if a.local else portable(proof,a.platform,a.optimization,True);q['status']=q['audit']['status']
    except Exception as error:q.update(status='FAILED_INDEPENDENT_ANALYTICAL_FROST_SCIENCE_NOT_QUALIFIED',error=repr(error));raise
    finally:
        assert git('rev-parse','HEAD').decode().strip()==observer
        with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)


if __name__=='__main__':main()
