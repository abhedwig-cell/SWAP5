#!/usr/bin/env python3
"""Exact additive admission boundary, with original incumbent science retained."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='ee2d84498bec23c55449f5d7fd8ebd9ecb7bfdde'
STATUS='integration/audits/MC_NUT01_MINERAL_TRANSPORT_STATUS.json'
GUARDS=['tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']
MINERAL_QUALIFIED='eb03024d99ef9256335eb6e2f3f74bccce8145f0'
NONLINEAR_PEER={
 'src/runtime/mod_fmr_b111_matrix_solute_route.f90':('M','f777ecb68888483bf1ae25ad05f84f1d745c8c87'),
 'tests/nut-sol/matrix_nonlinear_oracle.f90':('A','0f8983e0a16da71082917e70cf20502afcb83cd0'),
 'tests/nut-sol/run_matrix_route.py':('M','7394d1d204f7c9d22b08344dd8e617badf07dd5c'),
 'tests/nut-sol/test_matrix_joint.f90':('M','28eae2c907d2ceb5e3d5556f569d81a12ec3a491'),
 'tests/nut-sol/test_matrix_nonlinear_partition.f90':('A','8dae6dcb54369a947b5704a9c46bb836b36be3df'),
 'tests/nut-sol/test_matrix_route.f90':('M','3c1244fbc59cef38413a1a54a24a104ac5d1cc06'),
 'tests/crop-co2/test_nonlinear_admission_controls.py':('A','c7cb4120e05b7e9fdd9e513d087614a221d33016'),
}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def check(ok,label):
 if not ok:raise ValueError(label)
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def verify_source():
 if (ROOT/'src/process/mod_b111_soil_n_reactive_owner.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-reactive'))
  import verify_reactive_successor as reactive
  return reactive.verify_source()
 s=json.loads((ROOT/STATUS).read_text());git('merge-base','--is-ancestor',BASE,'HEAD')
 check(s['baseline']==BASE,'unknown baseline')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty dependency surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['source_blobs']};expected.update({p:'M'for p in GUARDS})
 expected.update({p:kind for p,(kind,h)in NONLINEAR_PEER.items()})
 check(rows==expected,'foreign additive delta')
 for p,h in {**s['source_blobs'],**s['guard_blobs']}.items():
  check(git('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 for p,(kind,h)in NONLINEAR_PEER.items():
  check(git('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown nonlinear peer '+p)
 check(set(s['guard_blobs'])==set(GUARDS),'guard coverage')
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'reference mutation')
 sys.path.insert(0,str(ROOT/'tests/crop-co2'))
 from verify_co2_successor import nonlinear_evidence
 nonlinear_evidence() # peer eligibility also requires terminal real-physics proof
 return dict(baseline=BASE,source_tree=git('rev-parse','HEAD:src'),mineral_successor=True,qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text())
 raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes(),validate=False)
 check(hashlib.sha256(raw).hexdigest()==s['evidence']['sha256'],'evidence archive hash')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as a:
  entries=a.getmembers();check(all(x.isfile()and not x.name.startswith('/')and'..'not in Path(x.name).parts for x in entries),'unsafe archive')
  check(len({x.name for x in entries})==len(entries),'duplicate evidence')
  data={x.name:a.extractfile(x).read()for x in entries}
 manifest=json.loads(data.pop('MANIFEST.json'))
 check(set(manifest)==set(data),'incomplete manifest')
 for p,h in manifest.items():check(hashlib.sha256(data[p]).hexdigest()==h,'evidence member drift '+p)
 return data

def verify_qualification():
 if (ROOT/'src/process/mod_b111_soil_n_reactive_owner.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-reactive'))
  import verify_reactive_successor as reactive
  return reactive.verify_qualification()
 source=verify_source();data=read_evidence();r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='SCOPED_LOCAL_QUALIFICATION_PASS_NOT_ADMITTED','unfinished qualification')
 check(r['source_tree']==git('rev-parse',MINERAL_QUALIFIED+':src'),'stale qualified mineral source tree')
 check(r['authority_sha256']=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722','historical source drift')
 for p,h in r['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'stale physical input '+p)
 production={p for p in json.loads((ROOT/STATUS).read_text())['source_blobs']if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested production addition')
 check(r['o0_o2_endpoint_identity']is True,'optimization endpoints differ')
 for opt in ['O0','O2']:
  row=r['runs'][opt]
  check(row['direct_production_provider_count']==4,'large direct process closure')
  check('MINERAL_FOUR_PROVIDER_LITERAL_ALL_CLASSES_OWNER_BALANCE_ROLLBACK_RESTART=PASS'in row['direct_stdout'],'direct oracle absent')
  check('MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'in row['physical_stdout'],'actual composition absent')
  check('MINERAL_ACTUAL_LITERAL_AND_NINE_CARRIER_NEGATIVES=PASS'in row['physical_stdout'],'carrier negatives absent')
  for name in ['fresh.bin','expected.bin','expected.bin.opaque']:
   check(hashlib.sha256(data[opt+'/'+name]).hexdigest()==row['fresh_endpoint_sha256'],'restart endpoint mismatch')
  check(hashlib.sha256(data[opt+'/mineral_grid_stubs.f90']).hexdigest()==row['generated_grid_sha256'],'grid fixture drift')
  check(hashlib.sha256(data[opt+'/matrix_fixture.inc']).hexdigest()==row['generated_fixture_sha256'],'physical fixture drift')
  check(hashlib.sha256(data[opt+'/wofost_soil_watern.f90']).hexdigest()==r['authority_sha256'],'literal oracle changed')
  compiles=[e['command']for e in events if e['category']=='physical_compile'and '-'+opt in e['command']]
  check(len(compiles)==row['physical_provider_count']+1,'physical compile closure incomplete')
  for path in production:
   check(sum(str(c[c.index('-c')+1]).endswith('/'+path)for c in compiles)==1,'production compile identity '+path)
  for c in compiles:
   check('-ffpe-trap=invalid,zero,overflow'in c and '-fcheck=all'in c and '-std=f2008'in c,'runtime checks missing')
  native=[e for e in events if e['category']=='physical_native'and '/'+opt+'/'in e['command'][0]]
  check(len(native)==2+len(row['corruption_negatives']),'incomplete physical executions')
  check(native[0]['command'][1]=='write'and native[1]['command'][1]=='resume','physical execution identity')
  for e in native[2:]:check('MINERAL_INVALID_DISK=PASS'in data[e['stdout_file']].decode(),'decoder negative absent')
  check(len(row['corruption_negatives'])==10,'decoder negative coverage')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed qualification event')
  for stream in ['stdout','stderr']:
   check(hashlib.sha256(data[e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'raw event drift')
 return {**source,'qualified':True,'direct_providers':4,'highest':'NOT_SELECTED_POLICY'}

def incumbent(mode='qualification'):
 if (ROOT/'src/process/mod_b111_soil_n_reactive_owner.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-reactive'))
  import verify_reactive_successor as reactive
  return reactive.incumbent(mode)
 # Run the unchanged, original owning verifier at its exact admitted tree.
 # Its evidence is inherited only after the complete additive delta check above.
 verify_qualification()
 base=ROOT.parent/'nut-mineral-baseline-ee2d8449'
 if not base.exists():
  subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'incumbent checkout head')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty incumbent checkout')
 args=[sys.executable,'-B',str(base/'tests/crop-co2/verify_co2_successor.py')]
 if mode!='qualification':args.append('--source-only'if mode=='source'else'--physical-only')
 result=subprocess.run(args,cwd=base,capture_output=True,text=True,check=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 r=json.loads(result.stdout);return {**r,'mineral_successor':True,'mineral_source_tree':git('rev-parse','HEAD:src'),'incumbent_dependency_baseline':BASE}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
