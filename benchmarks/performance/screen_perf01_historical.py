"""Research only: staged historical ZERO-TRACER project; preserve rejected cases."""
import csv,hashlib,json,os,re,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=Path(os.environ.get('PERF01_HISTORICAL_BUNDLE','/tmp/perf01-historical-current-O2'))
BUILD=Path(os.environ.get('PERF01_HISTORICAL_BUILD','/tmp/perf01-historical-current-v1'))
OUT=Path(os.environ.get('PERF01_HISTORICAL_OUT','/tmp/perf01-historical-stages-v1'));OUT.mkdir()
sys.path.insert(0,str(ROOT/'tools/solute'));import run_project
bundle=json.loads((BASE/'bundle.json').read_text());exe=BUILD/'project'
r=dict(status='RUNNING',production_qualified=False,original_positive_chemistry_qualified=False,checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),cases={},events=[])
def save():(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
def run(folder,executable,stop=481,restart='-'):
 cmd=[str(executable),'input.nml',str(restart),str(stop),'input.swp'];start=time.perf_counter()
 try:p=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=120);code=p.returncode;stdout=p.stdout;stderr=p.stderr
 except subprocess.TimeoutExpired as e:code='TIMEOUT120';stdout=e.stdout or b'';stderr=e.stderr or b''
 for k,v in [('stdout',stdout),('stderr',stderr)]:(folder/k).write_bytes(v)
 ev=dict(command=cmd,folder=str(folder),returncode=code,seconds=time.perf_counter()-start,fallback_days=stdout.count(b'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'))
 r['events'].append(ev);save();return ev
project=OUT/'zero-tracer-project';shutil.copytree('/tmp/perf01-practical-scope/project',project)
p=project/'project.swp';original=p.read_text();zero=original
for field,value in [('CPRE','0.'),('CDRAIN','0.'),('CMLTB','0.,0.,-3.,0.')]:
 zero,n=re.subn(r'^'+field+r'=.*$',field+'='+value,zero,flags=re.M);assert n==1
p.write_text(zero);r['transformation']=dict(original_swp_sha256=hashlib.sha256(original.encode()).hexdigest(),zero_tracer_swp_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),changed_fields=['CPRE','CDRAIN','CMLTB']);save()
doc,snapshot,audit,_=run_project.prepare(bundle,p,.001,solute_transport='implicit_upwind',water_conductivity='picard_continuous',surface_exfiltration='historical_zero')
def input_at(folder,text,snap=snapshot):folder.mkdir();(folder/'input.nml').write_text(text);(folder/'input.swp').write_bytes(snap)
# Fail closed on the ORIGINAL positive-chemistry input, before any accepted output.
positive,positive_snap,_,_=run_project.prepare(bundle,Path('/tmp/perf01-practical-scope/project/project.swp'),.001,solute_transport='implicit_upwind',water_conductivity='picard_continuous',surface_exfiltration='historical_zero')
folder=OUT/'positive-rejected';input_at(folder,positive.replace('&column','&column\n retain_accepted_step_proposal=.true.,water_flux_temporal=.true.,',1),positive_snap)
ev=run(folder,exe);assert ev['returncode']!=0 and b'native proposal requires zero tracer' in (folder/'stdout').read_bytes(),(folder/'stdout').read_text()[-2000:]
assert not(folder/'budget.csv').exists();r['original_positive_rejection_pass']=True;save()
for stage in os.environ.get('PERF01_HISTORICAL_STAGES','static,seasonal,detailed').split(','):
 text=doc
 if stage=='static':text=text.replace('seasonal_bottom=.true.','seasonal_bottom=.false.')
 if stage!='detailed':
  text=text.replace('detailed_rain=.true.','detailed_rain=.false.')
  text,n=re.subn(r'(?is)&rain_events\b.*?/','',text);assert n==1
 outcomes={};case=OUT/stage;case.mkdir()
 for arm in ['head','flux']:
  d=case/arm;arm_doc=text if arm=='head'else text.replace('&column','&column\n retain_accepted_step_proposal=.true.,water_flux_temporal=.true.,',1)
  input_at(d,arm_doc)
  reference=os.environ.get('PERF01_REFERENCE_ROOT')
  if arm=='head'and reference:
   previous=Path(reference)/stage/'head'
   assert all((d/n).read_bytes()==(previous/n).read_bytes()for n in ['input.nml','input.swp'])
   record=json.loads((Path(reference)/'RESULT.json').read_text())['cases'][stage]['head'];assert record['returncode']==0
   for n in ['budget.csv','state.csv','endpoint.csv','restart.bin','stdout','stderr']:shutil.copyfile(previous/n,d/n)
   event=dict(record);event['reused_exact_input_reference']=str(previous)
  else:event=run(d,exe)
  outcomes[arm]=event
  if event['returncode']==0:
   rows=list(csv.DictReader((d/'budget.csv').open()));assert len(rows)==481
   event['max_water_residual_cm']=max(abs(float(v['water_residual_cm']))for v in rows);assert event['max_water_residual_cm']<1e-10
   event['max_solute_residual_mg_cm2']=max(abs(float(v['solute_residual_mg_cm2']))for v in rows);assert event['max_solute_residual_mg_cm2']<1e-10
   assert all(float(v[k])==0 for v in rows for k in ['solute_start_mg_cm2','solute_end_mg_cm2','solute_in_mg_cm2','solute_out_mg_cm2'])
 if all(v['returncode']==0 for v in outcomes.values()):
  rows=lambda a:list(csv.DictReader((case/a/'budget.csv').open()));a,b=rows('head'),rows('flux')
  diff={k:10*max(abs(float(x[k])-float(y[k]))for x,y in zip(a,b))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']}
  diff['total_evaporation_cm']=10*max(abs(float(x['soil_evaporation_cm'])+float(x['pond_evaporation_cm'])-float(y['soil_evaporation_cm'])-float(y['pond_evaporation_cm']))for x,y in zip(a,b))
  outcomes['max_daily_difference_mm']=diff;outcomes['physical_screen_pass']=all(diff[k]<.01 for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','total_evaporation_cm'])
 r['cases'][stage]=outcomes;save()
r['status']='RESEARCH_STAGES_COMPLETED';save();print(json.dumps(r['cases'],indent=2))
