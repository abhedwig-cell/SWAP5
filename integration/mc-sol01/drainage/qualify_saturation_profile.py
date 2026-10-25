"""Current original matrix profile qualification after stable storage arithmetic."""
import argparse,csv,hashlib,json,os,re,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--days',type=int,default=30);p.add_argument('--split-day',type=int,default=9);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();bundle=a.bundle.resolve();b=json.loads((bundle/'bundle.json').read_text());m=b['storage_repair_build'];events=[];record=dict(status='RUNNING',optimization=b['optimization'],build=m,events=events,qualified=False,canonically_admitted=False);case=out/'project';record['original_sources']=runpy.run_path(str(ROOT/'integration/mc-sol01/drainage/qualify_original_matrix_profile.py'))['fixture'](case)
def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
for path,h in m['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
save()
def run(cmd,label,ok=True):
 start=time.monotonic();cmd=list(map(str,cmd))
 try:r=subprocess.run(cmd,cwd=out,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=1800)
 except subprocess.TimeoutExpired as e:
  for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(e,k)or b'')
  events.append(dict(label=label,command=cmd,returncode=None,seconds=time.monotonic()-start,censored=True));record['status']='CENSORED';save();raise
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
 events.append(dict(label=label,command=cmd,returncode=r.returncode,seconds=time.monotonic()-start,expected_success=ok));save();assert(r.returncode==0)==ok,(label,r.stderr.decode()[-1500:]);return r
common=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',case/'swap.swp','--bundle',bundle,'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
for label,extra in [('full',['--stop-after',str(a.days)]),('split',['--stop-after',str(a.split_day)]),('resumed',['--stop-after',str(a.days),'--restart',out/'split'])]:run(common+['--output',out/label]+extra,label)
rows=lambda p:list(csv.DictReader(p.open()));budget=rows(out/'full/budget.csv');assert len(budget)==a.days and budget[a.split_day:]==rows(out/'resumed/budget.csv');fs=['state.csv','endpoint.csv','temperature.csv','restart.bin']
for f in fs:assert(out/'full'/f).read_bytes()==(out/'resumed'/f).read_bytes(),f
assert(out/'full/restart.bin').read_bytes()[:8]==b'S5PT0002';state=rows(out/'full/state.csv');assert len(state)==112 and all(min(float(r[k])for k in ['theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'])>=0 for r in state)
gross=[]
for r in budget:
 assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10 and 0<=float(r['observed_heat_residual_j_cm2'])<=1e-9
 assert abs(float(r['potential_transpiration_cm'])-float(r['actual_transpiration_cm'])-float(r['drought_reduction_cm'])-float(r['oxygen_reduction_cm']))<1e-12
 gross.append(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['rain_supplied_cm'])+float(r['runoff_cm'])+float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])+float(r['actual_transpiration_cm'])-float(r['bottom_up_cm'])+float(r['drainage_cm']));assert abs(gross[-1])<1e-10
pairs={label:list(map(float,re.search(r'SWAP5_COMMITTED_BOESTEN_PAIR=\s*([-+\d.Ee]+)\s+([-+\d.Ee]+)',(out/label/'stdout').read_text()).groups()))for label in ['full','split','resumed']};assert pairs['full']==pairs['resumed']and min(pairs['full']+pairs['split'])>=0
# Admission guards and immutable source identity must survive the repair.
swp=case/'swap.swp';original=swp.read_bytes()
for name,data in [('macro',original.replace(b'SWMACRO = 0',b'SWMACRO = 1')),('profile',original.replace(b'GWLI = -80.9',b'GWLI = -81.9'))]:
 assert data!=original;swp.write_bytes(data);target=out/('forbidden-'+name);run(common+([]if name=='macro'else['--restart',out/'split'])+['--output',target],name,False);assert not target.exists();swp.write_bytes(original)
crop=case/'wintcer1.crp';old=crop.read_bytes();data,n=re.subn(rb'(?m)^(\s*SWINTER\s*=\s*)0',rb'\g<1>3',old);assert n==1;crop.write_bytes(data);target=out/'forbidden-rutter';run(common+['--output',target],'rutter',False);assert not target.exists();crop.write_bytes(old)
inputs=dict(m['input_sha256'])
for src in ['integration/mc-sol01/drainage/qualify_original_matrix_profile.py','integration/mc-sol01/drainage/qualify_saturation_profile.py','tools/solute/run_project.py','tools/solute/run_column.py','app/solute_crop/read_swp_project.f90']:inputs[src]=sha((ROOT/src).read_bytes())
for v in record['original_sources'].values():inputs[v['compressed_path']]=v['compressed_sha256']
record.update(status='ORIGINAL_MATRIX112_STORAGE_REPAIR30_RESTART_PASS',input_sha256=inputs,results=dict(files={f:sha((out/'full'/f).read_bytes())for f in fs},budget=budget,pairs=pairs),physical_results=dict(nodes=112,layers=8,days=a.days,split_day=a.split_day,exact_restarts=1,water_max_cm=max(abs(float(r['water_residual_cm']))for r in budget),solute_max_mg_cm2=max(abs(float(r['solute_residual_mg_cm2']))for r in budget),gross_water_max_cm=max(map(abs,gross)),observed_heat_max_j_cm2=max(float(r['observed_heat_residual_j_cm2'])for r in budget)));save();print(record['status'])
