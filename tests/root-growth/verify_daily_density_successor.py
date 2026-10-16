"""Bounded daily-density proof in the existing crop/application owner chain."""
from pathlib import Path
import base64,hashlib,io,json,os,re,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='2194651f55881e5aa7ea7ffd3f9e2eebfae952f9'
STATUS='integration/audits/MC_ROOT01_ROOT_GROWTH_OXYGEN_COMPOSITION_STATUS.json'
PRODUCTION={'src/crop/mod_crop_adaptive_root_profile_owner.f90',
 'src/crop/mod_crop_root_depth_rate_owner.f90',
 'src/runtime/mod_fmr_wofost_accepted_window_lineage.f90',
 'src/runtime/mod_fmr_wofost_crop_transaction.f90',
 'src/runtime/mod_fmr_production_application_bootstrap.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['daily_density_supply_20261016']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'foreign daily-density baseline')
 g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference','.github'),'dirty daily-density scientific surface')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference','.github').splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign daily-density delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'daily-density production scope widened')
 for p,v in r['postimages'].items():
  check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'daily-density postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'daily-density source tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'daily-density reference drift')
 return dict(baseline=BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],
  daily_density_successor=True,int12c_successor=True,co2_successor=True,swrd3_successor=True,
  swrd2_successor=True,harvest_successor=True,surface_successor=True,calendar_successor=True,
  input_successor=True,thermal_successor=True,qualified=False,admitted=False)
