"""Current native daily crop/root/solute composition, with exact incumbent scope."""
import base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='636760624e930f11517a42707fd16d885902c045'
CONCURRENT='f2b7be23dffd5067797623ac5ad26ced29718b5e'
NUT_OWNER='integration/audits/verify_nut_thermal_output.py'
NUT_STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
STATUS='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PARENT='integration/audits/verify_native_simple_crop.py'
SELF='integration/audits/verify_crop_root_joint.py'
KEY='root_joint_successor'
SCIENCE=['src','app','tools','tests','examples','.github','reference','integration/audits','integration/performance','integration/diagnostics']
def sha(raw):return hashlib.sha256(raw).hexdigest()
def require(ok,message):
 if not ok:raise ValueError(message)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):
 return json.loads(reader(STATUS))['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor'][KEY]
def parent_projection(path=PARENT):
 text=subprocess.check_output(['git','show',CONCURRENT+':'+path],cwd=ROOT).decode()
 condition="'evidence' in record().get('root_joint_successor', {})" if path==PARENT else "'evidence' in json.loads((ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json').read_text())['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor'].get('root_joint_successor',{})"
 indent='    ' if path==PARENT else ' '
 for name,args in [('source','reader,changed'),('verify',''),('self_test','')]:
  offset=text.index('\n',text.index('def '+name+'('))+1
  call="__import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")"
  hook=indent+"if "+condition+":\n"
  if path==PARENT:hook+=indent*2+"return "+call+"\n"
  elif name=='source':hook+="  "+call+"\n  return record(reader)\n"
  elif name=='verify':hook+="  composed="+call+"\n  return dict(composed['current_concurrent_nut'],composed_owner=composed)\n"
  else:hook+="  controls="+call+"\n  return dict(status='THERMAL_OUTPUT_GUARD_CONTROLS_PASS',count=len(controls),controls=controls,predecessor_controls=27,thermal_predecessor_controls=21,composed_owner='integration/audits/verify_crop_root_joint.py')\n"
  text=text[:offset]+hook+text[offset:]
 return text.encode()
def frozen_physical_reader(path):
 if path in record()['concurrent_production']:
  return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
 return (ROOT/path).read_bytes()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 if 'evidence' in record().get('substep_feedback_work',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['source'](reader,changed)
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('calendar_output_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_calendar_output.py'))['source'](reader,changed)
 r=record(reader);require(r['baseline']==BASE,'root joint baseline')
 current=json.loads(reader(STATUS));current['swp_water_successor']['daily_meteo_successor']['etref_successor']['simple_crop_preparation_successor'].pop(KEY)
 require(current==json.loads(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT)),'unrelated recovery state changed')
 for path in [PARENT,NUT_OWNER]:require(reader(path)==parent_projection(path),'incumbent assertion bodies changed '+path)
 require(r['concurrent_ref']==CONCURRENT,'concurrent source authority')
 for path in r['concurrent_paths']:
  if path in [PARENT,NUT_OWNER]:continue
  require(reader(path)==subprocess.check_output(['git','show',CONCURRENT+':'+path],cwd=ROOT),'concurrent admitted drift '+path)
 current_nut=json.loads(reader(NUT_STATUS))['extended_output_component_20261021']['thermal_output_successor_20261022']
 for path,h in current_nut['qualified_input_sha256'].items():require(sha(reader(path))==h,'current thermal NUT input '+path)
 paths=set(git('diff','--name-only',BASE,'HEAD').splitlines())-{STATUS}
 require(set(r['postimages'])==paths,'joint postimage inventory')
 for p,h in r['postimages'].items():require(sha(reader(p))==h,'joint postimage '+p)
 delta={line.split('\t')[1]:line.split('\t')[0] for line in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()}
 require(delta==r['source_delta'],'unregistered joint science delta')
 require(all(kind=='A' or p in [PARENT,STATUS,NUT_OWNER] or p in r['concurrent_paths'] for p,kind in delta.items()),'changed incumbent scientific provider')
 require(git('diff','--name-only',BASE,'HEAD','--','src').splitlines()==r['concurrent_production'],'foreign production equations changed')
 require(not git('status','--porcelain','--','src','app','tools','tests'),'dirty executable source')
 require(not git('diff','--name-only','--',*SCIENCE),'dirty tracked scientific evidence')
 if changed is not None:require(not any(p not in delta and p not in r['inherited_science_paths'] for p in changed),'foreign caller science')
 return json.loads(reader(STATUS))['swp_water_successor']
