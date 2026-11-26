"""Independently read actual implicit model/state artifacts without running a model."""
import argparse,hashlib,io,json,math,re,struct,subprocess,zipfile
from contextlib import ExitStack
from decimal import Decimal,localcontext
from pathlib import Path,PureWindowsPath
from datetime import date
R=Path(__file__).resolve().parents[2]
SHA=lambda b:hashlib.sha256(b).hexdigest()
CASES={'gardner-water':'-v2','model7-snow-cde-fitted':'','model3-water':'-v2',
       'model4-snow-water':'','model5-cde-profile':'-v2','model6-snow-cde-profile':'-v2',
       'mixed8-9-water':'','mixed10-11-snow-water':'','mixed1-7-cde':'-v2'}


def payload(path):
    with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
        assert set(z.namelist())=={'checkpoint.json','result.end','macro.bin'}
        meta=json.loads(z.read('checkpoint.json'));files={n:z.read(n) for n in ['result.end','macro.bin']}
        assert {n:SHA(raw) for n,raw in files.items()}==meta['files']
    return meta,files


def observe(folder,locations=None):
    q=json.loads((folder/'RESULT.json').read_text());frost=q['status']=='ACTUAL_ORIGINAL_IMPLICIT_FROST_ANALYTICAL_STATE_PHYSICAL_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    assert frost or q['status']=='ACTUAL_IMPLICIT_ANALYTICAL_STATE_PHYSICAL_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    build=Path(q['build_root']) if locations is None else locations(q['build_root'])
    inputs=Path(q['input_root']) if locations is None else locations(q['input_root'])
    b=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    for name,digest in b['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for role,name in [('donor','day_donor.exe'),('kernel','day_kernel.exe')]:assert SHA((build/name).read_bytes())==b['executable_sha256'][role]
    for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
    source=(inputs/'swap.swp').read_text(encoding='cp1252');active='\n'.join(line.split('!',1)[0] for line in source.splitlines() if not line.lstrip().startswith('*'))
    def integers(name):
        values=re.findall(r'(?mi)^\s*'+name+r'\s*=\s*([^\r\n]+)',active);assert len(values)==1;return list(map(int,values[0].split()))
    scalar=lambda n:integers(n)[0]
    assert all(scalar(k)==v for k,v in dict(SWMACRO=0,SWKIMPL=1,SWHYST=0,SWSOPHY=0,SWFROST=int(frost),SWHEA=1,SWCALT=2).items())
    grid=re.findall(r'(?mi)^\s*ISUBLAY\s+ISOILLAY\s+HSUBLAY\s+NCOMP[^\n]*\n((?:\s*\d+[^\n]*\n)+)',active);assert len(grid)==1
    layers=max(int(line.split()[1]) for line in grid[0].splitlines());models=integers('IHWCKMODEL');models=models*layers if len(models)==1 else models
    assert len(models)==layers and all(1<=v<=11 for v in models) and any(v!=1 for v in models)
    nodes=b['project']['nodes'];kind=scalar('SWSOLU');snow=scalar('SWSNOW');bottom=scalar('SWBOTB');assert bottom in (5,8)
    drainage=scalar('SWDRA');assert drainage in (0,1) and (frost or drainage==1)
    partition=0
    if drainage:
        names=re.findall(r"(?mi)^\s*DRFIL\s*=\s*'([^']+)'",active);prefix=re.findall(r"(?mi)^\s*PATHDRAIN\s*=\s*'([^']*)'",active);assert len(names)==len(prefix)==1
        drain=(inputs/(prefix[0].strip()+names[0]+'.dra')).read_text(encoding='cp1252');parts=re.findall(r'(?mi)^\s*SWDIVD\s*=\s*([01])\b',drain);assert len(parts)==1
        partition=int(parts[0]);assert not frost or partition==1
    domain=[1,nodes,layers,kind,1,0,snow,int(frost),1,2,drainage,bottom,partition,*models]
    expected=(b'S5IFX001' if frost else b'S5IHX001')+struct.pack('<'+str(len(domain))+'i',*domain)*2
    daily_path=folder/'trajectory/daily.jsonl';rows=[json.loads(line,parse_float=Decimal) for line in daily_path.read_text().splitlines()];assert len(rows)==35
    water=chemical=prefix_max=Decimal(0);ledger_totals=[Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec=80
        for day,row in enumerate(rows,1):
            assert row['day']==day and row['committed'] is True
            start,end,flux=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm'];residual=sum(start)-sum(end)+sum(flux[:7])-sum(flux[7:]);water=max(water,abs(residual))
            assert abs(residual)<=Decimal('1e-10') and abs(row['kernel_residual_cm'])<=Decimal('1e-10')
            if kind:
                ledger=row['solute_ledger_mg_cm2'];before=row['solute_start_mg_cm2'];after=row['solute_end_mg_cm2'];residual=after-before-sum(ledger[2:5])+sum(ledger[5:8]);chemical=max(chemical,abs(residual));assert abs(residual)<=Decimal('1e-10') and abs(after-ledger[0])<=Decimal('1e-10')
                ledger_totals=[a+b for a,b in zip(ledger_totals,ledger[2:8])];prefix=after-rows[0]['solute_start_mg_cm2']-sum(ledger_totals[:3])+sum(ledger_totals[3:]);prefix_max=max(prefix_max,abs(prefix));assert abs(prefix)<=Decimal('1e-10')
    samples=[]
    for day in [2,4,7,9,30,34,35]:
        meta,files=payload(folder/'trajectory'/f'accepted-column-1-day-{day}.zip');assert meta['binding']==b['binding']
        assert meta['receipt']==json.loads(daily_path.read_text().splitlines()[day-1])
        raw=files['macro.bin'];assert raw[:8].decode()==b['identity']['original_output']['native_codec'] and raw.endswith(expected)
        if kind:
            values=struct.unpack_from('<'+str(nodes+2)+'d',raw,48);assert all(math.isfinite(v) and v>=0 for v in values) and values[-1]==float(rows[day-1]['solute_end_mg_cm2'])
        samples.append(dict(day=day,bytes=len(raw),sha256=SHA(raw)))
    cold=[]
    windows=[(2,4),(7,9),(30,34)]
    first=date.fromisoformat(b['project']['start_date']);seam=(date(first.year+1,1,1)-first).days
    if frost and 2<seam<35:
        cuts=[2,4,7,9,30,34,35];pair=(max(d for d in cuts if d<seam),min(d for d in cuts if d>seam))
        if pair not in windows:windows.append(pair)
    for lo,hi in windows:
        _,full=payload(folder/'trajectory'/f'accepted-column-1-day-{hi}.zip');_,actual=payload(folder/f'own-{lo}'/f'accepted-column-1-day-{hi}.zip');assert full==actual
        cold.append(dict(start=lo,end=hi,actual_complete_native_and_original_end_bytes_equal=True))
    transaction_origin=None
    for relative,day in [('external/trial-1',5),('external/trial-2',5),('external',5),('recovered/trial-1',6)]:
        meta,actual=payload(folder/'transactions'/relative/f'accepted-column-1-day-{day}.zip')
        primary=json.loads(daily_path.read_text().splitlines()[day-1])
        actual_receipt=dict(meta['receipt']);primary.pop('revision');actual_receipt.pop('revision');actual_receipt.pop('coupling',None)
        assert actual_receipt==primary
        if day==5:
            if transaction_origin is None:transaction_origin=actual
            assert actual==transaction_origin
        # Primary checkpoints5/6 were deliberately not requested. Native byte
        # equality here is discard/replay/accept5; recovered6 is compared to
        # the exact actual primary physical receipt, without inventing a
        # missing primary native snapshot.
        assert actual['macro.bin'].endswith(expected)
    logs=[]
    for path in folder.rglob('*'):
        if path.suffix.lower() not in ('.stdout','.err','.wrn','.war','.log'):continue
        raw=path.read_bytes();assert b'No convergence was reached' not in raw;logs.append(dict(path=path.relative_to(folder).as_posix(),sha256=SHA(raw)))
    assert logs
    return dict(case=q['case'],optimization=q['optimization'],actual_producer_source=q['actual_source'],actual_BUILD_sha256=q['actual_BUILD_sha256'],days=35,models=models,initial=scalar('SWINCO'),snow=snow,solute=kind,water_daily_max_cm=str(water),cde_daily_max_mg_cm2=str(chemical),cde_every_prefix_max_mg_cm2=str(prefix_max),native_samples=samples,exact_cold_windows=cold,actual_discard_replay_accept_day5_native_payloads_equal=True,actual_recovered_next_day6_primary_physical_receipt_equal=True,original_convergence_diagnostics=logs)


def main():
    p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=dict(status='RUNNING_INDEPENDENT_ACTUAL_MODEL_BRANCH_COMPOSITION_SCIENCE',actual_observer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),observer_file_sha256=SHA(Path(__file__).read_bytes()),compiler_executions=0,model_executions=0,canonical_admission=False,contexts=[])
    def save():a.output.write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for folder in a.folder:q['contexts'].append(observe(folder));save()
        q.update(status='INDEPENDENT_ACTUAL_MODEL_BRANCH_COMPOSITION_NATIVE_COLD_TRANSACTIONS_AND_1E10_BUDGETS_PASS_NOT_ADMITTED',primary_days=sum(v['days'] for v in q['contexts']))
    except Exception as error:q.update(status='FAILED_INDEPENDENT_ACTUAL_MODEL_BRANCH_COMPOSITION_SCIENCE',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['contexts']),flush=True)
if __name__=='__main__':main()
