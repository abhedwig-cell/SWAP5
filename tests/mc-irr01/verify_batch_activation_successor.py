"""Source/evidence-bound full TCS2/3/4+DCS1 admission under existing MC-IRR01."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='f5504d30391baff52143ac6441ba231264cee5a0'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/process/mod_scheduled_irrigation_management_policy.f90','src/runtime/mod_fmr_irrigation_management_restart.f90',
 'src/runtime/mod_fmr_production_application_bootstrap.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90',
 'src/adapter/mod_swap_daily_weather_file_adapter.f90','src/crop/mod_crop_rotation_calendar.f90',
 'src/runtime/mod_fmr_irrigation_material_root_binding.f90'}
CAPABILITIES=['SW431-IRR-TCS2','SW431-IRR-TCS3','SW431-IRR-TCS4','SW431-IRR-DCS1']
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['batch_experiment_1271_20261017']['resume_20261017']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record();check(r['admission_baseline']==BASE,'batch baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines();check(not[x for x in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',x)],'dirty batch science')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign batch science');check({p for p in rows if p.startswith('src/')}==PRODUCTION,'batch production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'batch postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'batch source tree');check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'batch reference drift')
 check(r['selected_capabilities']==CAPABILITIES,'batch capability drift')
 top=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['batch_experiment_1271_20261017']
 frozen=json.loads(subprocess.check_output(['git','show','90167ddb13575ce4e270ec8d4c61e1d411024800:integration/audits/MC_IRR01_STATUS.json'],cwd=ROOT))['batch_experiment_1271_20261017']['closure_conditions']
 check(top['closure_conditions']==frozen,'batch frozen closure conditions changed')
 old=r['incumbent_result'];check(old['qualified']and old['full_capability']and old['depth_limit_successor'],'batch unqualified incumbent')
 return {**old,'baseline':BASE,'source_tree':r['source_tree'],'current_source_tree':r['source_tree'],'batch_activation_successor':True,'qualified':False,'admitted':False,'full_capability':False}
def evidence():
 r=record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes());check(sha(raw)==r['decoded_sha256']and len(raw)==r['decoded_bytes'],'batch capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  ms=t.getmembers();check(len(ms)==r['members']and len(ms)==len({x.name for x in ms})and all(x.isfile()and not Path(x.name).is_absolute()and '..'not in Path(x.name).parts for x in ms),'unsafe batch capsule')
  data={x.name:t.extractfile(x).read()for x in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(manifest)==set(data),'batch missing capsule members')
 for q,h in manifest.items():check(sha(data[q])==h,'batch capsule member '+q)
 return data
def events(data,prefix,rows):
 for i,e in enumerate(rows):
  check(e['returncode']==0,'failed batch command')
  for stream in ['stdout','stderr']:
   raws=[b for p,b in data.items()if p.startswith(prefix+'/'+f'{i:05d}-')and p.endswith('.'+stream)];check(len(raws)==1,'missing batch raw '+stream)
   if stream+'_sha256'in e:check(sha(raws[0])==e[stream+'_sha256'],'batch raw command hash')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and'-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked batch compile')
def validate_science(data):
 r=record();p=json.loads(data['physical/RESULTS.json']);inp=json.loads(data['physical/INPUTS.json'])
 check(p['status']=='PASS'and p['head']==r['execution_commit']==inp['head'],'unfinished batch physical')
 check(p['inputs']==inp['inputs']and p['generated']==inp['generated'],'batch executed input identity')
 for q,h in p['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'stale batch input '+q)
 check(PRODUCTION<=set(inp['providers'])and len(inp['providers'])==297,'batch provider closure')
 check(len(p['costs'])==2 and all(x['provider_compiles']==297 and x['external_compiles']==10 for x in p['costs']),'batch missing fresh O0/O2')
 names=['season2','season3','season4','schedule_off','weekly_dcs1','avail_root2']
 modes=[('continuous','neutral')]+[(md,ph)for ph in ['neutral','hydraulic']for md in ['native-write','native-resume','native-write-active','native-resume-active']]
 expected={(o,n,md,ph)for o in (0,2)for n in names for md,ph in modes};key=lambda x:(x['opt'],x['driver'],x['mode'],x['phase'])
 check(len(p['rows'])==len(expected)==108 and {key(x)for x in p['rows']}==expected,'batch missing/duplicate trajectories')
 for row in p['rows']:
  check(row['returncode']==0,'failed batch trajectory');matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+row['driver']and'/o'+str(row['opt'])+'/'in e['command'][0]and e['command'][-2:]==[row['mode'],row['phase']]]
  check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'batch trajectory not executed')
  other=next(x for x in p['rows']if key(x)==(2-row['opt'],*key(row)[1:]));check(other['stdout_sha256']==row['stdout_sha256'],'batch optimization drift')
 events(data,'physical',p['events'])
 for q,h in inp['fixture'].items():check(sha(data['physical/fixture/'+q])==h,'batch fixture drift')
 for q,h in p['generated'].items():check(sha(data['physical/'+q])==h,'batch generated drift')
 authority=inp['fixture_authority'];raw=base64.b64decode((ROOT/authority['path']).read_bytes());check(sha(raw)==authority['decoded_sha256'],'batch fixture authority drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for q in inp['fixture']:check(data['physical/fixture/'+q]==t.extractfile('physical/fixture/'+q).read(),'batch unauthenticated fixture')
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from batch_activation_cycle_driver import rooted,CASES
 from availability_cycle_driver import rooted as oldroot
 from tcs6_cycle_driver import prepare_native
 with tempfile.TemporaryDirectory()as tmp:
  for n,c,d,rate,kind in CASES:
   f=rooted(ROOT,Path(tmp)/(n+'.f90'),c,d,rate,kind);check(f.read_bytes()==data['physical/'+f.name],'batch unexecuted generator')
  for n,f in [('weekly_dcs1',prepare_native(ROOT,Path(tmp)/'weekly_dcs1.f90',1,True)),('avail_root2',oldroot(ROOT,Path(tmp)/'avail_root2.f90',2,1,.08))]:check(f.read_bytes()==data['physical/'+f.name],'batch incumbent generator drift')
 legacy=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['limit_completion_20261016']['science_archive'];raw=base64.b64decode((ROOT/legacy['path']).read_bytes());check(sha(raw)==legacy['decoded_sha256'],'batch legacy evidence drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for opt in (0,2):
   for n in names:
    for ph in ['morning','dayend']:
     pref=f'physical/o{opt}/test-{n}.{ph}.';ends=[data[pref+q]for q in ['full','opaque','resumed','active.resumed']]
     check(all(b==ends[0]for b in ends),'batch native endpoint drift');check(ends[0]==data[f'physical/o{2-opt}/test-{n}.{ph}.full'],'batch native optimization drift')
     if n in ['weekly_dcs1','avail_root2']:check(ends[0]==t.extractfile(pref+'full').read(),'batch changed incumbent native bytes')
 count=0
 for opt in (0,2):
  for n in ['season2','season3','season4']:
   for ph in ['neutral','hydraulic']:
    rows=json.loads(data[f'physical/DECODER_{opt}_{n}_{ph}.json']);check(len(rows)==22 and len({x['case']for x in rows})==22,'batch decoder coverage')
    check({'different_config','different_calendar','different_schedule','week7'}<=set(x['case']for x in rows),'batch missing configuration controls')
    for row in rows:
     raw=data[f'physical/o{opt}/'+row['input']];check(sha(raw)==row['input_sha256']and row['returncode']==0,'batch unbound decoder')
     mode={'different_config':'native-reject-config','different_calendar':'native-reject-calendar','different_schedule':'native-reject-schedule'}.get(row['case'],'native-reject')
     matches=[e for e in p['events']if Path(e['command'][0]).name=='test-'+n and'/o'+str(opt)+'/'in e['command'][0]and e['command'][-3:-1]==[mode,ph]and Path(e['command'][-1]).name==row['input']]
     check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'batch decoder unexecuted')
    count+=len(rows)
 check(count==264,'batch decoder count')
 for prefix,marker in [('root',b'BATCH_ROOT_LITERAL_AFGEN_TCS234_DCS1_FULL_DOMAIN=PASS'),('calendar',b'BATCH_ACTIVATION_EXISTING_CALENDAR_SOURCE_LEAP_INVALID=PASS'),('material',b'MC_IRR01_MATERIAL_ROOT_LITERAL_NONMUTATION_INVALID_ABA=PASS'),('interval',b'BATCH_FIXED_INTERVAL_LITERAL_RESTART_NONMUTATION=PASS')]:
  d=json.loads(data[prefix+'/RESULTS.json']);rows=d.get('rows',d.get('results'));check(d['status']=='PASS'and len(rows)==2 and {x['opt']for x in rows}=={0,2},'batch incomplete '+prefix)
  for q,h in d['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'batch stale '+prefix+' '+q)
  events(data,prefix,d['events']);raws=[b for q,b in data.items()if q.startswith(prefix+'/')and q.endswith('.stdout')];check(sum(marker in b for b in raws)==2,'batch missing assertions '+prefix)
  check(rows[0]['stdout_sha256']==rows[1]['stdout_sha256'],'batch direct optimization '+prefix)
  for q,h in d.get('generated',{}).items():check(sha(data[prefix+'/'+q])==h,'batch generated direct '+q)
 from run_batch_root_envelope import literal
 check(literal().encode()==data['root/literal.f90'],'batch literal source generator drift')
 from run_batch_activation_contract import literal as window_literal
 check(window_literal().encode()==data['calendar/literal.f90'],'batch window source generator drift')
 check(any(b'BATCH_ROOT_ENVELOPE_CASES=2079|FAILURES=0'in b for q,b in data.items()if q.startswith('root/')and q.endswith('.stdout')),'batch root source envelope count')
 check(any(b'MATERIAL_ROOT_LITERAL_CASES=360'in b for q,b in data.items()if q.startswith('material/')and q.endswith('.stdout')),'batch material endpoint domain')
 d=json.loads(data['limit/RESULTS.json']);check(d['status']=='PASS'and len(d['rows'])==2,'batch LIMIT preservation');events(data,'limit',d['events'])
 for q,h in d['inputs'].items():check(sha((ROOT/q).read_bytes())==h,'batch stale LIMIT '+q)
 small=json.loads(data['small/RESULTS.json']);check(small['returncode']==0 and small['native_invocations']==8,'batch small preservation failed')
 check(b'MC_IRR01_MANAGEMENT_POLICY_QUALIFICATION=PASS'in data['small/stdout.txt'],'batch original small assertions absent')
 proof=json.loads(data['review/incumbent-proof.json']);check(proof==r['incumbent_result']and sha(data['review/incumbent-proof.json'])==r['incumbent_proof_sha256'],'batch incumbent proof drift')
 check(proof['qualified']and proof['full_capability']and proof['current_source_tree']==git('rev-parse',BASE+':src'),'batch unqualified old source')
 check(b'LIMIT_ADMISSION_NEGATIVES=29|PASS'in data['review/incumbent-controls.stdout'],'batch original control assertions absent')
 projections=json.loads(data['review/projections.json']);check(set(projections)=={q for q,v in r['postimages'].items()if v['status']=='M'},'batch body review incomplete')
 for q,patches in projections.items():
  lines=(ROOT/q).read_text().splitlines(True)
  for patch in reversed(patches):
   lo,hi=patch['range'];check(lines[lo:hi]==patch['current'],'batch reviewed hunk drift '+q);lines[lo:hi]=patch['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+q],cwd=ROOT),'batch original body projection '+q)
 return dict(trajectories=108,decoder_negatives=264,root_source_vectors_per_optimization=2079,activation_boundaries_per_optimization=72,material_root_cases_per_optimization=360,continuous_opaque_fresh_native_exact=True,incumbent_native_bytes_preserved=True)
def verify_qualification():
 result=verify_source();check(record()['phase']in ['SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_FULL_NOT_ADMITTED','CANONICALLY_ADMITTED_FULL'],'unfinished batch admission')
 science=validate_science(evidence());return {**result,'qualified':True,'full_capability':True,'batch_capabilities':CAPABILITIES,'science':science,'full_fci':'NOT_SELECTED_IMPACT','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
