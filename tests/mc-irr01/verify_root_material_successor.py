"""Bounded material/root DCS1 proof in the existing successor authority chain."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,sys,tarfile,tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='7f5441c5caff025e6eb95ed6044e5a851d47363a'
STATUS='integration/audits/MC_IRR01_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/process/mod_irrigation_root_zone_summary.f90','src/runtime/mod_fmr_production_application_bootstrap.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['root_material_dcs1_20261016']
def evidence():
 r=record()['science_archive'];raw=base64.b64decode((ROOT/r['path']).read_bytes())
 check(sha(raw)==r['decoded_sha256'],'material evidence archive drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate material member')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe material member')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete material archive')
 for p,h in manifest.items():check(sha(data[p])==h,'material member drift '+p)
 return data
def verify_source(git_reader=None):
 g=git if git_reader is None else git_reader;r=record()
 check(r['baseline']==BASE,'unknown material baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--',*SURFACE),'dirty material source')
 rows={x.split('\t')[1]:x.split('\t')[0]for x in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign material source delta')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'material production scope widened')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'material postimage drift '+p)
 check(g('rev-parse','HEAD:src')==r['production_source_tree'],'material source tree drift')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'material reference drift')
 data=evidence();projections=json.loads(data['review/default_projections.json'])
 changed={p for p,k in rows.items()if k=='M'}
 check(set(projections)==changed,'material original-body review incomplete')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['current_range'];check(lines[a:b]==q['current'],'unreviewed material island');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'material complete default projection failed '+p)
 flags={n:True for n in ['managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor','swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor','b111_request_successor','root_material_irrigation_successor']}
 return dict(baseline=BASE,source_tree=r['production_source_tree'],current_source_tree=r['production_source_tree'],qualified=False,admitted=False,**flags)
def capsule_at_base():
 d=json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT))['managed_application_20261016']['science_archive']
 raw=base64.b64decode((ROOT/d['path']).read_bytes());check(sha(raw)==d['decoded_sha256'],'original managed evidence drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:return {m.name:a.extractfile(m).read()for m in a if m.isfile()}
def validate_science(data):
 r=json.loads(data['physical/RESULTS.json']);inputs=json.loads(data['physical/INPUTS.json'])
 check(r['status']=='PASS','unfinished material physical science')
 check(inputs['inputs']==r['source_inputs'],'material input index drift')
 check(PRODUCTION<=r['source_inputs'].keys(),'material production not executed')
 for p,h in r['source_inputs'].items():check(sha((ROOT/p).read_bytes())==h,'stale material executed input '+p)
 check(len(inputs['providers'])==len(set(inputs['providers'])),'duplicate material provider')
 rows=r['results'];identity=lambda x:(x['opt'],x['driver'],x['moisture'],x['mode'])
 keys={identity(x)for x in rows}
 old=capsule_at_base();prior=json.loads(old['physical/RESULTS.json'])
 expected={identity(x)for x in prior['results']}|{(o,n,'neutral','continuous')for o in (0,2)for n in ('material_rooted7','material_rooted8')}
 check(keys==expected and len(keys)==len(rows),'incomplete or duplicate material native matrix')
 hashes={identity(x):x['stdout_sha256']for x in rows}
 for x in prior['results']:check(hashes[identity(x)]==x['stdout_sha256'],'incumbent native output changed '+str(identity(x)))
 for row in rows:
  check(row['returncode']==0,'failed material native program')
  outs=[b for p,b in data.items()if p.startswith('physical/')and p.endswith('.stdout')and sha(b)==row['stdout_sha256']]
  check(bool(outs),'missing material raw stdout')
  check(any(Path(e['command'][0]).name=='test-'+row['driver']and '/o'+str(row['opt'])+'/'in e['command'][0]and
    e['command'][-2:]==[row['mode'],row['moisture']]and e['stdout_sha256']==row['stdout_sha256']for e in r['events']),
    'material native matrix row not bound to executed command')
  k=identity(row);check(hashes[(2-k[0],*k[1:])]==row['stdout_sha256'],'material O0/O2 drift')
  if row['driver'].startswith('material_rooted'):
   for marker in [b'MC_IRR01_MATERIAL_DCS1_ACCEPTED_ROOT_RAIN_MASS_RESTART=PASS',b'DAILY_DENSITY_ACTUAL_RICHARDS_SOURCE_RESTART=PASS',b'CROP_FILE_WEATHER_PRODUCTION=PASS']:
    check(marker in outs[0],'material physical/root/restart assertions absent')
   check(outs[0].count(b'MATERIAL_DAILY_GIFT=')==28,'material daily independent oracle incomplete')
 for n,e in enumerate(r['events']):
  check(e['returncode']==0,'failed material execution event')
  for stream in ['stdout','stderr']:
   names=[p for p in data if p.startswith('physical/'+f'{n:05d}-')and p.endswith('.'+stream)]
   check(len(names)==1,'material raw event absent')
   if stream+'_sha256'in e:check(sha(data[names[0]])==e[stream+'_sha256'],'material raw event drift')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked material compiler')
 for p,h in r['generated_inputs'].items():check(sha(data['physical/'+p])==h,'material generated input drift '+p)
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from root_material_cycle_driver import prepare
 with tempfile.TemporaryDirectory(prefix='swap5-material-proof-')as tmp:
  for n,c,nodes in [('material_rooted7',7,1),('material_rooted8',8,3)]:
   p=prepare(ROOT,Path(tmp)/(n+'.f90'),c,nodes)
   check(p.read_bytes()==data['physical/'+n+'.f90'],'unexecuted material discriminator '+n)
 leaf=json.loads(data['leaf/RESULTS.json'])
 check(leaf['status']=='PASS'and len(leaf['records'])==2,'unfinished material leaf')
 check({x['optimization']for x in leaf['records']}=={0,2},'material leaf optimization missing')
 for e in leaf['events']:
  check(e['returncode']==0,'failed material leaf command')
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked material leaf compiler')
 for row in leaf['records']:
  check(row['case']=='irrigation_material','wrong material leaf')
  for p,h in row['inputs'].items():check(sha((ROOT/p).read_bytes())==h,'stale material leaf input '+p)
  outs=[b for p,b in data.items()if p.startswith('leaf/')and p.endswith('.stdout')and sha(b)==row['stdout_sha256']]
  check(bool(outs)and b'IRR_ROOT_MATERIAL_PARTIAL_CELL_MVG_INVALID_ABA=PASS'in outs[0],'material leaf raw proof absent')
 check(b'MC_IRR01_LITERAL_DAILY_RAIN_O0_O2=PASS'in data['literal.log'],'literal daily rain proof missing')
 return r
def incumbent():
 base=ROOT.parent/'irr-material-incumbent-7f5441c5'
 if not base.exists():subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip()==BASE,'material incumbent moved')
 check(not subprocess.check_output(['git','status','--porcelain'],cwd=base,text=True).strip(),'material incumbent dirty')
 p=subprocess.run([sys.executable,'-B','tests/nut-crop/verify_b111_request_successor.py'],cwd=base,capture_output=True,text=True)
 check(p.returncode==0,'original material incumbent proof failed '+p.stderr[-1000:]);r=json.loads(p.stdout);check(r['qualified'],'material incumbent not qualified');return r
def verify_qualification():
 s=verify_source();check(record()['phase']in ['SCIENCE_COMPLETE_ADMISSION_CONTROLS_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED'],'material science unfinished')
 validate_science(evidence());old=incumbent()
 return {**s,'qualified':True,'incumbent':old,'scope':record()['scope'],'preservation':'EXACT_ORIGINAL_BODIES_AND_UNCHANGED_NATIVE_OUTPUTS_PLUS_ACTUAL_MATERIAL_ROOT_DCS1_MASS_RESTART','full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if '--source-only'in sys.argv else verify_qualification(),indent=2))