def capsule():
 e=record()['evidence'];raw=base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()),validate=True)
 require(len(raw)==e['decoded_bytes'] and sha(raw)==e['decoded_sha256'],'joint capsule bytes')
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
  members=t.getmembers();require(len(members)==e['members'] and len({m.name for m in members})==len(members),'joint census')
  require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe joint member')
  files={m.name:t.extractfile(m).read() for m in members}
 manifest=json.loads(files.pop('MANIFEST.json'));require(set(files)==set(manifest),'joint inventory')
 require(all(sha(files[p])==h for p,h in manifest.items()),'joint archive corruption')
 return files

def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
 def js(p):return json.loads(files[p])
 def rows(p):return [{k:float(v) for k,v in row.items()} for row in csv.DictReader(io.StringIO(files[p].decode()))]
 def inputs(mapping,label):
  for p,h in mapping.items():require(sha(reader(p))==h,label+' '+p)
 result=js('qualified/result.json');transaction=js('transaction/result.json')
 require(result['status']=='NATIVE_CROP_ROOT_JOINT_O0_O2_PASS' and len(result['cases'])==16 and
         len(result['events'])==86 and result['invalid_inputs']==34 and result['fresh_restarts']==16,'incomplete actual joint proof')
 inputs(result['inputs'],'joint executed test')
 current_nut=js('concurrent-owner.json');controls=js('concurrent-controls.json')
 require(current_nut['qualified'] and current_nut['status']=='THERMAL_OUTPUT_SOURCE_EVIDENCE_PASS' and
         controls['status']=='THERMAL_OUTPUT_GUARD_CONTROLS_PASS' and controls['count']==21 and len(controls['controls'])==21,'concurrent frozen owning proof')
 for event in result['events']:require((event['returncode']==0)==event['expected_success'],'failed joint process')
 require(transaction['status']=='CROP_ROOT_REAL_REJECT_RETRY_O0_O2_PASS' and len(transaction['events'])==4,'joint rejection proof')
 inputs(transaction['inputs'],'transaction input');require(all(e['returncode']==0 for e in transaction['events']),'transaction process failure')
 prep=runpy.run_path(str(ROOT/PARENT));prep_files=prep['capsule']()
 old=runpy.run_path(str(ROOT/'integration/audits/verify_swp_etref.py'));old_files=old['capsule']()
 observations=0
 for opt in ['O0','O2']:
  for kind,prefix,count in [('column','column-',194),('root-reader','root-',1)]:
   b=js(prefix+opt+'/build-complete.json');require(b==result['builds'][opt][kind] and b['status']=='BUILT','joint build identity')
   require('-'+opt in b['flags'] and '-fcheck=all' in b['flags'],'unchecked joint build')
   require(all(e['returncode']==0 for e in b['events']),'failed joint build')
   require(b.get('provider_count',b.get('application_providers'))==count,'joint measured closure')
   inputs(b['input_sha256'],'joint compiled input')
   require(not set(record()['concurrent_production']).intersection(b['input_sha256']),'concurrent output provider enters new crop closure')
   for p,h in b['generated_input_sha256'].items():require(sha(files[prefix+opt+'/'+p])==h,'joint original TTUTIL bytes')
  require(result['builds'][opt]['crop-reader']==json.loads(prep_files['final-'+opt+'/build-complete.json']),'foreign crop reader build')
  require(result['builds'][opt]['baseline-column']==json.loads(old_files['stable-'+opt+'/build-complete.json']),'foreign incumbent build')
  for name in ['dry','drought','oxygen','ponded','rain','no-salt-uptake','linear','maturity']:
   prefix='qualified/'+opt+'/'+name+'/'
   for generation in ['full','split','resumed']:
    manifest=js(prefix+generation+'/manifest.json');require(manifest['status']=='COMPLETE' and manifest['returncode']==0,'incomplete joint generation')
    require(manifest['executable_sha256']==result['builds'][opt]['column']['executable_sha256'],'joint executable binding')
    for p,h in manifest['files'].items():require(sha(files[prefix+generation+'/'+p])==h,'joint generation corruption')
   for p in ['state.csv','endpoint.csv','restart.bin']:require(files[prefix+'full/'+p]==files[prefix+'resumed/'+p],'joint fresh restart differs')
   budget=rows(prefix+'full/budget.csv');require(len(budget)==8 and rows(prefix+'resumed/budget.csv')==budget[3:],'joint continuation history')
   case=result['cases'][opt+'-'+name];require(budget==case['budget'],'joint raw budget')
   require(sha(files[prefix+'full/restart.bin'])==case['restart_sha256'],'joint restart receipt')
   for i,row in enumerate(budget):
    for substance,unit in [('water','cm'),('solute','mg_cm2')]:
     residual=row[f'{substance}_end_{unit}']-row[f'{substance}_start_{unit}']-row[f'{substance}_in_{unit}']+row[f'{substance}_out_{unit}']
     require(abs(residual)<1e-10 and abs(row[f'{substance}_residual_{unit}'])<1e-10,'joint hard balance')
    gross=row['water_end_cm']-row['water_start_cm']-case['rain_cm'][i]+row['soil_evaporation_cm']+row['pond_evaporation_cm']+row['runoff_cm']+row['actual_transpiration_cm']
    require(abs(gross)<1e-10,'gross root/atmosphere conservation')
    require(-1e-15<=row['actual_transpiration_cm']<=row['potential_transpiration_cm']+1e-12,'actual/potential root bound')
    require(abs(row['potential_transpiration_cm']-row['actual_transpiration_cm']-row['drought_reduction_cm']-row['oxygen_reduction_cm'])<1e-12,'root stress attribution')
    observations+=1
   require(sum(r['actual_transpiration_cm'] for r in budget)>0,'no actual crop water uptake')
   require(budget[0]['actual_transpiration_cm']==budget[-1]['actual_transpiration_cm']==0,'fallow uptake')
   if name=='no-salt-uptake':require(abs(budget[-1]['solute_end_mg_cm2']-budget[0]['solute_start_mg_cm2'])<1e-10,'TSCF zero exported salt')
   elif name!='rain':require(sum(r['solute_out_mg_cm2'] for r in budget)>0,'missing actual root chemical export')
   if name=='drought':require(sum(r['drought_reduction_cm'] for r in budget)>0,'drought inactive')
   if name=='oxygen':require(sum(r['oxygen_reduction_cm'] for r in budget)>0,'oxygen inactive')
   if name=='maturity':require(all(r['actual_transpiration_cm']==0 for r in budget[2:]),'harvest retained roots')
  prefix='qualified/'+opt+'/fallow/'
  for p in ['state.csv','endpoint.csv','restart.bin']:
   require(files[prefix+'new/'+p]==files[prefix+'old/'+p] and sha(files[prefix+'new/'+p])==result['fallow_preservation'][opt][p],'fallow incumbent drift')
  a,b=rows(prefix+'new/budget.csv'),rows(prefix+'old/budget.csv')
  require(len(a)==len(b)==8 and all(all(x[k]==y[k] for k in y) for x,y in zip(a,b)),'fallow accepted history drift')
  require(all(x['actual_transpiration_cm']==0 for x in a),'new fallow root sink')
  require(transaction['builds'][opt]==result['builds'][opt]['column'],'transaction provider build')
  for a,b in [('original.bin','rejected.bin'),('retry.bin','fresh.bin')]:require(files['transaction/'+opt+'/'+a]==files['transaction/'+opt+'/'+b],'root rejected/retry owner drift')
  case=transaction['cases'][opt];require(case['reused_provider_objects']==193,'transaction compile closure')
  require(sha(files['transaction/'+opt+'/original.bin'])==case['original_rejected_sha256'] and
          sha(files['transaction/'+opt+'/retry.bin'])==case['retry_fresh_sha256'],'transaction raw receipt')
 modular=js('modular/RESULTS.json');require(modular['status']=='PASS' and len(modular['records'])==4,'root modular contracts')
 require(all(e['returncode']==0 for e in modular['events']),'root modular failure')
 for r in modular['records']:
  require(r['case'] in ['root_contract','root_oxygen'] and r['optimization'] in [0,2],'root modular selection')
  inputs(r['inputs'],'root contract source')
  for p,h in r['artifact_sha256'].items():require(sha(files['modular/'+p])==h,'root modular raw artifact')
 comparison=js('input-boundary-preservation.json')
 require(comparison['status']=='INPUT_BOUNDARY_FIX_VALID_PHYSICAL_ARTIFACTS_EXACT_PASS' and
         comparison['previous_admission']=='d58d0c00e203f7135f2a3d3ff110cc6a9686d22a' and
         len(comparison['files'])==64 and comparison['application_builds_identical'],'input-boundary comparison')
 for path,h in comparison['files'].items():
  require(files['qualified/'+path]==files['diagnostics/qualified/'+path] and sha(files['qualified/'+path])==h,'valid physical route changed')
 require(observations==128,'joint day census')
 return {'qualified':True,'status':'NATIVE_DAILY_CROP_ROOT_JOINT_O0_O2_QUALIFIED','actual_daily_cases':16,
         'daily_balance_observations':128,'fresh_restarts':16,'invalid_inputs':34,'exact_fallow_artifacts':6,
         'root_chemical_reject_retry':'O0_O2_EXACT_BINARY_PASS','input_boundary_exact_artifacts':64,'full_historical_migration':False,'substep_stress_feedback':False}

