"""Fail-closed exact CO2 source and terminal evidence. Eligibility is not admission."""
from pathlib import Path
import hashlib,json,math,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/crop-cycle'),str(ROOT/'tests/modularity')]
from verify_oxygen_successor import read_capsule
BASE='82209d0df68d14c5ebe707e9b6303f9b150488ca'
BOOT='src/runtime/mod_fmr_production_application_bootstrap.f90'
ATM='src/adapter/mod_crop_atmospheric_co2_forcing.f90'
PINS={BOOT:'5a93008ed2fb18d0798ec0c967729815d156ec26',ATM:'86f8c7770b15dcd63f3c22295c81f0f7073cd993'}
STATUS=ROOT/'integration/audits/MC_CROP01_TRAJECTORY2_CO2_STATUS.json'
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
MARKERS={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','oxygen':b'CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS','co2':b'CROP_CO2_PHYSICAL_GROWTH_UPTAKE_RESTART=PASS','daily_demand':b'MC_MET01_AUTHENTIC_DAILY_DEMAND_RETRY_RESTART_MASS=PASS','raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}
def check(ok,message):
 if not ok:raise ValueError(message)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def validate_source(changed,postimages,reference,baseline_reference):
 check(changed==sorted(PINS),'foreign production mutation')
 check(postimages==PINS,'unknown CO2 source postimage')
 check(reference==baseline_reference,'reference mutation')
def verify_source():
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','reference'),'dirty production/reference')
 validate_source(git('diff','--name-only',BASE,'HEAD','--','src').splitlines(),{p:blob((ROOT/p).read_bytes())for p in PINS},git('rev-parse','HEAD:reference'),git('rev-parse',BASE+':reference'))
 for p,h in PINS.items():check(git('rev-parse','HEAD:'+p)==h,'unpersisted CO2 source')
 return {'baseline':BASE,'source_tree':git('rev-parse','HEAD:src'),'postimages':PINS,'co2_successor':True,'qualified':False,'admitted':False}
def dependencies(inputs):
 for p,h in inputs.items():
  check(not Path(p).is_absolute() and '..' not in Path(p).parts,'unsafe dependency')
  check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'stale dependency '+p)
def native_raw(data,digest):
 raws=[b for p,b in data.items()if p.endswith('.stdout')and hashlib.sha256(b).hexdigest()==digest]
 check(bool(raws),'missing raw native output');return raws[0]
