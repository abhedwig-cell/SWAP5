"""Bounded actual material/root irrigation proof, not a full source envelope."""
from pathlib import Path
import base64,hashlib,io,json,re,subprocess,sys,tarfile,tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='7f5441c5caff025e6eb95ed6044e5a851d47363a'
STATUS='integration/audits/MC_IRR01_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/runtime/mod_fmr_irrigation_allocation_binding.f90',
 'src/runtime/mod_fmr_irrigation_material_root_binding.f90',
 'src/runtime/mod_fmr_production_application_bootstrap.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['material_root_application_20261016']
def verify_source(git_reader=None):
 if (ROOT/'docs/science/MC_SOL01_SURFACE_MASS_RESTART_CONTRACT_20261016.md').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_successor as surface
  return surface.persistent_source(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'unknown material-root baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty material-root scientific surface')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign material-root scientific delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'material-root production scope widened')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'material-root postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'material-root production tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'material-root reference drift')
 flags={n:True for n in ['material_root_irrigation_successor','b111_request_successor','managed_irrigation_successor',
  'nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor',
  'swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor']}
 return dict(baseline=BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],qualified=False,admitted=False,**flags)
def capsule(descriptor):
 raw=base64.b64decode((ROOT/descriptor['path']).read_bytes());check(sha(raw)==descriptor['decoded_sha256'],'material-root capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate material-root archive member')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe material-root archive')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete material-root capsule')
 for p,h in manifest.items():check(sha(data[p])==h,'material-root archived member drift '+p)
 return data
def evidence():return capsule(record()['science_archive'])
def identity(row):return row['opt'],row['driver'],row['moisture'],row['mode']
def inputs(mapping):
 for p,h in mapping.items():check(sha((ROOT/p).read_bytes())==h,'stale material-root executed input '+p)
def physical(data,prefix,expected):
 r=json.loads(data[prefix+'/RESULTS.json']);check(r['status']=='PASS','unfinished material-root physical science')
 check(len(r['results'])==len(expected)and {identity(x)for x in r['results']}==expected,'missing/duplicate material-root physical programs')
 inputs(r['source_inputs']);hashes={identity(x):x['stdout_sha256']for x in r['results']}
 native=[e for e in r['events']if '/test-'in e['command'][0]and '-c'not in e['command']]
 check(len(native)==len(expected),'missing material-root actual native commands')
 for row in r['results']:
  check(row['returncode']==0,'failed material-root native program')
  events=[e for e in native if Path(e['command'][0]).name=='test-'+row['driver']and '/o'+str(row['opt'])+'/'in e['command'][0]
   and e['command'][-2:]==[row['mode'],row['moisture']]]
  check(len(events)==1 and events[0]['returncode']==0 and events[0]['stdout_sha256']==row['stdout_sha256'],'material-root program not actually executed')
  raw=[v for p,v in data.items()if p.startswith(prefix+'/')and p.endswith('.stdout')and sha(v)==row['stdout_sha256']]
  check(bool(raw),'missing material-root physical raw output')
  if row['driver'].startswith('material'):
   for marker in [b'MC_IRR01_MATERIAL_ROOT_POLICY_PHYSICAL_LITERAL_RESTART=PASS',b'DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS']:
    check(marker in raw[0],'missing material-root physical assertion')
  if row['driver']=='material_rain':check(b'MATERIAL_ROOT_UNCAPPED_DAILY_RAIN='in raw[0],'daily rain effect masked by depth cap')
  k=identity(row);check(hashes.get((2-row['opt'],*k[1:]))==row['stdout_sha256'],'material-root O0/O2 drift')
 for n,e in enumerate(r['events']):
  check(e['returncode']==0,'failed material-root qualification event')
  for stream in ('stdout','stderr'):
   names=[p for p in data if p.startswith(prefix+'/'+f'{n:05d}-')and p.endswith('.'+stream)]
   check(len(names)==1,'missing material-root raw event')
   if stream+'_sha256'in e:check(sha(data[names[0]])==e[stream+'_sha256'],'material-root raw event digest drift')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked material-root compilation')
 for p,h in r['generated_inputs'].items():check(sha(data[prefix+'/'+p])==h,'material-root generated input drift '+p)
 return r