def self_test():
 if 'evidence' in record().get('substep_feedback_work',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['self_test']()
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('calendar_output_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_calendar_output.py'))['self_test']()
 controls=[]
 for path in record()['postimages']:
  def altered(p):return (ROOT/p).read_bytes()+(b'corrupt' if p==path else b'')
  try:source(altered)
  except ValueError:controls.append(path)
  else:raise AssertionError('stale joint source accepted '+path)
 files=capsule()
 for path in ['qualified/result.json','qualified/O0/dry/full/budget.csv','qualified/O2/oxygen/resumed/restart.bin',
              'qualified/O0/fallow/old/endpoint.csv','transaction/O0/rejected.bin','transaction/O2/fresh.bin','root-O0/build-complete.json','modular/RESULTS.json','input-boundary-preservation.json']:
  bad=dict(files);bad[path]+=b'corrupt'
  try:validate(bad)
  except (ValueError,KeyError,json.JSONDecodeError):controls.append(path)
  else:raise AssertionError('joint raw corruption accepted '+path)
 for owner_path,member in [(PARENT,'qualified/result.json'),('integration/audits/verify_swp_etref.py','concurrent-project/result.json')]:
  owner=runpy.run_path(str(ROOT/owner_path));bad=owner['capsule']()
  arguments={'reader':frozen_physical_reader} if owner_path!=PARENT else {}
  owner['validate'](bad,**arguments);bad[member]+=b'corrupt'
  try:owner['validate'](bad,**arguments)
  except (ValueError,KeyError,json.JSONDecodeError):controls.append('incumbent:'+member)
  else:raise AssertionError('incumbent corruption accepted '+member)
 nut=runpy.run_path(str(ROOT/NUT_OWNER));nut_files=nut['capsule']();nut['validate'](nut_files)
 for member in ['thermal/O0/output.endpoint.generation','thermal/O2/output.restart.environment-after']:
  bad=dict(nut_files);bad[member]+=b'corrupt'
  try:nut['validate'](bad)
  except (ValueError,KeyError,AssertionError):controls.append('current_nut:'+member)
  else:raise AssertionError('current NUT corruption accepted '+member)
 try:source(changed={'src/foreign_root_joint.f90':'A'})
 except ValueError:controls.append('foreign scientific delta')
 else:raise AssertionError('foreign root joint source accepted')
 return controls

def verify():
 if 'evidence' in record().get('substep_feedback_work',{}):
  return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['verify']()
 if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('calendar_output_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_calendar_output.py'))['verify']()
 source();result=validate(capsule())
 parent=runpy.run_path(str(ROOT/PARENT));result['incumbent_preparation']=parent['validate'](parent['capsule']())
 old=runpy.run_path(str(ROOT/'integration/audits/verify_swp_etref.py'));result['baseline_physical_and_frozen_nut']=old['validate'](old['capsule'](),reader=frozen_physical_reader)
 result['prior_nut_scope']='FROZEN_63676062; current NUT replaced by thermal-output authority'
 nut=runpy.run_path(str(ROOT/NUT_OWNER));result['current_concurrent_nut']=nut['validate'](nut['capsule']())
 result['controls']=len(self_test());result['current_source_tree']=git('rev-parse','HEAD:src')
 return result
if __name__=='__main__':print(json.dumps(verify(),indent=2))
