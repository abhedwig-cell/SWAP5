"""Exact opt-in request delta, complete existing default bodies and real joint science."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='093bff909f38f8bfa3b1284b40a0c3736e864954'
STATUS='integration/audits/MC_NUT_SOL_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/crop/mod_crop_b111_n_request_binding.f90','src/crop/mod_crop_soil_n_configuration.f90','src/crop/mod_crop_soil_n_day.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['b111_request_binding_20261016']
def evidence():
 d=record()['science_archive'];raw=base64.b64decode((ROOT/d['path']).read_bytes())
 check(sha(raw)==d['decoded_sha256'],'request evidence archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate request member')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe request member')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete request archive')
 for p,h in manifest.items():check(sha(data[p])==h,'request raw member drift '+p)
 return data
def verify_source(git_reader=None):
 if (ROOT/'tests/mc-irr01/verify_material_root_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_material_root_successor as material
  return material.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'unknown request baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty request source')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign request source delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'request production scope widened')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'request postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'request source tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'request reference drift')
 data=evidence();projections=json.loads(data['review/default_projections.json'])
 changed={p for p,k in rows.items()if k=='M'}
 check(set(projections)==changed,'request original-body review incomplete')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'unreviewed request island');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'request complete original-body projection failed '+p)
 flags={n:True for n in ['managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor','swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor','b111_request_successor']}
 return dict(baseline=BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],qualified=False,admitted=False,**flags)
def validate_science(data):
 r=json.loads(data['science/result.json']);events=json.loads(data['science/events.json'])
 check(r['status']=='B111_REQUEST_AFFECTED_SCIENCE_PASS_NOT_ADMITTED','unfinished request science')
 check(r['source_tree']==record()['production_source_tree'],'request scientific source differs')
 check(set(r['b111_request'])=={'O0','O2'}and set(r['runs'])=={'O0','O2'},'missing request optimization')
 check(PRODUCTION<=set(r['input_sha256']),'request production not executed')
 for p,h in r['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale executed request input '+p)
 for n,e in enumerate(events):
  check(e['returncode']==0,'failed request execution event')
  for stream in ['stdout','stderr']:check(sha(data['science/'+e[stream+'_file']])==e[stream+'_sha256'],'request event output drift')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked request compilation')
 for opt in ['O0','O2']:
  row=r['b111_request'][opt]
  check('B111_REQUEST_REAL_SOIL_CROP_CASES=72'in row['direct_stdout'],'missing request direct matrix')
  check('B111_REQUEST_SINGLE_FIXATION_BALANCE_GATES_REPLAY=PASS'in row['direct_stdout'],'request single-booking proof absent')
  check(row['policy_identity_negatives']==2,'request identity negatives absent')
  check(sha(data['science/'+opt+'/b111-expected.bin'])==row['endpoint_sha256'],'request endpoint digest drift')
  check(sha(data['science/'+opt+'/b111-restart.bin'])==row['restart_sha256'],'request restart digest drift')
  check(data['science/'+opt+'/b111-expected.bin']==data['science/'+opt+'/b111-fresh.bin']==data['science/'+opt+'/b111-expected.bin.opaque'],'request continuation mismatch')
  native=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  check(any(Path(e['command'][0]).name=='test_b111_request_day'and data['science/'+e['stdout_file']].decode()==row['direct_stdout']for e in native),'request direct native not executed')
  for mode,marker in [('write','joint_stdout'),('resume','fresh_stdout')]:
   check(any(Path(e['command'][0]).name=='test_crop_soil_joint'and e['command'][1]==mode and e['command'][-1]=='b111'and data['science/'+e['stdout_file']].decode()==row[marker]for e in native),'request physical/native command missing '+mode)
  for policy in ['', 'wrong-policy']:
   check(any(Path(e['command'][0]).name=='test_crop_soil_joint'and e['command'][1]=='reject'and e['command'][-1]==policy and b'INVALID_DISK=PASS'in data['science/'+e['stdout_file']]for e in native),'request policy mismatch not executed')
  check(set(r['runs'][opt]['drivers'])=={'test_crop_soil_day','test_crop_soil_joint','test_reactive_joint','test_mineral_joint'},'incumbent default drivers absent')
  check(len(r['runs'][opt]['drivers']['test_crop_soil_joint']['decoder_negatives'])==18,'default crop decoder controls absent')
 check(r['b111_request']['O0']==r['b111_request']['O2'],'request O0/O2 drift')
 check(data['science/O0/b111-expected.bin']==data['science/O2/b111-expected.bin'],'request native optimization drift')
 log=data['component.log']
 for marker in [b'B111_NFIX_INVALID_CASES=39',b'B111_NFIXATION_POLICY_PASS',b'SWAP431_WOF81_07_N_ARBITRATION_PASS cases=1806',b'SWAP431_WOF81_04_EDGE_PASS']:
  check(log.count(marker)==2,'component/default W81 controls missing')
 check(b'B111_NFIX_CORPUS=593|PASS=True'in log,'literal request evidence missing')
 boundary=json.loads(data['boundaries/RESULTS.json'])
 check(boundary['status']=='PASS'and len(boundary['records'])==2,'boundary leaf unfinished')
 check({x['optimization']for x in boundary['records']}=={0,2},'boundary optimization absent')
 for row in boundary['records']:
  check(row['case']=='b111_request','wrong boundary leaf')
  for p,h in row['inputs'].items():check(sha((ROOT/p).read_bytes())==h,'stale boundary input '+p)
  outputs=[b for p,b in data.items()if p.startswith('boundaries/')and p.endswith('.stdout')and sha(b)==row['stdout_sha256']]
  check(bool(outputs)and b'B111_REQUEST_BOUNDARY_TINY_DEMAND_MULTI_ORGAN_NONFINITE=PASS'in outputs[0],'boundary raw science absent')
 for event in boundary['events']:check(event['returncode']==0,'failed boundary command')
 literal=json.loads(data['literal/result.json'])
 check(literal['cases']==593 and literal['pass'] and literal['byte_identity'],'literal corpus incomplete')
 for p,h in literal['source_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'literal input drift')
 for opt in ['O0','O2']:
  x=literal['optimizations'][opt];raw=data['literal/'+opt+'.stdout']
  check(x['exit']==0 and sha(raw)==x['stdout_sha256']and raw.count(b'NFIX_LITERAL_CASE=')==593,'literal raw evidence drift')
 # Compare actual default endpoints to immutable original qualified bytes.
 oldraw=base64.b64decode((ROOT/'integration/audits/evidence/MC_NUT01_CROP_SUPPLY_20261015.tar.xz.b64').read_bytes())
 check(sha(oldraw)=='166b93e043c6404d2cd7b9ea22a88af8fb80b1e4f20f9e115d08227c8a01de1a','original crop default evidence drift')
 with tarfile.open(fileobj=io.BytesIO(oldraw))as a:
  for opt in ['O0','O2']:
   for driver in ['test_crop_soil_joint','test_reactive_joint','test_mineral_joint']:
    name=opt+'/'+driver+'-expected.bin'
    check(data['science/'+name]==a.extractfile(name).read(),'default endpoint preservation failed '+name)
 return r

def incumbent():
 base=ROOT.parent/'nfix-incumbent-093bff90'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'request incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain'],cwd=base,text=True).strip(),'request incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/mc-irr01/verify_managed_weather_successor.py'],cwd=base,capture_output=True,text=True)
 check(p.returncode==0,'original incumbent proof failed '+p.stderr[-1000:]);r=json.loads(p.stdout);check(r['qualified'],'original incumbent unqualified');return r

def verify_qualification():
 if (ROOT/'tests/mc-irr01/verify_material_root_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/mc-irr01'));import verify_material_root_successor as material
  return material.verify_qualification()
 s=verify_source();check(record()['phase']in ['SCIENCE_COMPLETE_ADMISSION_CONTROLS_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED'],'request admission science unfinished')
 r=validate_science(evidence());old=incumbent()
 return {**s,'qualified':True,'incumbent':old,'scope':record()['scope'],'preservation':'EXACT_DEFAULT_BODIES_AND_ACTUAL_UNCHANGED_ENDPOINTS_PLUS_NEW_REQUEST_MASS_RESTART','full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
