"""Accepted matrix SALTEXCESS, bound to the existing fifteen-row incumbent."""
from pathlib import Path
import base64,gzip,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='0747fd7c8a5e754d73fa5d981e8f5437ee4c12f3'
FROZEN='4f10ece70116a9e172cb2725ced1630fd4c7586c'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/runtime/mod_fmr_irrigation_allocation_binding.f90','src/process/mod_irrigation_process.f90','src/runtime/mod_fmr_production_application_bootstrap.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90'}
CAPABILITIES=['SW431-IRR-SALTEXCESS']
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['salt_completion_1271_20261017']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record();check(r['baseline']==BASE,'salt baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines();check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty salt science')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign salt science');check({p for p in rows if p.startswith('src/')}==PRODUCTION,'salt production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'salt postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'salt source tree');check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'salt reference drift')
 check(r['capabilities']==CAPABILITIES,'salt capability drift')
 for path in r['inherited_archives']:
  check(g('rev-parse','HEAD:'+path)==g('rev-parse',BASE+':'+path)==blob((ROOT/path).read_bytes()),'salt inherited archive drift '+path)
 old=json.loads(subprocess.check_output(['git','show',BASE+':integration/audits/MC_IRR01_STATUS.json'],cwd=ROOT))
 now=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())
 for field in ['batch_experiment_1271_20261017','sensor_batch_1271_20261017']:
  check(now[field]==old[field],'salt changed admitted contract '+field)
 frozen=json.loads(subprocess.check_output(['git','show',FROZEN+':integration/audits/MC_IRR01_STATUS.json'],cwd=ROOT))['salt_completion_1271_20261017']
 for key in ['scientific_contract','interfaces_allowed','held_fixed','test_selection']:
  check(r[key]==frozen[key],'salt frozen contract changed '+key)
 proof=r['incumbent_result'];check(proof['qualified']and proof['full_capability']and proof['sensor_batch_successor'],'salt unqualified incumbent')
 return {**proof,'baseline':BASE,'source_tree':r['source_tree'],'current_source_tree':r['source_tree'],'salt_completion_successor':True,'scope':r['scientific_contract'],'qualified':False,'admitted':False,'full_capability':False}
def evidence():
 r=record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes());check(sha(raw)==r['decoded_sha256']and len(raw)==r['decoded_bytes'],'salt capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==r['members']and len(ms)==len({x.name for x in ms})and all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in ms),'unsafe salt capsule')
  data={x.name:t.extractfile(x).read()for x in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'salt missing capsule members')
 for q,h in manifest.items():check(sha(data[q])==h,'salt capsule member '+q)
 return data
def events(data,prefix,rows):
 for i,e in enumerate(rows):
  check(e['returncode']==0,'failed salt command')
  for stream in ['stdout','stderr']:
   raws=[b for p,b in data.items()if p.startswith(prefix+'/'+f'{i:05d}-')and p.endswith('.'+stream)];check(len(raws)==1,'missing salt raw '+stream)
   if stream+'_sha256'in e:check(sha(raws[0])==e[stream+'_sha256'],'salt raw command hash')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and'-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked salt compile')
