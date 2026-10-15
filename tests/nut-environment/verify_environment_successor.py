#!/usr/bin/env python3
"""Exact daily-temperature successor with literal and original native proof."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='dca8cbd87ceff62406d0d1a38447b7a7bc8fbd1c'
STATUS='integration/audits/MC_NUT01_DAILY_ENVIRONMENT_STATUS.json'
CHANGED={
 'tests/crop-co2/verify_co2_successor.py',
 'src/process/mod_b111_soil_n_reactive_owner.f90',
 'src/crop/mod_crop_soil_n_day.f90',
 'src/runtime/mod_fmr_crop_soil_n_joint_application.f90',
 'tests/nut-crop/verify_crop_supply_successor.py',
 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
EXPECTED_DRIVERS={'test_crop_soil_day','test_environment_day','test_environment_joint','test_crop_soil_joint','test_reactive_joint','test_mineral_joint'}
MARKERS={
 'test_environment_day':'DAILY_ENVIRONMENT_LITERAL_SUPPLY_ROLLBACK_IDENTITY=PASS',
 'test_crop_soil_day':'CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS',
 'test_environment_joint':'DAILY_ENVIRONMENT_ACTUAL_RICHARDS_LITERAL_ROLLBACK_OPAQUE_DISK=PASS',
 'test_crop_soil_joint':'CROP_SOIL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ROLLBACK_OPAQUE_DISK=PASS',
 'test_reactive_joint':'REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS',
 'test_mineral_joint':'MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(b):return hashlib.sha256(b).hexdigest()
def verify_source():
 if (ROOT/'src/crop/mod_crop_soil_n_material_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material'));import verify_material_successor as materials
  result=materials.verify_source(git_reader=git)
  return {**result,'source_tree':materials.ENV_SOURCE}

 s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'unknown baseline')
 git('merge-base','--is-ancestor',BASE,'HEAD')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty source surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign daily environment delta')
 check(set(s['changed_blobs'])==CHANGED,'changed surface coverage')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():
  b=(ROOT/p).read_bytes();blob=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
  check(git('rev-parse','HEAD:'+p)==h==blob,'unknown postimage '+p)
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'immutable reference changed')
 return dict(baseline=BASE,source_tree=git('rev-parse','HEAD:src'),daily_environment_successor=True,qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text())['evidence'];raw=base64.b64decode((ROOT/s['path']).read_bytes())
 check(sha(raw)==s['sha256'],'capsule identity')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe capsule')
  check(len({m.name for m in ms})==len(ms),'duplicate members')
  d={m.name:a.extractfile(m).read()for m in ms}
 m=json.loads(d.pop('MANIFEST.json'));check(set(m)==set(d),'manifest coverage')
 for p,h in m.items():check(sha(d[p])==h,'raw member identity '+p)
 return d

def validate(data,source):
 r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED'and r['direct_only']is False,'physical unfinished')
 check(r['source_tree']==source['source_tree'],'wrong physical source')
 check(r['authority']['management_soil.f90']=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b','literal authority')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'physical input drift '+p)
 s=json.loads((ROOT/STATUS).read_text())
 production={p for p in [*s['added_blobs'],*s['changed_blobs']]if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'production coverage')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(set(row['drivers'])==EXPECTED_DRIVERS,'driver coverage')
  check(row['production_providers']==260,'actual physical closure')
  for name,entry in row['drivers'].items():
   check(MARKERS[name]in entry['stdout'],'missing science '+name)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   count=18 if name in ['test_crop_soil_joint','test_environment_joint'] else 10
   if name in ['test_environment_day','test_crop_soil_day']:
    check(len(es)==1,'missing direct native '+name)
   else:
    check(len(set(entry['decoder_negatives']))==count,'decoder coverage '+name)
    check(len(es)==count+2 and es[0]['command'][1]=='write'and es[1]['command'][1]=='resume','native continuation matrix '+name)
    for suffix in ['-expected.bin','-fresh.bin','-expected.bin.opaque']:
     check(sha(data[opt+'/'+name+suffix])==entry['endpoint_sha256'],'continuation mismatch '+name)
    check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][name]['endpoint_sha256'],'O0 O2 endpoint drift '+name)
    for e in es[2:]:check(b'INVALID_DISK=PASS'in data[e['stdout_file']],'missing native rejection')
    if name!='test_environment_joint':
     check(entry['admitted_endpoint_identity']is True,'incumbent endpoint unproven')
     cap='MC_NUT01_CROP_SUPPLY'if name=='test_crop_soil_joint'else'MC_NUT01_REACTIVE_DAY'if name=='test_reactive_joint'else'MC_NUT01_MINERAL_TRANSPORT'
     with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/('integration/audits/evidence/'+cap+'_20261015.tar.xz.b64')).read_bytes())))as a:
      p=opt+'/'+name+'-expected.bin'if name=='test_crop_soil_joint'else opt+'/expected.bin'
      check(data[opt+'/'+name+'-expected.bin']==a.extractfile(p).read(),'original endpoint differs')
   check(data[es[0]['stdout_file']].decode()==entry['stdout'],'raw stdout binding '+name)
  body=data[opt+'/management_soil.f90'].decode();a=body.index('! Mineralisation, but Nminer is negative in case of immobilisation');b=body.index('      Call Wofost_SoilBalanceCheck',a)
  literal=body[a:b].encode();check(sha(literal)==r['literal_uptake_extraction']['block_sha256'],'literal block identity')
  check(literal in data[opt+'/literal_crop_exchange.f90'],'literal uptake replaced')
  for p,h in r['authority'].items():
   expected='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if p=='wofost_soil_orgmatn.f90'else h
   check(sha(data[opt+'/'+p])==expected,'source oracle identity')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed physical event')
  if e['category']in ['compile','driver_compile']:
   opt=Path(next(a[2:]for a in e['command']if a.startswith('-J'))).name
   check('-'+opt in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compilation')
  for stream in ['stdout','stderr']:check(sha(data[e[stream+'_file']])==e[stream+'_sha256'],'raw event digest')
 # The small route is independently compiled, not an inferred import graph.
 small=json.loads(data['direct/result.json']);se=json.loads(data['direct/events.json'])
 check(small['status']=='DIRECT_PASS'and small['source_tree']==source['source_tree'],'small route unfinished')
 for p,h in small['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'small input drift')
 for opt in ['O0','O2']:
  check(small['runs'][opt]['production_providers']==40,'small closure')
  check(set(small['runs'][opt]['drivers'])=={'test_environment_day','test_crop_soil_day'},'small drivers')
  for name,entry in small['runs'][opt]['drivers'].items():
   check(MARKERS[name]in entry['stdout'],'small native science absent')
   es=[e for e in se if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(es)==1 and data['direct/'+es[0]['stdout_file']].decode()==entry['stdout'],'small native binding')
 for e in se:
  check(e['returncode']==0,'failed small event')
  for stream in ['stdout','stderr']:check(sha(data['direct/'+e[stream+'_file']])==e[stream+'_sha256'],'small raw event')
 return r

def verify_qualification():
 if (ROOT/'src/crop/mod_crop_soil_n_material_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material'));import verify_material_successor as materials
  return materials.verify_qualification()
 source=verify_source();validate(read_evidence(),source)
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
def incumbent(mode='qualification'):
 if (ROOT/'src/crop/mod_crop_soil_n_material_day.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-material'));import verify_material_successor as materials
  return materials.incumbent(mode)
 verify_qualification();base=ROOT.parent/'environment-incumbent-dca8cbd8'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'wrong baseline')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty baseline')
 p=subprocess.run([sys.executable,'-B',str(base/'tests/nut-crop/verify_crop_supply_successor.py'),'--incumbent',mode],cwd=base,check=True,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return {**json.loads(p.stdout),'daily_environment_successor':True,'environment_baseline':BASE,'environment_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
