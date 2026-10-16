"""Full existing TCS6 admission: pinned production, executed native science and incumbent proof."""
from pathlib import Path
from functools import lru_cache
import base64,hashlib,io,json,subprocess,sys,tarfile,tempfile,os,re
os.environ["PYTHONDONTWRITEBYTECODE"]="1"
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='5d2518abd2b285b13f9b5f7d2177918589fd7abc'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/adapter/mod_crop_soil_n_joint_restart_file.f90','src/adapter/mod_swap_daily_weather_file_adapter.f90','src/crop/mod_crop_et_canopy_view_provider.f90','src/crop/mod_wofost_prepare_assimilation.f90','src/crop/mod_wofost_rate_table.f90','src/process/mod_scheduled_irrigation_management_policy.f90','src/runtime/mod_fmr_irrigation_allocation_binding.f90','src/runtime/mod_fmr_production_application_bootstrap.f90','src/runtime/mod_fmr_wofost_accepted_window_lineage.f90'}
def check(ok,label):
 if not ok:raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['tcs6_completion_20261016']
def verify_source(git_reader=None):
 if (ROOT/'tests/mc-irr01/verify_availability_successor.py').is_file():
  from verify_availability_successor import verify_source as successor
  return successor(git_reader)
 g=git if git_reader is None else git_reader;r=record()
 check(r['admission_baseline']==BASE,'TCS6 baseline drift');g('merge-base','--is-ancestor',BASE,'HEAD')
 dirty=g('status','--porcelain','--untracked-files=all','--',*SURFACE).splitlines()
 check(not [p for p in dirty if not re.fullmatch(r'\?\? .*/__pycache__/[^/]+\.pyc',p)],'dirty TCS6 scientific surface')
 rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
 check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign TCS6 science')
 check({p for p in rows if p.startswith('src/')}==PRODUCTION,'TCS6 production scope')
 for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'TCS6 postimage '+p)
 check(g('rev-parse','HEAD:src')==r['source_tree'],'TCS6 source tree')
 check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'TCS6 reference drift')
 flags={n:True for n in ('multilevel_divdra_successor','reference_leaf_successor','classic_annual_successor','signed_divdra_successor','reproductive_successor','pond_successor','dynamic_pond_successor','persistent_surface_restart_successor','material_root_irrigation_successor','b111_request_successor','managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor','swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor')}
 return dict(baseline=BASE,source_tree=r['source_tree'],current_source_tree=r['source_tree'],tcs6_successor=True,qualified=False,admitted=False,**flags)
def evidence():
 d=record()['science_archive'];raw=base64.b64decode((ROOT/d['path']).read_bytes());check(sha(raw)==d['decoded_sha256'],'TCS6 capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate TCS6 member')
  check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe TCS6 member')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete TCS6 capsule')
 for p,h in manifest.items():check(sha(data[p])==h,'TCS6 member '+p)
 return data
def inputs(mapping):
 for p,h in mapping.items():
  check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe TCS6 input')
  raw=(ROOT/p).read_bytes()
  if sha(raw)!=h:
   projection=record()['inherited_input_projections'].get(p)
   check(projection is not None and projection['old_sha256']==h and projection['new_sha256']==sha(raw),'stale TCS6 input '+p)
   check(p=='src/process/mod_drainage_spatial_distribution.f90','unreviewed inherited input')
   lines=raw.decode().splitlines(True)
   for q in reversed(projection['insertions']):
    a,b=q['range'];check(lines[a:b]==q['current']and not q['baseline'],'altered incumbent drainage body');lines[a:b]=[]
   check(sha(''.join(lines).encode())==h,'inexact unchanged drainage body')
  else:check(sha(raw)==h,'stale TCS6 input '+p)

def raw_events(data,prefix,events):
 for i,e in enumerate(events):
  check(e['returncode']==0,'failed TCS6 event')
  for stream in ('stdout','stderr'):
   candidates=[v for p,v in data.items()if p.startswith(prefix+'/'+f'{i:05d}-')and p.endswith('.'+stream)]
   if not candidates:candidates=[v for p,v in data.items()if p==prefix+'/'+e.get(stream,'')]
   check(len(candidates)==1,'missing raw '+prefix+str(i)+stream)
   if stream+'_sha256'in e:check(sha(candidates[0])==e[stream+'_sha256'],'raw digest '+prefix)
  if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked TCS6 compile')
