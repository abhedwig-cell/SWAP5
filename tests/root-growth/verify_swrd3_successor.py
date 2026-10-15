#!/usr/bin/env python3
"""Exact SWRD3 source and executed production proof; admission remains separate."""
from pathlib import Path
import argparse,base64,hashlib,io,json,math,os,subprocess,sys,tarfile
ROOT=Path(__file__).resolve().parents[2]
BASE='3b661766dc59298a7f541c970c2d3a55602d926c'
STATUS='integration/audits/MC_CROP01_TRAJECTORY3_ROOT_GROWTH_STATUS.json'
BOOT='src/runtime/mod_fmr_production_application_bootstrap.f90'
NEW='src/runtime/mod_fmr_biomass_root_uptake_input.f90'
FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
MARKERS={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','oxygen':b'CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS','co2':b'CROP_CO2_PHYSICAL_GROWTH_UPTAKE_RESTART=PASS','daily_demand':b'MC_MET01_AUTHENTIC_DAILY_DEMAND_RETRY_RESTART_MASS=PASS','raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','swrd3':b'SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS','swrd3_off':b'SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS'}
def check(ok,label):
 if not ok:raise ValueError(label)
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def verify_source(git_reader=None):
 if (ROOT/'src/crop/mod_wofost81_harvest_materials.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/crop-harvest'));import verify_harvest_successor as harvest
  return harvest.verify_source(git_reader)
 g=git if git_reader is None else git_reader;s=json.loads((ROOT/STATUS).read_text())
 check(s['baseline']==BASE,'wrong SWRD3 baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
 check(not g('status','--porcelain','--','src','tests','tools','reference'),'dirty scientific surface')
 expected=s['swrd3_postimages'];rows={r.split('\t')[1]:r.split('\t')[0]for r in g('diff','--name-status',BASE,'HEAD','--','src','tests','tools','reference').splitlines()}
 check(rows=={p:v['status']for p,v in expected.items()},'foreign SWRD3 delta')
 calendar_production={'src/process/mod_soil_n_amendment_calendar.f90','src/crop/mod_crop_soil_n_calendar_day.f90','src/runtime/mod_fmr_crop_soil_n_calendar_application.f90','src/process/mod_soil_n_amendment_input.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90','src/runtime/mod_fmr_b111_reactive_n_joint_application.f90','src/runtime/mod_fmr_serialized_reference_backend.f90','src/process/mod_soil_n_profile_temperature.f90','src/runtime/mod_fmr_soil_n_accepted_temperature.f90','src/runtime/mod_fmr_crop_soil_n_thermal_application.f90'}
 check({p for p in expected if p.startswith('src/')}=={BOOT,NEW}|calendar_production,'production scope widened')
 canonical=s['reconciliation_canonical'];g('merge-base','--is-ancestor',canonical,'HEAD')
 for p in calendar_production:check(g('rev-parse','HEAD:'+p)==g('rev-parse',canonical+':'+p),'canonical calendar production drift '+p)
 for p,v in expected.items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'SWRD3 postimage drift '+p)
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'reference drift')
 return dict(baseline=BASE,source_tree=g('rev-parse','HEAD:src'),postimages={p:v['blob']for p,v in expected.items()if p.startswith('src/')},co2_successor=True,swrd3_successor=True,qualified=False,admitted=False)
def capsule(record):
 raw=base64.b64decode((ROOT/record['path']).read_bytes());check(sha(raw)==record['decoded_sha256'],'SWRD3 capsule corruption')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  members=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in members),'unsafe raw member')
  check(len({m.name for m in members})==len(members),'duplicate raw member');d={m.name:a.extractfile(m).read()for m in members}
 manifest=json.loads(d.pop('MANIFEST.json'));check(set(manifest)==set(d),'manifest incomplete')
 for p,h in manifest.items():check(sha(d[p])==h,'raw digest drift '+p)
 return d
def read_evidence():
 s=json.loads((ROOT/STATUS).read_text());d=capsule(s['swrd3_science_evidence']);probe=capsule(s['swrd3_probe_evidence'])
 check(not set(d)&set(probe),'duplicate supplemental members');d.update(probe);return d
def compatible_default_dependency(path,expected):
 # Exact, canonical-reviewed absent/false projection; never dispatch qualification
 # here, because this helper is used inside the combined proof validator.
 if not (ROOT/'integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json').exists():return False
 sys.path.insert(0,str(ROOT/'tests/nut-thermal'))
 from thermal_default_projection import PROJECTORS
 if path not in PROJECTORS:return False
 old=subprocess.check_output(['git','show','cd64c5044a29643a068c6151720f76b2e70f570d:'+path],cwd=ROOT)
 check(sha(old)==expected,'foreign default dependency '+path)
 check(PROJECTORS[path]((ROOT/path).read_text()).encode()==old,'default projection drift '+path)
 return True