def validate_science(data):
 expected=set()
 for opt in (0,2):
  for moisture in ('neutral','dry','hydraulic'):
   for mode in ('continuous','restart'):expected.add((opt,'weather',moisture,mode))
  for mode in ('continuous','restart'):expected.add((opt,'managed','neutral',mode))
  for n in ('allocation_guards','managed_rooted7','managed_rooted8'):expected.add((opt,n,'neutral','continuous'))
  for c in (2,3,4):
   for n in (f'material_{c}_1',f'material_{c}_2',f'material_{c}_no'):expected.add((opt,n,'neutral','continuous'))
 main=physical(data,'physical',expected)
 physical(data,'rain',{(o,'material_rain','neutral','continuous')for o in (0,2)})
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'))
 from material_root_cycle_driver import prepare
 from material_root_rain_driver import prepare as rain
 with tempfile.TemporaryDirectory(prefix='swap5-material-proof-')as tmp:
  for c in (2,3,4):
   for suffix,dcs,trigger in [('1',1,True),('2',2,True),('no',1,False)]:
    n=f'material_{c}_{suffix}.f90';p=prepare(ROOT,Path(tmp)/n,c,dcs,trigger)
    check(p.read_bytes()==data['physical/'+n],'unexecuted current material-root generated driver '+n)
  p=rain(ROOT,Path(tmp)/'material_rain.f90');check(p.read_bytes()==data['rain/material_rain.f90'],'unexecuted current uncapped rain driver')
 direct=json.loads(data['direct/RESULTS.json']);check(direct['status']=='PASS'and len(direct['results'])==2,'unfinished direct material-root science');inputs(direct['inputs'])
 direct_native=[e for e in direct['events']if Path(e['command'][0]).name=='contract']
 check(len(direct_native)==2,'missing direct material-root native commands')
 for n,e in enumerate(direct['events']):
  check(e['returncode']==0,'failed direct material-root event')
  for stream in ('stdout','stderr'):
   names=[p for p in data if p.startswith('direct/'+f'{n:05d}-')and p.endswith('.'+stream)]
   check(len(names)==1,'missing direct material-root raw event')
   if stream+'_sha256'in e:check(sha(data[names[0]])==e[stream+'_sha256'],'stale direct material-root raw event')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked direct material-root compilation')
 for row in direct['results']:
  check(row['returncode']==0,'failed direct material-root program')
  raws=[v for p,v in data.items()if p.startswith('direct/')and p.endswith('.stdout')and sha(v)==row['stdout_sha256']]
  check(bool(raws)and b'MATERIAL_ROOT_LITERAL_CASES=240'in raws[0]and b'MC_IRR01_MATERIAL_ROOT_LITERAL_NONMUTATION_INVALID_ABA=PASS'in raws[0],'direct material/root scientific assertions missing')
  check(any(e['stdout_sha256']==row['stdout_sha256']and '/o'+str(row['opt'])+'/'in e['command'][0]for e in direct_native),'direct material-root result not executed')
 check(direct['results'][0]['stdout_sha256']==direct['results'][1]['stdout_sha256'],'direct optimization drift')
 old=capsule(json.loads((ROOT/STATUS).read_text())['managed_application_20261016']['science_archive'])
 prior=json.loads(old['physical/RESULTS.json'])
 actual={identity(x):x['stdout_sha256']for x in main['results']}
 for row in prior['results']:check(actual.get(identity(row))==row['stdout_sha256'],'admitted managed/weather physical output changed')
 owners=json.loads(data['owners/results.json']);original=json.loads(old['owners/results.json'])
 check(len(owners)==16 and {(r['driver'],r['optimization'])for r in owners}=={(r['driver'],r['optimization'])for r in original},'missing/duplicate incumbent application owner')
 check(all(r['returncode']==0 and not r['missing_markers']for r in owners),'failed incumbent application owner')
 inputs({r['path']:r['sha256']for r in json.loads(data['owners/compile_sources.json'])})
 boot='src/runtime/mod_fmr_production_application_bootstrap.f90';before=subprocess.check_output(['git','show',BASE+':'+boot],cwd=ROOT,text=True).splitlines();after=(ROOT/boot).read_text().splitlines()
 def relocate(m):
  statement=before[int(m[1])-1];hits=[i+1 for i,s in enumerate(after)if s==statement]
  check(len(hits)==1,'original owner diagnostic statement changed/ambiguous');return m[0].replace(m[1],str(hits[0]).encode(),1)
 for row in owners:
  n=(''if row['driver']=='endpoint'else row['driver']+'-')+'o'+str(row['optimization'])+'.txt'
  expected=re.sub(rb'At line (\d+) of file src/runtime/mod_fmr_production_application_bootstrap.f90\nFortran runtime warning: An array temporary was created\n',relocate,old['owners/'+n])
  check(data['owners/'+n]==expected,'admitted actual application owner output drift '+n)
 projections=json.loads(data['review/default_projections.json'])
 check(set(projections)=={p for p,v in record()['postimages'].items()if v['status']=='M'},'incomplete material-root default-body review')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'unreviewed material-root source island');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'complete incumbent body not preserved '+p)
 return {'physical_programs':42,'direct_programs':2,'incumbent_owner_programs':16}
def incumbent():
 base=ROOT.parent/'irr-material-incumbent-7f5441c5'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'material-root incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain','-uno'],cwd=base,text=True).strip(),'material-root incumbent tracked source dirty')
 p=subprocess.run([sys.executable,'-B','tests/nut-crop/verify_b111_request_successor.py'],cwd=base,capture_output=True,text=True)
 check(p.returncode==0,'original incumbent owner proof failed '+p.stderr[-1200:]);r=json.loads(p.stdout);check(r['qualified'],'unqualified original incumbent');return r
def verify_qualification():
 if (ROOT/'docs/science/MC_SOL01_SURFACE_MASS_RESTART_CONTRACT_20261016.md').exists():
  sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_surface_successor as surface
  return surface.persistent_qualification()
 s=verify_source();r=record();check(r['phase']in ['SCIENCE_COMPLETE_ADMISSION_CONTROLS_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED','CANONICALLY_ADMITTED_BOUNDED_MATERIAL_ROOT'],'material-root science unfinished')
 science=validate_science(evidence());old=incumbent()
 return {**s,'qualified':True,'scope':r['scope'],'science':science,'incumbent':old,'full_capability':False,
  'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
