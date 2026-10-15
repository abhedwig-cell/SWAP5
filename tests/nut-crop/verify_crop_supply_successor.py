#!/usr/bin/env python3
"""Exact bounded crop/soil delta and complete original native evidence."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2];BASE='26ddf94e58133acd413c2b2738b873a92f43f1da'
PEER='f8eca95ba623dc18db0110cd1b84af46857c8b9b'
QUALIFIED_SOURCE='2b6cd5bf30e1951b45ee1e9952c18aa1aee5285a'
STATUS='integration/audits/MC_NUT01_CROP_SUPPLY_STATUS.json'
CHANGED=['tests/crop-co2/verify_co2_successor.py','tests/nut-sol/verify_age_successor.py','src/process/mod_b111_soil_n_reactive_owner.f90','tests/nut-reactive/verify_reactive_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def verify_source():
 s=json.loads((ROOT/STATUS).read_text());git('merge-base','--is-ancestor',PEER,'HEAD')
 check(s['baseline']==BASE,'unknown baseline')
 check(not git('status','--porcelain','--','src','tests','tools','reference'),'dirty dependency surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in git('diff','--name-status',PEER,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected,'foreign crop supply delta');check(set(s['changed_blobs'])==set(CHANGED),'changed seam coverage')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(git('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference'),'immutable reference mutation')
 return dict(baseline=BASE,source_tree=QUALIFIED_SOURCE,current_source_tree=git('rev-parse','HEAD:src'),canonical_peer=PEER,crop_supply_successor=True,qualified=False,admitted=False)
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());raw=base64.b64decode((ROOT/s['evidence']['path']).read_bytes())
 check(hashlib.sha256(raw).hexdigest()==s['evidence']['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  members=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe archive')
  check(len({m.name for m in members})==len(members),'duplicate members')
  data={m.name:a.extractfile(m).read()for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'manifest coverage')
 for p,h in manifest.items():check(hashlib.sha256(data[p]).hexdigest()==h,'raw member drift '+p)
 return data

def verify_qualification():
 source=verify_source()
 sys.path.insert(0,str(ROOT/'tests/nut-sol'))
 import verify_age_successor as age
 age.validate_evidence(age.read_evidence()) # exact unchanged independent peer physics
 data=read_evidence();r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED'and r['direct_only']is False,'unfinished physical qualification')
 check(r['source_tree']==source['source_tree'],'stale source tree')
 check(r['authority']['management_soil.f90']=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b','unbound literal uptake source')
 for p,h in r['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'physical input drift '+p)
 s=json.loads((ROOT/STATUS).read_text());production={p for p in [*s['added_blobs'],*s['changed_blobs']]if p.startswith('src/')}
 check(production<=r['input_sha256'].keys(),'untested production')
 reuse=r['controlled_reuse'];check(reuse['prior_execution']=='de55c442988715dae5ee8d87c4c86c8e49810fa6','unknown reused execution')
 check(reuse['unchanged_native_results_reused']is False,'native results reused')
 for p,h in reuse['artifacts_before'].items():
  if p.endswith('.mod'):check(reuse['artifacts_after'][p]==h,'reused module interface drift '+p)
 check(len(reuse['reused_inputs'])>=250,'incomplete provider audit')
 for p,h in reuse['reused_inputs'].items():
  matches=[q for q in r['input_sha256']if p.endswith('/'+q)]
  if matches:check(r['input_sha256'][matches[0]]==h,'changed reused provider')
  else:check(hashlib.sha256(data['O0/'+Path(p).name]).hexdigest()==h,'changed generated provider')
 old_events=json.loads(data['retained/physical-first/events.json']);prior=[e for e in old_events if e['category']=='compile']
 check(len(prior)>=250 and all(e['returncode']==0 for e in prior),'missing original provider build')
 for e in prior:check('-O0'in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked reused provider')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(250<=row['production_providers']<=280,'physical production closure')
  check(set(row['drivers'])=={'test_crop_soil_day','test_crop_soil_joint','test_reactive_joint','test_mineral_joint'},'driver coverage')
  check('CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS'in row['drivers']['test_crop_soil_day']['stdout'],'real WOFOST81 direct test absent')
  direct_events=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name=='test_crop_soil_day']
  check(len(direct_events)==1 and data[direct_events[0]['stdout_file']].decode()==row['drivers']['test_crop_soil_day']['stdout'],'primary direct native missing')
  for d,marker,count in [('test_crop_soil_joint','CROP_SOIL_ACTUAL_RICHARDS_WOFOST81_LITERAL_ROLLBACK_OPAQUE_DISK=PASS',18),('test_reactive_joint','REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS',10),('test_mineral_joint','MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS',10)]:
   entry=row['drivers'][d];check(marker in entry['stdout'],'actual physical driver absent '+d)
   check(len(set(entry['decoder_negatives']))==count,'incomplete decoder controls '+d)
   for suffix in ['-expected.bin','-fresh.bin','-expected.bin.opaque']:check(hashlib.sha256(data[opt+'/'+d+suffix]).hexdigest()==entry['endpoint_sha256'],'restart continuation drift '+d)
   check(entry['endpoint_sha256']==r['runs']['O0']['drivers'][d]['endpoint_sha256'],'O0 O2 endpoint mismatch '+d)
   if d!='test_crop_soil_joint':
    check(entry['admitted_endpoint_identity']is True,'incumbent not preserved')
    cap='MC_NUT01_REACTIVE_DAY_20261015.tar.xz.b64'if d=='test_reactive_joint'else'MC_NUT01_MINERAL_TRANSPORT_20261015.tar.xz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence'/cap).read_bytes())))as a:
     check(data[opt+'/'+d+'-expected.bin']==a.extractfile(opt+'/expected.bin').read(),'prior admitted endpoint differs')
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==d]
   check(len(es)==count+2 and es[0]['command'][1]=='write'and es[1]['command'][1]=='resume','native execution matrix '+d)
   for e in es[2:]:check(b'INVALID_DISK=PASS'in data[e['stdout_file']],'missing decoder rejection')
  body=data[opt+'/management_soil.f90'].decode();a=body.index('! Mineralisation, but Nminer is negative in case of immobilisation');b=body.index('      Call Wofost_SoilBalanceCheck',a)
  literal=body[a:b].encode();check(hashlib.sha256(literal).hexdigest()==r['literal_uptake_extraction']['block_sha256'],'literal extraction drift')
  check(literal in data[opt+'/literal_crop_exchange.f90'],'source uptake branch translated or absent')
  for p,h in r['authority'].items():
   raw=data[opt+'/'+p]
   if p=='wofost_soil_orgmatn.f90':check(hashlib.sha256(raw).hexdigest()=='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696','corrected reference drift')
   else:check(hashlib.sha256(raw).hexdigest()==h,'literal source drift '+p)
 for prefix,count,marker in [('direct_stable',39,'CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS'),('reactive_regression',13,'REACTIVE_LITERAL_16_ENVIRONMENTS_TRANSPORT_OFF_MASS_IMMOBILISATION_RESTART=PASS')]:
  small=json.loads(data[prefix+'/result.json']);small_events=json.loads(data[prefix+'/events.json'])
  check(small['status']=='DIRECT_PASS'and small['source_tree']==source['source_tree'],'stale small production closure')
  for p,h in small['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'small input drift '+p)
  for opt in ['O0','O2']:
   row=small['runs'][opt]
   check(row.get('production_providers',row.get('direct_production_provider_count'))==count,'small closure changed')
   output=row['drivers']['test_crop_soil_day']['stdout']if prefix=='direct_stable'else row['direct_stdout']
   check(marker in output,'small native science absent')
  for e in small_events:
   check(e['returncode']==0,'failed small event')
   for stream in ['stdout','stderr']:check(hashlib.sha256(data[prefix+'/'+e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'small raw event drift')
 edge=json.loads(data['restart_expectations/result.json']);edge_events=json.loads(data['restart_expectations/events.json'])
 check(edge['status']=='PASS'and edge['source_tree']==source['source_tree'],'expected configuration controls unfinished')
 check(edge['primary_result_sha256']==hashlib.sha256(data['result.json']).hexdigest(),'wrong primary edge binding')
 for p,h in edge['input_sha256'].items():check(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,'edge input drift')
 for opt in ['O0','O2']:
  check('CROP_SOIL_SEVEN_EXPECTED_CONFIGURATION_IDENTITY_NEGATIVES=PASS'in edge['runs'][opt]['stdout'],'missing expected configuration science')
  check(edge['runs'][opt]['artifacts_before']==edge['runs'][opt]['artifacts_after'],'edge shared providers changed')
 check(len([e for e in edge_events if e['category']=='native'])==2,'expected configuration native coverage')
 for e in edge_events:
  check(e['returncode']==0,'failed configuration edge event')
  for stream in ['stdout','stderr']:check(hashlib.sha256(data['restart_expectations/'+e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'edge raw proof drift')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed physical event')
  if e['category']in ['compile','driver_compile']:
   module_dir=Path(next(a[2:]for a in e['command']if a.startswith('-J')))
   check('-'+module_dir.name in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked current compile')
  for stream in ['stdout','stderr']:check(hashlib.sha256(data[e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'raw event drift')
 import verify_science_edges as edges
 edges.validate(ROOT,data,edges.read(ROOT))
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}

def incumbent(mode='qualification'):
 verify_qualification();base=ROOT.parent/'nut-crop-peer-f8eca95b'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),PEER],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==PEER,'baseline changed')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'dirty baseline')
 args=[sys.executable,'-B',str(base/'tests/crop-co2/verify_co2_successor.py')]
 if mode!='qualification':args.append('--source-only'if mode=='source'else'--physical-only')
 p=subprocess.run(args,cwd=base,capture_output=True,text=True,check=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return {**json.loads(p.stdout),'crop_supply_successor':True,'crop_supply_baseline':BASE,'crop_supply_peer':PEER,'crop_supply_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_qualification(),indent=2))
