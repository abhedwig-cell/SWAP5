#!/usr/bin/env python3
"""Exact additive age qualification; original incumbent science stays authoritative."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='26ddf94e58133acd413c2b2738b873a92f43f1da'
STATUS='integration/audits/MC_SOL01_ACCEPTED_AGE_STATUS.json'
CAPSULE_SHA='412d64c279074b6b21334be7cfb8d841ca14ccb5e5b5c6c66d5799bcd6b14cb5'
GUARDS={'tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def validate_delta(rows,tree,s):
 expected={p:'A' for p in s['added_blobs']};expected.update({p:'M' for p in GUARDS})
 check(rows==expected,'foreign age dependency delta')
 check(set(s['guard_blobs'])==GUARDS,'age guard coverage')
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():
  check(tree.get(p)==h,'unqualified age postimage '+p)
def verify_source():
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.verify_source()
 s=json.loads((ROOT/STATUS).read_text());check(s['baseline']==BASE,'wrong age baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty age dependencies')
 rows={r.split('\t')[1]:r.split('\t')[0] for r in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 tree={r.split('\t')[1]:r.split('\t')[0].split()[2] for r in git('ls-tree','-r','HEAD').splitlines()}
 validate_delta(rows,tree,s)
 for p,h in {**s['added_blobs'],**s['guard_blobs']}.items():check(blob((ROOT/p).read_bytes())==h,'dirty age postimage '+p)
 # This is a whole dependency-surface identity, including callers, immutable
 # fixtures, external procedures, manifests and build selection, not imports.
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'age reference mutation')
 return dict(baseline=BASE,source_tree=git('rev-parse','HEAD:src'),qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes())
 check(sha(raw)==s['evidence']['sha256']==CAPSULE_SHA,'age capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as a:
  members=a.getmembers();check(all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members),'unsafe age capsule')
  check(len({m.name for m in members})==len(members),'duplicate age evidence')
  data={m.name:a.extractfile(m).read() for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'))
 check(set(manifest)==set(data),'incomplete age evidence manifest')
 for p,h in manifest.items():check(sha(data[p])==h,'age member drift '+p)
 return data
def validate_evidence(data):
 r=json.loads(data['stable/result.json']);events=json.loads(data['stable/events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished age qualification')
 check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','wrong age historical authority')
 check(r['literal_lines']==[939,987],'different historical age loop')
 check(r['baseline']==json.loads((ROOT/STATUS).read_text())['execution_commit'],'unbound age execution')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute() and '..' not in Path(p).parts,'unsafe age input')
  if p=='tests/nut-sol/test_age_joint.f90':
   check(h=='db93d3fd3f4bac09c532fedcca02a2f5fd8d4ec9d65fae9e062611b71bc10138','unknown primary age driver')
  else:check(sha((ROOT/p).read_bytes())==h,'stale age physical input '+p)
 production={p for p in json.loads((ROOT/STATUS).read_text())['added_blobs'] if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested age production')
 for opt in ('O0','O2'):
  row=r['runs'][opt]
  check(row['process_provider_count']==2,'age process closure changed')
  check('AGE_LITERAL_150_STEPS_PRODUCTION_UNITS_BALANCE_INVALID_RETRY=PASS' in row['process_stdout'],'age process science absent')
  check('AGE_JOINT_ATOMIC_RETRY_RESTART_BALANCE=PASS' in row['physical_stdout'],'age joint science absent')
  check(row['physical_stdout'].count('AGE_ACTUAL_LITERAL_FIFTEEN_CARRIER_NEGATIVES_REPLAY=PASS')==2,'both actual signed trajectories not tested')
  check(sha(data['stable/'+opt+'/literal_age.f90'])==row['oracle_sha256'],'literal age oracle drift')
  check(sha(data['stable/'+opt+'/expected.bin'])==row['endpoint_sha256']==row['fresh_sha256']==sha(data['stable/'+opt+'/fresh.bin']),'age restart continuation drift')
  compiles=[e for e in events if e['category']=='physical_compile' and '-'+opt in e['command']]
  check(len(compiles)==row['physical_provider_count']+1,'incomplete age compilation')
  for p in production:check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p) for e in compiles)==1,'age production not compiled '+p)
  for e in compiles:check('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'],'age checks removed')
  natives=[e for e in events if e['category']=='physical_native' and '/'+opt+'/' in e['command'][0]]
  check(len(row['restart_negatives'])==10 and len(natives)==12,'incomplete age restart negatives')
  check(natives[0]['command'][1]=='write' and natives[1]['command'][1]=='resume','age native identity')
  check(data['stable/'+natives[0]['stdout']].decode()==row['physical_stdout'],'age raw physical assertion drift')
  process=[e for e in events if e['category']=='process_native' and '/'+opt+'/' in e['command'][0]]
  check(len(process)==1 and data['stable/'+process[0]['stdout']].decode()==row['process_stdout'],'age raw process assertion drift')
  check(b'AGE_FRESH_PROCESS=PASS' in data['stable/'+natives[1]['stdout']],'missing fresh age process')
  for e in natives[2:]:check(b'AGE_INVALID_DISK=PASS' in data['stable/'+e['stdout']],'missing age disk rejection')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed age command')
  for stream in ('stdout','stderr'):
   check('stable/'+e[stream] in data,'missing raw age stream')
 check(r['runs']['O0']['endpoint_sha256']==r['runs']['O2']['endpoint_sha256'],'age O0/O2 drift')
 validate_final_driver(data,r)
 return r
def validate_final_driver(data,primary):
 r=json.loads(data['final/result.json']);events=json.loads(data['final/events.json']);s=json.loads((ROOT/STATUS).read_text())
 check(r['status']=='FINAL_DRIVER_PHYSICAL_PASS' and r['execution_commit']==s['final_execution_commit'],'unfinished final age execution')
 check(r['primary_result_sha256']==sha(data['stable/result.json']),'unbound age primary execution')
 expected=dict(primary['input_sha256']);expected['tests/nut-sol/test_age_joint.f90']=sha((ROOT/'tests/nut-sol/test_age_joint.f90').read_bytes())
 check(r['inputs']==expected,'incomplete final age input binding')
 for p,h in r['inputs'].items():check(sha((ROOT/p).read_bytes())==h,'stale final age source '+p)
 check(r['all_reused_artifacts_unchanged'] is True and r['all_inputs_unchanged'] is True,'uncontrolled age artifact reuse')
 check(len(r['verified_reused_artifacts'])>900,'incomplete age provider/module artifact binding')
 check(r['compiler']==primary['compiler'],'different final age compiler')
 check(len(events)==30,'incomplete final age command matrix')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed final age command')
  for stream in ('stdout','stderr'):check('final/'+e[stream] in data,'missing final age raw event')
 for opt in ('O0','O2'):
  row=r['runs'][opt]
  compiles=[e for e in events if e['category']=='final_compile' and '-'+opt in e['command']]
  check(len(compiles)==1,'age final leaf compile count')
  cmd=compiles[0]['command']
  check(cmd[cmd.index('-c')+1].endswith('/tests/nut-sol/test_age_joint.f90') and '-fcheck=all' in cmd and '-ffpe-trap=invalid,zero,overflow' in cmd,'wrong final age leaf/flags')
  check(len([e for e in events if e['category']=='final_link' and '-'+opt in e['command']])==1,'age final link absent')
  natives=[e for e in events if e['category']=='final_native' and '/'+opt+'/' in e['command'][0]]
  check(len(natives)==12 and len(row['decoder_negatives'])==10,'incomplete final age native coverage')
  check(data['final/'+natives[0]['stdout']].decode()==row['physical_stdout'],'final age raw physical assertions drift')
  check(row['physical_stdout'].count('AGE_ACTUAL_LITERAL_FIFTEEN_CARRIER_NEGATIVES_REPLAY=PASS')==2,'final age extreme carrier controls absent')
  check(b'AGE_FRESH_PROCESS=PASS' in data['final/'+natives[1]['stdout']],'final age fresh process absent')
  for e in natives[2:]:check(b'AGE_INVALID_DISK=PASS' in data['final/'+e['stdout']],'final age disk negative absent')
  check(sha(data['final/'+opt+'/expected.bin'])==sha(data['final/'+opt+'/fresh.bin'])==row['endpoint_sha256']==primary['runs'][opt]['endpoint_sha256'],'final age endpoint drift')
  check(row['process_stdout']==primary['runs'][opt]['process_stdout'],'final age process regression')
 check(r['runs']['O0']==r['runs']['O2'],'final age optimization drift')
 witness=json.loads(data['preimage/result.json'])
 check(witness['status']=='EXPECTED_PREIMAGE_FPE_WITNESS','missing pre-validation regression witness')
 check(witness['driver_sha256']==expected['tests/nut-sol/test_age_joint.f90'],'different extreme preimage driver')
 check(witness['events'][-1]['exit']==-8 and b'SIGFPE' in data['preimage/native.stderr'],'missing real Fortran preimage overflow')
def verify_qualification():
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.verify_qualification()
 source=verify_source();validate_evidence(read_evidence());return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent_mineral():
 if (ROOT/'src/crop/mod_crop_soil_n_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-crop'))
  import verify_crop_supply_successor as crop_supply
  return crop_supply.incumbent()
 verify_qualification()
 base=ROOT.parent/'age-incumbent-26ddf94e'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'wrong incumbent age baseline')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty age incumbent')
 p=subprocess.run([sys.executable,'-B','tests/nut-mineral/verify_mineral_successor.py'],cwd=base,check=True,capture_output=True,text=True,
  env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent-mineral',action='store_true');a=p.parse_args()
 print(json.dumps(incumbent_mineral() if a.incumbent_mineral else verify_source() if a.source_only else verify_qualification(),indent=2))
