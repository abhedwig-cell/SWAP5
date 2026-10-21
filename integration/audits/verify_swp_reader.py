"""Source-bound original SWP chemistry, production application and exact predecessor."""
import base64,copy,csv,hashlib,io,json,os,subprocess,sys,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='c8b35ac3e9f2a2cf2400033d0225aea8198469ea'
NUT_PREDECESSOR='c4ec414fe5ae55e992e557e394cb4003beaf3e39'
PREDECESSOR='fb00736e320498f2e610b0671af9c7dc5a381921'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
SCIENCE=['src','tests','tools','reference','.github','app','examples','integration/performance',
 'integration/audits/verify_nonlinear_pond.py','integration/audits/verify_pond_thermal.py',
 'integration/audits/qualify_pond_thermal.py','integration/audits/verify_swp_reader.py','integration/audits/verify_nut_negative.py']
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['swp_reader_successor']
def hook(fn):
 return " if 'evidence' in json.loads((ROOT/STATUS).read_text()).get('swp_reader_successor', {}):\n  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['"+fn+"']("+('reader,changed' if fn=='source' else '')+")\n"
def nut_hook(fn):
 return " if 'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_reader_successor', {}):\n  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))['"+fn+"']("+('reader,changed' if fn=='source' else '')+")\n"
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=record();require(s['baseline']==BASE,'wrong input-route baseline');git('merge-base','--is-ancestor',BASE,'HEAD')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty scientific source')
 actual=changed if changed is not None else {x.split('\t')[1]:x.split('\t')[0] for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(actual=={p:v['status'] for p,v in s['postimages'].items()},'unregistered scientific delta')
 require(not any(p.startswith('src/') for p in actual),'input adapter changed incumbent process equations')
 for p,v in s['postimages'].items():require(sha(reader(p))==v['sha256'],'source identity '+p)
 p='integration/audits/verify_pond_thermal.py'
 expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 for fn in ['source','verify_qualification','self_test']:
  a=expected.index('\ndef '+fn)+1;end=expected.index('\n',a)+1
  expected=expected[:end]+hook(fn)+expected[end:]
 require(reader(p).decode()==expected,'predecessor verifier body changed')
 p='integration/audits/verify_nut_negative.py'
 expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 for fn in ['source','verify_qualification','self_test']:
  a=expected.index('\ndef '+fn)+1;end=expected.index('\n',a)+1
  expected=expected[:end]+nut_hook(fn)+expected[end:]
 require(reader(p).decode()==expected,'concurrent finite-donor verifier body changed')
 p='.github/workflows/mc-sol01-thermal-pond.yml'
 expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT,text=True)
 start=expected.index('          set -euo pipefail',expected.index('- name: Actual six-exponent'))
 end=expected.index('      - name: Current application',start);body=expected[start:end]
 replacement="          if test -f integration/audits/verify_swp_reader.py && git diff --quiet "+BASE+" HEAD -- src; then\n            python -B integration/audits/verify_swp_reader.py\n          else\n"+''.join('  '+line if line.strip() else line for line in body.splitlines(True))+"          fi\n"
 expected=expected[:start]+replacement+expected[end:]
 require(reader(p).decode()==expected,'thermal workflow changed beyond exact input-only impact handoff')
 return s
