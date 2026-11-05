"""Exact bounded thermal-profile successor; predecessor authority stays immutable."""
import argparse,csv,hashlib,io,json,os,subprocess,sys,tarfile,tempfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE='8367ca0c9'
SCOPE='integration/dataqual15/THERMAL_PROFILE_PRODUCTION_SCOPE_20261105.json'
KEY='registered_thermal_profile_successor_20261105'
ENTRY='tests/dataqual15/verify_current_native_admission.py'
PATHS={'src/runtime/mod_fmr_serialized_reference_backend.f90','app/grass_project/initial_interval.f90',
 'app/grass_project/restart_file.f90','app/solute_project/main_water.f90','app/solute_column/macro_water_restart.f90'}
GATES={ENTRY,'tests/dataqual15/thermal_profile_production.py','tests/dataqual15/thermal_temporal_driver.f90',
 'tests/dataqual15/qualify_thermal_runtime.py','tests/dataqual15/qualify_native_disk_restart.py',
 'tests/dataqual15/run_original.py','tests/dataqual15/continue_original_andelst.py','tools/solute/build_grass_startup.py',
 'tests/dataqual15/seal_thermal_profile_production.py','tests/dataqual15/test_thermal_profile_production.py',
 '.github/workflows/grass-thermal-production.yml','tests/dataqual15/qualify_andelst_codec.py'}
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)

def guard(r):
 assert r['predecessor']==git('rev-parse',BASE)and r['whole_scientific_admission']is False
 assert r['profile']=='thermal-control-1e-5C'and r['thermal_tolerance_c']==1e-5
 assert set(r['production_delta'])==PATHS and set(r['gate_sha256'])==GATES
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())==PATHS
 assert not git('diff','HEAD','--','src','app','reference')
 assert not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 for p,pins in r['production_delta'].items():
  assert blob(BASE,p)==pins['before']and blob('HEAD',p)==pins['after'],p
  assert (ROOT/p).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT),p
 for p,pin in r['gate_sha256'].items():assert sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==pin,p
 route=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())[KEY]
 assert route=={'scope':SCOPE}
 before=json.loads(subprocess.check_output(['git','show',BASE+':integration/dataqual15/STATUS.json'],cwd=ROOT))
 current=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())
 for key in ('native_disk_restart_20261102','project_diagnostic_restart_successor_20261104','native_crop_logical_successor_20261105'):
  assert current.get(key)==before.get(key),key

def unpack(r):
 raw=(ROOT/r['archive']).read_bytes();assert sha(raw)==r['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers();assert all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members)
  assert len({m.name for m in members})==len(members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b)for n,b in files.items()}
 return files