def validate_science(data):
 r=json.loads(data['physical/RESULTS.json']);check(r['status']=='PASS'and r['head']==record()['execution_commit'],'unfinished/wrong TCS6 physical science');inputs(r['source_inputs'])
 check(PRODUCTION<=set(r['source_inputs']),'untested changed production owner')
 for p,h in r['source_inputs'].items():
  if p.startswith('src/')and p!='src/process/mod_drainage_spatial_distribution.f90':
   text=(ROOT/p).read_text().lower()
   check('distribute_multilevel_signed_divdra'not in text,'unexecuted new multilevel caller')
   joined=re.sub(r'&\s*\n\s*&?', '',text)
   for statement in joined.splitlines():
    if re.match(r'\s*use\s+mod_drainage_spatial_distribution\b',statement):
     check('only:'in statement.replace(' ','')and 'drainage_multilevel_diagnostics_t'not in statement,'unqualified drainage import')

 check(len(r['costs'])==2 and all(x['providers']==295 and x['provider_compiles']==295 for x in r['costs']),'incomplete fresh application provider build')
 expected={(o,n,'neutral','continuous')for o in (0,2)for n in ('weekly_dcs1','weekly_dcs2','weekly_nontrigger')}
 expected|={(o,n,p,m)for o in (0,2)for n in ('weekly_dcs1','weekly_dcs2','weekly_nontrigger')for p in ('neutral','hydraulic')for m in ('native-write','native-resume','native-write-active','native-resume-active')}
 ident=lambda x:(x['opt'],x['driver'],x['moisture'],x['mode'])
 check(len(r['results'])==54 and {ident(x)for x in r['results']}==expected,'missing/duplicate TCS6 trajectories')
 native=[e for e in r['events']if Path(e['command'][0]).name.startswith('test-')and '-c'not in e['command']and 'native-reject'not in e['command']and 'native-reject-config'not in e['command']]
 check(len(native)==54,'missing actual TCS6 trajectory commands')
 for row in r['results']:
  check(row['returncode']==0,'failed TCS6 trajectory')
  matches=[e for e in native if Path(e['command'][0]).name=='test-'+row['driver']and '/o'+str(row['opt'])+'/'in e['command'][0]and e['command'][-2:]==[row['mode'],row['moisture']]]
  check(len(matches)==1 and matches[0]['stdout_sha256']==row['stdout_sha256'],'unexecuted TCS6 result')
  other=next(x for x in r['results']if ident(x)==(2-row['opt'],*ident(row)[1:]));check(other['stdout_sha256']==row['stdout_sha256'],'TCS6 O0/O2 drift')
 raw_events(data,'physical',r['events'])
 for p,h in r['generated_inputs'].items():check(sha(data['physical/'+p])==h,'stale generated TCS6 input '+p)
 sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from tcs6_cycle_driver import prepare_native
 with tempfile.TemporaryDirectory()as tmp:
  for n,dcs,trigger in [('weekly_dcs1',1,True),('weekly_dcs2',2,True),('weekly_nontrigger',2,False)]:
   generated=prepare_native(ROOT,Path(tmp)/(n+'.f90'),dcs,trigger);check(generated.read_bytes()==data['physical/'+n+'.f90'],'unexecuted TCS6 generator')
 for o in (0,2):
  for n in ('weekly_dcs1','weekly_dcs2','weekly_nontrigger'):
   for phase,arg in [('morning','neutral'),('dayend','hydraulic')]:
    files=[data[f'physical/o{o}/test-{n}.{phase}.{s}']for s in ('full','opaque','resumed','active.resumed')]
    check(all(b==files[0]for b in files),'TCS6 native endpoint drift')
    dec=json.loads(data[f'physical/DECODER_{o}_{n}_{arg}.json']);check(all(x['returncode']==0 for x in dec)and len(dec)==(16 if n=='weekly_nontrigger'else 18),'missing TCS6 native negatives')
    check(files[0]==data[f'physical/o{2-o}/test-{n}.{phase}.full'],'TCS6 optimization endpoint drift')
    cases={'bad_crc','truncated','wrong_tag','trailing','different_source','irrigation_schema','future_day','nan_clock','infinite_clock','wrong_clock','nan_delivery','negative_delivery','week7','negative_week','overflow_week','different_config'}
    if n!='weekly_nontrigger':cases|={'provider_fraction','nan_provider_fraction'}
    check({x['case']for x in dec}==cases,'duplicate/missing TCS6 invalid case')
    for row in dec:
     tail=f'{n}-{phase}-{row["case"]}.bad'if row['case']!='different_config'else f'test-{n}.{phase}.checkpoint'
     check(sha(data[f'physical/o{o}/'+tail])==row['input_sha256'],'unbound decoder input')
     es=[e for e in r['events']if Path(e['command'][0]).name=='test-'+n and '/o'+str(o)+'/'in e['command'][0]and Path(e['command'][-1]).name==tail and arg in e['command']]
     check(len(es)==1 and es[0]['returncode']==0 and es[0]['stdout_sha256']==row['stdout_sha256'],'unexecuted decoder negative')

 d=json.loads(data['direct/RESULTS.json']);check(d['status']=='PASS'and len(d['results'])==2,'unfinished TCS6 literal contract');inputs(d['inputs']);raw_events(data,'direct',d['events'])
 check(sha(data['direct/literal_tcs6.f90'])==d['oracle_sha256'],'TCS6 literal drift')
 w=json.loads(data['domain/RESULTS.json']);check(w['status']=='PASS_SOURCE_UNIT_DOMAIN_CORRECTION_AND_ORIGINAL_DOMAIN_EXACT'and len(w['results'])==4,'unfinished source-unit preservation');inputs(w['inputs']);raw_events(data,'domain',w['events'])
 p=json.loads(data['preservation/RESULTS.json']);check(p['status']=='PASS'and len(p['rows'])==6,'unfinished affected owner preservation');inputs(p['inputs']);raw_events(data,'preservation',p['events'])
 projections=json.loads(data['review/projections.json']);check(set(projections)=={p for p,v in record()['postimages'].items()if v['status']=='M'},'incomplete TCS6 incumbent review')
 for p,patches in projections.items():
  lines=(ROOT/p).read_text().splitlines(True)
  for q in reversed(patches):
   a,b=q['range'];check(lines[a:b]==q['current'],'changed reviewed TCS6 hunk');lines[a:b]=q['baseline']
  check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'incumbent body projection drift '+p)
 return dict(trajectories=54,decoder_negatives=208,direct_literal=True,source_unit_preservation=True,affected_owners=6,continuous_opaque_fresh_native_exact=True)
