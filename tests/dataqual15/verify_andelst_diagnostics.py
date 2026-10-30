"""Verify bounded experimental Andelst evidence, never current production admission."""
import csv,hashlib,io,json,struct,tarfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def verify():
 report=json.loads((ROOT/'integration/dataqual15/ANDELST_STORAGE_AND_SHARP_RESULT.json').read_text())
 assert not report['canonical_admitted']and not report['full_original_complete']and not report['scientific_equivalence']
 raw=(ROOT/report['evidence_path']).read_bytes();assert sha(raw)==report['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b)for n,b in files.items()}
 get=lambda n:json.loads(files[n]);rows=lambda n:list(csv.DictReader(io.StringIO(files[n].decode())))
 def checkpoint(n,clock):
  b=files[n];assert b[:8]==b'S5WM0001'and zlib.crc32(b[:-4])==struct.unpack('=I',b[-4:])[0]
  assert struct.unpack_from('=ii',b,72)==(112,5)and struct.unpack_from('=d',b,204)[0]==clock
  return b
 for opt,days in [('O0',50),('O2',65)]:
  name='andelst-contact-conservative-'+opt;build=get(name+'/BUILD.json');assert sha(files[name+'/native'])==build['executable_sha256']
  assert build['provider_count']==199 and all(e['returncode']==0 for e in build['events'])
  run='andelst-conservative-original-'+opt;r=get(run+'/RESULT.json');assert not r['censored']and r['completed_day']==days
  assert r['returncode']==(0 if opt=='O0'else 1)
  launch=get(run+'/LAUNCH.json');assert launch['command'][9]=='0.0001'
  b=rows(run+'/budget.csv');assert len(b)==days and[int(q['day'])for q in b]==list(range(1,days+1))
  assert max(abs(float(q['water_residual_cm']))for q in b)<1e-10
  checkpoint(run+'/restart.bin',days)
 a=checkpoint('andelst-conservative-original-O0/restart.bin',50)
 b=checkpoint('andelst-conservative-original-O2/restart-50.bin',50)
 assert a[72:-4]==b[72:-4]
 full=rows('andelst-conservative-original-O2/budget.csv');assert rows('andelst-conservative-original-O0/budget.csv')==full[:50]
 split='andelst-conservative-restart43-50-O2';r=get(split+'/RESULT.json');assert r['returncode']==0 and r['checkpoint_exact']and r['daily_budget_exact']
 assert checkpoint(split+'/restart.bin',50)==b
 assert rows(split+'/budget.csv')==full[43:50]
 sharp='andelst-original-entry-O2';launch=get(sharp+'/LAUNCH.json');assert launch['command'][9]==''and launch['entry_transition_width_cm']==0.
 censor=get(sharp+'/CENSOR.json');assert censor['censored']and censor['completed_full_days']==1
 assert censor['natural_native_terminal_status']=='UNKNOWN'
 checkpoint(sharp+'/restart.bin',1)
 diag='andelst-sharp-failed-state';r=get(diag+'/RESULT.json');assert r['returncode']==86 and r['diagnostic_stop_expected']==86 and not r['censored']
 assert r['physical_payload_unchanged']and r['command'][9]==''
 assert checkpoint(diag+'/origin.bin',1)[72:-4]==files[sharp+'/restart.bin'][72:-4]
 build=get('andelst-sharp-diagnostic-O2/BUILD.json');assert build['freshly_compiled_providers']==1
 assert sha(files['andelst-sharp-diagnostic-O2/native'])==build['executable_sha256']==r['executable_sha256']
 records=[l.split()for l in files[diag+'/sharp-entry-failed-newton.log'].decode().splitlines()if l.split()and l.split()[0]=='RESIDUAL_SIDES']
 contact=[q for q in records if q[1]=='2'];assert len(contact)==5
 last=contact[-1];assert int(last[2])==45 and abs(float(last[3])-1e-12)<1e-25
 assert float(last[4])>0.0047 and float(last[5])<-.036
 return dict(status='BOUNDED_EXPERIMENTAL_AND_CAUSE_EVIDENCE_VERIFIED',O0_O2_exact_days=50,ramped_executed_days=65,original_sharp_full_days=1,sharp_censored=True,full_project_complete=False,scientific_equivalence=False,current_source_admission=False)
def verify_saturated_metric():
 report=json.loads((ROOT/'integration/dataqual15/ANDELST80_RESULT.json').read_text())
 assert not report['full_original_complete']and not report['scientific_equivalence']and not report['canonical_admitted']
 raw=(ROOT/report['evidence_path']).read_bytes();assert sha(raw)==report['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b)for n,b in files.items()}
 get=lambda n:json.loads(files[n]);rows=lambda n:list(csv.DictReader(io.StringIO(files[n].decode())))
 def checkpoint(n,clock):
  b=files[n];assert b[:8]==b'S5WM0001'and zlib.crc32(b[:-4])==struct.unpack('=I',b[-4:])[0]
  assert struct.unpack_from('=ii',b,72)==(112,5)and struct.unpack_from('=d',b,204)[0]==clock
  return b
 for prefix in ['andelst65-diagnostic-','andelst-event-edge-']:
  for opt in ['O0','O2']:
   name=prefix+opt;r=get(name+'/BUILD.json');assert sha(files[name+'/native'])==r['executable_sha256']
   assert r['provider_count']==199 and all(e.get('returncode',0)==0 for e in r['events'])
 continuous='andelst65-dae-original-O2';other='andelst65-dae-original-O0'
 assert get(continuous+'/RESULT.json')['completed_day']==80 and get(continuous+'/RESULT.json')['returncode']==1
 assert get(other+'/RESULT.json')['completed_day']==70 and get(other+'/RESULT.json')['returncode']==0
 a=rows(continuous+'/budget.csv');b=rows(other+'/budget.csv');assert len(a)==80 and len(b)==70 and a[:70]==b
 assert max(abs(float(q['water_residual_cm']))for q in a)<1e-10
 assert checkpoint(continuous+'/restart-70.bin',70)[72:-4]==checkpoint(other+'/restart.bin',70)[72:-4]
 for start,end in [(2,5),(65,70)]:
  split=f'andelst65-dae-restart{start}-{end}-O2';assert get(split+'/RESULT.json')['returncode']==0
  assert rows(split+'/budget.csv')==a[start:end]
  assert checkpoint(split+'/restart.bin',end)==checkpoint(continuous+f'/restart-{end}.bin',end)
 old=checkpoint(continuous+'/restart.bin',80);edge='andelst-event-edge-replay80-81'
 for suffix in ['', '-O0']:
  name=edge+suffix;r=get(name+'/RESULT.json');assert r['returncode']==0 and not r['censored']and r['physical_payload_unchanged']
  assert checkpoint(name+'/origin.bin',80)[72:-4]==old[72:-4]
 assert rows(edge+'/budget.csv')==rows(edge+'-O0/budget.csv')
 assert checkpoint(edge+'/restart.bin',81)[72:-4]==checkpoint(edge+'-O0/restart.bin',81)[72:-4]
 final=rows(continuous+'/cost.csv')[-1];assert final['completed']=='F'and float(final['t1'])>float(final['t0'])
 assert float(final['t1'])-float(final['t0'])<1.2e-12
 return dict(status='BOUNDED_SATURATED_METRIC_AND_EDGE_EVIDENCE_VERIFIED',executed_days=80,O0_O2_exact_days=70,restart_65_70_exact=True,edge_80_81_O0_O2_exact=True,full_original_complete=False,scientific_equivalence=False,current_source_admission=False)
def verify_temporal_stiffness():
 report=json.loads((ROOT/'integration/dataqual15/ANDELST130_RESULT.json').read_text())
 assert not report['full_original_complete']and not report['scientific_equivalence']and not report['canonical_admitted']
 raw=(ROOT/report['evidence_path']).read_bytes();assert sha(raw)==report['evidence_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b)for n,b in files.items()}
 get=lambda n:json.loads(files[n]);rows=lambda n:list(csv.DictReader(io.StringIO(files[n].decode())))
 def checkpoint(n,clock):
  b=files[n];assert b[:8]==b'S5WM0001'and zlib.crc32(b[:-4])==struct.unpack('=I',b[-4:])[0]
  assert struct.unpack_from('=ii',b,72)==(112,5)and struct.unpack_from('=d',b,204)[0]==clock
  return b
 main='andelst-event-edge-original-O2';c=get(main+'/CENSOR.json')
 assert c['censored']and c['controller_exit_code']==130 and c['natural_native_terminal_status']=='UNKNOWN_INTERRUPTED'
 assert c['completed_full_days']==130 and not c['full_project_complete']
 budget=rows(main+'/budget.csv');assert len(budget)==130 and max(abs(float(q['water_residual_cm']))for q in budget)<1e-10
 assert float(rows(main+'/progress.csv')[-1]['t1'])==c['last_accepted_source_time']
 checkpoint(main+'/restart.bin',130)
 for prefix in ['andelst-event-edge-O2','andelst130-observation']:
  b=get(prefix+'/BUILD.json');assert sha(files[prefix+'/native'])==b['executable_sha256']
 for name,clock in [('andelst130-observed',129),('andelst131-observed',130)]:
  r=get(name+'/RESULT.json');assert r['returncode']==87 and r['diagnostic_stop_expected']==87 and not r['censored']
  assert checkpoint(name+'/origin.bin',clock)[72:-4]==checkpoint(main+f'/restart-{clock}.bin',clock)[72:-4]
  lines=[l.split()for l in files[name+'/stdout'].decode().splitlines()]
  weather=[q for q in lines if q and q[0]=='DIAG130_WEATHER'][-1]
  assert float(weather[1])<1e-6 and float(weather[2])==float(weather[3])and float(weather[3])>.01
  head=[q for q in lines if q and q[0]=='DIAG130_HEAD'][-1]
  assert max(float(head[2]),float(head[3]))<0 and abs(float(head[4])-float(head[5]))<2e-8
  solves=[q[1:]for q in lines if q and q[0]=='DIAG130_SOLVE'][-3:];assert len(solves)==3
  for q in solves:
   assert list(map(int,q[2:8]))==[1,3,1,3,3,0]and q[8]=='T'
   assert abs(float(q[9])*(float(q[1])-float(q[0])))<1e-10 and abs(float(q[11]))<1e-10
 return dict(status='CENSORED130DAY_NEAR_SATURATED_TEMPORAL_COMPONENTS_VERIFIED',full_days=130,last_accepted_source_time=c['last_accepted_source_time'],natural_terminal=False,full_original_complete=False,scientific_equivalence=False,current_source_admission=False)
if __name__=='__main__':print(json.dumps(dict(sealed26=verify(),saturated_metric=verify_saturated_metric(),temporal_stiffness=verify_temporal_stiffness()),indent=2))