def capsule():
 e=record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True)
 require(sha(raw)==e['decoded_sha256'],'capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  members=t.getmembers();require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe evidence')
  require(len(members)==len({m.name for m in members}),'duplicate members')
  files={m.name:t.extractfile(m).read() for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'));require(set(files)==set(manifest),'member inventory')
 require(all(sha(files[p])==h for p,h in manifest.items()),'member corruption')
 return files
def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(files[p])
 def current(inputs):
  for p,h in inputs.items():require(sha(reader(p))==h,'stale executed input '+p)
 def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(io.StringIO(files[p].decode()))]
 with tempfile.TemporaryDirectory(prefix='swap5-original-input-proof-') as tmp:
  folder=Path(tmp)
  materialize=__import__('runpy').run_path(str(ROOT/'tools/solute/legacy_reader_sources.py'))['materialize']
  original,providers=materialize(ROOT,folder)
  generated={str(p.relative_to(folder)):sha(p.read_bytes()) for p in [original]+sorted(p for p in providers[0].parent.rglob('*') if p.is_file())}
 r=js('native/result.json')
 require(r['status']=='ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS','unfinished original reader')
 require(len(r['cases'])==22 and len(r['events'])==172,'missing native input observations')
 current(r['inputs'])
 for label in ['native','column','annual']:
  report=js(label+'/result.json')
  if label=='column':
   require(report['status']=='PASS' and len(report['events'])==86,'original application failed')
   require(report['test_sha256']==sha(reader('tests/nut-sol/test_column_input.py')) and report['runner_sha256']==sha(reader('tools/solute/run_column.py')),'application assertions changed')
   builds={o:js('build-'+o+'/build-complete.json') for o in ['O0','O2']}
  else:
   current(report['inputs']);builds=report['builds']
  for b in builds.values():
   require(b['status']=='BUILT' and b['provider_count']==189 and b['original_input_provider_count']>100,'unqualified provider closure')
   current(b['input_sha256'])
   require(b['generated_input_sha256']==generated,'original provider/include identity')
   require(all(e['returncode']==0 for e in b['events']),'failed build')
  for i,e in enumerate(report['events']):
   if label=='native':
    require((e['returncode']==0)==e['positive'],'native observation failure')
    if 'reader'==Path(e['command'][0]).name:
     require(b'SWP_ORIGINAL_READER_CONTRACT=PASS' in files[f'native/{i:04d}.stdout'],'missing native reader marker')
   elif label=='annual':require(e['returncode']==0,'annual observation failed')
 for key,v in r['cases'].items():
  opt,name=key.split('-',1);prefix=f'native/{opt}/{name}/'
  require(max(abs(x['water_residual_cm']) for x in v['budget'])<1e-10 and max(abs(x['solute_residual_mg_cm2']) for x in v['budget'])<1e-11,'SWP balance')
  for p in ['restart.bin','state.csv','endpoint.csv']+(['temperature.csv'] if name=='decay' else []):
   require(files[prefix+'full/'+p]==files[prefix+'resumed/'+p],'SWP fresh restart')
  require(sha(files[prefix+'full/restart.bin'])==v['restart_sha256'],'SWP endpoint identity')
  for generation in ['full','split','resumed']:
   m=js(prefix+generation+'/manifest.json')
   require(m['status']=='COMPLETE' and m['swp_sha256']==sha(files[prefix+'source.swp']),'SWP generation source binding')
   for p,h in m['files'].items():require(sha(files[prefix+generation+'/'+p])==h,'SWP generation byte binding')
  for b in rows(prefix+'full/budget.csv'):require(abs(b['water_residual_cm'])<1e-10 and abs(b['solute_residual_mg_cm2'])<1e-11,'raw SWP balance')
  for state,params in zip(rows(prefix+'full/state.csv'),v['vectors']):
   want=params[8]*v['scalar'][4]*(state['concentration_mg_cm3']/v['scalar'][4])**v['scalar'][3]*state['dz_cm']
   require(abs(state['sorbed_mg_cm2']-want)<1e-11,'raw original sorption product')
 for name in {k.split('-',1)[1] for k in r['cases']}:
  require(r['cases']['O0-'+name]==r['cases']['O2-'+name],'original-reader optimization difference')
 for o in ['O0','O2']:
  require(files[f'native/{o}/layered/full/state.csv']==files[f'native/{o}/heat_off_decay/full/state.csv'],'original zero heat factor changed')
 # Independent old application bytes are bound to the immutable prior capsule.
 predecessor_status=json.loads(subprocess.check_output(['git','show',PREDECESSOR+':'+STATUS],cwd=ROOT))
 e=predecessor_status['thermal_pond_successor']['evidence']
 raw=base64.b64decode(b''.join(reader(e['path']).split()));require(sha(raw)==e['decoded_sha256'],'predecessor evidence changed')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  old={m.name:t.extractfile(m).read() for m in t.getmembers()}
 comparisons=js('incumbent-comparison.json');require(comparisons['count']==160 and comparisons['all_exact'],'incumbent byte drift')
 for p,h in comparisons['artifacts'].items():
  require(sha(files['column/'+p])==h and files['column/'+p]==old['column/qualification/'+p],'incumbent physical output changed')
 annual=js('annual/result.json');require(annual['days']==365 and len(annual['runs'])==18,'annual application scope')
 require(annual['status']=='PHYSICAL_LONG_FILE_RUNS_PASS_ACCURACY_ASSESSMENT_REQUIRED','annual validation unfinished')
 for key,v in annual['runs'].items():
  require(v['max_water']<=1e-10 and v['max_solute']<=1e-11 and v['endpoint']['time_day']==365,'annual balance')
  for p in ['restart.bin','state.csv','endpoint.csv','temperature.csv','budget.csv']:
   require(files[f'annual/{key}/full/{p}']==old[f'season/{key}/full/{p}'],'unchanged annual physics drift')
 return {'qualified':True,'original_swp_chemistry':True,'native_observations':172,'valid_configurations':22,
         'old_application_artifacts_exact':160,'annual_application_cases_exact':18,'full_swp_default_application':False,'full_capability':False}