def validate_science(data):
 r=record();p=json.loads(data['physical/RESULTS.json']);inp=json.loads(data['physical/INPUTS.json'])
 check(p['status']=='PASS'and p['head']==r['execution_commit']==inp['head'],'unfinished salt physical')
 check(p['inputs']==inp['inputs']and p['generated']==inp['generated'],'salt executed input identity')
 for q,h in p['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'stale salt input '+q)
 check(PRODUCTION<=set(inp['providers'])and len(inp['providers'])==297,'salt provider closure')
 check(len(p['costs'])==2 and all(x['provider_compiles']==297 and x['external_compiles']==10 for x in p['costs']),'salt missing fresh O0/O2')
 names=['salt_root','salt_sensor','season3','weekly_dcs1','avail_root2']
 modes=[('continuous','neutral')]+[(md,ph)for ph in ['neutral','hydraulic']for md in ['native-write','native-resume','native-write-active','native-resume-active']]
 expected={(o,n,md,ph)for o in (0,2)for n in names for md,ph in modes};key=lambda x:(x['opt'],x['driver'],x['mode'],x['phase'])
 check(len(p['rows'])==len(expected)==90 and {key(x)for x in p['rows']}==expected,'salt missing/duplicate trajectories')
 for row in p['rows']:
  check(row['returncode']==0,'failed salt trajectory');matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+row['driver']and'/o'+str(row['opt'])+'/'in e['command'][0]and e['command'][-2:]==[row['mode'],row['phase']]]
  check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'salt trajectory not executed')
  other=next(x for x in p['rows']if key(x)==(2-row['opt'],*key(row)[1:]));check(other['stdout_sha256']==row['stdout_sha256'],'salt optimization drift')
 events(data,'physical',p['events'])
 for q,h in inp['fixture'].items():check(sha(data['physical/fixture/'+q])==h,'salt fixture drift')
 for q,h in p['generated'].items():check(sha(data['physical/'+q])==h,'salt generated drift')
 authority=inp['fixture_authority'];raw=base64.b64decode((ROOT/authority['path']).read_bytes());check(sha(raw)==authority['decoded_sha256'],'salt fixture authority drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for q in inp['fixture']:check(data['physical/fixture/'+q]==t.extractfile('physical/fixture/'+q).read(),'salt unauthenticated fixture')
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from salt_completion_cycle_driver import salt_cycle,CASES
 from batch_activation_cycle_driver import rooted as root_preservation
 from availability_cycle_driver import rooted as oldroot
 from tcs6_cycle_driver import prepare_native
 with tempfile.TemporaryDirectory()as tmp:
  for n,c,d,kind in CASES:
   f=salt_cycle(ROOT,Path(tmp)/(n+'.f90'),c,d,kind);check(f.read_bytes()==data['physical/'+f.name],'salt unexecuted generator')
  for n,f in [('season3',root_preservation(ROOT,Path(tmp)/'season3.f90',3,1,0.,'annual')),('weekly_dcs1',prepare_native(ROOT,Path(tmp)/'weekly_dcs1.f90',1,True)),('avail_root2',oldroot(ROOT,Path(tmp)/'avail_root2.f90',2,1,.08))]:check(f.read_bytes()==data['physical/'+f.name],'salt incumbent generator drift')
 legacy=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['sensor_batch_1271_20261017']['science_archive'];raw=base64.b64decode((ROOT/legacy['path']).read_bytes());check(sha(raw)==legacy['decoded_sha256'],'salt legacy evidence drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for opt in (0,2):
   for n in names:
    for ph in ['morning','dayend']:
     pref=f'physical/o{opt}/test-{n}.{ph}.';ends=[data[pref+q]for q in ['full','opaque','resumed','active.resumed']]
     check(all(b==ends[0]for b in ends),'salt native endpoint drift');check(ends[0]==data[f'physical/o{2-opt}/test-{n}.{ph}.full'],'salt native optimization drift')
     if n in ['season3','weekly_dcs1','avail_root2']:check(ends[0]==t.extractfile(pref+'full').read(),'salt changed incumbent native bytes')
 count=0
 for opt in (0,2):
  for n in ['salt_root','salt_sensor']:
   for ph in ['neutral','hydraulic']:
    rows=json.loads(data[f'physical/DECODER_{opt}_{n}_{ph}.json']);check(len(rows)==31 and len({x['case']for x in rows})==31,'salt decoder coverage')
    check({'negative_salt','nan_salt','inf_salt','salt_source','salt_revision','salt-policy','salt-boundary','salt-threshold','salt-tscf'}<=set(x['case']for x in rows),'salt missing discriminating controls')
    for row in rows:
     raw=data[f'physical/o{opt}/'+row['input']];check(sha(raw)==row['input_sha256']and row['returncode']==0,'salt unbound decoder')
     mode={'different_config':'native-reject-config','different_calendar':'native-reject-calendar','different_schedule':'native-reject-schedule'}.get(row['case'],'native-reject-'+row['case']if row['case'].startswith('salt-')else'native-reject')
     matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+n and'/o'+str(opt)+'/'in e['command'][0]and e['command'][-3:-1]==[mode,ph]and Path(e['command'][-1]).name==row['input']]
     check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'salt decoder unexecuted')
    count+=len(rows)
 check(count==248,'salt decoder count')
 d=json.loads(data['direct/RESULTS.json']);check(d['status']=='PASS'and len(d['rows'])==2 and {x['opt']for x in d['rows']}=={0,2},'salt direct incomplete');events(data,'direct',d['events'])
 for q,h in d['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'salt stale direct '+q)
 from run_salt_completion_contract import literal
 check(literal().encode()==data['direct/literal.f90'],'salt literal generator drift')
 check(d['rows'][0]['stdout_sha256']==d['rows'][1]['stdout_sha256'],'salt direct optimization drift')
 check(sum(b'SALT_COMPLETION_LITERAL360_INVALID6=PASS'in b for q,b in data.items()if q.startswith('direct/')and q.endswith('.stdout'))==2,'salt missing direct assertions')
 rollback=json.loads(data['rollback/RESULTS.json']);ri=json.loads(data['rollback/INPUTS.json'])
 check(rollback['status']=='PASS'and len(rollback['rows'])==4,'salt real prefix rollback incomplete')
 check({(x['opt'],x['mode'])for x in rollback['rows']}=={(o,m)for o in (0,2)for m in ['continuous','restart']},'salt rollback mode coverage')
 check(rollback['inputs']==ri['inputs']and rollback['generated']==ri['generated'],'salt rollback input identity')
 for q,h in rollback['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'salt stale rollback '+q)
 check(all(rollback['inputs'].get(q)==p['inputs'][q]for q in inp['providers']),'salt rollback provider drift')
 events(data,'rollback',rollback['events'])
 from salt_rollback_cycle_driver import rollback as rollback_generator
 with tempfile.TemporaryDirectory()as tmp:
  f=rollback_generator(ROOT,Path(tmp)/'salt_rollback.f90');check(f.read_bytes()==data['rollback/salt_rollback.f90'],'salt rollback generator drift')
 check(sum(b'SALT_REAL_INCOMPLETE_PREFIX_MASS_EVENT_RETRY_OPAQUE=PASS'in b for q,b in data.items()if q.startswith('rollback/')and q.endswith('.stdout'))==4,'salt real incomplete-prefix assertions absent')
 for x in rollback['rows']:
  match=[e for e in rollback['events']if Path(e['command'][0]).name=='test-salt_rollback'and'/o'+str(x['opt'])+'/'in e['command'][0]and e['command'][-2:]==[x['mode'],x['phase']]]
  check(len(match)==1 and match[0]['stdout_sha256']==x['stdout_sha256'],'salt rollback command missing')
  other=next(z for z in rollback['rows']if z['opt']==2-x['opt']and z['mode']==x['mode']);check(other['stdout_sha256']==x['stdout_sha256'],'salt rollback optimization drift')
 proof=json.loads(data['review/incumbent-proof.json']);check(proof==r['incumbent_result']and sha(data['review/incumbent-proof.json'])==r['incumbent_proof_sha256'],'salt incumbent proof drift')
 check(proof['qualified']and proof['full_capability']and proof['current_source_tree']==git('rev-parse',BASE+':src'),'salt unqualified old source')
 projections=json.loads(data['review/projections.json']);check(set(projections)=={q for q,v in r['postimages'].items()if v['status']=='M'},'salt body review incomplete')
 for q,patches in projections.items():
  lines=(ROOT/q).read_text().splitlines(True)
  for patch in reversed(patches):
   lo,hi=patch['range'];check(lines[lo:hi]==patch['current'],'salt reviewed hunk drift '+q);lines[lo:hi]=patch['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+q],cwd=ROOT),'salt original body projection '+q)
 return dict(trajectories=90,decoder_negatives=248,literal_source_cases_per_optimization=360,continuous_opaque_fresh_native_exact=True,incumbent_native_bytes_preserved=True)
def verify_qualification():
 result=verify_source();check(record()['phase']in ['SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_FULL_NOT_ADMITTED','CANONICALLY_ADMITTED_FULL'],'unfinished salt admission')
 science=validate_science(evidence());return {**result,'qualified':True,'full_capability':True,'salt_capabilities':CAPABILITIES,'science':science,'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
