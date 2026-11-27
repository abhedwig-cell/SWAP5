"""Independent actual artifact audit; no model, compiler, HEAD or identity substitution."""
from contextlib import ExitStack
from decimal import Decimal,localcontext
from pathlib import Path
import argparse,ast,io,json,math,re,struct,sys,zipfile
from datetime import date
from closed_implicit_state_feedback import R,P,PARENT,SHA,git
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


class OriginalInputs:
    """A concrete archive opened from the real pinned scientific input commit."""
    NAME='IMPLICIT_HYDRAULIC_STATE11_FIRST_WINDOWS_O0_ORIGINAL_V1'
    def __init__(self,stack):
        self.source=GitArchiveSource(R,PARENT)
        self.archive=Archive(self.source,self.NAME,stack)


def original_inputs(q,inputs,original_store=None):
    authority=q['inputs']['authority']
    assert authority['actual_git_source']==PARENT and authority['archive']==OriginalInputs.NAME
    assert q['inputs']['additional_original_parameter_authority'] is None
    assert q['inputs']['declared_selectors']==dict(SWDRA=0,SWBOTB=6)
    with ExitStack() as stack:
        store=OriginalInputs(stack) if original_store is None else original_store
        assert isinstance(store,OriginalInputs) and store.source.repository==R.resolve() and store.source.revision==PARENT
        archive=store.archive;assert archive.record['sha256']==authority['archive_sha256']
        prefix=authority['prefix'];original={n[len(prefix):]:archive.get(n) for n in archive.names if n.startswith(prefix)}
        assert original and authority['original_members']=={n:dict(bytes=len(raw),sha256=SHA(raw)) for n,raw in original.items()}
        assert set(original)=={n for n,_ in q['input_inventory']}
        for name,raw in original.items():
            if name=='swap.swp':
                text=raw.decode('cp1252')
                for key,value in [('SWDRA',0),('SWBOTB',6)]:text=assignment(text,key,value)
                assert text.encode('cp1252')==(inputs/name).read_bytes()
            else:assert raw==(inputs/name).read_bytes()
    return dict(original_archive_sha256=archive.record['sha256'],all_original_parameters_and_other_input_bytes_preserved=True,only_explicit_declared_selectors_changed=True)


