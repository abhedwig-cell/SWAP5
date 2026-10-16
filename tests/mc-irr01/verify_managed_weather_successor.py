"""Source-bound managed-weather proof; immutable incumbent remains its own authority."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='27dea4829f7025eb4701599d5dbef7b86e4fd20a'
STATUS='integration/audits/MC_IRR01_STATUS.json'
PRODUCTION={
 'src/runtime/mod_fmr_production_application_bootstrap.f90',
 'src/runtime/mod_fmr_irrigation_allocation_binding.f90',
 'src/runtime/mod_fmr_scheduled_irrigation_application.f90',
 'src/runtime/mod_fmr_scheduled_irrigation_forcing_binding.f90'}
GUARDS={'tests/root-growth/verify_daily_density_successor.py','tests/root-growth/check_daily_density_controls.py',
 'tests/fpm/verify_hyd_successor.py','tests/fpm/test_hyd_successor_controls.py',
 'tests/fwof/pp02/verify_b111_nfixation_successor.py','tests/fwof/pp02/test_b111_nfixation_successor_controls.py'}
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['managed_application_20261016']
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'unknown managed-weather baseline')
 g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference','.github'),'dirty managed-weather scientific surface')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference','.github').splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign managed-weather source delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'managed-weather production scope widened')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'managed-weather postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'managed-weather production tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'managed-weather reference drift')
 for path in PRODUCTION:check(not re.search(r'\buse\s*(?:::\s*)?mod_b111_nfixation_policy\b',(ROOT/path).read_text(),re.I),'unqualified NFIX runtime caller')
 flags={name:True for name in ['managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor',
  'swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor']}
 return dict(baseline=BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],qualified=False,admitted=False,**flags)
def capsule(descriptor):
 raw=base64.b64decode((ROOT/descriptor['path']).read_bytes())
 check(sha(raw)==descriptor['decoded_sha256'],'managed-weather capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  members=t.getmembers()
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe managed-weather capsule')
  check(len(members)==len({m.name for m in members}),'duplicate managed-weather member')
  data={m.name:t.extractfile(m).read()for m in members}
 manifest=json.loads(data.pop('MANIFEST.json'))
 check(set(data)==set(manifest),'managed-weather capsule incomplete')
 for p,h in manifest.items():check(sha(data[p])==h,'managed-weather member drift '+p)
 return data
def evidence():return capsule(record()['science_archive'])
def inputs(rows):
 for p,h in rows.items():check(sha((ROOT/p).read_bytes())==h,'stale managed-weather compiled input '+p)
def expected_matrix():
 rows={(o,'weather',m,c)for o in (0,2)for m in ('neutral','dry','hydraulic')for c in ('continuous','restart')}
 rows|={(o,'managed','neutral',c)for o in (0,2)for c in ('continuous','restart')}
 rows|={(o,n,'neutral','continuous')for o in (0,2)for n in ('allocation_guards','managed_rooted7','managed_rooted8')}
 return rows
def validate_science(data):
 r=json.loads(data['physical/RESULTS.json']);i=json.loads(data['physical/INPUTS.json'])
 check(r['status']=='PASS','unfinished managed-weather physical qualification')
 inputs(r['source_inputs']);check(i['flags']==FLAGS,'managed-weather compiler policy drift')
 check(i['inputs']==r['source_inputs'],'managed-weather input index drift')
 check(PRODUCTION<=r['source_inputs'].keys(),'managed-weather changed production uncompiled')
 check(len(i['providers'])==245 and len(set(i['providers']))==245,'managed-weather ordered provider closure drift')
 identity=lambda x:(x['opt'],x['driver'],x['moisture'],x['mode'])
 rows=r['results'];keys={identity(x)for x in rows}
 check(keys==expected_matrix()and len(rows)==len(keys),'incomplete or duplicate managed-weather native matrix')
 digests={identity(x):x['stdout_sha256']for x in rows}
 for row in rows:
  check(row['returncode']==0,'failed managed-weather native programme')
  output=[b for name,b in data.items()if name.startswith('physical/')and name.endswith('.stdout')and sha(b)==row['stdout_sha256']]
  check(bool(output),'missing managed-weather raw native output')
  native=output[0]
  if row['driver']=='managed':
   for marker in [b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS',b'MC_IRR01_MANAGED_INCOMPLETE_PREFIX_ROLLBACK_RETRY_RESTART=PASS']:
    check(marker in native,'managed-weather scientific assertions absent')
   check(native.count(b'MANAGED_FINAL_BITS=')==112,'managed-weather eight-case actual state output incomplete')
  if row['driver'].startswith('managed_rooted'):
   for marker in [b'MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS',b'DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS',b'CROP_FILE_WEATHER_PRODUCTION=PASS']:
    check(marker in native,'managed-weather actual rooted science absent')
  if row['driver']=='allocation_guards':check(b'MC_IRR01_ALLOCATION_GUARDS=PASS'in native,'original allocation guards missing')
  k=identity(row);other=(2-row['opt'],*k[1:]);check(digests.get(other)==row['stdout_sha256'],'managed-weather O0/O2 drift')
  if row['driver']in ('weather','managed'):
   other=(*k[:3],'restart');check(digests.get(other)==row['stdout_sha256'],'managed-weather joint restart drift')
 for n,e in enumerate(r['events']):
  check(e['returncode']==0,'failed managed-weather build/link/native event')
  for stream in ('stdout','stderr'):
   names=[p for p in data if p.startswith('physical/'+f'{n:05d}-')and p.endswith('.'+stream)]
   check(len(names)==1,'missing managed-weather raw event stream')
   if stream+'_sha256'in e:check(sha(data[names[0]])==e[stream+'_sha256'],'managed-weather event output drift')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked managed-weather compilation')
 for p,h in r['generated_inputs'].items():check(sha(data['physical/'+p])==h,'managed-weather executed generated input drift '+p)
 # Regenerate current changed scientific drivers, never accept an old weaker test.
 base=(ROOT/'tests/fmig431/test_crop_file_weather_production.f90').read_text()
 modified=base.replace('  implicit none\n','  use mod_fmr_irrigation_allocation_binding\n  use, intrinsic :: ieee_arithmetic\n  implicit none\n',1)
 first=modified.index('  call test_rooted_weather_production()');boundary=modified.index('\ncontains\n')
 modified=modified[:first]+'  call test_managed_weather_application()\n'+modified[boundary:]
 modified=modified.replace('\ncontains\n','\ncontains\n'+(ROOT/'tests/mc-irr01/test_managed_weather_application.inc').read_text(),1)
 check(data['physical/managed_driver.f90']==modified.encode(),'unexecuted current managed scientific driver')
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from managed_root_cycle_driver import prepare
 with tempfile.TemporaryDirectory(prefix='swap5-managed-proof-')as tmp:
  for n,c,nodes in [('managed_rooted7',7,1),('managed_rooted8',8,3)]:
   p=prepare(ROOT,Path(tmp)/(n+'.f90'),c,nodes)
   check(p.read_bytes()==data['physical/'+n+'.f90'],'unexecuted current managed rooted discriminator')
 # Actual unchanged weather outputs, not reconstructed placeholder PASS.
 predecessor=capsule(record()['incumbent_science'])
 old=json.loads(predecessor['physical/RESULTS.json'])
 for row in old['results']:
  if row['driver']=='weather':check(digests.get(identity(row))==row['stdout_sha256'],'original weather native drift')
 owner_rows=json.loads(data['owners/results.json'])
 names={'endpoint','test_ppa_wu01_production_application_bootstrap','test_ppa_wu03_common_forcing_adapter',
  'test_ppa_wu04a_black_runtime','test_ppa_wu04b_boesten_runtime','test_ppa_wu04a_black_process',
  'test_ppa_wu04b_boesten_process','test_rutter_output_binding'}
 check(len(owner_rows)==16 and {(x['driver'],x['optimization'])for x in owner_rows}=={(n,o)for n in names for o in (0,2)},'incomplete or duplicate managed-weather incumbent owners')
 check(all(x['returncode']==0 and not x['missing_markers']for x in owner_rows),'failed managed-weather incumbent owners')
 inputs({x['path']:x['sha256']for x in json.loads(data['owners/compile_sources.json'])})
 boot='src/runtime/mod_fmr_production_application_bootstrap.f90';before=subprocess.check_output(['git','show',BASE+':'+boot],cwd=ROOT,text=True).splitlines();after=(ROOT/boot).read_text().splitlines()
 def relocate(m):
  line=int(m[1]);statement=before[line-1];hits=[i+1 for i,s in enumerate(after)if s==statement]
  check(len(hits)==1,'original diagnostic statement changed/ambiguous')
  return m[0].replace(str(line).encode(),str(hits[0]).encode(),1)
 for row in owner_rows:
  name=(''if row['driver']=='endpoint'else row['driver']+'-')+'o'+str(row['optimization'])+'.txt'
  old=re.sub(rb'At line (\d+) of file src/runtime/mod_fmr_production_application_bootstrap.f90\nFortran runtime warning: An array temporary was created\n',relocate,predecessor['owners/'+name])
  check(data['owners/'+name]==old,'original actual application owner output drift '+name)
 # Reviewed inverse islands preserve whole original bodies. This source review
 # is not a substitute for the actual current physical and owner executions.
 projections=json.loads(data['review/incumbent_projections.json'])
 check(set(projections)==PRODUCTION|GUARDS,'incomplete managed-weather original-body review')
 for path,patches in projections.items():
  lines=(ROOT/path).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'unreviewed managed-weather postimage island');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT),'original complete body reconstruction failed '+path)
 check('logical :: file_weather_irrigation=.false.'in (ROOT/boot).read_text(),'managed profile default enabled')
 return r

def incumbent():
 base=ROOT.parent/'irr-incumbent-27dea482'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'managed-weather incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=base,text=True).strip(),'managed-weather incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/fwof/pp02/verify_b111_nfixation_successor.py'],cwd=base,capture_output=True,text=True)
 check(p.returncode==0,'actual admitted density authority rejected '+p.stderr[-800:]);r=json.loads(p.stdout);check(r['qualified'],'actual density authority not qualified');return r

def verify_qualification():
 source=verify_source();check(record()['phase']in ('SCIENCE_COMPLETE_ADMISSION_CONTROLS_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED'),'managed-weather science unfinished')
 validate_science(evidence());old=incumbent()
 return {**source,'qualified':True,'incumbent':old,'scope':'Bounded authentic full-day TCS7/8,DCS2,1/3-node SSDI,limits/frozen allocation; actual adaptive SWRD2/supply with current/lagged crop, common-prefix rollback/retry and opaque joint restart. Existing64-interval daily schedule; no arbitrary long-tail accuracy, bottom7 salt, DCS1/root timing or native weather disk claim.','preservation':'12_BYTE_IDENTICAL_WEATHER_AND_16_BYTE_IDENTICAL_APPLICATION_OWNER_OUTPUTS_PLUS_ACTUAL_NEW_MANAGED_PHYSICS_AND_REVIEWED_DEFAULT_BODY','full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
