"""Independent actual artifact audit; no model, compiler, HEAD or identity substitution."""
from contextlib import ExitStack
from decimal import Decimal,localcontext
from pathlib import Path
import argparse,io,json,math,re,struct,sys,zipfile
from datetime import date
from closed_gardner_state_feedback import R,P,PARENT,SHA,git
from original_output_baseline import assignment
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from original_output_files import compare as compare_output


def payload(path):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        assert set(z.namelist())=={'checkpoint.json','result.end','macro.bin'}
        meta=json.loads(z.read('checkpoint.json'));raw={n:z.read(n) for n in ['result.end','macro.bin']}
        assert {n:SHA(v) for n,v in raw.items()}==meta['files']
        return meta,raw


def original_inputs(q,inputs):
    authority=q['inputs']['authority'];source=GitArchiveSource(R,authority['actual_git_source'])
    assert source.revision==PARENT
    descriptor=json.loads((source/(authority['archive']+'.json')).read_bytes())
    assert descriptor['sha256']==authority['archive_sha256']
    with ExitStack() as stack:
        if 'parts' in descriptor:
            a=Archive(source,authority['archive'],stack);names=a.names;get=a.get
        else:
            raw=(source/descriptor['archive']).read_bytes();assert len(raw)==descriptor['bytes'] and SHA(raw)==descriptor['sha256']
            z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==len(descriptor['members']) and set(z.namelist())==set(descriptor['members'])
            names=descriptor['members']
            def get(n):
                raw=z.read(n);item=names[n];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
        prefix=authority['prefix'];original={n[len(prefix):]:get(n) for n in names if n.startswith(prefix)}
        assert original and authority['original_members']=={n:dict(bytes=len(v),sha256=SHA(v)) for n,v in original.items()}
        assert set(original)=={n for n,_ in q['input_inventory']}
        for name,raw in original.items():
            if name=='swap.swp':
                text=raw.decode('cp1252')
                extra=q['inputs'].get('additional_original_parameter_authority')
                if extra is not None:
                    assert extra['actual_git_source']==PARENT and extra['archive']==authority['archive'] and extra['archive_sha256']==descriptor['sha256']
                    donor=get(extra['member']);assert SHA(donor)==extra['member_sha256']
                    for key,row in extra['literal_original_named_lines'].items():
                        assert key in ['HA','APAR','OMEGA_K','H0'] and not re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text)
                        matches=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*(?:\r?\n|$)',donor.decode('cp1252'))
                        assert matches==[row];text+='\n'+row
                for key,value in q['inputs']['declared_selectors'].items():
                    text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
                assert text.encode('cp1252')==(inputs/name).read_bytes()
            else:assert raw==(inputs/name).read_bytes()
    return dict(original_archive_sha256=descriptor['sha256'],all_original_parameters_and_other_input_bytes_preserved=True,only_explicit_declared_selectors_changed=True)


