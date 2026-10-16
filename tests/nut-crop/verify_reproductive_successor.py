"""Bounded B1.11 source process, sole-owner transaction and native preservation."""
from pathlib import Path
from functools import lru_cache
import base64,hashlib,io,json,subprocess,sys,tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='71551d19d7f9a5e973d2deff5347049174502cbf'
STATUS='integration/audits/MC_NUT_SOL_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/crop/mod_b111_reproductive_n_process.f90','src/crop/mod_crop_b111_reproductive_binding.f90',
 'src/crop/mod_crop_soil_n_configuration.f90','src/crop/mod_crop_soil_n_day.f90'}
POLICY_NEGATIVES=['absent','old-profile','wrong-dvsnlt','wrong-dvsnt','wrong-nfixf','wrong-fntrt']
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['reproductive_process_20261016']
def verify_source(git_reader=None):
 if (ROOT/'tests/fmig431/verify_signed_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_signed_divdra_successor as drain
  return drain.verify_source(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'reproductive baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty reproductive input')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign reproductive science')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'reproductive production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'reproductive postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'reproductive source tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reproductive reference drift')
 flags={n:True for n in ('pond_successor','dynamic_pond_successor','persistent_surface_restart_successor','material_root_irrigation_successor',
  'b111_request_successor','managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor',
  'int12c_successor','co2_successor','swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor')}
 return dict(baseline=BASE,source_tree=r['source_tree'],current_source_tree=r['source_tree'],reproductive_successor=True,qualified=False,admitted=False,**flags)
def evidence():
 d=record()['science_archive'];raw=base64.b64decode((ROOT/d['path']).read_bytes())
 check(sha(raw)==d['decoded_sha256'],'reproductive capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate reproductive member')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe reproductive member')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete reproductive capsule')
 for p,h in manifest.items():check(sha(data[p])==h,'corrupt reproductive member '+p)
 return data
