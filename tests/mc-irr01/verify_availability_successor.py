"""Full existing AVAIL admission: actual production/native evidence and exact incumbent preservation."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='4a3e1d6bdb66a235d8fd529e30d6def6457da2d1'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/runtime/mod_fmr_production_application_bootstrap.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['availability_completion_20261016']
def tcs6_record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['tcs6_completion_20261016']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record();check(r['admission_baseline']==BASE,'AVAIL baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines();check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty AVAIL science')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign AVAIL science');check({p for p in rows if p.startswith('src/')}==PRODUCTION,'AVAIL production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'AVAIL postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'AVAIL source tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'AVAIL reference drift')
 old=r['incumbent_result'];return {**old,'baseline':BASE,'source_tree':r['source_tree'],'current_source_tree':r['source_tree'],'availability_successor':True,'tcs6_successor':True,'scope':r['scope'],'qualified':False,'admitted':False,'full_capability':False}
def evidence():
 r=record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes());check(sha(raw)==r['decoded_sha256']and len(raw)==r['decoded_bytes'],'AVAIL archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==r['members']and len(ms)==len({m.name for m in ms})and all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe AVAIL capsule')
  d={m.name:t.extractfile(m).read()for m in ms}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(d)==set(manifest),'AVAIL incomplete capsule')
 for p,h in manifest.items():check(sha(d[p])==h,'AVAIL member '+p)
 return d
def raw_events(data,prefix,events):
 for i,e in enumerate(events):
  check(e['returncode']==0,'failed AVAIL command')
  for stream in ['stdout','stderr']:
   files=[v for p,v in data.items()if p.startswith(prefix+'/'+f'{i:05d}-')and p.endswith('.'+stream)]
   check(len(files)==1,'missing AVAIL raw '+str(i)+stream)
   if stream+'_sha256'in e:check(sha(files[0])==e[stream+'_sha256'],'AVAIL raw digest')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked AVAIL compile')
def validate_science(data):
 r=record();p=json.loads(data['physical/RESULTS.json']);check(p['status']=='PASS'and p['head']==r['execution_commit'],'AVAIL unfinished/wrong execution')
 for path,h in p['source_inputs'].items():check(sha((ROOT/path).read_bytes())==h,'stale AVAIL input '+path)
 check(PRODUCTION<=set(p['source_inputs']),'untested AVAIL production')
 expected={(o,n,m,ph)for o in(0,2)for n in['root2','root3','root4zero','root7','root8','weekly_dcs1']for m,ph in [('continuous','neutral')]+[(m,ph)for ph in['neutral','hydraulic']for m in['native-write','native-resume','native-write-active','native-resume-active']]}
 expected|={(o,n,m,'neutral')for o in(0,2)for n in['sensor7','sensor8']for m in['continuous','restart','native-write','native-resume']}
 ident=lambda x:(x['opt'],x['driver'],x['mode'],x['phase'])
 check(len(p['rows'])==124 and {ident(x)for x in p['rows']}==expected,'missing/duplicate AVAIL trajectory')
 native=[e for e in p['events']if Path(e['command'][0]).name.startswith('test-')and e['command'][-2]in['continuous','restart','native-write','native-resume','native-write-active','native-resume-active']]
 check(len(native)==124,'missing AVAIL native command')
 for row in p['rows']:
  check(row['returncode']==0,'failed AVAIL trajectory')
  match=[e for e in native if Path(e['command'][0]).name=='test-'+row['driver']and '/o'+str(row['opt'])+'/'in e['command'][0]and e['command'][-2:]==[row['mode'],row['phase']]]
  check(len(match)==1 and match[0]['stdout_sha256']==row['stdout_sha256'],'unexecuted AVAIL row')
  other=next(x for x in p['rows']if ident(x)==(2-row['opt'],*ident(row)[1:]));check(other['stdout_sha256']==row['stdout_sha256'],'AVAIL O0/O2 output drift')
 raw_events(data,'physical',p['events'])
 for path,h in p['generated_inputs'].items():check(sha(data['physical/'+path])==h,'AVAIL generated drift')
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from availability_cycle_driver import rooted,sensor
 from tcs6_cycle_driver import prepare_native
 with tempfile.TemporaryDirectory()as tmp:
  for n,c,d,rate in [('root2',2,1,.08),('root3',3,2,.08),('root4zero',4,1,0.),('root7',7,2,.08),('root8',8,1,.08)]:
   f=rooted(ROOT,Path(tmp)/(n+'.f90'),c,d,rate);check(f.read_bytes()==data['physical/'+f.name],'unexecuted AVAIL root generator')
  for n,c,ns,day in [('sensor7',7,1,20),('sensor8',8,3,21)]:
   f=sensor(ROOT,Path(tmp)/(n+'.f90'),c,ns,day);check(f.read_bytes()==data['physical/'+f.name],'unexecuted AVAIL sensor generator')
  f=prepare_native(ROOT,Path(tmp)/'weekly_dcs1.f90',1,True);check(f.read_bytes()==data['physical/weekly_dcs1.f90'],'unexecuted TCS6 preservation')
 check(len(p['costs'])==2 and all(c['provider_compiles']==3 and c['reused_providers']==292 for c in p['costs']),'AVAIL provider execution drift')
 # Exact source, flags, compiler and artifact hashes of the admitted donor are
 # checked by the executed runner and cross-bound to the immutable TCS6 capsule.
 import verify_tcs6_successor as old
 prior=old.evidence();donor=json.loads(prior['physical/INPUTS.json']);check(sha(prior['physical/INPUTS.json'])==p['reuse']['donor_input_sha256'],'unbound AVAIL donor')
 check(p['reuse']['prior_execution']==tcs6_record()['execution_commit']and p['reuse']['compiler']==donor['compiler'],'AVAIL donor/compiler drift')
 artifacts={}
 for opt in(0,2):artifacts.update(json.loads(prior[f'physical/COST_O{opt}.json'])['shared_provider_hashes'])
 check(p['reuse']['compiled_artifacts']==artifacts,'incomplete AVAIL artifact identity')
 check(p['reuse']['drainage_projection']==tcs6_record()['inherited_input_projections']['src/process/mod_drainage_spatial_distribution.f90'],'AVAIL unrelated drainage drift')
 check(p['reuse']['frost_reconciliation']==r['inherited_frost_reconciliation'],'AVAIL frost reconciliation drift')
 for prefix in ['physical/o0/test-','physical/o2/test-']:
  for path,raw in data.items():
   if path.startswith(prefix)and path.endswith(('.full','.checkpoint','.final')):check(prior['physical/fixture/weather.999']in raw,'unauthenticated AVAIL weather source')
 for path,h in donor['inputs'].items():
  if path not in PRODUCTION and path not in['src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90']:check(p['source_inputs'][path]==h,'AVAIL foreign donor input')
 total=0
 for opt in(0,2):
  for n in['root2','root3','root4zero','root7','root8','weekly_dcs1']:
   for ph,arg in [('morning','neutral'),('dayend','hydraulic')]:
    path=f'physical/o{opt}/test-{n}.{ph}.';ends=[data[path+s]for s in['full','opaque','resumed','active.resumed']];check(all(x==ends[0]for x in ends),'AVAIL native owner drift')
    check(ends[0]==data[f'physical/o{2-opt}/test-{n}.{ph}.full'],'AVAIL endpoint optimization drift')
    if n=='weekly_dcs1':check(ends[0]==prior[f'physical/o{opt}/test-{n}.{ph}.full'],'TCS6 native representation changed');continue
    total+=decoder(data,p,opt,n,arg,20)
  for n in['sensor7','sensor8']:
   ends=[data[f'physical/o{opt}/test-{n}.{s}.final']for s in['continuous','restart','native-resume']];check(all(x==ends[0]for x in ends),'AVAIL root-free native drift')
   check(ends[0]==data[f'physical/o{2-opt}/test-{n}.continuous.final'],'AVAIL root-free optimization drift');total+=decoder(data,p,opt,n,'neutral',20)
 check(total==480,'AVAIL decoder matrix missing')
 direct=json.loads(data['direct/RESULTS.json']);check(direct['status']=='PASS'and direct['vectors_per_optimization']==404 and len(direct['rows'])==4,'AVAIL literal unfinished')
 for path,h in direct['inputs'].items():check(sha((ROOT/path).read_bytes())==h,'stale AVAIL direct input')
 check(sha(data['direct/literal.f90'])==direct['generated']['literal.f90'],'AVAIL literal changed');raw_events(data,'direct',direct['events'])
 check({(x['opt'],x['name'])for x in direct['rows']}=={(o,n)for o in(0,2)for n in['literal','nonfinite']},'AVAIL literal optimization coverage')
 for row in direct['rows']:
  events=[e for e in direct['events']if Path(e['command'][0]).name==row['name']and '/o'+str(row['opt'])+'/'in e['command'][0]]
  check(row['returncode']==0 and len(events)==1 and events[0]['stdout_sha256']==row['stdout_sha256'],'AVAIL direct unexecuted row')
 # Recover the exact literal-source program expression without executing its
 # build runner. Only constants, concatenation and the authenticated body exist.
 import ast
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as archive:
  raw=archive.extractfile(next(m for m in archive.getmembers()if m.name.endswith('SWAP/irrigation.f90'))).read()
 check(sha(raw)=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1','AVAIL original authority')
 body='\n'.join(raw.decode().split('      case(4)')[1].split('      case(9)')[0].splitlines()[1:])
 tree=ast.parse((ROOT/'tests/mc-irr01/run_availability_contract.py').read_text())
 expression=next(n.value for n in ast.walk(tree)if isinstance(n,ast.Assign)and any(isinstance(x,ast.Name)and x.id=='code'for x in n.targets))
 def literal(n):
  if isinstance(n,ast.Constant)and isinstance(n.value,str):return n.value
  if isinstance(n,ast.Name)and n.id=='body':return body
  if isinstance(n,ast.BinOp)and isinstance(n.op,ast.Add):return literal(n.left)+literal(n.right)
  raise ValueError('unregistered AVAIL oracle expression')
 check(literal(expression).encode()==data['direct/literal.f90'],'unexecuted AVAIL literal generator')
 oldproof=json.loads(data['review/incumbent.json']);check(oldproof==r['incumbent_result']and sha(data['review/incumbent.json'])==r['incumbent_proof_sha256']and oldproof['qualified']and oldproof['full_capability']and oldproof['current_source_tree']==git('rev-parse',BASE+':src'),'unqualified AVAIL predecessor')
 check(b'TCS6_ADMISSION_NEGATIVES=30|PASS'in data['review/original-tcs6-controls.stdout'],'missing original TCS6 controls')
 check(b'INF_SPLIT_EVIDENCE_CORRUPTION_CONTROLS=8'in data['review/original-inf-controls.stdout'],'missing original INF controls')
 projections=json.loads(data['review/projections.json']);check(set(projections)=={p for p,v in r['postimages'].items()if v['status']=='M'},'AVAIL body review incomplete')
 for path,patches in projections.items():
  lines=(ROOT/path).read_text().splitlines(True)
  for patch in reversed(patches):
   a,b=patch['range'];check(lines[a:b]==patch['current'],'AVAIL reviewed hunk drift');lines[a:b]=patch['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),'AVAIL original body projection')
 return dict(trajectories=124,decoder_negatives=480,literal_vectors_per_optimization=404,continuous_opaque_fresh_native_exact=True,TCS6_native_bytes_preserved=True)
def decoder(data,p,opt,name,phase,count):
 rows=json.loads(data[f'physical/DECODER_{opt}_{name}_{phase}.json']);check(len(rows)==count and len({x['case']for x in rows})==count,'missing/duplicate AVAIL decoder negative')
 for row in rows:
  raw=data[f'physical/o{opt}/'+row['input']];check(sha(raw)==row['input_sha256']and row['returncode']==0,'AVAIL decoder unbound/failed')
  mode='native-reject-config'if row['case']=='different_config'else'native-reject'
  matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+name and '/o'+str(opt)+'/'in e['command'][0]and e['command'][-3:]==[mode,phase,e['command'][-1]]and Path(e['command'][-1]).name==row['input']]
  check(len(matches)==1 and matches[0]['returncode']==0 and matches[0]['stdout_sha256']==row['stdout_sha256'],'AVAIL decoder not executed')
 return len(rows)
def run_original_inf_controls():
 import os
 root=ROOT.parent/('availability-incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'AVAIL original INF moved')
 p=subprocess.run([sys.executable,'-B','tests/fmig431/verify_inf_split_successor.py','--self-test'],cwd=root,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(ROOT.parent/'avail-python-cache')})
 check(p.returncode==0 and 'INF_SPLIT_EVIDENCE_CORRUPTION_CONTROLS=8'in p.stdout,'original INF controls failed '+p.stderr[-1000:])
 print(p.stdout,end='')
def verify_qualification():
 result=verify_source();check(record()['phase']in['SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_FULL_NOT_ADMITTED','CANONICALLY_ADMITTED_FULL'],'unfinished AVAIL admission')
 science=validate_science(evidence());return {**result,'qualified':True,'full_capability':True,'science':science,'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
