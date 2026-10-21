"""Validate bounded local SWP water evidence; does not confer canonical admission."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import runpy
import tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
BASE='95a3bd5721a4dfb4c0c38823c475ff55b95bee57'
SELF='integration/audits/verify_swp_water.py'
PARENT='integration/audits/verify_nut_output_generation.py'
RESEARCH='integration/diagnostics/verify_perf01_pond_policy.py'
SCIENCE=['src','app','tests','tools','reference','examples','.github','integration/audits','integration/performance','integration/diagnostics']
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def hook(entry,target):
 args='reader,changed' if entry=='source' else ''
 return " if 'admission' in json.loads((ROOT/'"+STATUS+"').read_text()).get('swp_water_successor',{}):\n  return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+target+"']("+args+")\n"
def project_parent(path):
 text=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 entries=[('source','source'),('verify','verify_qualification'),('self_test','self_test')] if path==PARENT else [('verify','research_verify'),('self_test','research_controls')]
 for entry,target in entries:
  start=text.index('def '+entry+'(');offset=text.index('\n',start)+1
  text=text[:offset]+hook(entry,target)+text[offset:]
 return text.encode()

def sha(data):return hashlib.sha256(data).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def record():return json.loads((ROOT/STATUS).read_text())['swp_water_successor']
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record()
 if 'admission' in r:
  git('merge-base','--is-ancestor',BASE,'HEAD')
  actual={v.split('\t')[1]:v.split('\t')[0] for v in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()} if changed is None else changed
  require(actual==r['admission']['source_delta'],'foreign scientific delta')
  prior=json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT))
  current=json.loads(reader(STATUS));current.pop('swp_water_successor',None)
  require(current==prior,'unrelated SOL authority changed')
  for path in [PARENT]:require(reader(path)==project_parent(path),'predecessor assertions changed '+path)
 for p,h in r.get('inherited_inputs',{}).items():require(sha(reader(p))==h,'inherited source identity '+p)
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'source identity '+p)
 tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
 require(tree==r['production_source_tree'],'incumbent production source changed')
 require(not subprocess.check_output(['git','status','--porcelain','--','src'],cwd=ROOT,text=True),'dirty production source')
 return r

def capsule(e=None):
 e=e or record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True)
 require(sha(raw)==e['decoded_sha256'],'capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  members=t.getmembers()
  require(len(members)==e['members'] and len(members)==len({m.name for m in members}),'member census')
  require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe member')
  files={m.name:t.extractfile(m).read() for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'))
 require(set(files)==set(manifest),'member inventory')
 require(all(sha(files[p])==h for p,h in manifest.items()),'member corruption')
 return files

def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(files[p])
 def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(io.StringIO(files[p].decode()))]
 def current(inputs):
  for p,h in inputs.items():require(sha(reader(p))==h,'stale executed input '+p)
 r=js('qualified-native/result.json');require(r['status']=='PASS','unfinished water proof')
 require(len(r['cases'])==12 and len(r['events'])==110,'native observations missing')
 current(r['inputs'])
 for opt in ['O0','O2']:
  b=js('final-'+opt+'/build-complete.json');current(b['input_sha256'])
  require(b['status']=='BUILT' and b['provider_count']==190,'build closure')
  require(all(e['returncode']==0 for e in b['events']),'failed build')
  require('-'+opt in b['flags'] and '-fcheck=all' in b['flags'],'unchecked build')
  for p,h in b['generated_input_sha256'].items():require(sha(files['final-'+opt+'/'+p])==h,'original generated source')
  require(b==r['builds'][opt],'build proof mismatch')
 for i,e in enumerate(r['events']):
  require((e['returncode']==0)==e['expected_success'],'native failure counted as pass')
  if Path(e['command'][0]).name=='reader':require(b'SWP_WATER_CONTRACT_COMPLETED' in files[f'qualified-native/{i:04d}.stdout'],'missing mapping observation')
 for key,c in r['cases'].items():
  opt,name=key.split('-',1);prefix='qualified-native/'+opt+'/'+name+'/'
  for p in ['restart.bin','state.csv','endpoint.csv']:require(files[prefix+'full/'+p]==files[prefix+'resumed/'+p],'fresh-process mismatch')
  require(sha(files[prefix+'full/restart.bin'])==c['restart_sha256'],'restart identity')
  require(rows(prefix+'full/budget.csv')==c['budget'],'raw budget mismatch')
  for generation in ['full','split','resumed']:
   m=js(prefix+generation+'/manifest.json');require(m['status']=='COMPLETE','incomplete generation')
   require(m['swp_sha256']==sha(files[prefix+'source.swp']),'SWP source binding')
   require(m['input_sha256']==sha(files[prefix+'input.nml']),'namelist binding')
   require(m['executable_sha256']==r['builds'][opt]['executable_sha256'],'executable binding')
   for p,h in m['files'].items():require(sha(files[prefix+generation+'/'+p])==h,'generation bytes')
  for b in c['budget']:
   require(abs(b['water_residual_cm'])<1e-10 and abs(b['solute_residual_mg_cm2'])<1e-10,'native mass residual')
   for substance,unit in [('water','cm'),('solute','mg_cm2')]:
    residual=b[f'{substance}_end_{unit}']-b[f'{substance}_start_{unit}']-b[f'{substance}_in_{unit}']+b[f'{substance}_out_{unit}']
    require(abs(residual)<1e-10,'independent mass residual')
 require(js('qualified-chemistry/result.json')['status']=='ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS','chemistry preservation')
 require(len(js('qualified-chemistry/result.json')['events'])==172,'chemistry observations')
 require(js('qualified-incumbent/result.json')['status']=='PASS' and len(js('qualified-incumbent/result.json')['events'])==86,'original application preservation')
 p=js('preservation.json');require(p['status']=='PASS' and len(p['exact_files'])==152,'baseline observations')
 for item in p['exact_files']:
  path=item['path'];old=files['baseline-incumbent/'+path];new=files['qualified-incumbent/'+path]
  require(old==new and sha(old)==item['sha256'],'incumbent byte drift')
 return {'qualified':True,'local_native_validated':True,'water_mapping_cases':12,'fresh_process_restarts':12,'invalid_cases':60,'old_exact_artifacts':152,'full_historical_migration':False,'canonically_admitted':False}

def self_test():
 files=capsule();checks=[]
 for p in ['qualified-native/result.json','qualified-native/O2/layered/full/restart.bin','qualified-native/O0/layered/full/budget.csv','qualified-incumbent/O0/full/state.csv','preservation.json']:
  bad=dict(files);bad[p]=bad[p]+b'corrupt'
  try:validate(bad)
  except (ValueError,KeyError,UnicodeError,json.JSONDecodeError):checks.append(p)
  else:raise AssertionError('corruption accepted '+p)
 for p in ['app/solute_column/read_swp_water.f90','app/solute_column/main.f90','tests/nut-sol/qualify_swp_water.py']+list(record().get('inherited_inputs',{})):
  def stale(path):return (ROOT/path).read_bytes()+(b'corrupt' if path==p else b'')
  try:source(stale)
  except ValueError:checks.append(p)
  else:raise AssertionError('stale source accepted '+p)
 if 'admission' in record():
  bad=dict(record()['admission']['source_delta']);bad['src/foreign_water_source.f90']='A'
  try:source(changed=bad)
  except ValueError:checks.append('unregistered scientific delta')
  else:raise AssertionError('foreign source accepted')
 return checks
def predecessor():
 e=record()['admission']['predecessor'];raw=(ROOT/e['path']).read_bytes()
 require(sha(raw)==e['sha256'],'predecessor receipt')
 r=json.loads(raw);require(r['baseline']==BASE,'predecessor identity')
 require(r['owner']['status']=='JOINT_OUTPUT_SOURCE_AND_EVIDENCE_PASS','original NUT owner')
 require(r['controls']['count']==14,'original predecessor controls')
 return r

def verify_qualification():
 source();r=validate(capsule())
 if 'admission' in record():
  r['predecessor']=predecessor()
  e=record()['admission']['annual'];raw=(ROOT/e['path']).read_bytes();require(sha(raw)==e['sha256'],'annual receipt')
  annual=json.loads(raw);require(len(annual['runs'])==18,'annual composition observations')
  for p,h in annual['inputs'].items():require(sha((ROOT/p).read_bytes())==h,'annual input drift '+p)
  files=capsule(record()['admission']['evidence'])
  require(json.loads(files['annual/result.json'])==annual,'raw annual proof')
  require(all(e['returncode']==0 for e in annual['events']),'annual native failure')
  for name,v in annual['runs'].items():
   prefix='annual/'+name+'/'
   require(sha(files[prefix+'full/restart.bin'])==v['restart_sha256'],'annual endpoint identity')
   require(v['max_water']<1e-10 and v['max_solute']<1e-10,'annual balance')
   for gen in ['full']:
    m=json.loads(files[prefix+gen+'/manifest.json'])
    for p,h in m['files'].items():require(sha(files[prefix+gen+'/'+p])==h,'annual generation bytes')
   if name.endswith('-4'):
    for p in ['restart.bin','state.csv','endpoint.csv','temperature.csv']:require(files[prefix+'full/'+p]==files[prefix+'resumed/'+p],'annual fresh restart')
 return r

if __name__=='__main__':
 import sys
 print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(),indent=2))