def validate_science(data):
 rec=record();r=json.loads(data['final/result.json']);events=json.loads(data['final/events.json'])
 check(r['status']=='REPRODUCTIVE_PHYSICAL_PASS_NOT_ADMITTED','unfinished reproductive physical science')
 check(r['execution_commit']==rec['execution_commit'],'wrong reproductive execution')
 check(r['source_tree']==rec['source_tree'],'wrong reproductive scientific source')
 check(not r['direct_only'],'direct process substituted for actual owners')
 check(PRODUCTION<=r['input_sha256'].keys(),'reproductive providers not tested')
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe reproductive input')
  check(sha((ROOT/p).read_bytes())==h,'stale reproductive input '+p)
 leaf=json.loads(data['process/result.json']);le=json.loads(data['process/events.json'])
 check(leaf['status']=='PROCESS_PASS_NOT_RUNTIME_ADMISSION','unfinished reproductive process')
 check(leaf['execution_commit']==rec['execution_commit'],'wrong process execution')
 check(leaf['authority_sha256']=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2','reproductive literal source drift')
 check(leaf['literal_lines']==[[354,370],[197,255]],'reproductive literal line drift')
 check(sha(data['process/literal.f90'])==leaf['oracle_sha256']==r['literal_sha256'],'reproductive literal disagreement')
 for p,h in leaf['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale process input '+p)
 check(len(le)==12 and [e['category']for e in le].count('native')==2,'missing process commands')
 for e in le:
  check(e['returncode']==0 and e['seconds']>=0,'failed process command')
  for stream in ('stdout','stderr'):check('process/'+e[stream]in data,'missing process raw '+stream)
  if e['category']=='native':check(data['process/'+e['stdout']].decode()==leaf['stdout']and b'B111_REPRODUCTIVE_LITERAL_CORPUS_GUARDS=PASS'in data['process/'+e['stdout']],'missing literal process assertions')
  if e['category']=='compile':check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked process compilation')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed reproductive physical event')
  for stream in ('stdout','stderr'):check(sha(data['final/'+e[stream+'_file']])==e[stream+'_sha256'],'physical raw output drift')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked physical compilation')
 # Immutable admitted PR1253 bytes cover both default and selected vegetative mode.
 oldpath=ROOT/'integration/audits/evidence/MC_NUT01_B111_REQUEST_BINDING_SCIENCE_20261016.tar.xz.b64'
 oldrec=json.loads((ROOT/STATUS).read_text())['b111_request_binding_20261016']['science_archive']
 raw=base64.b64decode(oldpath.read_bytes());check(sha(raw)==oldrec['decoded_sha256'],'1253 authority drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  old={m.name:a.extractfile(m).read()for m in a.getmembers()if m.isfile()}
 for opt in ('O0','O2'):
  row=r['reproductive'][opt];prior=r['b111_request'][opt]
  check('B111_REPRODUCTIVE_REAL_SOIL_CROP_CASES=72'in row['daily_stdout']and 'B111_REPRODUCTIVE_LITERAL_DEATH_DONORS_BALANCE_ROLLBACK_REPLAY=PASS'in row['daily_stdout'],'missing reproductive daily matrix')
  check('REPRODUCTIVE_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'in row['joint_stdout'],'missing reproductive actual Richards/pending')
  check(row['policy_identity_negatives']==POLICY_NEGATIVES,'missing source policy identity negatives')
  check(sha(data['final/'+opt+'/reproductive-expected.bin'])==row['endpoint_sha256'],'reproductive endpoint drift')
  check(sha(data['final/'+opt+'/reproductive-restart.bin'])==row['restart_sha256'],'reproductive restart drift')
  check(data['final/'+opt+'/reproductive-expected.bin']==data['final/'+opt+'/reproductive-fresh.bin']==data['final/'+opt+'/reproductive-expected.bin.opaque'],'reproductive restart mismatch')
  native=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  for stem,marker in [('test_b111_reproductive_day',row['daily_stdout']),('test_b111_request_day',prior['direct_stdout'])]:
   found=[e for e in native if Path(e['command'][0]).name==stem]
   check(len(found)==1 and data['final/'+found[0]['stdout_file']].decode()==marker,'missing actual daily program '+stem)
  j=[e for e in native if Path(e['command'][0]).name=='test_reproductive_joint']
  check(len(j)==8,'missing reproductive native commands')
  for mode,key in [('write','joint_stdout'),('resume','fresh_stdout')]:
   found=[e for e in j if e['command'][1]==mode]
   check(len(found)==1 and data['final/'+found[0]['stdout_file']].decode()==row[key],'missing reproductive native '+mode)
  for policy in POLICY_NEGATIVES:check(any(e['command'][1]=='reject'and e['command'][-1]==policy and b'INVALID_DISK=PASS'in data['final/'+e['stdout_file']]for e in j),'missing native policy rejection '+policy)
  for name in ('b111-expected.bin','b111-restart.bin','test_crop_soil_joint-expected.bin','test_crop_soil_joint-restart.bin'):
   check(data['final/'+opt+'/'+name]==old['science/'+opt+'/'+name],'default1253 bytes changed '+name)
  check('B111_REQUEST_REAL_SOIL_CROP_CASES=72'in prior['direct_stdout']and prior['policy_identity_negatives']==2,'1253 controls absent')
  check(set(r['runs'][opt]['drivers'])=={'test_crop_soil_day','test_crop_soil_joint','test_reactive_joint','test_mineral_joint'},'default programs missing')
  check(len(r['runs'][opt]['drivers']['test_crop_soil_joint']['decoder_negatives'])==18,'incumbent decoder negatives missing')
  for p in PRODUCTION:check(sum('-c'in e['command']and str(e['command'][e['command'].index('-c')+1]).endswith('/'+p)and '-'+opt in e['command']for e in events)==1,'provider not compiled exactly once '+p)
 check(r['reproductive']['O0']==r['reproductive']['O2'],'reproductive O0/O2 drift')
 # All modifications of incumbent science/guards are removable insertions.
 projections=json.loads(data['review/insertions.json'])
 shared={p for p,v in rec['postimages'].items()if v['status']=='M'}
 check(set(projections)==shared,'reproductive default body review incomplete')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['range'];check(lines[a:b]==q['inserted'],'changed reproductive insertion');lines[a:b]=[]
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'incumbent body changed '+p)
 return dict(daily_cases_per_opt=72,source_process=True,actual_richards=True,delayed_pending=True,native_and_opaque=True,default1253_native_byte_identity=True)
@lru_cache(None)
def incumbent():
 root=ROOT.parent/('reproductive-incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'reproductive incumbent moved')
 p=subprocess.run([sys.executable,'-B','tests/nut-sol/verify_dynamic_pond_successor.py'],cwd=root,capture_output=True,text=True)
 check(p.returncode==0,'actual incumbent rejected '+p.stderr[-1000:]);r=json.loads(p.stdout)
 check(r['qualified']and r['dynamic_pond_successor'],'incomplete reproductive incumbent');return r
def verify_qualification():
 if (ROOT/'tests/fmig431/verify_signed_divdra_successor.py').exists():
  sys.path.insert(0,str(ROOT/'tests/fmig431'));import verify_signed_divdra_successor as drain
  return drain.verify_qualification()
 s=verify_source();check(record()['stage']in ('SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED','CANONICALLY_ADMITTED_BOUNDED'),'reproductive science not ready')
 science=validate_science(evidence());old=incumbent()
 return {**old,**s,'qualified':True,'incumbent':old,'science':science,'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
