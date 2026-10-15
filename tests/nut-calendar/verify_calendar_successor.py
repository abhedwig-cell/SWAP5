#!/usr/bin/env python3
"""Exact additive calendar eligibility, literal B1-R2 and actual current science."""
from pathlib import Path
import ast,argparse,base64,hashlib,io,json,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='3b661766dc59298a7f541c970c2d3a55602d926c'
STATUS='integration/audits/MC_NUT01_MANAGEMENT_CALENDAR_STATUS.json'
CHANGED={'tests/nut-senescence/verify_senescence_successor.py','tests/nut-senescence/check_senescence_controls.py','tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'}
PRODUCTION={'src/process/mod_soil_n_amendment_calendar.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/runtime/mod_fmr_crop_soil_n_calendar_application.f90'}
MARKERS={'test_calendar':'CALENDAR_R2_SOURCE_ORDER_UNITS_20_INVALID_EMPTY_ABA=PASS','test_calendar_day':'CALENDAR_REAL_DAY_DELAYED_LITERAL_WHOLE_N_ROLLBACK_REPLAY=PASS','test_calendar_joint':'CALENDAR_ACTUAL_RICHARDS_DELAYED_LITERAL_ATOMIC_PENDING_OPAQUE_DISK=PASS'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 expected={p:'A'for p in s['added_blobs']};expected.update({p:'M'for p in CHANGED})
 check(rows==expected and set(s['changed_blobs'])==CHANGED,'foreign/incomplete calendar delta')
 check({p for p in s['added_blobs']if p.startswith('src/')}==PRODUCTION,'unexpected production addition')
 for p,h in {**s['added_blobs'],**s['changed_blobs']}.items():check(g('rev-parse','HEAD:'+p)==h==blob((ROOT/p).read_bytes()),'unknown postimage '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'immutable source changed')
 return {'baseline':BASE,'source_tree':g('rev-parse','HEAD:src'),'current_source_tree':g('rev-parse','HEAD:src'),'calendar_successor':True,'senescence_successor':True,'qualified':False,'admitted':False}
def read_evidence():
 rec=json.loads((ROOT/STATUS).read_text())['evidence'];raw=base64.b64decode((ROOT/rec['path']).read_bytes());check(sha(raw)==rec['sha256'],'capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe member')
  d={m.name:a.extractfile(m).read()for m in ms};check(len(d)==len(ms),'duplicate member')
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(manifest)==set(d),'manifest coverage')
 for p,h in manifest.items():check(sha(d[p])==h,'raw member drift '+p)
 return d
