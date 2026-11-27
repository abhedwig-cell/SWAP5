"""Independent original default pressure/calendar artifact audit; no model execution."""
import argparse,ast,io,json,re,struct,sys,zipfile
from contextlib import ExitStack
from datetime import date
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from closed_default_calendar_feedback import P,PARENT,SHA,git
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from original_output_baseline import assignment
from initial_pressure_profile_science import initialized_heads,PROVIDER
from implicit_conductivity_forensics import water,original_observations,output_calendar,sequential_records
from original_output_files import compare as compare_output
from output_hysteresis_baseline import history
from cde_interval_runtime import audit_daily
from closed_implicit_state_science import payload
CODECS={'implicit-monthly-cde':'S5CIC001','implicit-perstep-water':'S5IOW001',
        'hys1-clock-water':'S5IHW001','hys2-monthly-water':'S5IHW001','hys2-periodic-cde':'S5CIH001'}
FROZEN=['tests/nomacro_drainage/initial_pressure_profile_science.py',
        'tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py',
        'tests/nomacro_scheduled_subsurface/original_output_files.py',
        'tests/nomacro_scheduled_subsurface/output_hysteresis_baseline.py',
        'tests/nomacro_scheduled_subsurface/cde_interval_runtime.py']


class OriginalInputs:
    def __init__(self,stack):
        self.source=GitArchiveSource(R,PARENT)
        self.archive=Archive(self.source,'INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1',stack)


