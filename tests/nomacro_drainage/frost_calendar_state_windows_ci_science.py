"""Fresh read-only original calendar bytes, Decimal budgets, cold and native audits."""
import argparse,hashlib,io,json,math,struct,zipfile,sys
from pathlib import Path
REPOSITORY=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(REPOSITORY/'tests/nomacro_drainage'),str(REPOSITORY/'app/hybrid_water'),str(REPOSITORY/'tests/nomacro_scheduled_subsurface')]
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_calendar_state_portable_custody import source
from frost_calendar_state_probe import budgets
from frost_history_state_central import original_history
from original_output_files import compare

PRODUCER='a6823044669a113bfb3b5329c36377ed5941155b'
ARTIFACTS={'O0':(15017562125,37404281,'781fa5000d296f6f0b0dfd1dc2f30ad606a7f886db85b1cd9cad7cc2d935c84c'),
           'O2':(15018370008,39247011,'85d8c815ea64a11870bd5a4b1fcc8ca7a9d878064c1670ed2c986bf7a06e163d')}
ROOT=REPOSITORY


def read(path):return json.loads(path.read_text())


def seal(proof,opt):
    name='FROST_CALENDAR_STATE02_WINDOWS_CI_'+opt+'_ORIGINAL_V1';path=proof/(name+'.zip');artifact,size,digest=ARTIFACTS[opt]
    assert path.stat().st_size==size and SHA(path.read_bytes())==digest
    with zipfile.ZipFile(path) as z:
        assert len(z.namelist())==len(set(z.namelist())) and all(not n.endswith('/') for n in z.namelist())
        members={}
        for n in z.namelist():
            raw=z.read(n);members[n]=dict(bytes=len(raw),sha256=SHA(raw))
    q=dict(status='ACTUAL_ORIGINAL_CALENDAR_WINDOWS_CI_RAW_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,actual_artifact=artifact,actual_workflow_run=45604931670,actual_producer=PRODUCER,optimization=opt,canonical_admission=False)
    target=proof/(name+'.json')
    if target.exists():assert read(target)==q
    else:target.write_text(json.dumps(q,indent=2)+'\n')


def native(raw,meta,case):
    nodes=meta['project']['nodes'];solute=int(case['kind']=='cde');implicit=case['implicit'];hys=case['hysteresis']
    expected={('water',0):b'S5FCW001',('cde',0):b'S5FCC001',('water',1):b'S5FCW002',('cde',1):b'S5FCC002'}[(case['kind'],implicit)]
    assert raw[:8]==expected==meta['identity']['original_output']['native_codec'].encode()
    domain=struct.pack('<10i',1,nodes,0,solute,hys,1,1,1,1,2);assert raw.count(domain+domain)==1
    snow=struct.pack('<4i',1,nodes,solute,7);assert raw.count(snow+snow)==1
    values=struct.unpack_from('<7d',raw,raw.index(snow+snow)+32);assert all(math.isfinite(x) and x>=0 for x in values)
    if solute:
        n=20+nodes;header=struct.pack('<3i',2,nodes,n);assert raw.count(header+header)==1
        values=struct.unpack_from('<'+str(2*n)+'d',raw,raw.index(header+header)+24);assert values[:n]==values[n:] and all(map(math.isfinite,values))
    if implicit:
        header=(4,nodes,solute,1,hys,6,1,0);assert struct.unpack('<16i',raw[-96:-32])==header+header
        values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))


def checkpoint(path,meta,case,expected=None,external=False):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        q=json.loads(z.read('checkpoint.json'));binding=q['binding']
        if external:binding={k:v for k,v in binding.items() if k!='external_daily'}
        assert binding==meta['binding']
        assert all(SHA(z.read(n))==digest for n,digest in q['files'].items())
        if expected is not None:
            actual={k:v for k,v in q['receipt'].items() if k!='coupling'}
            assert physical(actual)==physical(expected)
        raw=z.read('macro.bin');native(raw,meta,case);original_history(z.read('result.end'),case['kind'],case['hysteresis'])
        return raw,z.read('result.end')


FIELDS=('stock_start_cm','stock_end_cm','external_flux_cm','pressure_head_cm','groundwater_cm','drainage_outward_cm','bottom_outward_cm')
def physical(row):return {k:row[k] for k in FIELDS}


def controls(folder,warm,data,meta,case):
    q=read(folder/'RESULT.json');assert q['status']=='ACTUAL_FROST_CALENDAR_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and q['accepted_mutant_model_days']==0
    groups=[('native',q['existing_calendar_thermal_refusals']),('extra-native',q['new_snow_private_and_codec_refusals'])]
    assert len(groups[0][1])==(44 if case['kind']=='cde' else 39) and len(groups[1][1])==(31 if case['kind']=='cde' else 27)
    if case['implicit']:
        assert q['root']['accepted_model_days']==0 and len(q['root']['refusals'])==25;groups.append(('root',q['root']['refusals']))
    good=checkpoint(warm/'accepted-column-1-day-4.zip',meta,case)[0];count=0
    for stem,items in groups:
        for item in items:
            target=folder/stem/item['attack'];errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            assert len(errors)==len(outputs)==1 and b'ERROR STOP' in errors[0].read_bytes()
            text=outputs[0].read_bytes();assert b'HYBRID_READY' not in text and b'HYBRID_DAY_RETURN' not in text
            assert not list(target.rglob('accepted-*.zip')) and (target/'origin/macro.bin').read_bytes()!=good;count+=1
    transactions=[]
    for stem,start in [('snow-transactions',4),('frost-calendar-transactions',30 if case['start'][5:7]=='12' else 4)]:
        base=folder/stem/'external';observed=[]
        for stage in ('trial-1','trial-2',''):
            observed.append(checkpoint(base/stage/f'accepted-column-1-day-{start+1}.zip',meta,case,data[start],True))
        assert observed[0]==observed[1]==observed[2]
        checkpoint(folder/stem/'recovered/trial-1'/f'accepted-column-1-day-{start+2}.zip',meta,case,data[start+1],True)
        if stem=='snow-transactions':assert max(data[start]['stock_start_cm'][2],data[start]['stock_end_cm'][2])>0
        transactions.append(dict(start=start,discard_replay_accept_exact=True,recovered_next_day_exact=True))
    return dict(actual_compiled_refusals=count,accepted_mutant_days=0,transactions=transactions)


