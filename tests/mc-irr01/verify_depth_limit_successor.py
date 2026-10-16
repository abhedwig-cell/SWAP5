"""Existing LIMIT full admission: source-pinned production, raw science and retained owners."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='63658aa0835f13c64c2bc2562f0d0f820c77e97d'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/process/mod_irrigation_process.f90','src/process/mod_scheduled_irrigation_management_policy.f90','src/runtime/mod_fmr_scheduled_management_irrigation_application.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['limit_completion_20261016']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record();check(r['admission_baseline']==BASE,'LIMIT baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines();check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty LIMIT science')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign LIMIT science');check({p for p in rows if p.startswith('src/')}==PRODUCTION,'LIMIT production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'LIMIT postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'LIMIT source tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'LIMIT reference drift')
 old=r['incumbent_result'];check(old['qualified']and old['full_capability']and old['availability_successor'],'LIMIT unqualified predecessor')
 return {**old,'baseline':BASE,'current_source_tree':r['source_tree'],'source_tree':r['source_tree'],'depth_limit_successor':True,'scope':r['closure_target'],'qualified':False,'admitted':False,'full_capability':False}
def evidence():
 r=record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes());check(sha(raw)==r['decoded_sha256']and len(raw)==r['decoded_bytes'],'LIMIT capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==r['members']and len(ms)==len({x.name for x in ms})and all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in ms),'unsafe LIMIT capsule')
  data={x.name:t.extractfile(x).read()for x in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'LIMIT capsule members')
 for p,h in manifest.items():check(sha(data[p])==h,'LIMIT capsule member '+p)
 return data
def events(data,prefix,rows):
 for i,e in enumerate(rows):
  check(e['returncode']==0,'failed LIMIT command')
  for stream in ['stdout','stderr']:
   raw=[b for p,b in data.items()if p.startswith(prefix+'/'+f'{i:05d}-')and p.endswith('.'+stream)];check(len(raw)==1,'missing LIMIT raw command')
   if stream+'_sha256'in e:check(sha(raw[0])==e[stream+'_sha256'],'LIMIT raw hash')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked LIMIT compile')
def validate_science(data):
 r=record();p=json.loads(data['physical/RESULTS.json']);inp=json.loads(data['physical/INPUTS.json'])
 check(p['status']=='PASS'and p['head']==r['execution_commit']==inp['head'],'unfinished LIMIT application')
 for q,h in p['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'stale LIMIT input '+q)
 check(p['inputs']==inp['inputs']and PRODUCTION<=set(inp['providers'])and len(inp['providers'])==296,'LIMIT missing tested owners')
 check(p['generated']==inp['generated'],'LIMIT generated identity')
 check(len(p['costs'])==2 and all(x['provider_compiles']==296 and x['external_compiles']==10 for x in p['costs']),'LIMIT incomplete fresh build')
 names=['root2_lower','root3_zero_input','root4_upper','root7_inactive','root8_equal','root8_zero_max','weekly_dcs1','avail_root2']
 expected={(o,n,md,ph)for o in(0,2)for n in names for md,ph in [('continuous','neutral')]+[(md,ph)for ph in ['neutral','hydraulic']for md in ['native-write','native-resume','native-write-active','native-resume-active']]}
 expected|={(o,n,md,'neutral')for o in(0,2)for n in ['sensor7','sensor8']for md in ['continuous','restart','native-write','native-resume']}
 key=lambda x:(x['opt'],x['driver'],x['mode'],x['phase'])
 check(len(p['rows'])==len(expected)==160 and {key(x)for x in p['rows']}==expected,'LIMIT missing/duplicate trajectory')
 for row in p['rows']:
  check(row['returncode']==0,'failed LIMIT trajectory')
  matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+row['driver']and '/o'+str(row['opt'])+'/'in e['command'][0]and e['command'][-2:]==[row['mode'],row['phase']]]
  check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'LIMIT unexecuted trajectory')
  check(next(x for x in p['rows']if key(x)==(2-row['opt'],*key(row)[1:]))['stdout_sha256']==row['stdout_sha256'],'LIMIT optimization drift')
 events(data,'physical',p['events'])
 for q,h in inp['fixture'].items():check(sha(data['physical/fixture/'+q])==h,'LIMIT fixture drift')
 # The complete authenticated TCS6 capsule and all current immutable evidence
 # stay unchanged. It supplies fixture/oracles only; all295 production providers
 # and every selected scientific program were compiled/executed fresh here.
 oldraw=base64.b64decode((ROOT/inp['fixture_authority']['path']).read_bytes());check(sha(oldraw)==inp['fixture_authority']['decoded_sha256'],'LIMIT fixture authority')
 with tarfile.open(fileobj=io.BytesIO(oldraw))as t:
  for q in inp['fixture']:check(t.extractfile('physical/fixture/'+q).read()==data['physical/fixture/'+q],'LIMIT unauthenticated fixture')
 for q,h in p['generated'].items():check(sha(data['physical/'+q])==h,'LIMIT generated source drift')
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from depth_limit_cycle_driver import rooted,CASES
 from availability_cycle_driver import rooted as oldroot,sensor
 from tcs6_cycle_driver import prepare_native
 with tempfile.TemporaryDirectory()as tmp:
  for n,c,d,rate,kind in CASES:
   f=rooted(ROOT,Path(tmp)/(n+'.f90'),c,d,rate,kind);check(f.read_bytes()==data['physical/'+f.name],'LIMIT unexecuted root generator')
  for n,c,ns,day in [('sensor7',7,1,20),('sensor8',8,3,21)]:
   f=sensor(ROOT,Path(tmp)/(n+'.f90'),c,ns,day);check(f.read_bytes()==data['physical/'+f.name],'LIMIT unexecuted sensor generator')
  for n,f in [('weekly_dcs1',prepare_native(ROOT,Path(tmp)/'weekly_dcs1.f90',1,True)),('avail_root2',oldroot(ROOT,Path(tmp)/'avail_root2.f90',2,1,.08))]:check(f.read_bytes()==data['physical/'+f.name],'LIMIT preservation generator')
 # Existing AVAIL capsule is immutable canonical evidence. Compare original
 # representative complete native endpoints, rather than claiming new PASS from imports.
 ar=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['availability_completion_20261016']['science_archive']
 araw=base64.b64decode((ROOT/ar['path']).read_bytes());check(sha(araw)==ar['decoded_sha256'],'LIMIT incumbent capsule')
 with tarfile.open(fileobj=io.BytesIO(araw))as t:
  for opt in(0,2):
   for n in names:
    for ph in ['morning','dayend']:
     pref=f'physical/o{opt}/test-{n}.{ph}.';ends=[data[pref+suffix]for suffix in ['full','opaque','resumed','active.resumed']]
     check(all(x==ends[0]for x in ends),'LIMIT joint owner endpoint drift');check(ends[0]==data[f'physical/o{2-opt}/test-{n}.{ph}.full'],'LIMIT endpoint optimization drift')
     if n in('weekly_dcs1','avail_root2'):
      oldn='root2'if n=='avail_root2'else n
      check(ends[0]==t.extractfile(f'physical/o{opt}/test-{oldn}.{ph}.full').read(),'LIMIT changed incumbent native bytes')
   for n in ['sensor7','sensor8']:
    ends=[data[f'physical/o{opt}/test-{n}.{suffix}.final']for suffix in ['continuous','restart','native-resume']]
    check(all(x==ends[0]for x in ends),'LIMIT root-free joint drift');check(ends[0]==data[f'physical/o{2-opt}/test-{n}.continuous.final'],'LIMIT root-free optimization drift')
    check(ends[0]==t.extractfile(f'physical/o{opt}/test-{n}.continuous.final').read(),'LIMIT changed original sensor bytes')
 total=0
 for opt in(0,2):
  for n in ['root2_lower','root3_zero_input','root4_upper','root7_inactive','root8_equal','avail_root2','sensor7','sensor8']:
   for ph in(['neutral']if n.startswith('sensor')else['neutral','hydraulic']):
    rows=json.loads(data[f'physical/DECODER_{opt}_{n}_{ph}.json']);check(len(rows)==20 and len({x['case']for x in rows})==20,'LIMIT incomplete decoder negatives')
    for row in rows:
     raw=data[f'physical/o{opt}/'+row['input']];check(sha(raw)==row['input_sha256']and row['returncode']==0,'LIMIT unbound decoder')
     mode='native-reject-config'if row['case']=='different_config'else'native-reject'
     matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+n and '/o'+str(opt)+'/'in e['command'][0]and e['command'][-3:-1]==[mode,ph]and Path(e['command'][-1]).name==row['input']]
     check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'LIMIT decoder not executed')
    total+=len(rows)
 check(total==560,'LIMIT decoder count')
 direct=json.loads(data['direct/RESULTS.json']);check(direct['status']=='PASS'and {x['opt']for x in direct['rows']}=={0,2},'LIMIT incomplete direct')
 for q,h in direct['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'LIMIT stale direct input')
 events(data,'direct',direct['events']);from run_depth_limit_contract import program
 check(program().encode()==data['direct/literal.f90']and sha(data['direct/literal.f90'])==direct['generated']['literal.f90'],'LIMIT literal/source generator drift')
 for x in direct['rows']:
  check(x['returncode']==0,'LIMIT direct failed');matches=[e for e in direct['events']if Path(e['command'][0]).name=='literal'and'/o'+str(x['opt'])+'/'in e['command'][0]]
  check(len(matches)==1 and x['stdout_sha256']==matches[0]['stdout_sha256'],'LIMIT direct unexecuted')
  raw=[b for q,b in data.items()if q.startswith('direct/')and q.endswith('.stdout')and sha(b)==x['stdout_sha256']]
  check(raw and all(b'LIMIT_SOURCE_VECTORS=934|FAILURES=0'in b for b in raw),'LIMIT direct case count')
 check(direct['rows'][0]['stdout_sha256']==direct['rows'][1]['stdout_sha256'],'LIMIT direct optimization drift')
 small=json.loads(data['small/RESULTS.json']);check(small['status']=='PASS'and len(small['events'])==2,'LIMIT small preservation incomplete')
 for q,h in small['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'LIMIT small preservation stale '+q)
 events(data,'small',small['events'])
 raw=b'\n'.join(b for q,b in data.items()if q.startswith('small/')and q.endswith('.stdout'))
 check(b'MC_IRR01_MANAGEMENT_POLICY_QUALIFICATION=PASS'in raw and b'MC_IRR01_LITERAL_MANAGEMENT_48_CASES=PASS'in raw,'LIMIT original assertions missing')
 oldproof=json.loads(data['review/incumbent.json']);check(oldproof==r['incumbent_result']and sha(data['review/incumbent.json'])==r['incumbent_proof_sha256']and oldproof['qualified']and oldproof['full_capability']and oldproof['current_source_tree']==git('rev-parse',BASE+':src'),'LIMIT unqualified predecessor proof')
 check(b'AVAIL_ADMISSION_NEGATIVES=27|PASS'in data['review/incumbent-controls.stdout'],'LIMIT missing original controls')
 check(b'DRAMET3_EVIDENCE_CORRUPTION_CONTROLS=8'in data['review/dramet3-controls.stdout']and b'MC_DRAIN01_DRAMET3_SOURCE_EVIDENCE=PASS'in data['review/dramet3-controls.stdout'],'LIMIT missing native drainage preservation controls')
 check(oldproof['dramet3_successor'],'LIMIT missing native drainage owner')
 check(b'DISLAYER_EVIDENCE_CORRUPTION_CONTROLS=8'in data['review/dislayer-controls.stdout']and b'DISLAYER_REFERENCE_NEGATIVE_CONTROLS=3'in data['review/dislayer-controls.stdout'],'LIMIT missing admitted drainage controls')
 projections=json.loads(data['review/projections.json']);check(set(projections)=={q for q,v in r['postimages'].items()if v['status']=='M'},'LIMIT original body review incomplete')
 for q,patches in projections.items():
  lines=(ROOT/q).read_text().splitlines(True)
  for patch in reversed(patches):
   lo,hi=patch['range'];check(lines[lo:hi]==patch['current'],'LIMIT reviewed hunk drift');lines[lo:hi]=patch['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+q],cwd=ROOT),'LIMIT original body projection')
 return dict(trajectories=160,decoder_negatives=560,literal_vectors_per_optimization=934,continuous_opaque_fresh_native_exact=True,TCS6_AVAIL_native_bytes_preserved=True)
def verify_qualification():
 result=verify_source();check(record()['phase']in ['SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_FULL_NOT_ADMITTED','CANONICALLY_ADMITTED_FULL'],'unfinished LIMIT admission')
 science=validate_science(evidence());return {**result,'qualified':True,'full_capability':True,'science':science,'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
