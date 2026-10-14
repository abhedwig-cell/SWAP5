"""Exact crop-cycle source/evidence successor. Never itself canonical admission."""
from pathlib import Path
import base64, hashlib, io, json, math, subprocess, tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='f0dd03704cd6eb19336269438e99c6bf5db08024'
BOOT='src/runtime/mod_fmr_production_application_bootstrap.f90'
PRE='8b480b09f47bb4443d755109c9093486853c0809'
POST='cb845eecd2409d6ee473bd7a0cb8194c0b501ad6'
COMMENT=b'''      ! Empirical wet stress uses the existing committed-head Feddes binding.
      ! ROOT_COMP_OFF retains one prescribed sink and accepted uptake receipt.
      ! Parameter validation above also covers the wet thresholds/layer split.
'''
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def check(v,msg):
 if not v:raise ValueError(msg)
def validate_source(old,new,changed,reference,baseline_reference):
 check(changed==[BOOT],'foreign production mutation')
 check(blob(old)==PRE and blob(new)==POST,'unknown crop-cycle preimage/postimage')
 check(new.count(COMMENT)==1 and new.replace(COMMENT,b'      if(config%file_weather_root_parameters%empirical_oxygen_enabled) return\n')==old,'change outside exact refusal')
 check(reference==baseline_reference,'immutable reference mutation')
def verify_source():
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','reference'),'dirty production/reference')
 old=subprocess.check_output(['git','show',BASE+':'+BOOT],cwd=ROOT);new=(ROOT/BOOT).read_bytes()
 validate_source(old,new,git('diff','--name-only',BASE,'HEAD','--','src').splitlines(),git('rev-parse','HEAD:reference'),git('rev-parse',BASE+':reference'))
 check(git('rev-parse','HEAD:'+BOOT)==blob(new),'unpersisted production postimage')
 return {'baseline':BASE,'source_tree':git('rev-parse','HEAD:src'),'postimages':{BOOT:POST},'oxygen_cycle_successor':True,'qualified':False,'admitted':False}
