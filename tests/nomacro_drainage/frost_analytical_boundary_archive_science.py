"""Independent read-only audit of original analytical Frost scientific bytes."""
import argparse,hashlib,io,json,math,re,struct,subprocess,tarfile,zipfile
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
from frost_undrained_archive_science import source_and_build as undrained_source_and_build,active_temperature

R=Path(__file__).resolve().parents[2]
P='integration/f-ci/nomacro-complete01/'
PRODUCER='b4ffcc914453225562ffe0e847faa21a765432ce'
BASE='9af88c3de6198ddec40c2674dd1542a89fa9c0d7'
LOCAL='23dd30d6a2bbf062a8b6a23ea2089399526db6a4'

def git(*args):return subprocess.check_output(['git',*args],cwd=R)
def read(path):return json.loads(path.read_text())


def source_and_build(build,provider,case,opt):
    if case['drainage']==0:return undrained_source_and_build(build,provider,case,opt)
    meta=read(build/'BUILD.json');identity=meta['identity']
    assert meta['project']['water_tolerance']==1e-10 and meta['project']['nodes']==34 and case['implicit']==case['hysteresis']==0
    assert all('-'+opt in identity[k] and '-ffp-contract=off' in identity[k] for k in ['donor_flags','kernel_flags'])
    for n,digest in identity['donor_generated'].items():assert SHA((build/n).read_bytes())==digest
    for key,folder in [('donor_objects','swap-obj'),('donor_modules','swap-obj'),('ttutil_modules','ttutil-obj')]:
        for n,digest in identity[key].items():assert SHA(provider.get('original-provider-build/'+folder+'/'+n))==digest
    assert SHA(provider.get('original-provider-build/ttutil-obj/libttutil.a'))==identity['ttutil_library']
    suffix='.exe' if (build/'day_donor.exe').is_file() else ''
    for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+suffix)).read_bytes())==digest
    publisher='restart_publish.dll' if suffix else 'restart_publish.so';assert SHA((build/publisher).read_bytes())==identity['restart_publisher']['library_sha256']
    owner=identity['frost_drainage_composition'];assert owner['fixed_SWKIMPL']==0 and owner['fixed_SWDIVD']==1 and owner['correction']=='FROST-DIVDRA-OVERLAP-01' and owner['new_physical_state'] is False
    assert owner['boundary_composition']['requires_divdra'] is True and owner['analytical_frost_models']==case['effective_models']
    assert owner['analytical_frost_native']['native_header_version']==3 and owner['analytical_frost_native']['physical_equations_changed'] is False
    from frost_divdra_overlap import source as overlap
    assert (build/'divdra.f90').read_text(encoding='cp1252')==overlap(provider.get('original-provider-build/swap-selected/divdra.f90'))
    from frost_calendar_terminal_water import source as terminal
    expected=terminal()
    if case['bottom']==8:
        from frost_boundary_terminal_trial import receipt_source,original_head_source
        original_head_source((build/'headcalc.f90').read_text(encoding='cp1252'),case['bottom'])
        expected=receipt_source(expected)
    assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==expected
    from time_event_closure import source as event
    assert (build/'timecontrol.f90').read_bytes().replace(b'\r\n',b'\n')==event(provider.get('original-provider-build/swap-selected/timecontrol.f90')).replace(b'\r\n',b'\n')
    if case['kind']=='cde':
        text=(build/'solute.f90').read_text(encoding='cp1252')
        assert text.count('               if (cmsy(i) <= 0d0) then')==1 and '               if (cmsy(i) < vsmall) then' not in text
    return meta


