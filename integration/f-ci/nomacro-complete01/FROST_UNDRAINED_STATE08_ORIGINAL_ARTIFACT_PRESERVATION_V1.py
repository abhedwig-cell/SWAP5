"""Preserve exact terminal CI artifacts; no scientific execution."""
import hashlib,json,zipfile,subprocess
from pathlib import Path
E=Path(__file__).resolve().parent
R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01')
P=R/'integration/f-ci/nomacro-complete01'
SHA=lambda b:hashlib.sha256(b).hexdigest()
PRODUCER='127af752c5519e7f9d9a6894c61137f0ee7f3920'
items=[('UBUNTU','O0',15081318316),('UBUNTU','O2',15081188078),('WINDOWS','O0',15082460157),('WINDOWS','O2',15081483258)]
records=[]
for platform,opt,artifact in items:
    source=E/f'FROST_UNDRAINED_STATE08_ORIGINAL_ARTIFACT_{artifact}.zip'
    official=json.loads(source.with_suffix('.zip.json').read_text())['official']
    raw=source.read_bytes();assert len(raw)==official['size_in_bytes'] and 'sha256:'+SHA(raw)==official['digest']
    assert official['workflow_run']['head_sha']==PRODUCER and not official['expired']
    name=f'FROST_UNDRAINED_STATE08_{platform}_{opt}_ORIGINAL_V1'
    with zipfile.ZipFile(source) as z:
        assert len(z.namelist())==len(set(z.namelist()))
        assert all(not n.endswith('/') and '..' not in Path(n).parts and not Path(n).is_absolute() for n in z.namelist())
        members={n:dict(bytes=len(z.read(n)),sha256=SHA(z.read(n))) for n in z.namelist()}
        current=json.loads(z.read('current/RESULT.json'));inherited=json.loads(z.read('current-inherited-postimages/RESULT.json'))
        assert current['source']==inherited['actual_source']==PRODUCER
        assert current['status']=='ACTUAL_SELECTED_UNDRAINED_FROST_PERIODS_NATIVE_COLD_AND_CONTROLS_PASS_NOT_ADMITTED'
        assert inherited['status']=='EIGHT_CURRENT_UNCHANGED_DRAINED_FROST_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
        assert len(current['contexts'])==16 and len(inherited['contexts'])==8 and inherited['model_executions']==0
    parts=[]
    for i,offset in enumerate(range(0,len(raw),25*1024**2),1):
        value=raw[offset:offset+25*1024**2];file=name+f'.zip.part{i:03d}'
        with (P/file).open('xb') as out:out.write(value)
        assert (P/file).read_bytes()==value
        parts.append(dict(file=file,bytes=len(value),sha256=SHA(value)))
    record=dict(status='ORIGINAL_TERMINAL_CI_BYTES_PRESERVED_PENDING_INDEPENDENT_SCIENCE_AND_ADMISSION',archive=name+'.zip',bytes=len(raw),sha256=SHA(raw),parts=parts,members=members,official=official,actual_producer=PRODUCER,platform=platform,optimization=opt,scientific_contexts=16,unchanged_drained_builds=8,canonical_admission=False)
    with (P/(name+'.json')).open('x',encoding='utf8') as out:json.dump(record,out,indent=2);out.write('\n')
    records.append({k:v for k,v in record.items() if k!='members'})
    print(platform,opt,len(raw),SHA(raw),len(members),flush=True)
active=E.parent/'frost-undrained-state08-active-frost-transaction-v1'
name='FROST_UNDRAINED_STATE08_ACTIVE_FROST_TRANSACTIONS_RAW_V1';target=P/(name+'.zip');members={}
files={p.relative_to(active).as_posix():p for p in active.rglob('*') if p.is_file()}
for file in ['FROST_UNDRAINED_STATE08_ACTIVE_FROST_TRANSACTIONS_V1.json','frost-undrained-state08-actual-active-frost-transactions-v1.py',Path(__file__).name]:files['controllers/'+file]=E/file
with zipfile.ZipFile(target,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for n,p in sorted(files.items()):
        value=p.read_bytes();z.writestr(n,value);members[n]=dict(bytes=len(value),sha256=SHA(value))
raw=target.read_bytes()
with zipfile.ZipFile(target) as z:
    assert set(z.namelist())==set(members)
    for n,item in members.items():assert SHA(z.read(n))==item['sha256']
record=dict(status='TWO_ACTUAL_DAY19_ACTIVE_FROST_TRANSACTIONS_PRESERVED_NOT_ADMITTED',archive=target.name,bytes=len(raw),sha256=SHA(raw),parts=[dict(file=target.name,bytes=len(raw),sha256=SHA(raw))],members=members,actual_observer=PRODUCER,actual_compiled_producer='656cd3ed25c91dc6ab8de12f2525fd30be8e358f',compiler_executions=0,full_period_replays=0,canonical_admission=False)
with (P/(name+'.json')).open('x',encoding='utf8') as out:json.dump(record,out,indent=2);out.write('\n')
with (E/'FROST_UNDRAINED_STATE08_PRESERVED_FOUR_PORTABLE_AND_ACTIVE_V1.json').open('x',encoding='utf8') as out:json.dump(dict(portable=records,active={k:v for k,v in record.items() if k!='members'},actual_preservation_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()),out,indent=2);out.write('\n')
print('PRESERVED_FOUR_ORIGINAL_PORTABLE_AND_TWO_ACTIVE_TRANSACTIONS_NO_REPLAY',flush=True)
