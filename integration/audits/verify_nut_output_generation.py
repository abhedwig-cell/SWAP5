"""Local source/evidence guard for PR1358's bounded joint output generation.

This is not a replacement for the existing canonical admission dispatcher.
"""
from pathlib import Path
import base64,functools,hashlib,io,json,runpy,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
BASE='a737c605'
SELF='integration/audits/verify_nut_output_generation.py'
PARENT='integration/diagnostics/verify_perf01_empty_pond.py'
RESEARCH='integration/diagnostics/verify_perf01_pond_policy.py'
SCIENCE=['src','app','tests','tools','reference','examples','.github','integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()
def require(ok,why):
 if not ok:raise ValueError(why)
def record():return json.loads((ROOT/STATUS).read_text())['extended_output_component_20261021']['joint_generation_successor']
def capsule():
 r=record();p=ROOT/r['evidence_index'];require(sha(p.read_bytes())==r['evidence_index_sha256'],'generation index')
 index=json.loads(p.read_text());raw=base64.b64decode((p.parent/'evidence.tar.gz.b64').read_bytes(),validate=False)
 require(sha(raw)==index['decoded_sha256'],'generation capsule')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz')as t:
  members=t.getmembers()
  require(all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in members),'unsafe members')
  require(len(members)==len({m.name for m in members}),'duplicate members')
  f={m.name:t.extractfile(m).read()for m in members}
 require(f.keys()==index['members'].keys(),'member inventory')
 require(all(sha(f[p])==h for p,h in index['members'].items()),'member integrity')
 return f
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def hook(entry,target=None):
 target=target or entry
 condition="'joint_generation_successor' in json.loads((ROOT/'"+STATUS+"').read_text()).get('extended_output_component_20261021',{})"
 return "    if "+condition+":\n        return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+target+"']("+('reader,changed'if entry=='source'else'reader'if entry=='registered_additions'else'')+")\n"
def project_owner(path):
 text=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
 if path==PARENT:
  for entry,target in [('source','source'),('verify_qualification','verify'),('self_test','self_test')]:
   prefix='def '+entry+'('
   start=text.index(prefix);offset=text.index('\n',start)+1
   text=text[:offset]+hook(entry,target)+text[offset:]
 else:
  prefix='def registered_additions(reader=lambda p:(ROOT/p).read_bytes()):\n'
  require(text.count(prefix)==1,'registered additions anchor')
  text=text.replace(prefix,prefix+hook('registered_additions'),1)
 return text.encode()
def registered_additions(reader=lambda p:(ROOT/p).read_bytes()):
 source(reader)
 return set(record()['postimages'])
@functools.lru_cache(maxsize=None)
def predecessor():
 receipt=record().get('predecessor_receipt')
 if receipt:
  raw=(ROOT/receipt['path']).read_bytes();require(sha(raw)==receipt['sha256'],'predecessor receipt identity')
  r=json.loads(raw);require(r['baseline']==git('rev-parse',BASE),'predecessor baseline receipt');return r
 checkout=ROOT.parent/'joint-output-admission-predecessor'
 if not checkout.exists():subprocess.run(['git','worktree','add','--detach',str(checkout),BASE],cwd=ROOT,check=True,capture_output=True)
 require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=checkout,text=True).strip()==git('rev-parse',BASE),'predecessor checkout')
 owner=runpy.run_path(str(checkout/PARENT));research=runpy.run_path(str(checkout/RESEARCH))
 r=dict(baseline=git('rev-parse',BASE),owning_qualification=owner['verify_qualification'](),owning_controls=owner['self_test'](),research_qualification=research['verify'](),research_controls=research['self_test']())
 (ROOT.parent/'joint-output-admission-predecessor-receipt.json').write_text(json.dumps(r,indent=2)+'\n')
 return r
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'admission' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_water_successor',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_water.py'))['source'](reader,changed)
 r=record()
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'new output source '+p)
 for p,h in r['qualified_input_sha256'].items():require(sha(reader(p))==h,'executed output dependency '+p)
 require(reader(PARENT)==project_owner(PARENT)and reader(RESEARCH)==project_owner(RESEARCH),'incumbent owning assertions changed')
 prior=json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT))
 current=json.loads(reader(STATUS));current.pop('extended_output_component_20261021',None)
 require(current==prior,'unrelated NUT status changed')
 require(not git('status','--porcelain','--',*SCIENCE),'dirty output scientific surface')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 expected=r['source_delta']
 actual={v.split('\t')[1]:v.split('\t')[0]for v in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}if changed is None else changed
 require(actual==expected,'foreign output scientific delta')
 return r