def verify(r,files=None):
 f=unpack(r)if files is None else files
 j=lambda n:json.loads(f[n])
 rows=lambda n:list(csv.DictReader(io.StringIO(f[n].decode())))
 mapping=j('SOURCE_MAP.json')
 for name,member in mapping.items():assert sha(f[member])==j('SOURCE_HASHES.json')[name],name
 artifacts=j('ARTIFACT_MAP.json')
 for member in set(artifacts.values()):
  assert member.startswith('artifacts/')and sha(f[member])==member.split('/')[-1],member
 for entry in j('BUILDS.json'):
  meta=j(entry['metadata'])
  for name,pin in meta['source_sha256'].items():assert sha(f[mapping[name]])==pin,name
  for name,pin in meta.get('object_sha256',{}).items():assert sha(f[artifacts[name]])==pin,name
  assert sha(f[entry['executable']])==meta['executable_sha256']
  if 'publication_provider'in meta:
   pub=meta['publication_provider'];assert sha(f[mapping[pub['source']]])==pub['source_sha256']
   assert sha(f[artifacts[pub['object']]])==pub['object_sha256']
  if 'ttutil_archive'in meta:assert sha(f[artifacts[meta['ttutil_archive']]])==meta['archive_sha256']
 for p in PATHS:assert f['sources/'+p].replace(b'\r\n',b'\n')==(ROOT/p).read_bytes().replace(b'\r\n',b'\n'),p
 contracts=j('thermal-contract/RESULT.json')
 assert contracts['status']=='SPRINT03_CURRENT_RUNTIME_AND_THERMAL_TEMPORAL_CONTRACT_PASS'
 assert len([e for e in contracts['events']if e['label']=='native_existing_contract'])==10
 assert all(e['returncode']==0 for e in contracts['events'])
 for opt in ('O0','O2'):
  build=j('grass-'+opt+'/BUILD.json');disk=j('thermal-disk-'+opt+'/RESULT.json')
  assert build['provider_count']==203 and build['native_returncode']==0
  assert build['grass_numerical_profile']=='thermal-control-1e-5C'
  assert '-'+opt in build['flags']and '-fcheck=all'in build['flags']
  assert disk['status']=='NATIVE_ORIGINAL_DISK_RESTART_PASS'and len(disk['invalid_restart_controls'])>=10
  assert len(disk['profile_controls'])==5 and all(e['returncode']!=0 for e in disk['profile_controls'])
  assert {e['case']for e in disk['profile_controls']}=={'missing-marker','wrong-marker','duplicate-marker','missing-switch','wrong-switch'}
  for kind in disk['invalid_restart_controls']:
   assert b'bound grass prefix restart rejected'in f['thermal-disk-'+opt+'/'+kind+'/stdout']
   assert 'thermal-disk-'+opt+'/'+kind+'/checkpoint.bin'not in f
  assert f['thermal-disk-'+opt+'/continuous/checkpoint.bin']==f['thermal-disk-'+opt+'/resume/checkpoint.bin']
 default=rows('default-140/budget.csv');incumbent=rows('incumbent-140/budget.csv')
 assert default==incumbent and len(default)==140
 assert rows('default-140/crop.csv')==rows('incumbent-140/crop.csv')
 year=j('grass-367/RESULT.json');daily=rows('grass-367/budget.csv')
 assert year['returncode']==0 and not year['censored']and year['completed_days']==367
 assert [int(x['day'])for x in daily]==list(range(1,368))
 for x in daily:
  assert abs(float(x['residual_cm']))<1e-10
  assert abs(float(x['water_end_cm'])-float(x['water_start_cm'])-float(x['input_cm'])+float(x['output_cm']))<1e-10
 assert f['grass-367/checkpoint-367.bin']==f['grass-year-restart/checkpoint.bin']
 for name in ('budget.csv','crop.csv'):
  assert rows('grass-367/'+name)[365:]==rows('grass-year-restart/'+name)
 restart=j('grass-year-restart/RESULT.json')
 assert restart['returncode']==0 and not restart['censored']
 historical=j('HISTORICAL_THERMAL_REUSE.json')
 assert historical['days']==1827 and historical['original_gate_remains_failed']and not historical['whole_scientific_admission']
 assert historical['archive_sha256']=='19f6f3f6dc45a115bf161ad7efff22006336ded20dbec047ad7abd859974ff2d'
 macro=j('andelst-codec/RESULT.json')
 assert macro['status']=='NATIVE_MACRO_O0_O2_OWN_BYTES_AND_REFUSALS_PASS'and macro['optimization_physical_payload_exact']and not macro['full481']
 for opt in ('O0','O2'):
  assert len(macro['builds'][opt]['events'])==3 and all(e['returncode']!=0 for e in macro['builds'][opt]['events'])
  assert {e['kind']for e in macro['builds'][opt]['events']}=={'crc','truncated','binding'}
  assert f['andelst-own-'+opt+'/restart.bin']==f['andelst-prefix-'+opt+'/restart.bin']
  assert j('andelst-prefix-'+opt+'/RESULT.json')['original_sharp_entry']
  origin=f['andelst-'+('day1-O0'if opt=='O0'else'original-O2')+'/restart.bin']
  for kind in ('crc','truncated','binding'):
   prefix='andelst-codec/'+opt+'-'+kind+'/'
   assert b'native macro water restart rejected'in f[prefix+'stdout']and prefix+'budget.csv'not in f
   assert f[prefix+'restart.bin']==origin
 assert j('andelst-continue-O2/RESULT.json')['censored']and not j('andelst-continue-O2/RESULT.json')['full_original_complete']
 assert j('andelst-continue-O2/RESULT.json')['last_completed_source_interval']==1.9580000000023283
 return dict(current_days=367,default_exact_days=140,own_year_restart='365->367 exact',
  maximum_water_residual_cm=max(abs(float(x['residual_cm']))for x in daily),
  inherited_historical_days=1827,whole_scientific_admission=False,full_original_andelst=False)