def audit(proof,opt):
    if (proof/('FROST_CALENDAR_STATE02_WINDOWS_CI_'+opt+'_ORIGINAL_V1.zip')).is_file():seal(proof,opt)
    with ExitStack() as stack:
        store=Archive(proof,'FROST_CALENDAR_STATE02_WINDOWS_CI_'+opt+'_ORIGINAL_V1',stack)
        assert (store.record['actual_artifact'],store.record['bytes'],store.record['sha256'])==ARTIFACTS[opt]
        _,provenance=source(store,stack,expected_producer=PRODUCER,expected_physical='ed7042f02214b492eb23c1e7a9fda393865e8dc4',expected_workflow='.github/workflows/nomacro-frost-calendar-state02-windows.yml');batch=json.loads(store.get('current/RESULT.json'))
        assert batch['status']=='ACTUAL_WINDOWS_SELECTED_CALENDAR_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and batch['platform']=='Windows' and batch['actual_source']==PRODUCER and batch['optimization']==opt
        cases=json.loads((ROOT/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_CONTRACT_V1.json').read_text())['representative_cases']
        split=json.loads((ROOT/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_SPLIT_WINDOWS_EXECUTION_V1.json').read_text());selected=split['remaining_ci_contexts'][opt];cases=[case for case in cases if case['name'] in selected]
        assert [x['name'] for x in cases]==selected and [x['case'] for x in batch['contexts']]==cases
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));results=[]
        for case in cases:
            folder=ReadView(store,'current/'+case['name']);profile=folder/'science';q=read(profile/'RESULT.json');warm=profile/'trajectory'
            assert q['source']==q['actual_controller_source']==PRODUCER and q['duration_days']==case['days'] and q['kind']==case['kind']
            entry=projection[q['build_root']];build=ReadView(store,entry['archive_prefix']);meta=read(build/'BUILD.json');identity=meta['identity']
            assert SHA((build/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']==q['trajectory']['build_sha256']
            for n,digest in identity['donor_generated'].items():assert SHA((build/n).read_bytes())==digest
            for n,digest in identity['donor_objects'].items():assert SHA(store.get('original-provider-build/swap-obj/'+n))==digest
            for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+'.exe')).read_bytes())==digest
            assert '-'+opt in identity['donor_flags'] and '-'+opt in identity['kernel_flags'] and '-ffp-contract=off' in identity['donor_flags'] and '-ffp-contract=off' in identity['kernel_flags']
            from frost_calendar_terminal_water import source as terminal
            assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==terminal()
            scientific=budgets(warm,case['kind'],case['days']);assert scientific==q['independent_original_budgets']
            data=[json.loads(line) for line in (warm/'daily.jsonl').read_text().splitlines()]
            windows=[(2,4),(19,23),(30,34)] if case['days']==35 else [(2,case['days'])]
            if case['start'][5:7]=='12' and case['days']==35:windows.append((15,19))
            assert [(x['start'],x['end']) for x in q['own']]==windows
            cuts={case['days']}|{n for pair in windows for n in pair}
            paths=warm.glob('accepted-column-1-day-*.zip');assert {int(p.stem.rsplit('-',1)[1]) for p in paths}==cuts
            for day in cuts:checkpoint(warm/f'accepted-column-1-day-{day}.zip',meta,case,data[day-1])
            for start,end in windows:
                cold=profile/('own-'+str(start));rows=[json.loads(line) for line in (cold/'daily.jsonl').read_text().splitlines()]
                assert [physical(x) for x in rows]==[physical(x) for x in data[start:end]]
                assert checkpoint(cold/f'accepted-column-1-day-{end}.zip',meta,case,rows[-1])==checkpoint(warm/f'accepted-column-1-day-{end}.zip',meta,case,data[end-1])
                compare(warm/'original',cold/'original',identity['original_output'],start,end,case['start'])
            item=dict(case=case,actual_source=PRODUCER,science=scientific,native_samples=len(cuts),exact_cold_windows=len(windows))
            if case['days']==35:item['controls']=controls(folder/'controls',warm,data,meta,case)
            results.append(item)
        return dict(status='FRESH_ACTUAL_CALENDAR_ARCHIVE_SOURCE_ORIGINAL_BUDGET_NATIVE_COLD_OUTPUT_AND_CONTROLS_PASS',optimization=opt,archive_sha256=store.record['sha256'],source=provenance,contexts=results,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists();q=audit(a.proof,a.optimization);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],a.optimization)
