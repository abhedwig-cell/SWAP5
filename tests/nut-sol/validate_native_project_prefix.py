"""Validate completed bounded observations without rerunning unchanged physics.

The first prefix recipe retained an annual positive-runoff coverage assertion.
Its actual full/split/resume processes are reusable only after their exact raw
source, executable, output and original fixed/ETpot contracts are checked here.
This never turns a failed native process into a PASS or claims full-year coverage.
"""
import argparse,base64,csv,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def scope_successor(old,new):
 needle="    assert sum(d['runoff_cm']for d in budget)>0"
 replacement="    if simulated_days==days:assert sum(d['runoff_cm']for d in budget)>0"
 return old.count(needle)==1 and old.replace(needle,replacement)==new
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--days',type=int,required=True);a=ap.parse_args()
 proof=a.proof.resolve();r=json.loads((proof/'result.json').read_text())
 assert r['physical_limit']==a.days and r['grid']=='refined'and r['optimizations']==['O2']
 assert all(e['returncode']==0 for e in r['events']),'native failure is not a coverage-only correction'
 oldsha=r['inputs']['tests/nut-sol/qualify_native_project.py']
 recipe=proof/'execution-recipe.py'
 old=recipe.read_bytes()if recipe.exists()else subprocess.check_output(['git','show','5e60f181:tests/nut-sol/qualify_native_project.py'],cwd=ROOT)
 current=(ROOT/'tests/nut-sol/qualify_native_project.py').read_bytes()
 assert sha(old)==oldsha and scope_successor(old.decode(),current.decode())
 if not recipe.exists():recipe.write_bytes(old)
 for p,h in r['inputs'].items():
  if p!='tests/nut-sol/qualify_native_project.py':assert sha((ROOT/p).read_bytes())==h,(p,'execution input changed')
 meta=r['bundles']['O2']
 for p,h in meta['executable_sha256'].items():assert sha(Path(p).read_bytes())==h
 def rows(p):return[{k:float(v)for k,v in d.items()}for d in csv.DictReader(p.open())]
 cases={};observations={}
 for name,days in [('single',8),('annual1998',a.days)]:
  case=proof/'O2'/name;document=(case/'full/input.nml').read_text()
  encoded=''.join(line.split('=',1)[1]for line in document.splitlines()if line.startswith('! native_project_audit_base64='))
  info=json.loads(base64.b64decode(encoded));data=rows(case/'full/budget.csv');assert len(data)==days
  split=len(rows(case/'split/budget.csv'));assert 0<split<days
  assert rows(case/'resumed/budget.csv')==data[split:]
  for p in ['state.csv','endpoint.csv','restart.bin']:assert(case/'full'/p).read_bytes()==(case/'resumed'/p).read_bytes()
  for period in info['prepared_periods']:
   oracle=rows(case/('oracle/original-'+str(period['index'])+'.csv'))
   assert oracle==[{k:float(v)for k,v in d.items()}for d in period['plan']]
  rain=[float(d['rain_cm_day'])for d in info['prepared_periods'][0]['rain']]
  for i,d in enumerate(data):
   for s,u in [('water','cm'),('solute','mg_cm2')]:
    residual=d[s+'_end_'+u]-d[s+'_start_'+u]-d[s+'_in_'+u]+d[s+'_out_'+u]
    assert abs(residual)<1e-10 and abs(d[s+'_residual_'+u])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-rain[i]+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']+(.01 if name!='single'else 0.)
   assert abs(gross)<1e-10
   assert abs(d['potential_transpiration_cm']-d['actual_transpiration_cm']-d['drought_reduction_cm']-d['oxygen_reduction_cm'])<1e-12
   if info['profile_index'][i]==0:assert d['actual_transpiration_cm']==0
  assert sum(d['actual_transpiration_cm']for d in data)>0
  if name!='single':assert sum(d['solute_out_mg_cm2']for d in data)>0
  # All three observations must come from successful recorded fresh processes.
  for target in ['full','split','resumed']:
   hits=[e for e in r['events']if '--output'in e['command']and e['command'][e['command'].index('--output')+1]==str(case/target)]
   assert len(hits)==1 and hits[0]['returncode']==0
   manifest=json.loads((case/target/'manifest.json').read_text())
   assert manifest['executable_sha256']==sha(Path(meta['exe']).read_bytes())
  for p in case.rglob('*'):
   if any('.pending-'in part for part in p.relative_to(case).parts):continue
   if p.is_file()and p.suffix not in ['.o','.mod','.smod','.a','.so','.tmp','.pyc']:
    with p.open('rb')as stream:magic=stream.read(4)
    if magic!=b'\x7fELF':observations[str(p.relative_to(proof))]=sha(p.read_bytes())
  cases['O2-'+name]=dict(days=days,declared_days=info['days'],full_period_simulated=days==info['days'],budget=data,rain_cm=rain,
   profiles=info['profile_index'],historical_weather=name!='single',original_Andelst_model=False)
 report=dict(status='NATIVE_PROJECT_BOUNDED_PREFIX_'+str(a.days)+'_DAYS_PASS',physical_limit=a.days,grid='refined',
  optimizations=['O2'],cases=cases,inputs={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes()),
   'tests/nut-sol/qualify_native_project.py':sha(current)},execution_recipe_sha256=oldsha,observations=observations,
  disposition='ANNUAL_RUNOFF_COVERAGE_ASSERTION_DOES_NOT_APPLY_TO_98_DAY_PREFIX',numerical_processes_rerun=False,
  full_refined_year_qualified=False)
 (proof/'prefix-validation.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()