def data_controls(r,files):
 cases={
  'changed-current-source':('sources/'+sorted(PATHS)[0],lambda b:b+b'changed'),
  'changed-linked-object':(next(iter(json.loads(files['ARTIFACT_MAP.json']).values())),lambda b:b+b'changed'),
  'default-regression':('default-140/budget.csv',lambda b:b+b'changed'),
  'year-restart-mismatch':('grass-year-restart/checkpoint.bin',lambda b:b[:-1]+bytes([b[-1]^1])),
  'macro-restart-mismatch':('andelst-own-O0/restart.bin',lambda b:b[:-1]+bytes([b[-1]^1])),
  'missing-native-refusal':('andelst-codec/RESULT.json',lambda b:json.dumps({**json.loads(b),'optimization_physical_payload_exact':False}).encode()),
  'promoted-historical-science':('HISTORICAL_THERMAL_REUSE.json',lambda b:json.dumps({**json.loads(b),'whole_scientific_admission':True}).encode()),
  'missing-full-prefix':('grass-367/RESULT.json',lambda b:json.dumps({**json.loads(b),'completed_days':366}).encode())}
 refused=[]
 for label,(name,change)in cases.items():
  bad=files.copy();bad[name]=change(files[name])
  try:verify(r,bad)
  except(AssertionError,KeyError,ValueError):refused.append(label)
  else:raise AssertionError('accepted actual evidence defect '+label)
 return refused

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);p.add_argument('--verify-only',action='store_true');a=p.parse_args()
 r=json.loads((ROOT/SCOPE).read_text());guard(r);files=unpack(r);proof=verify(r,files);proof['data_refusals']=data_controls(r,files)
 if a.verify_only:print(json.dumps(proof));return
 assert a.output is not None
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 # Execute exact predecessor bytes, including its original fail-closed guards.
 # This is inherited authority, explicitly separate from the current data above.
 work=Path(tempfile.mkdtemp(prefix='s5t-'));view=work/'predecessor'
 subprocess.run(['git','-c','core.longpaths=true','worktree','add','--detach',str(view),git('rev-parse',BASE)],cwd=ROOT,check=True,capture_output=True)
 try:
  cp=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'proof')],cwd=view,capture_output=True,env=dict(os.environ,PYTHONUTF8='1'))
  (out/'predecessor.stdout').write_bytes(cp.stdout);(out/'predecessor.stderr').write_bytes(cp.stderr)
  assert cp.returncode==0,cp.stderr[-3000:]
  with tarfile.open(out/'predecessor-proof.tar.xz','w:xz')as t:t.add(work/'proof',arcname='proof')
  guard(r);(out/'RESULT.json').write_text(json.dumps(dict(status='BOUNDED_THERMAL_PROFILE_AND_EXACT_PREDECESSOR_AUTHORITY_PASS',current=proof,predecessor=git('rev-parse',BASE)),indent=2)+'\n')
 finally:subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,check=True,capture_output=True)

if __name__=='__main__':main()