def baseline_command(path,extra=()):
 root=ROOT.parent/('calendar-baseline-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,capture_output=True,check=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=root,text=True).strip(),'dirty baseline')
 p=subprocess.run([sys.executable,'-B',str(root/path),*extra],cwd=root,capture_output=True,check=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 return json.loads(p.stdout)
def inputs_valid(r):
 for p,h in r['input_sha256'].items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe input');check(sha((ROOT/p).read_bytes())==h,'scientific input drift '+p)
def events_valid(d,prefix,events):
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed native/build event')
  if e['category']in ['compile','driver_compile','compile_link']:
   check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked compilation')
  for stream in ['stdout','stderr']:check(sha(d[prefix+e[stream+'_file']])==e[stream+'_sha256'],'event digest drift')
def validate_reference(d):
 r=json.loads(d['reference/result.json']);events=json.loads(d['reference/events.json'])
 check(r['status']=='B0_DEFECT_B1_R2_PASS','unfinished reference');inputs_valid(r);events_valid(d,'reference/',events)
 original=d['reference/O0/management_soil.f90'];check(sha(original)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b','historical authority changed')
 text=original.decode();a=text.index('!     Converting kg/ha -> kg/m2');b=text.index('! -   open file with soil nutrient parameters',a);group=text[a:b]
 a=text.index('      if (abs(TimeAmend(isme)');b=text.index('      return',a);trigger=text[a:b]
 old='smedate(isme)-smedate(isme-1) < 0.d-3';new='smedate(isme)-smedate(isme-1) < 1.d-3'
 check(r['correction']=={'old':old,'new':new}and group.count(old)==1,'reference transform changed')
 for opt in ['O0','O2']:
  check(d['reference/'+opt+'/management_soil.f90']==original,'reference source identity')
  for label,marker in [('B0','B0_SAME_DATE_STALLS_ALL_LATER_AMENDMENTS=PASS'),('B1_R2','B1_R2_SAME_DATE_SOURCE_ORDER_LATER_DATES_MASS=PASS')]:
   body=d['reference/'+opt+'/'+label+'.f90'];check((group if label=='B0'else group.replace(old,new)).encode()in body and trigger.encode()in body,'literal grouping/trigger altered')
   row=r['runs'][opt+'/'+label];check(sha(body)==row['source_sha256']and marker in row['stdout'],'reference native proof absent')
   es=[e for e in events if e['category']=='native'and e['command'][0].endswith('/'+opt+'/'+label)]
   check(len(es)==1 and d['reference/'+es[0]['stdout_file']].decode()==row['stdout'],'reference raw binding')
  b0=r['runs'][opt+'/B0']['stdout'];b1=r['runs'][opt+'/B1_R2']['stdout']
  check('SELECT_DAY=0 COUNT=1'in b0 and 'SELECT_DAY=1 COUNT=0'in b0,'original stall witness absent')
  check('SELECT_DAY=0 COUNT=2'in b1 and 'SELECT_DAY=1 COUNT=1'in b1 and 'SELECT_DAY=3 COUNT=1'in b1,'corrected whole sequence absent')
 check(len([e for e in events if e['category']=='compile_link'])==4,'reference fresh builds missing')
 return r
def validate_events(d,prefix,source,mode,reference):
 r=json.loads(d[prefix+'result.json']);events=json.loads(d[prefix+'events.json']);check(r['status']=='PASS'and r['mode']==mode,'unfinished calendar science')
 check(r['source_tree']==source['source_tree'],'stale source');inputs_valid(r);events_valid(d,prefix,events)
 check(r['compiler']==reference['compiler'],'compiler identity drift')
 check(set(r['authority'])=={'wofost_soil_declarations.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90','wofost_soil_parameters.f90','management_soil.f90','wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90'},'incomplete literal authority')
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as a:
  check(r['authority']=={name:sha(a.extractfile('SWAP/'+name).read())for name in r['authority']},'literal authority drift')
 needed=PRODUCTION if mode=='joint'else PRODUCTION-{'src/runtime/mod_fmr_crop_soil_n_calendar_application.f90'}if mode=='day'else {'src/process/mod_soil_n_amendment_calendar.f90'}
 check(needed<=r['input_sha256'].keys(),'untested new provider')
 expected=set(MARKERS)if mode=='joint'else {'test_calendar','test_calendar_day'}if mode=='day'else {'test_calendar'}
 check({'tests/nut-calendar/'+name+'.f90'for name in expected}<=r['input_sha256'].keys(),'driver input coverage')
 script=ast.parse((ROOT/'tests/nut-calendar/run_calendar.py').read_text())
 wrapper=next(ast.literal_eval(n.value)for n in script.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(row['production_providers']==(266 if mode=='joint'else 46 if mode=='day'else 3),'closure drift');check(set(row['drivers'])==expected,'driver missing')
  builds=[e for e in events if e['category']=='compile'and '-'+opt in e['command']]
  compiled={'src/'+e['command'][e['command'].index('-c')+1].split('/src/',1)[1]for e in builds if '/src/'in e['command'][e['command'].index('-c')+1]}
  check(compiled=={p for p in r['input_sha256']if p.startswith('src/')}and len(compiled)==row['production_providers'],'fresh provider coverage')
  for name,entry in row['drivers'].items():
   for category in ['driver_compile','link']:
    es=[e for e in events if e['category']==category and '-'+opt in e['command']and any(Path(x).name==name+('.f90'if category=='driver_compile'else'')for x in e['command'])]
    check(len(es)==1,'fresh driver/link missing '+name)
   es=[e for e in events if e['category']=='native'and '/'+opt+'/'in e['command'][0]and Path(e['command'][0]).name==name]
   check(len(es)==(4 if name=='test_calendar_joint'else 1),'native coverage '+name)
   if name!='test_calendar_joint':
    check(MARKERS[name]in entry['stdout']and d[prefix+es[0]['stdout_file']].decode()==entry['stdout'],'literal native proof missing')
    if name=='test_calendar':
     lines=lambda s:[x for x in s.splitlines()if x.startswith('SELECT_DAY=')]
     check(lines(entry['stdout'])==lines(reference['runs'][opt+'/B1_R2']['stdout']),'B2 differs from actual corrected B1 selection')
    continue
   check(set(entry)=={'manual','calendar'},'missing physical counterpart')
   for profile in ['manual','calendar']:
    subset=[e for e in es if e['command'][-1]==profile];check(len(subset)==2 and subset[0]['command'][1]=='write'and subset[1]['command'][1]=='resume','fresh profile missing')
    value=entry[profile];check(MARKERS[name]in value['stdout']and 'FRESH_PROCESS_CONTINUATION=PASS'in value['fresh_stdout'],'physical science absent')
    check(d[prefix+subset[0]['stdout_file']].decode()==value['stdout']and d[prefix+subset[1]['stdout_file']].decode()==value['fresh_stdout'],'physical raw stdout drift')
    check(sha(d[prefix+opt+'/'+profile+'-restart.bin'])==value['restart_sha256'],'initial native payload drift')
    for suffix in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(d[prefix+opt+'/'+profile+'-'+suffix])==value['endpoint_sha256'],'native/opaque/fresh drift')
    check(value['endpoint_sha256']==r['runs']['O0']['drivers'][name][profile]['endpoint_sha256'],'O0/O2 endpoint drift')
   for suffix in ['restart.bin','expected.bin','fresh.bin','expected.bin.opaque']:
    check(d[prefix+opt+'/manual-'+suffix]==d[prefix+opt+'/calendar-'+suffix],'scheduled/manual complete state mismatch')
   check(d[prefix+opt+'/calendar-restart.bin'][:8]==b'S5NC0002','pending physical profile missing')
  check(d[prefix+opt+'/material_oracle.inc']==wrapper.encode(),'material oracle wrapper altered')
  for name,h in r['authority'].items():
   expected_hash='a17a727e35c453a17be599eede2c501b36baf921b9937edd6b0309dcb26d9696'if name=='wofost_soil_orgmatn.f90'and mode!='process'else h
   check(sha(d[prefix+opt+'/'+name])==expected_hash,'literal source drift '+name)
  if mode!='process':
   body=d[prefix+opt+'/management_soil.f90'];a=body.index(b'! Mineralisation, but Nminer is negative in case of immobilisation');b=body.index(b'      Call Wofost_SoilBalanceCheck',a)
   check(body[a:b]in d[prefix+opt+'/literal_crop_exchange.f90'],'literal uptake missing')
 return r
def validate(d,source):
 ref=validate_reference(d)
 validate_events(d,'process/',source,'process',ref);validate_events(d,'direct/',source,'day',ref)
 r=validate_events(d,'',source,'joint',ref)
 probe=json.loads(d['empty/result.json']);check(probe['status']=='PASS'and probe['primary_result_sha256']==sha(d['result.json']),'unfinished/unbound empty-day probe')
 check(probe['source_tree']==source['source_tree']and probe['compiler']==r['compiler'],'stale empty-day probe')
 inputs_valid(probe);events_valid(d,'empty/',probe['events'])
 for opt in ['O0','O2']:
  row=probe['runs'][opt];check(row['native_results_reused']is False and bool(row['artifacts_before_and_after']),'unproven empty-day provider reuse')
  check(row['artifacts_before_and_after']==json.loads(d['empty/BUILD_ARTIFACTS.json'])[opt],'empty-day build hash drift')
  es=[e for e in probe['events']if e['category']=='native'and '/'+opt+'/'in e['command'][0]]
  check(len(es)==1 and b'CALENDAR_NO_EVENT_ACTUAL_CROP_SOIL_PENDING_EXACT_IDENTITY=PASS'in d['empty/'+es[0]['stdout_file']],'empty-day native identity absent')
  for category in ['driver_compile','link']:
   check(len([e for e in probe['events']if e['category']==category and '-'+opt in e['command']])==1,'empty-day fresh driver/link absent')
 return r
def verify_qualification():
 source=verify_source();validate(read_evidence(),source)
 baseline_command('tests/nut-senescence/verify_senescence_successor.py')
 return {**source,'qualified':True,'highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');a=p.parse_args()
 print(json.dumps(verify_source()if a.source_only else verify_qualification(),indent=2))