def validate(f):
 def js(p):return json.loads(f[p])
 r=js('final/result.json')
 require(r['status']=='JOINT_OUTPUT_AUTOMATIC_ATOMIC_GENERATION_O0_O2_PASS','no final actual success')
 require(r['physical_proof_sha256']==sha(f['predecessor/accepted-output-2-result.json']),'physical proof handoff')
 require(r['csv_proof_sha256']==sha(f['predecessor/accepted-csv-1-result.json']),'CSV proof handoff')
 for name,h in js('predecessor/accepted-csv-1-result.json')['input_sha256'].items():require(sha((ROOT/name).read_bytes())==h,'executed CSV dependency '+name)
 require(r['results']['O0']==r['results']['O2'],'optimization drift')
 require(r['generated_driver_sha256']==sha(f['final/driver.f90']),'generated driver drift')
 for name,h in {**r['physical_input_sha256'],**r['input_sha256']}.items():require(sha((ROOT/name).read_bytes())==h,'executed capsule source '+name)
 for opt in ['O0','O2']:
  v=r['results'][opt];require(v['invalids']==14,'invalid inventory')
  require(set(v['crashes'])=={'before','after'},'crash boundary inventory')
  require(all(x['returncode']==-9 and x['complete']for x in v['crashes'].values()),'crash claims')
  for suffix in ['', '.output','.csv','.generation','.automatic.csv']:
   require(f['final/'+opt+'/model.endpoint'+suffix]==f['final/'+opt+'/model.fresh'+suffix],'fresh endpoint '+opt+suffix)
  for suffix in ['generation.zero','failed-save-after']:
   require('final/'+opt+'/model.restart.'+suffix in f,'missing failure state')
  require(f['final/'+opt+'/model.restart.generation.zero']==f['final/'+opt+'/model.restart.failed-save-after'],'failed-save memory drift')
  require(f['final/'+opt+'/model.restart.view-failed.generation']==f['final/'+opt+'/model.restart.view-failed.memory']==f['final/'+opt+'/model.restart.generation'],'view failure model mismatch')
  require(f['final/'+opt+'/model.endpoint.automatic-inner']==f['final/'+opt+'/model.endpoint.ordinary-inner'],'automatic science drift')
  for phase in ['before','after']:
   prefix='final/'+opt+'/crash-'+phase+'/'
   want=f[prefix+'model.restart.generation.zero']if phase=='before'else f['final/'+opt+'/model.restart.generation']
   require(f[prefix+'model.restart.generation']==f[prefix+'recovered']==want,'partial crash generation')
 e=js('final/events.json')
 for v in e:
  require(v['returncode']==0,'failed selected final event')
  for stream in ['stdout','stderr']:require('final/'+v[stream]in f,'missing final native stream')
 counts={c:sum(v['category']==c for v in e)for c in ['compile','driver_compile','native','fresh_native','invalid_generation','invalid_identity','crash_reconstruction']}
 require(counts==dict(compile=6,driver_compile=2,native=2,fresh_native=2,invalid_generation=26,invalid_identity=2,crash_reconstruction=4),'native gate inventory')
 for v in e:
  if v['category']in ['native','fresh_native']:
   require(b'PASS'in f['final/'+v['stdout']],'missing actual assertions')
 return dict(status='JOINT_OUTPUT_SOURCE_AND_EVIDENCE_PASS',invalids_per_optimization=14,crash_boundaries=4)
def verify():
 if 'admission' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_water_successor',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_water.py'))['verify_qualification']()
 source();r=validate(capsule());r['frozen_predecessor']=predecessor();return r
def self_test():
 if 'admission' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text()).get('swp_water_successor',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_swp_water.py'))['self_test']()
 source();f=capsule();validate(f);controls=[]
 def reject(name,fn):
  try:fn()
  except(ValueError,KeyError,AssertionError):controls.append(name);return
  raise ValueError('corruption accepted: '+name)
 for p in ['src/adapter/mod_crop_n_output_generation.f90','src/adapter/mod_crop_soil_n_output_day.f90','src/legacy/b1_10_port/headcalc.f90']:
  reject('source '+p,lambda p=p:source(lambda x:(ROOT/x).read_bytes()+(b'!'if x==p else b'')))
 for p in ['final/result.json','final/driver.f90','final/O0/model.endpoint.generation','final/O2/model.fresh.output','final/O0/crash-before/recovered','final/O2/crash-after/model.restart.generation','final/O0/model.restart.failed-save-after']:
  bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
 for p in ['final/O0/model.fresh.csv','final/O2/model.restart.view-failed.memory','final/O0/crash-before/model.restart.generation']:
  bad=dict(f);bad[p]+=b'!';reject('changed '+p,lambda bad=bad:validate(bad))
 bad=dict(f);r=json.loads(bad['final/result.json']);r['results']['O0']['invalids']=0;bad['final/result.json']=json.dumps(r).encode();reject('missing negatives',lambda:validate(bad))
 return dict(status='JOINT_OUTPUT_GUARD_CONTROLS_PASS',count=len(controls),controls=controls)
if __name__=='__main__':print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