@lru_cache(None)
def incumbent():
 r=record()
 if 'incumbent_proof_sha256'in r:
  raw=evidence()['review/tcs6-incumbent-proof.json'];check(sha(raw)==r['incumbent_proof_sha256'],'incumbent proof drift');old=json.loads(raw)
  check(old['qualified']and old['classic_annual_successor']and old['current_source_tree']==git('rev-parse',BASE+':src')and old['authority_commit']==BASE and old['authority_tree']==git('rev-parse',BASE+'^{tree}')and old['annual_source_evidence_revalidated']and old['multilevel_source_evidence_revalidated'],'incumbent proof scope')
  return old
 root=ROOT.parent/('tcs6-incumbent-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'TCS6 incumbent moved')
 import os
 env=os.environ.copy();i=int(env.get('GIT_CONFIG_COUNT','0'));env['GIT_CONFIG_COUNT']=str(i+1);env['GIT_CONFIG_KEY_'+str(i)]='core.abbrev';env['GIT_CONFIG_VALUE_'+str(i)]='8'
 p=subprocess.run([sys.executable,'-B','tests/nut-crop/verify_reproductive_successor.py'],cwd=root,capture_output=True,text=True,env=env)
 check(p.returncode==0,'TCS6 incumbent proof failed '+p.stderr[-1200:]);r=json.loads(p.stdout);check(r['qualified'],'unqualified incumbent');return r
def run_multilevel_predecessor_controls():
 # Execute the unchanged original six assertions at the admitted snapshot.
 root=ROOT.parent/('tcs6-multilevel-controls-'+BASE[:12])
 if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
 check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'multilevel controls moved')
 env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1','PYTHONPYCACHEPREFIX':str(ROOT.parent/'tcs6-control-python-cache')}
 p=subprocess.run([sys.executable,'-B','tests/fmig431/verify_multilevel_divdra_successor.py','--self-test'],cwd=root,capture_output=True,text=True,env=env)
 check(p.returncode==0 and 'MULTILEVEL_EVIDENCE_CORRUPTION_CONTROLS=6'in p.stdout,'original multilevel controls failed '+p.stderr[-1500:])
 print(p.stdout,end='')
def verify_qualification():
 if (ROOT/'tests/mc-irr01/verify_availability_successor.py').is_file():
  from verify_availability_successor import verify_qualification as successor
  return successor()
 s=verify_source();check(record()['phase']in ('SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_FULL_NOT_ADMITTED','CANONICALLY_ADMITTED_FULL'),'TCS6 unfinished')
 science=validate_science(evidence());old=incumbent()
 return {**old,**s,'qualified':True,'incumbent':old,'science':science,'full_capability':True,'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