def native(raw,meta,case):
    nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');models=case['effective_models']
    if len(models)==1:models=models*2
    assert len(models)==2 and case['implicit']==case['hysteresis']==0 and case['drainage'] in (0,1)
    magic=b'S5FAC001' if solute else b'S5FAW001'
    assert raw[:8]==magic==meta['identity']['original_output']['native_codec'].encode()
    header=struct.pack('<9i',3,nodes,2,solute,case['bottom'],case['drainage'],int(case['drainage']==1),*models)
    assert raw.count(header+header)==1
    thermal=struct.pack('<10i',1,nodes,0,solute,0,1,1,case['drainage'],1,2);assert raw.count(thermal+thermal)==1
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
    assert q['status']=='ACTUAL_ANALYTICAL_BOUNDARY_FROST_COMPILED_NATIVE_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
    assert q['accepted_mutant_model_days']==0 and q['actual_controller_source']==q['actual_compiler_source']==producer
    assert q['actual_BUILD_sha256']==SHA((meta['_build']/'BUILD.json').read_bytes())
    groups=[('boundary-native',q['analytical_boundary_refusals'])]
    assert len(groups[0][1])==18
    if case['full_legacy_native_controls']:
        groups.extend([('calendar-native',q['calendar_thermal_refusals']),('extra-native',q['snow_private_codec_refusals'])])
        assert [len(items) for _,items in groups]==([18,44,47] if case['kind']=='cde' else [18,39,43])
    else:assert q['legacy_controls_selection']=='NOT_SELECTED_IMPACT_UNCHANGED_THERMAL_SNOW_CDE_IMPL_REPRESENTATIVES0_3'
    good=checkpoint(warm/'accepted-column-1-day-2.zip',meta,case,data[1])[0];count=0
    for stem,items in groups:
        assert len({item['attack'] for item in items})==len(items)
        for item in items:
            target=folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes()
            text=outputs[0].read_bytes();assert b'HYBRID_READY' not in text and b'HYBRID_DAY_RETURN' not in text
            assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
    transactions=[]
    for stem,start in [('snow-transaction',2)]+([('active-frost-transaction',19)] if case['active_frost_transactions'] else []):
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
    assert q['status']=='ACTUAL_ANALYTICAL_BOUNDARY_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_MODEL_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
    assert q['duration_days']==case['days']
    selected=q['selection'];models=case['effective_models']
    assert selected['analytical_frost_models']==models and selected['requires_divdra']==(case['drainage']==1) and bool(selected.get('undrained_frost'))==(case['drainage']==0)
    assert all(selected[k]==case[k] for k in ['kind','bottom','implicit','hysteresis','initial','drainage'])
    for n,digest in meta['inputs'].items():assert SHA((folder/'inputs'/n).read_bytes())==digest
    from experimental_project import switches
    text=(folder/'inputs/swap.swp').read_text(encoding='cp1252');values=switches(text)
    expected=dict(SWMACRO=0,SWDRA=case['drainage'],SWBOTB=case['bottom'],SWKIMPL=0,SWHYST=0,SWINCO=case['initial'],SWSOLU=int(case['kind']=='cde'),SWFROST=1,SWSNOW=1,SWCALT=2)
    assert all(values[k]==v for k,v in expected.items())
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^!\r\n]+)',text)
    assert (not rows and not case['models']) or (len(rows)==1 and list(map(int,rows[0].split()))==case['models'])
    if 3 in models:
        for crop in (folder/'inputs').glob('*.crp'):
            oxygen=re.findall(r'(?mi)^[ \t]*SWOXYGEN[ \t]*=[ \t]*([^!\r\n]+)',crop.read_text(encoding='cp1252'))
            assert len(oxygen)==1 and oxygen[0].strip()=='1'
    limits=re.findall(r'(?mi)^[ \t]*TFROSTSTA[ \t]*=[ \t]*([^!\r\n]+)',text);assert len(limits)==1
    limit=float(limits[0].strip().replace('D','e').replace('d','e'));assert math.isfinite(limit)
    convergence=require_convergence(profile);scientific=budgets(warm,case['kind'],case['days'])
    assert scientific==q['independent_original_budgets']
    data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()];assert len(data)==case['days']
    if case.get('require_active_drainage'):
        total=sum(row['drainage_outward_cm'] for row in data);top=read(folder/'RESULT.json')
        assert total==top['actual_drainage_outward_cm'] and total>0 and sum(row['drainage_outward_cm']>0 for row in data)==top['actual_nonzero_drainage_days']
    if case['drainage']==1:
        from experimental_project import one
        name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
        assert switches((folder/'inputs'/(prefix+name+'.dra')).read_text(encoding='cp1252'))['SWDIVD']==1
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
    assert q['actual_source']==PRODUCER and q['optimization']==opt and q['model_executions']==0 and len(q['contexts'])==4
    assert q['status']=='FOUR_CURRENT_UNCHANGED_ANALYTICAL09_FROST_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
    current_projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));result=[]
    from frost_analytical_boundary_inherited_postimages import NAMES
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
        store=Archive(proof,f'FROST_ANALYTICAL_BOUNDARY10_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        _,custody=captured_source(store,stack,PRODUCER,PRODUCER,f'.github/workflows/nomacro-frost-analytical-boundary10-{platform.lower()}.yml')
        contract=json.loads(git('show',PRODUCER+':'+P+'FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json'))
        assert json.loads(store.get('actual-input-contract.json'))==contract
        q=json.loads(store.get('current/RESULT.json'))
        assert q['status']=='SIXTEEN_ACTUAL_ANALYTICAL_BOUNDARY_FROST_PORTABLE_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
        assert q['source']==PRODUCER and q['optimization']==opt and q['platform']==platform and len(q['contexts'])==16
        assert [c['case'] for c in q['contexts']]==contract['representative_cases']
        contexts=[]
        for case in contract['representative_cases']:
            contexts.append(case_audit(store,'current/'+case['name'],case,store,PRODUCER,opt))
            if verbose:print('INDEPENDENT_ANALYTICAL_FROST_CONTEXT_PASS',platform,opt,case['name'],flush=True)
        old=Archive(GitArchiveSource(R,BASE),f'FROST_ANALYTICAL_COMPOSITION09_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        return dict(status='INDEPENDENT_SIXTEEN_ANALYTICAL_FROST_SCIENCE_NATIVE_COLD_REFUSALS_TRANSACTIONS_AND_MODEL1_POSTIMAGES_PASS_NOT_ADMITTED',source=custody,platform=platform,optimization=opt,contexts=contexts,inherited_postimages=inherited(store,old,opt),compiler_executions=0,model_executions=0,canonical_admission=False)



def first_portable(proof,platform,opt,verbose=False):
    with ExitStack() as stack:
        store=Archive(proof,f'FROST_ANALYTICAL_BOUNDARY10_FIRST_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        _,custody=captured_source(store,stack,PRODUCER,PRODUCER,f'.github/workflows/nomacro-frost-analytical-boundary10-{platform.lower()}.yml')
        contract=json.loads(git('show',PRODUCER+':'+P+'FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json'))
        assert json.loads(store.get('actual-input-contract.json'))==contract
        q=json.loads(store.get('current/RESULT.json'))
        assert q['status']=='FAILED_ANALYTICAL_FROST_PORTABLE_NOT_QUALIFIED' and q['source']==PRODUCER and q['platform']==platform and q['optimization']==opt
        assert len(q['contexts'])==7 and [c['case'] for c in q['contexts']]==contract['representative_cases'][:7]
        contexts=[]
        for case in contract['representative_cases'][:7]:
            contexts.append(case_audit(store,'current/'+case['name'],case,store,PRODUCER,opt))
            if verbose:print('INDEPENDENT_FIRST_ORIGINAL_BOUNDARY_CONTEXT_PASS',platform,opt,case['name'],flush=True)
        old=Archive(GitArchiveSource(R,BASE),f'FROST_ANALYTICAL_COMPOSITION09_{platform.upper()}_{opt}_ORIGINAL_V1',stack)
        postimages=inherited(store,old,opt);assert len(postimages)==4 and sum(x['whole_objects'] for x in postimages)==100
        case=contract['representative_cases'][7];assert case['effective_models']==[8,8] and case['drainage']==0 and case['bottom']==6
        folder=ReadView(store,'current/'+case['name']);failed=read(folder/'science/RESULT.json')
        assert failed['source']==failed['actual_controller_source']==PRODUCER and failed['status']=='FAILED_ACTUAL_ANALYTICAL_BOUNDARY_FROST_CALENDAR_NOT_QUALIFIED'
        rows=[json.loads(line) for line in (folder/'science/trajectory/daily.jsonl').read_text().splitlines()]
        assert len(rows)==33 and [x['day'] for x in rows]==list(range(1,34)) and all(x['committed'] for x in rows[:32]) and not rows[-1]['committed']
        assert abs(rows[-1]['independent_residual_cm'])>1e-10 and abs(rows[-1]['kernel_residual_cm'])>1e-10 and abs(rows[-1]['integrated_guard_residual_cm'])<=1e-10
        assert b'Rejected day 33' in (folder/'actual-public-runtime.stderr').read_bytes()
        return dict(status='INDEPENDENT_FIRST7_SUCCESSFUL_CONTEXTS_4_OLD09_POSTIMAGES_AND_TRUE_MODEL8_DAY33_REFUSAL_VERIFIED_NOT_ADMITTED',source=custody,platform=platform,optimization=opt,contexts=contexts,inherited_postimages=postimages,failed_case=case,actual_rejected_receipt=rows[-1],failed_case_prior_accepted_days=32,whole_batch_qualified=False,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--first',action='store_true');p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    head=git('rev-parse','HEAD').decode().strip();q=dict(status='RUNNING_INDEPENDENT_BOUNDARY_ARCHIVE_AUDIT',actual_observer=head)
    try:q['audit']=(first_portable if a.first else portable)(GitArchiveSource(R,head),a.platform,a.optimization,True);q['status']=q['audit']['status']
    except Exception as error:q.update(status='FAILED_INDEPENDENT_BOUNDARY_ARCHIVE_AUDIT',error=repr(error));raise
    finally:
        assert git('rev-parse','HEAD').decode().strip()==head
        with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