def evidence():
 e=record()['science_archive'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
 check(sha(raw)==e['decoded_sha256'],'daily-density capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers()
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe daily-density member')
  check(len({m.name for m in members})==len(members),'duplicate daily-density member')
  data={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'))
 check(set(data)==set(manifest),'daily-density capsule members incomplete')
 for p,h in manifest.items():check(sha(data[p])==h,'daily-density raw evidence drift '+p)
 return data
def inputs(rows,except_paths=()):
 for p,h in rows.items():
  if p not in except_paths:check(sha((ROOT/p).read_bytes())==h,'stale daily-density input '+p)
def native(data,prefix,digest):
 values=[b for p,b in data.items()if p.startswith(prefix)and p.endswith('.stdout')and sha(b)==digest]
 check(bool(values),'daily-density native output missing')
 return values[0]
def validate_science(data):
 d=json.loads(data['direct/result.json']);p=json.loads(data['physical/RESULTS.json']);n=json.loads(data['nodal/RESULTS.json'])
 check(d['status']==p['status']==n['status']=='PASS','unfinished daily-density science')
 check(len(d['runs'])==40 and len(p['results'])==36 and len(n['results'])==8,'incomplete daily-density native matrix')
 inputs(d['inputs']);inputs(p['source_inputs'],('tests/root-growth/density_cycle_driver.py',));inputs(n['inputs'])
 check(PRODUCTION<=d['inputs'].keys()|p['source_inputs'].keys(),'uncompiled daily-density production')
 check(n['reused_provider_and_oracle_compiles']==0,'unverified cross-environment reuse')
 check(p['costs'][0]['providers']==p['costs'][1]['providers']==n['providers']==233,'physical provider closure drift')
 check(n['flags']==['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow'],'nodal compile policy drift')
 for result,key,prefix in [(d,'runs','direct/'),(p,'results','physical/'),(n,'results','nodal/')]:
  for row in result[key]:
   check(row.get('returncode',0)==0,'failed daily-density native command')
   output=native(data,prefix,row['stdout_sha256'])
   check(b'PASS'in output,'daily-density native assertions absent')
   if row['driver']in ('density','density_supply'):
    check(b'DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS'in output,'actual Richards density proof absent')
   if row['driver']=='test_daily_density_transaction.f90':
    check(b'DAILY_DENSITY_LAYER_IDENTITY_NONFINITE_RETRY_FINALIZATION=PASS'in output,'nodal falsification proof absent')
  events=json.loads(data['direct/events.json'])if prefix=='direct/'else result['events']
  for index,e in enumerate(events):
   check(e['returncode']==0,'failed daily-density compiler/link/native event')
   if 'stdout_sha256'in e:native(data,prefix,e['stdout_sha256'])
   for stream in ('stdout','stderr'):
    names=[prefix+e[stream]]if prefix=='direct/'else [name for name in data if name.startswith(prefix+f'{index:05d}-')and name.endswith('.'+stream)]
    check(len(names)==1 and names[0]in data,'missing exact daily-density event stream')
    if stream+'_sha256'in e:check(sha(data[names[0]])==e[stream+'_sha256'],'daily-density event stream drift')
   if '-c'in e['command']:
    check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked density compile')
 for result,key in [(d,'runs'),(p,'results'),(n,'results')]:
  identity=lambda x:tuple(x.get(k)for k in ['opt','driver','profile','moisture','mode'])
  hashes={identity(x):x['stdout_sha256']for x in result[key]}
  check(len(hashes)==len(result[key]),'duplicate daily-density native case')
  for row in result[key]:
   other=dict(row,opt=2-row['opt']);check(hashes.get(identity(other))==row['stdout_sha256'],'daily-density O0/O2 drift')
   if 'mode'in row:
    other=dict(row,mode='continuous');check(hashes.get(identity(other))==row['stdout_sha256'],'daily-density restart drift')
 check({(x['opt'],x['driver'],x['mode'])for x in n['results']}=={(o,name,mode)for o in (0,2)for name in ('density','density_supply')for mode in ('continuous','restart')},'nodal physical domain incomplete')
 # Regenerate the stronger nodal driver from current, source-pinned generators.
 # Its literal layer comparisons cannot be replaced by the earlier scalar proof.
 sys.path.insert(0,str(ROOT/'tests/root-growth'))
 from density_cycle_driver import prepare
 with tempfile.TemporaryDirectory(prefix='swap5-density-proof-')as tmp:
  for name,supply in [('density',False),('density_supply',True)]:
   path=prepare(ROOT,Path(tmp)/(name+'.f90'),supply)
   check(data['nodal/'+name+'.f90']==path.read_bytes(),'unexecuted current nodal discriminator')
 # Prove the original30 direct and28 physical native outputs remain exactly
 # equal to their actually qualified immutable predecessor executions.
 old=record()['incumbent_root_science'];raw=base64.b64decode((ROOT/old['path']).read_bytes())
 check(sha(raw)==old['decoded_sha256'],'incumbent root science corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for name,new,key in [('direct/result.json',d,'runs'),('physical/RESULTS.json',p,'results')]:
   prior=json.load(t.extractfile(name))
   identity=lambda x:tuple(x.get(k)for k in ['opt','driver','profile','moisture','mode'])
   current={identity(x):x['stdout_sha256']for x in new[key]}
   for row in prior[key]:check(current.get(identity(row))==row['stdout_sha256'],'incumbent root native drift')
 # Exact default guard routing is additive; the complete predecessor guard
 # and its original controls remain in place after removing only these islands.
 for path,patches in json.loads(data['review/owner_dispatch_projections.json']).items():
  lines=(ROOT/path).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'owner dispatch projection drift');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),'original owner guard body changed')
 owners=json.loads(data['owners/results.json'])
 check(len(owners)==16 and all(x['returncode']==0 and not x['missing_markers']for x in owners),'incomplete current application owners')
 for row in json.loads(data['owners/compile_sources.json']):check(sha((ROOT/row['path']).read_bytes())==row['sha256'],'stale application owner source')
 e=json.loads((ROOT/'integration/audits/F-MIG431-INT12-C_STATUS.json').read_text())['direct_application_recovery_20261016']['archive']
 raw=base64.b64decode((ROOT/e['path']).read_bytes());check(sha(raw)==e['decoded_sha256'],'incumbent application evidence corruption')
 boot='src/runtime/mod_fmr_production_application_bootstrap.f90'
 before=subprocess.check_output(['git','show',BASE+':'+boot],cwd=ROOT,text=True).splitlines()
 after=(ROOT/boot).read_text().splitlines()
 def diagnostic_location(match):
  line=int(match[1]);statement=before[line-1];hits=[i+1 for i,text in enumerate(after)if text==statement]
  check(len(hits)==1,'compiler diagnostic statement changed or ambiguous')
  return match[0].replace(str(line).encode(),str(hits[0]).encode(),1)
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  for row in owners:
   name=(''if row['driver']=='endpoint'else row['driver']+'-')+'o'+str(row['optimization'])+'.txt'
   old=t.extractfile('final/'+name).read()
   # Only the source line number of the identical array-temporary statement
   # relocates. Retain every diagnostic text/count and numerical output byte.
   old=re.sub(rb'At line (\d+) of file src/runtime/mod_fmr_production_application_bootstrap.f90\nFortran runtime warning: An array temporary was created\n',diagnostic_location,old)
   check(data['owners/'+name]==old,'incumbent application native drift '+name)
 # The capsule's reviewed default projection records exact source islands,
 # not numerical PASS. All original bodies must reconstruct byte-for-byte.
 projections=json.loads(data['review/default_projections.json'])
 check(set(projections)==PRODUCTION,'incomplete reviewed default projection')
 for path,patches in projections.items():
  lines=(ROOT/path).read_text().splitlines(True)
  for patch in reversed(patches):
   a,b=patch['current_range'];check(lines[a:b]==patch['current'],'default projection postimage drift')
   lines[a:b]=patch['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),'incumbent production body changed '+path)
 check('file_weather_adaptive_root_profile=.false.'in (ROOT/'src/runtime/mod_fmr_production_application_bootstrap.f90').read_text(),'adaptive default enabled')
 return d,p,n
def incumbent():
 base=ROOT.parent/'root-density-incumbent-2194651f'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'daily-density incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'daily-density incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/fpm/verify_int12c_successor.py'],cwd=base,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 check(p.returncode==0,'actual incumbent authority rejected '+p.stderr[-1200:]);r=json.loads(p.stdout);check(r['qualified'],'incumbent not qualified')
 return r
def verify_qualification():
 source=verify_source();check(record()['phase']in ('SCIENCE_COMPLETE_ADMISSION_VALIDATION_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED'),'daily-density not scientifically closed')
 data=evidence();validate_science(data);old=incumbent()
 return {**source,'qualified':True,'incumbent_owner':old,
  'scope':'Bounded daily SWRD2 adaptive density, authentic emergence, uncompensated accepted-layer uptake/reduction and optional SWDMI2RD2; current/lagged and opaque joint restart.',
  'preservation':'REVIEWED_DEFAULT_SOURCE_PROJECTION_PLUS_58_IDENTICAL_ROOT_AND_16_IDENTICAL_APPLICATION_NATIVE_OUTPUTS_AND_FRESH_NEW_PHYSICS',
  'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
