"""Real native SWP water bootstrap, independent mapping/balances and restart."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build-O0',type=Path,required=True);ap.add_argument('--build-O2',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report={'status':'RUNNING','events':[],'builds':{},'cases':{},'inputs':{str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__),ROOT/'tests/nut-sol/test_swp_water.f90',ROOT/'examples/solute_column/layered_water.swp',ROOT/'examples/solute_column/swp_water.nml']}}
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,valid=True):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=90);i=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append({'command':list(map(str,cmd)),'cwd':str(cwd),'returncode':r.returncode,'expected_success':valid,'seconds':time.perf_counter()-start});save()
  assert (r.returncode==0)==valid,(cmd,r.stdout.decode(errors='replace'),r.stderr.decode(errors='replace'))
  return r
 base=(ROOT/'examples/solute_column/layered_water.swp').read_text();nml=(ROOT/'examples/solute_column/swp_water.nml').read_text()
 variants={'layered':base,'ksat_alias':base.replace('KSATFIT=','KSAT='),'reversed_layers':base.replace('1 1 1.0 2\n2 2 2.0 2','1 2 1.0 2\n2 1 2.0 2'),
 'constant_head':base.replace('HTB=0.,-75.,-3.,-90.','HTB=0.,-75.,-3.,-75.'),
 'grammar':base.lower().replace('ihwckmodel=1','ihwckmodel=2*1').replace('ksatfit=.00475,.008','ksatfit=4.75D-3,8.D-3'),
 'no_model_default':base.replace('IHWCKMODEL=1\n','')}
 bad={
 'hyst':('SWHYST=0','SWHYST=1'),'table':('SWSOPHY=0','SWSOPHY=1'),'model':('IHWCKMODEL=1','IHWCKMODEL=2'),
 'layer_gap':('2 2 2.0 2','2 3 2.0 2'),'unordered':('2 2 2.0 2','3 2 2.0 2'),
 'too_many_nodes':('2 2 2.0 2','2 2 2.0 256'),'too_few_nodes':('1 1 1.0 2\n2 2 2.0 2','1 1 1.0 1'),
 'bad_retention':('OSAT=.423,.45','OSAT=.01,.45'),'head_saturated':('HTB=0.,-75.,-3.,-90.','HTB=0.,-75.,-3.,0.'),
 'head_duplicate':('HTB=0.,-75.,-3.,-90.','HTB=0.,-75.,0.,-90.'),'head_reverse':('HTB=0.,-75.,-3.,-90.','HTB=-3.,-75.,0.,-90.'),
 'head_nonfinite':('HTB=0.,-75.,-3.,-90.','HTB=0.,NaN,-3.,-90.'),'head_too_dry':('HTB=0.,-75.,-3.,-90.','HTB=0.,-1.D7,-3.,-90.'),
 'head_odd':('HTB=0.,-75.,-3.,-90.','HTB=0.,-75.,-3.'),'hydro_narrow_alpha':('ALFA=.0135,.02','ALFA=.0135,2.'),
 'hydro_narrow_n':('NPAR=1.455,1.6','NPAR=1.455,6.'),'hydro_short':('NPAR=1.455,1.6','NPAR=1*1.455'),
 'gw_initial':('SWINCO=1','SWINCO=2'),'loose_restart':('SWINCO=1','SWINCO=3'),
 'legacy_head':('HTB=0.,-75.,-3.,-90.','ZI=0.,-3.\nH=-75.,-90.'),
 'ksatexm':('SWHYST=0','SWHYST=0\nKSATEXM=.01'), 'power':('SWHYST=0','SWHYST=0\nH_POWER=-100.'),
 'elastic':('SWHYST=0','SWHYST=0\nELAS=0.'),'database':('SWHYST=0',"SWHYST=0\nSWAP_SOILS_DB='soil'")}
 for opt in ['O0','O2']:
  build=getattr(a,'build_'+opt).resolve();meta=json.loads((build/'build-complete.json').read_text());report['builds'][opt]=meta
  assert meta['executable_sha256']==sha(build/'swap5_solute_column')
  for p,h in meta['input_sha256'].items():assert sha(ROOT/p)==h,p
  for p,h in meta['generated_input_sha256'].items():assert sha(build/p)==h,p
  directory=out/opt;directory.mkdir();driver=directory/'reader'
  # Three application/input providers plus original TTUTIL, no copied physics/mock.
  objects=[]
  for e in meta['events']:
   if e['category']=='compile' and any(str(e['command'][-3]).endswith(x) for x in ['legacy_swp_original.f90','read_swp_water.f90','link_context.f90']):objects.append(Path(e['command'][-1]))
  assert len(objects)==3,objects
  run(meta['compiler_command']+meta['flags']+[ROOT/'tests/nut-sol/test_swp_water.f90']+objects+[build/'libttutil.a','-o',driver],directory)
  for name,text in variants.items():
   case=directory/name;case.mkdir();swp=case/'source.swp';swp.write_text(text)
   r=run([driver,swp.name],case)
   vectors=[list(map(float,x.split()[2:])) for x in r.stdout.decode().splitlines() if x.startswith('NODE ')]
   assert len(vectors)==4
   heads=[-76.25,-78.75,-82.5,-87.5] if name!='constant_head' else [-75.]*4
   layers=[1,1,0,0] if name=='reversed_layers' else [0,0,1,1]
   pars=[[.032,.423,.00475,.0135,.365,1.455],[.04,.45,.008,.02,.4,1.6]]
   for i,v in enumerate(vectors):
    param=pars[layers[i]];expected=[[.5,.5,1.,1.][i],heads[i]]+param+[1.-1./param[-1]]
    assert max(abs(x-y) for x,y in zip(v,expected))<2e-14,(name,i,v,expected)
   source=case/'input.nml';source.write_text(nml)
   common=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',source,'--swp',swp]
   for target,extra in [('full',[]),('split',['--stop-after','1']),('resumed',['--restart',case/'split'])]:run(common+['--output',case/target]+extra,case)
   for p in ['state.csv','endpoint.csv','restart.bin']:assert (case/'full'/p).read_bytes()==(case/'resumed'/p).read_bytes(),p
   budget=rows(case/'full/budget.csv');state=rows(case/'full/state.csv');endpoint=rows(case/'full/endpoint.csv')[0]
   assert rows(case/'resumed/budget.csv')==budget[1:]
   # Independent MvG and Freundlich inventory; no production theta copied.
   water=.5;chemical=.25
   for i,(v,layer) in enumerate(zip(vectors,layers)):
    dz,h=v[:2];tr,ts,ks,alpha,l,n=pars[layer];theta=tr+(ts-tr)/(1.+abs(alpha*h)**n)**(1.-1./n)
    concentration=[.25,.35,.5,.7][i];rho_kf=[.26,.6][layer]
    water+=dz*theta;chemical+=dz*(theta*concentration+rho_kf*concentration**.5)
   assert abs(budget[0]['water_start_cm']-water)<2e-13
   assert abs(budget[0]['solute_start_mg_cm2']-chemical)<2e-13
   for b in budget:
    assert abs(b['water_end_cm']-b['water_start_cm']-b['water_in_cm']+b['water_out_cm'])<1e-10
    assert abs(b['solute_end_mg_cm2']-b['solute_start_mg_cm2']-b['solute_in_mg_cm2']+b['solute_out_mg_cm2'])<1e-10
    assert abs(b['water_residual_cm'])<1e-10 and abs(b['solute_residual_mg_cm2'])<1e-10
   assert abs(sum(x['theta']*x['dz_cm'] for x in state)+endpoint['pond_cm']-endpoint['total_water_cm'])<1e-10
   assert abs(sum(x['dissolved_mg_cm2']+x['sorbed_mg_cm2'] for x in state)+endpoint['pond_solute_mg_cm2']-endpoint['total_solute_mg_cm2'])<1e-10
   report['cases'][opt+'-'+name]={'mapping':vectors,'budget':budget,'endpoint':endpoint,'restart_sha256':sha(case/'full/restart.bin')};save()
  for name,(old,new) in bad.items():
   case=directory/('invalid-'+name);case.mkdir();swp=case/'source.swp';swp.write_text(base.replace(old,new));source=case/'input.nml';source.write_text(nml)
   target=case/'forbidden';run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',source,'--swp',swp,'--output',target],case,False)
   assert not target.exists()
  for name,old,new in [('dual_grid','nodes=0','nodes=4'),('hydraulic_override','schema=2','schema=2,theta_s=.5'),('head_override','schema=2','schema=2,initial_head=-10'),('wrong_schema','schema=2','schema=1')]:
   source=directory/(name+'.nml');source.write_text(nml.replace(old,new));target=directory/('forbidden-'+name)
   run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',source,'--swp',ROOT/'examples/solute_column/layered_water.swp','--output',target],directory,False);assert not target.exists()
  # Existing launcher must bind water source bytes, including changed-but-valid SWP.
  case=directory/'layered';changed=directory/'changed.swp';changed.write_text(base.replace('NPAR=1.455,1.6','NPAR=1.455,1.7'));target=directory/'forbidden-restart'
  run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',case/'input.nml','--swp',changed,'--restart',case/'split','--output',target],directory,False);assert not target.exists()
  target=directory/'forbidden-missing';run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',ROOT/'examples/solute_column/swp_water.nml','--output',target],directory,False);assert not target.exists()
 report.update(status='PASS',native_mapping_cases=12,independent_process_restarts=12,invalid_cases=60,full_historical_migration=False)
 save();print(json.dumps({k:report[k] for k in ['status','native_mapping_cases','independent_process_restarts','invalid_cases']}))
if __name__=='__main__':main()