def dependencies(inputs,guard_rebinding=False):
 s=json.loads((ROOT/STATUS).read_text())
 allowed={'tests/crop-co2/verify_co2_successor.py','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh','tests/nut-calendar/verify_calendar_successor.py','tests/nut-calendar/check_calendar_controls.py'}
 for p,h in inputs.items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe dependency '+p)
  actual=sha((ROOT/p).read_bytes())
  if actual==h:continue
  if compatible_default_dependency(p,h):continue
  rec=s.get('input_guard_rebinding',{}).get(p,{})
  check(guard_rebinding and p in allowed and rec=={'before':h,'after':actual},'stale dependency '+p)
def native_raw(d,h):
 raw=[b for p,b in d.items()if p.endswith('.stdout')and sha(b)==h];check(bool(raw),'raw native output absent');return raw[0]
def validate_physical(d,source):
 r=json.loads(d['physical/RESULTS.json']);i=json.loads(d['physical/INPUTS.json']);dependencies(r['source_inputs'])
 check(r['status']=='PASS'and r['source_inputs']==i['inputs'],'unfinished/contradictory physical evidence')
 check({BOOT,NEW}<=r['source_inputs'].keys(),'production not compiled')
 check(i['flags']==FLAGS,'physical flags drift')
 providers=subprocess.check_output([sys.executable,'-B',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all','tests/fsi/fsi04_real_headcalc_stubs.f90',BOOT,'src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
 check(i['providers']==providers and set(providers)<=r['source_inputs'].keys(),'provider closure drift')
 for p,h in i['generated'].items():check(sha(d['physical/'+p])==h,'generated oracle/driver drift '+p)
 expected={(o,n,mo,mode)for o in (0,2)for n in MARKERS for mo in (['neutral','dry','hydraulic']if n=='weather'else['neutral'])for mode in ['continuous','restart']}
 rows=r['results'];keys=[(x['opt'],x['driver'],x['moisture'],x['mode'])for x in rows]
 check(len(rows)==36 and len(set(keys))==36 and set(keys)==expected,'physical coverage incomplete')
 hashes={}
 for row,key in zip(rows,keys):
  check(row['returncode']==0 and math.isfinite(row['wall_seconds'])and row['wall_seconds']>0,'failed native row')
  raw=native_raw(d,row['stdout_sha256']);check(MARKERS[row['driver']]in raw,'scientific marker absent')
  hashes[key]=row['stdout_sha256']
 for o,n,mo,mode in expected:check(hashes[(o,n,mo,mode)]==hashes[(2-o,n,mo,mode)]==hashes[(o,n,mo,'restart'if mode=='continuous'else'continuous')],'optimization/restart drift')
 natives=[e for e in r['events']if Path(e['command'][0]).name.startswith('test-')];nkeys=[]
 for e in natives:
  cmd=e['command'];check(len(cmd)==7 and Path(cmd[0]).parent.name in ['o0','o2'],'native command scope')
  key=(int(Path(cmd[0]).parent.name[1:]),Path(cmd[0]).name.removeprefix('test-'),cmd[-1],cmd[-2]);nkeys.append(key)
  check(key in hashes and e['stdout_sha256']==hashes[key],'native event/result drift')
 check(len(nkeys)==36 and set(nkeys)==expected,'native execution incomplete')
 for e in r['events']:
  check(e['returncode']==0 and math.isfinite(e['wall_seconds'])and e['wall_seconds']>=0,'failed raw event')
  if '-c'in e['command']:check(e['command'][1:1+len(FLAGS)]==FLAGS and e['command'][1+len(FLAGS)]in ['-O0','-O2'],'unchecked compilation')
 # Every incumbent native record is compared to its immutable admitted output.
 sys.path.insert(0,str(ROOT/'tests/crop-cycle'))
 from verify_oxygen_successor import read_capsule as prior_capsule
 old_status=json.loads(git('show',BASE+':integration/audits/MC_CROP01_TRAJECTORY2_CO2_STATUS.json'))
 old,_=prior_capsule(old_status['evidence']);prior=json.loads(old['physical/RESULTS.json'])
 prior_hashes={(x['opt'],x['driver'],x['moisture'],x['mode']):x['stdout_sha256']for x in prior['results']}
 check(len(prior_hashes)==28 and all(hashes[k]==h for k,h in prior_hashes.items()),'immutable incumbent output drift')
 probe=json.loads(d['probe/RESULTS.json']);pi=json.loads(d['probe/INPUTS.json'])
 check(probe['status']=='PASS'and probe['source_inputs']==pi['inputs'],'supplemental gate unfinished');dependencies(probe['source_inputs'])
 check(pi['flags']==FLAGS and pi['providers']==providers,'supplemental provider/flags drift')
 for p,h in pi['generated'].items():check(sha(d['probe/'+p])==h,'supplemental generated input drift')
 wanted={(o,n,mode)for o in (0,2)for n in ['swrd3_probe','swrd3_probe_off']for mode in ['continuous','restart']}
 probe_rows=probe['results'];pkeys=[(x['opt'],x['driver'],x['mode'])for x in probe_rows]
 check(len(pkeys)==8 and set(pkeys)==wanted,'actual anaerobic matrix incomplete');ph={}
 for row,key in zip(probe_rows,pkeys):
  check(row['returncode']==0 and math.isfinite(row['wall_seconds'])and row['wall_seconds']>0,'probe native failed')
  raw=native_raw(d,row['stdout_sha256']);check(MARKERS['swrd3']in raw,'probe full scientific assertions absent')
  if row['driver']=='swrd3_probe':
   check(b'SWRD3_ACTUAL_RICHARDS_ANAEROBIC_ROOT_DEATH=PASS'in raw,'actual suppression absent')
   import re
   factors=[float(x)for x in re.findall(rb'SWRD3_PROBE_ACCEPTED_OXYGEN=\s*(\S+)',raw)]
   check(len(factors)==20 and all(math.isfinite(x)and 0<=x<1 for x in factors),'probe accepted oxygen evidence absent')
  else:check(b'SWRD3_ACTUAL_RICHARDS_ANAEROBIC_ROOT_DEATH=PASS'not in raw,'OFF unexpectedly suppresses growth')
  ph[key]=row['stdout_sha256']
 for o,n,mode in wanted:check(ph[(o,n,mode)]==ph[(2-o,n,mode)]==ph[(o,n,'restart'if mode=='continuous'else'continuous')],'probe optimization/restart drift')
 pn=[e for e in probe['events']if Path(e['command'][0]).name.startswith('test-')]
 check(len(pn)==8,'probe native commands missing')
 for e in probe['events']:
  check(e['returncode']==0 and math.isfinite(e['wall_seconds'])and e['wall_seconds']>=0,'probe failed raw event')
  if '-c'in e['command']:check(e['command'][1:1+len(FLAGS)]==FLAGS and e['command'][1+len(FLAGS)]in ['-O0','-O2'],'probe unchecked flags')
 for e in pn:
  cmd=e['command'];key=(int(Path(cmd[0]).parent.name[1:]),Path(cmd[0]).name.removeprefix('test-'),cmd[-2])
  check(len(cmd)==7 and key in ph and e['stdout_sha256']==ph[key],'probe native identity drift')
 direct=json.loads(d['direct/result.json']);check(direct['status']=='PASS','direct unfinished');dependencies(direct['inputs'])
 check(len(direct['runs'])==20 and {x['opt']for x in direct['runs']}=={0,2},'focused original coverage')
 return {**source,'physical_programs':44,'qualified':False,'highest':'NOT_SELECTED_POLICY'}
def baseline_root():
 p=ROOT.parent/('swrd3-baseline-'+BASE[:12])
 if not p.exists():subprocess.run(['git','worktree','add','--detach',str(p),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=p,text=True).strip()==BASE,'baseline moved')
 check(not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=p,text=True).strip(),'baseline dirty');return p
def baseline_command(path,extra=()):
 p=baseline_root();r=subprocess.run([sys.executable,'-B',str(p/path),*extra],cwd=p,check=True,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'});return json.loads(r.stdout)
def verify_physical():
 if (ROOT/'src/crop/mod_wofost81_harvest_materials.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/crop-harvest'));import verify_harvest_successor as harvest
  return harvest.verify_physical()
 return validate_physical(read_evidence(),verify_source())
def verify_qualification():
 if (ROOT/'src/crop/mod_wofost81_harvest_materials.f90').exists():
  sys.path.insert(0,str(ROOT/'tests/crop-harvest'));import verify_harvest_successor as harvest
  return harvest.verify_qualification()
 source=verify_physical();s=json.loads((ROOT/STATUS).read_text());d=capsule(s['swrd3_owner_evidence'])
 native_source={**source,'source_tree':s['qualified_native_source_tree']}
 r=json.loads(d['additional/RESULTS.json']);check(r['status']=='PASS'and r['source']['source_tree']==native_source['source_tree'],'owner source/status drift')
 sys.path.insert(0,str(ROOT/'tests/mc-met01'));from run_joint_owner_additional import STEPS
 check([(x['name'],x['command'])for x in r['steps']]==STEPS,'owner matrix incomplete')
 for x in r['steps']:check(x['exit']==0 and sha(d['additional/'+x['name']+'.stdout'])==x['stdout_sha256'],'owner raw failure/corruption')
 dependencies(json.loads(d['owner-inputs.json']),guard_rebinding=True)
 # Fresh current ABI actual senescence/material/crop/N execution, not baseline PASS reuse.
 n=json.loads(d['nut/result.json']);check(n['status']=='PASS'and n['source_tree']==native_source['source_tree'],'current N owner science absent');dependencies(n['input_sha256'])
 old_record=json.loads(git('show',BASE+':integration/audits/MC_NUT01_SENESCENCE_CYCLE_STATUS.json'))['evidence']
 old=capsule({'path':old_record['path'],'decoded_sha256':old_record['sha256']});prior=json.loads(old['result.json'])
 events=json.loads(d['nut/events.json'])
 for e in events:
  check(e['returncode']==0 and math.isfinite(e['seconds'])and e['seconds']>=0,'failed N event')
  if e['category']=='compile':check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked N compile')
  for stream in ['stdout','stderr']:check(sha(d['nut/'+e[stream+'_file']])==e[stream+'_sha256'],'N raw event corruption')
 check(n['incumbent_endpoints_identical']is True,'original N endpoints changed')
 for opt in ['O0','O2']:
  check(len(n['runs'][opt]['drivers'])==8,'N owner matrix incomplete')
  for name,row in n['runs'][opt]['drivers'].items():
   check('=PASS'in row['stdout'],'N owner assertions absent')
   check(row['stdout']==prior['runs'][opt]['drivers'][name]['stdout'],'original N driver scientific output changed')
   if name.endswith('_joint'):
    check(row['endpoint_sha256']==prior['runs'][opt]['drivers'][name]['endpoint_sha256'],'immutable N endpoint drift')
    prefix={'test_material_joint':'','test_material_environment_joint':'environment-','test_senescence_joint':'senescence-'}[name]
    for path in ['expected.bin','fresh.bin','expected.bin.opaque']:check(sha(d['nut/'+opt+'/'+prefix+path])==row['endpoint_sha256'],'N continuation payload drift')
   if name.endswith('_joint'):check(row['endpoint_sha256']==n['runs']['O0']['drivers'][name]['endpoint_sha256'],'N endpoint optimization drift')
 # Both scientific routes are required. Direct validation avoids recursive
 # successor dispatch; original baseline qualification remains mandatory.
 sys.path.insert(0,str(ROOT/'tests/nut-calendar'));import verify_calendar_successor as calendar
 calendar.validate(calendar.read_evidence(),native_source)
 sys.path.insert(0,str(ROOT/'tests/nut-input'));import verify_input_successor as amendment_input
 amendment_input.validate(amendment_input.read_evidence(),source)
 sys.path.insert(0,str(ROOT/'tests/nut-thermal'));import verify_thermal_successor as thermal
 thermal.compatibility()
 thermal_status=thermal.v.source();thermal.v.validate(thermal.v.read(thermal_status),thermal_status)
 check(amendment_input.baseline_command('tests/nut-calendar/verify_calendar_successor.py')['qualified'],'original calendar authority failed')
 baseline_command('tests/nut-senescence/verify_senescence_successor.py')
 return {**source,'qualified':True,'calendar_successor':True,'input_successor':True,'thermal_successor':True}
def incumbent(mode='qualification'):
 verify_qualification()
 return {**baseline_command('tests/nut-senescence/verify_senescence_successor.py',['--incumbent',mode]),'swrd3_successor':True,'swrd3_source_tree':git('rev-parse','HEAD:src')}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-only',action='store_true');p.add_argument('--physical-only',action='store_true');p.add_argument('--incumbent',choices=['source','physical','qualification']);a=p.parse_args()
 print(json.dumps(incumbent(a.incumbent)if a.incumbent else verify_source()if a.source_only else verify_physical()if a.physical_only else verify_qualification(),indent=2))