def source_contract(producer):
    names=git('diff','--name-only',PARENT,producer,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines()
    available=[]
    for version in [1,2,3]:
        name=P+'CLOSED_DEFAULT_CALENDAR_STATE14_SOURCE_PROPOSAL_V'+str(version)+'.json'
        import subprocess
        child=subprocess.run(['git','show',producer+':'+name],cwd=R,capture_output=True)
        if child.returncode==0:available.append(json.loads(child.stdout))
    assert available;proposal=available[-1];assert proposal['actual_canonical_parent']==PARENT
    assert set(names)==set(proposal['files'])
    for name,v in proposal['files'].items():
        after=git('show',producer+':'+name);assert SHA(after)==v['after_lf_sha256']
        if v['new_file']:assert after.decode()==v['complete_source'];continue
        before=git('show',PARENT+':'+name);assert SHA(before)==v['before_lf_sha256'];replay=before.decode()
        for edit in reversed(v['ordered_literal_edits']):
            lo,hi=edit['base_start'],edit['base_end'];assert replay[lo:hi]==edit['before'];replay=replay[:lo]+edit['after']+replay[hi:]
        assert replay.encode()==after
    assert all(proposal[k] is False for k in ['new_native_codec','new_physical_state','physical_equations_changed','new_numerical_policy','tolerances_or_iteration_limits_changed','parameters_or_output_controls_or_dates_normalized'])
    return dict(actual_producer=producer,complete_literal_inverses=len(names),source_proposal_sha256=SHA(json.dumps(proposal,sort_keys=True).encode()))


def observe(folder,reference,build=None,inputs=None,controls=None,store=None):
    for name in FROZEN:assert (R/name).read_bytes().replace(b'\r\n',b'\n')==git('show',PARENT+':'+name),'Changed complete inherited observer '+name
    q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_CLOSED_DEFAULT_CALENDAR_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED' and q['days']==35
    spec=q['specification'];assert q['case'] in CODECS
    plan=json.loads(git('show',q['actual_source']+':'+P+'CLOSED_DEFAULT_CALENDAR_STATE14_FINITE_CASE_PLAN_V1.json'))
    assert spec==next(v for v in plan['cases'] if v['name']==q['case'])
    source=source_contract(q['actual_source'])
    build=Path(q['build_root']) if build is None else build;inputs=Path(q['input_root']) if inputs is None else inputs
    meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];selected=identity['original_output'];n=meta['project']['nodes']
    assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    assert selected['native_codec']==CODECS[q['case']] and not identity.get('implicit_hydraulic_state')
    for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
    for name,digest in PROVIDER.items():assert SHA((reference/'build/swap-selected'/name).read_bytes().replace(b'\r\n',b'\n'))==digest
    for field in ['donor_flags','kernel_flags']:assert '-'+q['optimization'] in identity[field]
    for role,digest in meta['executable_sha256'].items():
        paths=[v for v in [build/('day_'+role),build/('day_'+role+'.exe')] if v.is_file()];assert len(paths)==1 and SHA(paths[0].read_bytes())==digest
    assert dict(q['input_inventory'])==meta['inputs']
    authority=q['inputs']['authority'];assert authority['actual_git_source']==PARENT and authority['actual_original_scientific_producer']==spec['actual_original_input_producer']
    assert authority['archive']=='INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1' and authority['prefix']==spec['actual_original_input_prefix']
    assert q['inputs']['declared_selectors']==dict(SWDRA=0,SWBOTB=6) and q['inputs']['additional_original_parameter_authority'] is None
    with ExitStack() as stack:
        original=OriginalInputs(stack) if store is None else store
        assert isinstance(original,OriginalInputs) and original.source.repository==R.resolve() and original.source.revision==PARENT
        archive=original.archive;assert archive.record['sha256']==authority['archive_sha256'];prefix=authority['prefix']
        members={name[len(prefix):]:archive.get(name) for name in archive.names if name.startswith(prefix)}
        assert members and set(members)==set(meta['inputs']) and authority['original_members']=={name:dict(bytes=len(raw),sha256=SHA(raw)) for name,raw in members.items()}
        for name,raw in members.items():
            if name=='swap.swp':
                text=raw.decode('cp1252')
                for key,value in [('SWDRA',0),('SWBOTB',6)]:text=assignment(text,key,value)
                raw=text.encode('cp1252')
            assert raw==(inputs/name).read_bytes() and SHA(raw)==meta['inputs'][name]
    text=(inputs/'swap.swp').read_text(encoding='cp1252');active='\n'.join(v.split('!',1)[0] for v in text.splitlines() if not v.lstrip().startswith('*'))
    scalar=lambda key:int(re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([+-]?\d+)[ \t]*$',active)[0])
    assert all(scalar(key)==value for key,value in dict(SWINCO=1,SWDRA=0,SWBOTB=6,SWMACRO=0,SWFROST=0,SWSNOW=0,SWHYST=spec['hysteresis'],SWKIMPL=spec['implicit'],SWSOLU=int(spec['kind']=='cde')).items())
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    assert not models or len(models)==1 and set(map(int,models[0].split()))=={1}
    rows=[json.loads(line) for line in (folder/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
    budgets=water(rows);assert all(row['external_flux_cm'][-1]==0 for row in rows)
    observations=original_observations((folder/'trajectory/original/donor.stdout').read_bytes(),rows,meta['project']['start_date'])
    expected,initial=initialized_heads(text)
    actual=next(list(map(float,line.split()[3:])) for line in (folder/'trajectory/original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_HYDRAULIC '))
    assert len(actual)==n and actual==expected
    windows=[(2,4),(7,9),(30,34)];cuts={2,4,7,9,30,34,35}
    first=date.fromisoformat(meta['project']['start_date']);seam=(date(first.year+1,1,1)-first).days
    if 2<seam<35:
        pair=(max(d for d in cuts if d<seam),min(d for d in cuts if d>seam))
        assert q['actual_calendar_derived_year_window']==dict(start_date=str(first),new_year_offset=seam,window=list(pair))
        if pair not in windows:windows.append(pair)
    samples=[];active_history=False
    for day in sorted(cuts):
        receipt,raw=payload(folder/'trajectory'/f'accepted-column-1-day-{day}.zip')
        assert receipt['binding']==meta['binding'] and receipt['receipt']==rows[day-1] and raw['macro.bin'][:8].decode()==CODECS[q['case']]
        assert struct.unpack_from('<i',raw['macro.bin'],8)[0]==n
        calendar=output_calendar(raw['macro.bin'],n,rows[day-1],selected,meta['project']['start_date'],spec['kind']=='cde')
        sequential_records(raw['result.end'])
        if spec['hysteresis']:
            observed=history(raw['result.end']);assert observed['mode']==spec['hysteresis']
            active_history|=any(v!=(1 if spec['hysteresis']==1 else -1) for v in observed['index']) or any(v!=1. for v in observed['fhyst'])
            domain=struct.pack('<5i',1,n,0,spec['hysteresis'],int(spec['kind']=='cde'));assert raw['macro.bin'].count(domain+domain)==1
        samples.append(dict(day=day,sha256=SHA(raw['macro.bin']),calendar=calendar))
    if spec['hysteresis']:assert active_history
    cold=[]
    for lo,hi in windows:
        _,warm=payload(folder/'trajectory'/f'accepted-column-1-day-{hi}.zip');_,restarted=payload(folder/f'own-{lo}'/f'accepted-column-1-day-{hi}.zip');assert warm==restarted
        files=compare_output(folder/'trajectory/original',folder/f'own-{lo}'/'original',selected,lo,hi,meta['project']['start_date']);assert files and all(v['exact'] for v in files.values())
        cold.append(dict(start=lo,end=hi,complete_payload_equal=True,exact_original_output=files))
    chemical=audit_daily(folder/'trajectory',35,n) if spec['kind']=='cde' else None
    previous=None
    for relative,day in [('external/trial-1',5),('external/trial-2',5),('external',5),('recovered/trial-1',6)]:
        receipt,raw=payload(folder/'transactions'/relative/f'accepted-column-1-day-{day}.zip');a=dict(rows[day-1]);b=dict(receipt['receipt']);a.pop('revision');b.pop('revision');b.pop('coupling',None);assert a==b
        if day==5:
            if previous is None:previous=raw
            assert previous==raw
    refusals=0
    if controls is not None:
        c=json.loads((controls/'RESULT.json').read_text());assert c['status']=='ACTUAL_DEFAULT_CALENDAR_OWN_POSITIVE_AND_COMPILED_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
        assert c['actual_producer_source']==q['actual_source'] and c['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and c['genuine_own_positive_ready'] and c['model_days']==c['compiler_executions']==0
        assert c['original_checkpoint_sha256']==SHA((folder/'trajectory/accepted-column-1-day-4.zip').read_bytes())
        stdout=(controls/'genuine-own-positive/donor.stdout').read_bytes();assert b'HYBRID_READY' in stdout and b'HYBRID_DAY_RETURN' not in stdout and not (controls/'genuine-own-positive/donor.stderr').read_bytes()
        assert c['refusals']
        for attack in c['refusals']:
            assert attack['status']=='REFUSED';target=controls/'native'/attack['attack'];errors=list(target.rglob('donor.stderr'));assert errors
            assert any(b'ERROR STOP' in path.read_bytes() for path in errors)
            assert all(b'HYBRID_READY' not in path.read_bytes() and b'HYBRID_DAY_RETURN' not in path.read_bytes() for path in target.rglob('donor.stdout'))
            assert not list(target.glob('accepted-*.zip'));refusals+=1
    return dict(status='INDEPENDENT_ACTUAL_DEFAULT_CALENDAR_INPUT_SOURCE_BUDGET_PRIVATE_NATIVE_COLD_TRANSACTION_PASS',actual_producer=q['actual_source'],case=q['case'],optimization=q['optimization'],source_contract=source,
        days=35,initial_pressure_nodes=n,initial_profile=initial,actual_default_hydraulic_model=1,native_codec=CODECS[q['case']],water=budgets,original_observations=observations,
        original_input_archive_sha256=authority['archive_sha256'],only_declared_selectors_changed=True,native_samples=samples,active_original_hysteresis=bool(active_history),cold=cold,
        actual_CDE_daily_increment_rows=chemical['actual_days'] if chemical else 0,native_refusals=refusals,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ['profile','reference-work','output']:p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--controls',type=Path);a=p.parse_args();q=observe(a.profile,a.reference_work,controls=a.controls)
    with a.output.open('x',encoding='utf8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],q['case'],q['optimization'],flush=True)