def read_capsule(record):
 raw=base64.b64decode((ROOT/record['path']).read_bytes());check(hashlib.sha256(raw).hexdigest()==record['decoded_sha256'],'capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  m=json.load(t.extractfile('MANIFEST.json'));data={}
  for name,v in m['members'].items():
   check(not Path(name).is_absolute() and '..' not in Path(name).parts,'unsafe member')
   b=t.extractfile('blobs/'+v['sha256']).read();check(len(b)==v['bytes'] and hashlib.sha256(b).hexdigest()==v['sha256'],'raw member corruption');data[name]=b
 return data,m
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
def validate_physical(data,m,source):
 r=json.loads(data['cycle-physical-attempt2/RESULTS.json']);rows=r['results']
 expected={(o,n,mo,mode) for o in (0,2) for n in ['weather','oxygen','daily_demand','raintb'] for mo in (['neutral','dry','hydraulic'] if n=='weather' else ['neutral']) for mode in ['continuous','restart']}
 keys=[(x['opt'],x['driver'],x['moisture'],x['mode'])for x in rows]
 check(r['status']=='PASS' and len(keys)==24 and set(keys)==expected,'incomplete/duplicate physical matrix')
 hashes={}
 for row,key in zip(rows,keys):
  check(row['returncode']==0 and math.isfinite(row['wall_seconds']) and row['wall_seconds']>0,'failed/invalid physical result');hashes[key]=row['stdout_sha256']
 events=r['events'];natives=[e for e in events if e['command'][0].split('/')[-1].startswith('test-')]
 check(len(natives)==24,'native evidence coverage')
 native_keys=[]
 for e in natives:
  cmd=e['command'];parent=Path(cmd[0]).parent.name
  check(parent in ['o0','o2'] and len(cmd)==7,'native command/optimization identity')
  key=(int(parent[1:]),Path(cmd[0]).name.removeprefix('test-'),cmd[-1],cmd[-2])
  native_keys.append(key);check(key in hashes and e['stdout_sha256']==hashes[key],'native row/output mismatch')
 check(len(set(native_keys))==24 and set(native_keys)==expected,'duplicate/missing native commands')
 compiles=[e for e in events if '-c' in e['command']]
 links=[e for e in events if '-c' not in e['command'] and '-o' in e['command']]
 check(len(compiles)==468 and len(links)==8,'controlled compile/link coverage')
 import sys
 sys.path.insert(0,str(ROOT/'tests/modularity'))
 from run_modular_tests import DEP
 providers=subprocess.check_output(['python3','-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',
  'tests/fsi/fsi04_real_headcalc_stubs.f90',BOOT,'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
 check(len(providers)==221 and set(providers)<=r['source_inputs'].keys(),'incomplete scientific dependency closure')
 for opt in (0,2):
  commands=[e['command'] for e in compiles if '-O'+str(opt) in e['command']]
  check(len(commands)==234,'optimization compile coverage')
 for e in natives:
  check(e['returncode']==0,'failed native event')
  check(any(hashlib.sha256(b).hexdigest()==e['stdout_sha256'] for name,b in data.items() if name.startswith('cycle-physical-attempt2/') and name.endswith('.stdout')),'native raw output missing')
 for key,h in hashes.items():
  o,n,mo,mode=key;check(h==hashes[(2-o,n,mo,mode)]==hashes[(o,n,mo,'restart' if mode=='continuous' else 'continuous')],'physical optimization/restart drift')
 for name in ['weather','oxygen','daily_demand','raintb']:
  marker={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','oxygen':b'CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS','daily_demand':b'MC_MET01_AUTHENTIC_DAILY_DEMAND_RETRY_RESTART_MASS=PASS','raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]
  for row in rows:
   if row['driver']==name:
    raws=[b for p,b in data.items() if p.startswith('cycle-physical-attempt2/') and p.endswith('.stdout') and hashlib.sha256(b).hexdigest()==row['stdout_sha256']]
    check(raws and marker in raws[0],'physical assertions missing')
 for e in events:
  cmd=e['command']
  if '-c' in cmd or ('-o' in cmd and cmd[0].endswith('gfortran')):
   check(cmd[1:1+len(FLAGS)]==FLAGS and cmd[1+len(FLAGS)] in ['-O0','-O2'],'physical flags changed')
 for p,h in r['source_inputs'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'stale physical dependency '+p)
 # Match the actual executed source subtree, not its later packaging metadata.
 check(git('rev-parse',r['head']+':src')==source['source_tree'],'physical source tree drift')
 direct=json.loads(data['cycle-contract-final/RESULTS.json']);check(direct['status']=='PASS','direct not PASS')
 check({x['opt'] for x in direct['results']}=={0,2} and len(direct['results'])==2,'direct optimization coverage')
 check(direct['authority']['sha256']=='8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5','historical source authority')
 for p,h in direct['inputs'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'stale direct dependency '+p)
 direct_raw=[b for p,b in data.items() if p.startswith('cycle-contract-final/') and p.endswith('native.stdout')]
 check(len(direct_raw)==2 and all(b'OXYGEN_LITERAL_SOURCE_CASES=360' in b and b'CROP_CYCLE_OXYGEN_LITERAL_CONTRACT=PASS' in b for b in direct_raw),'literal oracle assertions missing')
 fast=json.loads(data['cycle-preservation-fast/RESULTS.json']);check(fast['status']=='PASS','fast preservation not PASS')
 for case in ['assimilation','low_air_physical']:
  rr=[x for x in fast['records'] if x['case']==case]
  check(len(rr)==4 and {(x['optimization'],x['build']) for x in rr}=={(o,b) for o in (0,2) for b in ['cold','warm_same_transaction']},'fast original physical/O0/O2 cold/warm scope')
  if case=='low_air_physical':check(len({x['stdout_sha256']for x in rr})==1,'fast physical optimization drift')
  else:
   import sys
   sys.path.insert(0,str(ROOT/'tests/modularity'))
   from contract_oracles import prepare
   payload,validate,paths=prepare(ROOT,'assimilation')
   for x in rr:
    check(hashlib.sha256(payload).hexdigest()==x['stdin_sha256'],'assimilation independent oracle inputs')
    raws=[b for p,b in data.items() if p.startswith('cycle-preservation-fast/') and p.endswith('.stdout') and hashlib.sha256(b).hexdigest()==x['stdout_sha256']]
    check(bool(raws),'assimilation raw output missing');validate(raws[0])
  for x in rr:
   for p,h in x['inputs'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'stale fast dependency '+p)
 return {'source_tree':source['source_tree'],'physical_programs':24,'highest':'NOT_SELECTED_POLICY','qualified':False,'admitted':False}
def verify_physical():
 source=verify_source();s=json.loads((ROOT/'integration/audits/MC_CROP01_OXYGEN_CYCLE_STATUS.json').read_text());data,m=read_capsule(s['evidence']);return validate_physical(data,m,source)
def verify_qualification():
 result=verify_physical()
 # Independent shared owner/coupling evidence is still required before F-CI.
 s=json.loads((ROOT/'integration/audits/MC_CROP01_OXYGEN_CYCLE_STATUS.json').read_text())
 record=s['additional_owner_evidence'];data,m=read_capsule(record)
 r=json.loads(data['additional/RESULTS.json']);check(r['status']=='PASS','additional owner incomplete')
 from importlib.util import spec_from_file_location,module_from_spec
 spec=spec_from_file_location('joint_additional',ROOT/'tests/mc-met01/run_joint_owner_additional.py');module=module_from_spec(spec);spec.loader.exec_module(module)
 check([(x['name'],x['command'])for x in r['steps']]==module.STEPS,'additional owner coverage')
 check(r['source']['source_tree']==result['source_tree'],'additional source tree')
 for step in r['steps']:
  check(step['exit']==0 and hashlib.sha256(data['additional/'+step['name']+'.stdout']).hexdigest()==step['stdout_sha256'],'additional failed/corrupt')
 for p,b in m['dependency_blobs'].items():check(git('rev-parse','HEAD:'+p)==b and blob((ROOT/p).read_bytes())==b,'additional dependency drift '+p)
 return result
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--physical-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_physical() if a.physical_only else verify_qualification(),indent=2))