def observe(folder,build=None,inputs=None,controls=None):
    q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_CLOSED_GARDNER_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED' and q['days']==35
    build=Path(q['build_root']) if build is None else build;inputs=Path(q['input_root']) if inputs is None else inputs
    meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for role in ['donor','kernel']:
        names=[n for n in ['day_'+role,'day_'+role+'.exe'] if (build/n).is_file()];assert len(names)==1 and SHA((build/names[0]).read_bytes())==meta['executable_sha256'][role]
    assert dict(q['input_inventory'])==meta['inputs']
    for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
    input_proof=original_inputs(q,inputs)
    plan=json.loads(git('show',q['actual_source']+':'+P+'CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3.json'))
    spec=next(v for v in plan['cases'] if v['name']==q['case']);assert spec==q['specification']
    text=(inputs/'swap.swp').read_text(encoding='cp1252');active='\n'.join(v.split('!',1)[0] for v in text.splitlines() if not v.lstrip().startswith('*'))
    def integers(key):
        rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active);assert len(rows)==1;return list(map(int,rows[0].split()))
    scalar=lambda key:integers(key)[0]
    expected=dict(SWMACRO=0,SWSOPHY=0,SWBR=0,SWHEA=1,SWCALT=2,SWSOLU=int(spec['kind']=='cde'),SWINCO=spec['initial'],SWKIMPL=spec['implicit'],SWHYST=spec['hysteresis'],SWFROST=spec['frost'],SWSNOW=spec['snow'],SWDRA=spec['drainage'],SWBOTB=spec['bottom'])
    assert all(scalar(key)==v for key,v in expected.items())
    models=integers('IHWCKMODEL');assert models==spec['models'];nodes=meta['project']['nodes']
    rows=[json.loads(line,parse_float=Decimal) for line in (folder/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
    water=chemical=prefix=Decimal(0);flows=[Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec=80
        for day,row in enumerate(rows,1):
            assert row['day']==day and row['committed'] is True
            a,b,f=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm'];res=sum(a)-sum(b)+sum(f[:7])-sum(f[7:]);water=max(water,abs(res));assert abs(res)<=Decimal('1e-10') and abs(row['kernel_residual_cm'])<=Decimal('1e-10')
            if spec['bottom']==6:assert f[-1]==0
            if spec['kind']=='cde':
                v=row['solute_ledger_mg_cm2'];a=row['solute_start_mg_cm2'];b=row['solute_end_mg_cm2'];res=b-a-sum(v[2:5])+sum(v[5:8]);chemical=max(chemical,abs(res));assert abs(res)<=Decimal('1e-10') and abs(b-v[0])<=Decimal('1e-10')
                flows=[x+y for x,y in zip(flows,v[2:8])];res=b-rows[0]['solute_start_mg_cm2']-sum(flows[:3])+sum(flows[3:]);prefix=max(prefix,abs(res));assert abs(res)<=Decimal('1e-10')
    primary=[json.loads(v) for v in (folder/'trajectory/daily.jsonl').read_text().splitlines()]
    samples=[]
    for day in [2,4,7,9,30,34,35]:
        receipt,raw=payload(folder/'trajectory'/f'accepted-column-1-day-{day}.zip');assert receipt['binding']==meta['binding'] and receipt['receipt']==primary[day-1]
        assert raw['macro.bin'][:8].decode()==meta['identity']['original_output']['native_codec']
        if spec['kind']=='cde':
            values=struct.unpack_from('<'+str(nodes+2)+'d',raw['macro.bin'],48);assert all(math.isfinite(v) and v>=0 for v in values) and values[-1]==float(rows[day-1]['solute_end_mg_cm2'])
        samples.append(dict(day=day,bytes=len(raw['macro.bin']),sha256=SHA(raw['macro.bin'])))
    cold=[];windows=[(2,4),(7,9),(30,34)]
    first=date.fromisoformat(meta['project']['start_date']);seam=(date(first.year+1,1,1)-first).days
    if 2<seam<35:
        cuts=[2,4,7,9,30,34,35];pair=(max(v for v in cuts if v<seam),min(v for v in cuts if v>seam))
        assert q['actual_calendar_derived_year_window']==dict(start_date=str(first),new_year_offset=seam,window=list(pair))
        if pair not in windows:windows.append(pair)
    if spec['snow']:assert max(v['stock_end_cm'][2] for v in rows)>0
    for lo,hi in windows:
        _,full=payload(folder/'trajectory'/f'accepted-column-1-day-{hi}.zip');_,actual=payload(folder/f'own-{lo}'/f'accepted-column-1-day-{hi}.zip');assert full==actual
        output=compare_output(folder/'trajectory/original',folder/f'own-{lo}'/'original',meta['identity']['original_output'],lo,hi,meta['project']['start_date']);assert output and all(v['exact'] for v in output.values())
        cold.append(dict(start=lo,end=hi,complete_native_and_original_end_bytes_equal=True,exact_original_user_output=output))
    transaction=None
    for relative,day in [('external/trial-1',5),('external/trial-2',5),('external',5),('recovered/trial-1',6)]:
        receipt,raw=payload(folder/'transactions'/relative/f'accepted-column-1-day-{day}.zip');a=dict(primary[day-1]);b=dict(receipt['receipt']);a.pop('revision');b.pop('revision');b.pop('coupling',None);assert a==b
        if day==5:
            if transaction is None:transaction=raw
            assert transaction==raw
    refusals=0
    if controls is not None:
        c=json.loads((controls/'RESULT.json').read_text());assert c['status']=='ACTUAL_COMPILED_CLOSED_GARDNER_OWN_POSITIVE_AND_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS' and c['actual_producer_source']==q['actual_source'] and c['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and c['genuine_own_positive_ready'] and c['model_days']==0
        assert b'HYBRID_READY' in (controls/'genuine-own-positive/donor.stdout').read_bytes() and not (controls/'genuine-own-positive/donor.stderr').read_bytes()
        for check in c['refusals']:
            root=controls/check['attack'];assert SHA((root/'origin/macro.bin').read_bytes())==check['actual_mutant_sha256'];out=(root/'donor.stdout').read_bytes();err=(root/'donor.stderr').read_bytes();assert b'ERROR STOP' in err and b'HYBRID_READY' not in out and b'HYBRID_DAY_RETURN' not in out;refusals+=1
        assert refusals>=3
    return dict(case=q['case'],optimization=q['optimization'],actual_producer_source=q['actual_source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],original_inputs=input_proof,days=35,water_daily_max_cm=str(water),cde_daily_max_mg_cm2=str(chemical),cde_every_prefix_max_mg_cm2=str(prefix),native_samples=samples,exact_cold_windows=cold,actual_transaction_receipts_and_day5_native_replay_exact=True,compiled_native_refusals=refusals,compiler_executions=0,model_executions=0,canonical_admission=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=dict(status='RUNNING_INDEPENDENT_CLOSED_GARDNER_ARTIFACT_SCIENCE',actual_observer_source=git('rev-parse','HEAD').decode().strip(),observer_file_sha256=SHA(Path(__file__).read_bytes()),contexts=[],compiler_executions=0,model_executions=0,canonical_admission=False)
    def save():a.output.write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for folder in a.folder:
            q['contexts'].append(observe(folder,controls=folder.with_name(folder.name+'-native-controls')));save()
        q['status']='INDEPENDENT_CLOSED_GARDNER_ORIGINAL_INPUTS_1E10_NATIVE_COLD_AND_COMPILED_REFUSALS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_INDEPENDENT_CLOSED_GARDNER_SCIENCE',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['contexts']),flush=True)

if __name__=='__main__':main()