def observe(folder,build=None,inputs=None,controls=None,original_store=None):
    q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_CLOSED_IMPLICIT_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED' and q['days']==35
    build=Path(q['build_root']) if build is None else build;inputs=Path(q['input_root']) if inputs is None else inputs
    meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for role in ['donor','kernel']:
        names=[n for n in ['day_'+role,'day_'+role+'.exe'] if (build/n).is_file()];assert len(names)==1 and SHA((build/names[0]).read_bytes())==meta['executable_sha256'][role]
    assert dict(q['input_inventory'])==meta['inputs']
    trial=meta['identity']['implicit_hydraulic_state'].get('closed_desaturation_trial_start')
    if trial is not None:
        owner=git('show',q['actual_source']+':app/hybrid_water/implicit_closed_desaturation.py')
        tree=ast.parse(owner);policy=next(ast.literal_eval(v.value) for v in tree.body if isinstance(v,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='POLICY' for t in v.targets))
        assert trial['policy']==policy and trial['new_numerical_policy'] is True
        assert not trial['accepted_state_added'] and not trial['physical_equations_changed'] and not trial['tolerances_changed']
        assert trial['original_full_residual_and_budget_acceptance_required'] is True
        assert trial['providers']=={name:SHA(git('show',q['actual_source']+':app/hybrid_water/'+name)) for name in ['implicit_closed_desaturation.py','implicit_closed_desaturation_trial.f90']}
    for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
    input_proof=original_inputs(q,inputs,original_store)
    plan=json.loads(git('show',q['actual_source']+':'+P+'CLOSED_IMPLICIT_STATE13_FINITE_CASE_PLAN_V1.json'))
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
        grid=re.search(r'(?mis)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[ \t]*\n([^\n]*(?:\n[^\n]+)*)',active)
        assert grid is not None
        layers=[];grid_nodes=0
        for line in grid.group(1).splitlines():
            fields=line.split()
            if len(fields)!=4:break
            try:sub,soil,count=int(fields[0]),int(fields[1]),int(fields[3]);depth=float(fields[2].replace('D','e').replace('d','e'))
            except ValueError:break
            assert sub==len(layers)+1 and soil>0 and count>0 and math.isfinite(depth) and depth>0;layers.append(soil);grid_nodes+=count
        assert grid_nodes==nodes
        assert layers and set(layers)==set(range(1,max(layers)+1))
        effective=models*max(layers) if len(models)==1 else models;assert len(effective)==max(layers)
        header=[1,nodes,len(effective),int(spec['kind']=='cde'),1,0,spec['snow'],spec['frost'],1,2,0,6,0,*effective]
        packed=struct.pack('<'+str(len(header))+'i',*header);tag=b'S5IFX001' if spec['frost'] else b'S5IHX001'
        assert raw['macro.bin'].endswith(tag+packed+packed)

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
        c=json.loads((controls/'RESULT.json').read_text());assert c['status']=='ACTUAL_COMPILED_CLOSED_IMPLICIT_OWN_POSITIVE_AND_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS' and c['actual_producer_source']==q['actual_source'] and c['actual_BUILD_sha256']==q['actual_BUILD_sha256'] and c['genuine_own_positive_ready'] and c['model_days']==0
        assert b'HYBRID_READY' in (controls/'genuine-own-positive/donor.stdout').read_bytes() and not (controls/'genuine-own-positive/donor.stderr').read_bytes()
        original_receipt,original_payload=payload(folder/'trajectory/accepted-column-1-day-4.zip')
        good=original_payload['macro.bin'];assert c['original_checkpoint_sha256']==SHA((folder/'trajectory/accepted-column-1-day-4.zip').read_bytes())
        positive=(controls/'genuine-own-positive/donor.stdout').read_text().splitlines()
        states=[line.split()[1:] for line in positive if line.startswith('HYBRID_STOCK_FLUX ')]
        heads=[line.split()[1:] for line in positive if line.startswith('HYBRID_HYDRAULIC ')]
        assert len(states)==len(heads)==1 and list(map(float,states[0][:6]))==original_receipt['receipt']['stock_end_cm']
        assert list(map(float,heads[0][2:]))==original_receipt['receipt']['pressure_head_cm']
        domains=[]
        if spec['frost']:
            domains.append(['thermal',[1,nodes,0,int(spec['kind']=='cde'),spec['hysteresis'],1,1,0,1,2]])
            domains.append(['root',[5,nodes,int(spec['kind']=='cde'),1,spec['hysteresis'],6,1,0]])
        elif spec['snow']:
            domains.append(['root',[3,nodes,int(spec['kind']=='cde'),1,spec['hysteresis'],6,1,0]])
        domains.append(['implicit-per-layer',header]);assert c['domains']==domains
        expected_attacks={'foreign-magic':b'S5BAD999'+good[8:],'truncated':good[:-1],'trailing':good+b'x'}
        for label,values in domains:
            packed=struct.pack('<'+str(len(values))+'i',*values);assert good.count(packed+packed)==1
            pos=good.index(packed+packed);size=len(packed)
            for index,value in enumerate(values):
                bad=bytearray(good)
                for offset in [pos,pos+size]:struct.pack_into('<i',bad,offset+4*index,value+1)
                expected_attacks[label+'-field-'+str(index)]=bytes(bad)
            bad=bytearray(good);struct.pack_into('<i',bad,pos+size,values[0]+1);expected_attacks[label+'-single-witness']=bytes(bad)
        if scalar('SWODAT')==1 and scalar('SWMONTH')==0:
            dates=re.findall(r'(?mis)^\s*OUTDATINT\s*=\s*\n\s*(\d{4}-\d{2}-\d{2})',text);assert len(dates)==1
            if dates[0]<meta['project']['start_date']:
                positions=[]
                for pos in range(8,len(good)-160):
                    if good[pos:pos+8]!=struct.pack('<2i',1,nodes):continue
                    values=struct.unpack_from('<20i',good,pos)
                    if values[3]>100 and values==struct.unpack_from('<20i',good,pos+80):positions.append((pos,values))
                assert len(positions)==1;pos,values=positions[0];assert values[10]==1
                bad=bytearray(good)
                for offset in [pos,pos+80]:struct.pack_into('<i',bad,offset+40,2)
                expected_attacks['forged-advance-of-original-pending-date-pointer']=bytes(bad)
        assert len(c['refusals'])==len({v['attack'] for v in c['refusals']})==len(expected_attacks)
        assert {v['attack'] for v in c['refusals']}==set(expected_attacks)
        for check in c['refusals']:
            root=controls/check['attack'];assert (root/'origin/macro.bin').read_bytes()==expected_attacks[check['attack']];assert SHA((root/'origin/macro.bin').read_bytes())==check['actual_mutant_sha256'];out=(root/'donor.stdout').read_bytes();err=(root/'donor.stderr').read_bytes();assert b'ERROR STOP' in err and b'HYBRID_READY' not in out and b'HYBRID_DAY_RETURN' not in out;refusals+=1
        assert refusals==len(expected_attacks)
    return dict(case=q['case'],optimization=q['optimization'],actual_producer_source=q['actual_source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],original_inputs=input_proof,days=35,water_daily_max_cm=str(water),cde_daily_max_mg_cm2=str(chemical),cde_every_prefix_max_mg_cm2=str(prefix),native_samples=samples,exact_cold_windows=cold,actual_transaction_receipts_and_day5_native_replay_exact=True,compiled_native_refusals=refusals,compiler_executions=0,model_executions=0,canonical_admission=False)


def main():
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=dict(status='RUNNING_INDEPENDENT_CLOSED_IMPLICIT_ARTIFACT_SCIENCE',actual_observer_source=git('rev-parse','HEAD').decode().strip(),observer_file_sha256=SHA(Path(__file__).read_bytes()),contexts=[],compiler_executions=0,model_executions=0,canonical_admission=False)
    def save():a.output.write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        with ExitStack() as stack:
            original_store=OriginalInputs(stack)
            for folder in a.folder:
                q['contexts'].append(observe(folder,controls=folder.with_name(folder.name+'-native-controls'),original_store=original_store));save()
        q['status']='INDEPENDENT_CLOSED_IMPLICIT_ORIGINAL_INPUTS_1E10_NATIVE_COLD_AND_COMPILED_REFUSALS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_INDEPENDENT_CLOSED_IMPLICIT_SCIENCE',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['contexts']),flush=True)

if __name__=='__main__':main()