def validate_physical(data,manifest,source):
 r=json.loads(data['physical/RESULTS.json']);inputs=json.loads(data['physical/INPUTS.json'])
 expected={(o,n,mo,mode) for o in (0,2) for n in MARKERS for mo in (['neutral','dry','hydraulic']if n=='weather'else['neutral'])for mode in ['continuous','restart']}
 keys=[(x['opt'],x['driver'],x['moisture'],x['mode'])for x in r['results']]
 check(r['status']=='PASS'and len(keys)==28 and set(keys)==expected,'incomplete/duplicate physical matrix')
 check(inputs['flags']==FLAGS,'physical flag manifest drift')
 from run_modular_tests import DEP
 providers=subprocess.check_output(['python3','-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all','tests/fsi/fsi04_real_headcalc_stubs.f90',BOOT,'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
 check(inputs['providers']==providers and set(providers)<=r['source_inputs'].keys(),'provider closure incomplete')
 dependencies(r['source_inputs'])
 check(r['source_inputs']==inputs['inputs'],'physical input manifests disagree')
 for p,h in inputs['generated'].items():check(hashlib.sha256(data['physical/'+p]).hexdigest()==h,'generated input drift')
 hashes={}
 for x,k in zip(r['results'],keys):
  check(x['returncode']==0 and math.isfinite(x['wall_seconds'])and x['wall_seconds']>0,'failed native row')
  raw=native_raw(data,x['stdout_sha256']);check(MARKERS[x['driver']]in raw,'original assertions missing')
  if x['driver']=='co2':check(b'OXYGEN_CYCLE_STRESSED_SEGMENTS=320'in raw,'physical oxygen/CO2 path absent')
  hashes[k]=x['stdout_sha256']
 for o,n,mo,mode in expected:
  check(hashes[(o,n,mo,mode)]==hashes[(2-o,n,mo,mode)]==hashes[(o,n,mo,'restart'if mode=='continuous'else'continuous')],'physical optimization/restart drift')
 natives=[e for e in r['events']if Path(e['command'][0]).name.startswith('test-')]
 nkeys=[]
 for e in natives:
  cmd=e['command'];parent=Path(cmd[0]).parent.name
  check(parent in ['o0','o2']and len(cmd)==7 and e['returncode']==0,'native event identity')
  k=(int(parent[1:]),Path(cmd[0]).name.removeprefix('test-'),cmd[-1],cmd[-2]);nkeys.append(k)
  check(k in hashes and hashes[k]==e['stdout_sha256'],'native event/result mismatch')
 check(len(nkeys)==28 and set(nkeys)==expected,'native commands incomplete/duplicate')
 for opt in (0,2):
  compiles=[e['command']for e in r['events']if '-c'in e['command']and '-O'+str(opt)in e['command']]
  check(len(compiles)==len(providers)+10+5,'compile coverage')
  for cmd in compiles:check(cmd[1:len(FLAGS)+2]==[*FLAGS,'-O'+str(opt)],'compiler flags drift')
  compiled=[Path(c[c.index('-c')+1])for c in compiles[:len(providers)]]
  check([str(p.relative_to(ROOT))if p.is_relative_to(ROOT)else p.name for p in compiled]==[p if p!='tests/fsi/fsi04_real_headcalc_stubs.f90'else'grid_stubs.f90'for p in providers],'compiled provider order')
 links=[e for e in r['events']if '-c'not in e['command']and '-o'in e['command']]
 check(len(links)==10 and all(e['returncode']==0 for e in links),'link coverage')
 direct=json.loads(data['direct/RESULTS.json'])
 check(direct['status']=='PASS'and len(direct['results'])==2 and {x['opt']for x in direct['results']}=={0,2},'direct O0/O2 incomplete')
 check(direct['authority']['cropdevelopment_sha256']=='aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210','historical source identity')
 dependencies(direct['inputs'])
 rows=[e for e in direct['events']if Path(e['command'][0]).name=='test']
 check(len(rows)==2 and all(e['returncode']==0 and b'CO2_LITERAL_SOURCE_CASES=2991'in native_raw(data,e['stdout_sha256'])and b'CO2_ANNUAL_SOURCE_CONTRACT=PASS'in native_raw(data,e['stdout_sha256'])for e in rows),'direct literal assertions missing')
 check(rows[0]['stdout_sha256']==rows[1]['stdout_sha256'],'direct optimization drift')
 fast=json.loads(data['fast/RESULTS.json'])
 check(fast['status']=='PASS','fast contracts not PASS')
 for case in ['assimilation','root_oxygen','root_contract','low_air_policy','low_air_physical']:
  rows=[x for x in fast['records']if x['case']==case]
  check(len(rows)==4 and {(x['optimization'],x['build'])for x in rows}=={(o,b)for o in (0,2)for b in ['cold','warm_same_transaction']},'fast O0/O2 cold/warm incomplete')
  for row in rows:dependencies(row['inputs']);native_raw(data,row['stdout_sha256'])
 return {**source,'physical_programs':28,'highest':'NOT_SELECTED_POLICY'}
def verify_physical():
 s=json.loads(STATUS.read_text());data,m=read_capsule(s['evidence']);return validate_physical(data,m,verify_source())
def verify_qualification():
 result=verify_physical();s=json.loads(STATUS.read_text());data,m=read_capsule(s['additional_owner_evidence'])
 from importlib.util import spec_from_file_location,module_from_spec
 spec=spec_from_file_location('additional_owner',ROOT/'tests/mc-met01/run_joint_owner_additional.py');mod=module_from_spec(spec);spec.loader.exec_module(mod)
 from verify_joint_preservation import MARKERS as markers
 r=json.loads(data['additional/RESULTS.json'])
 check(r['status']=='PASS'and r['source']['source_tree']==result['source_tree'],'additional owner status/source')
 check([(x['name'],x['command'])for x in r['steps']]==mod.STEPS,'additional owner matrix')
 for row in r['steps']:
  raw=data['additional/'+row['name']+'.stdout']
  check(row['exit']==0 and hashlib.sha256(raw).hexdigest()==row['stdout_sha256']and markers[row['name']]in raw,'additional original assertion/exit/log')
 tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2]for line in git('ls-tree','-r','HEAD').splitlines()}
 conservative=set(git('ls-tree','-r','--name-only','HEAD','--','src','tests','tools').splitlines())
 check(conservative<=m['dependency_blobs'].keys(),'additional dependency closure incomplete')
 for p,h in m['dependency_blobs'].items():check(tree.get(p)==h and blob((ROOT/p).read_bytes())==h,'additional dependency drift '+p)
 return result
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--physical-only',action='store_true');p.add_argument('--source-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_physical()if a.physical_only else verify_qualification(),indent=2))