def predecessor():
 for ref,owner in [(PREDECESSOR,'integration/audits/verify_pond_thermal.py'),(NUT_PREDECESSOR,'integration/audits/verify_nut_negative.py'),(BASE,'integration/diagnostics/verify_trace_scope.py')]:
  with tempfile.TemporaryDirectory(prefix='swap5-swp-predecessor-') as tmp:
   path=Path(tmp)/'base'
   subprocess.run(['git','worktree','add','--detach',path,ref],cwd=ROOT,check=True,capture_output=True)
   try:
    r=subprocess.run([sys.executable,'-B',owner],cwd=path,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
    require(r.returncode==0,'exact predecessor '+ref+' '+r.stderr[-1200:]);require(json.loads(r.stdout)['qualified'],'predecessor not qualified')
   finally:subprocess.run(['git','worktree','remove','--force',path],cwd=ROOT,check=True,capture_output=True)
 return True
def verify_qualification():
 source();r=validate(capsule());r.update(predecessor_qualified=predecessor(),source_tree=git('rev-parse','HEAD:src'),current_source_tree=git('rev-parse','HEAD:src'));return r
def self_test():
 source();files=capsule();validate(files);controls=[]
 def reject(name,fn):
  try:fn()
  except (ValueError,KeyError,AssertionError):controls.append(name);return
  raise ValueError('control accepted: '+name)
 p='app/solute_column/read_swp_chemistry.f90'
 reject('changed reader source',lambda:source(lambda x:(ROOT/x).read_bytes()+(b'\n! mutation' if x==p else b'')))
 actual={p:v['status'] for p,v in record()['postimages'].items()};actual['src/unregistered.f90']='A'
 reject('unregistered process change',lambda:source(changed=actual))
 for name,path,edit in [
  ('missing native case','native/result.json',lambda d:d['cases'].pop(next(iter(d['cases'])))),
  ('failed native negative','native/result.json',lambda d:d['events'][-1].update(returncode=0)),
  ('false restart inventory','native/O0/layered/full/manifest.json',lambda d:d.update(swp_sha256='0'*64)),
  ('missing old controls','column/result.json',lambda d:d['events'].pop()),
  ('short annual horizon','annual/result.json',lambda d:d.update(days=364))]:
  bad=dict(files);d=json.loads(bad[path]);edit(d);bad[path]=json.dumps(d).encode();reject(name,lambda:validate(bad))
 bad=dict(files);p='native/O0/layered/resumed/restart.bin';bad[p]=bad[p][:-1]+bytes([bad[p][-1]^1]);reject('corrupt fresh restart',lambda:validate(bad))
 bad=dict(files);p='annual/O0-0.5-1/full/state.csv';bad[p]+=b'\n';reject('annual physics byte drift',lambda:validate(bad))
 return {'self_test':'PASS','negative_controls':controls}
if __name__=='__main__':print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(),indent=2))
