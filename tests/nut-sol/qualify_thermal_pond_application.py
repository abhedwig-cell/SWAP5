"""Real file application: nonlinear heat, bounded seasonal forcing and restart."""
import argparse,csv,hashlib,json,math,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [{k:float(v) for k,v in r.items()} for r in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build-O0',type=Path,required=True);ap.add_argument('--build-O2',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--days',type=int,default=365);args=ap.parse_args()
 out=args.output.resolve();out.mkdir(exist_ok=False,parents=True);report={'status':'RUNNING','events':[],'runs':{},'days':args.days,'inputs':{str(Path(__file__).relative_to(ROOT)):sha(Path(__file__))}}
 def persist():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=180);i=len(report['events']);(out/f'{i:04d}.stdout').write_bytes(r.stdout);(out/f'{i:04d}.stderr').write_bytes(r.stderr);report['events'].append({'command':list(map(str,cmd)),'returncode':r.returncode,'seconds':time.perf_counter()-start});persist()
  if r.returncode:print(r.stdout.decode(errors='replace'),r.stderr.decode(errors='replace'),flush=True);r.check_returncode()
 for opt in ['O0','O2']:
  exe=getattr(args,'build_'+opt).resolve()/'swap5_solute_column'
  build=json.loads((exe.parent/'build-complete.json').read_text());assert sha(exe)==build['executable_sha256']
  for p,h in build['input_sha256'].items():assert sha(ROOT/p)==h,p
  report.setdefault('builds',{})[opt]=build
  for exponent in [.5,1.,2.]:
   cases=[]
   for per_day in [1,2,4]:
    n=args.days*per_day;assert n<=2048
    case=out/f'{opt}-{exponent}-{per_day}';case.mkdir();source=case/'input.nml'
    ends=[(j+1)/per_day for j in range(n)]
    temperatures=[12+8*math.sin(2*math.pi*(t-.5/per_day)/365) for t in ends]
    text='''&column
 schema=1
 initial_head=-10
 initial_pond_cm=.5
 initial_pond_mass_mg_cm2=.25
 concentration_mg_cm3=.2,.3,.4,.5
 ksat_cm_day=.00000475
 diffusion_cm2_day=.0001
 dispersivity_cm=.0001
 pond_max_cm=.49
 runoff_resistance_day=.001
 dynamic_temperature=.true.
 decay_rate_day=.001
 initial_temperature_c=4*12
'''+f' freundlich_exponent={exponent}\n/\n&surface\n windows={n}\n ends_day='+','.join(map(str,ends))+'\n surface_temperature_c='+','.join(map(str,temperatures))+f'\n rain_cm_day={n}*.001\n runon_cm_day={n}*.001\n evaporation_cm_day={n}*.0005\n rain_c=.125\n runon_c=.3\n/\n'
    source.write_text(text)
    run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',exe,'--input',source,'--output',case/'full'],case)
    budget=rows(case/'full/budget.csv');state=rows(case/'full/state.csv');heat=rows(case/'full/temperature.csv');endpoint=rows(case/'full/endpoint.csv')[0]
    assert len(budget)==n and endpoint['time_day']==args.days
    assert max(abs(r['water_residual_cm']) for r in budget)<=1e-10
    assert max(abs(r['solute_residual_mg_cm2']) for r in budget)<=1e-11
    assert sum(r['runon_cm'] for r in budget)>0 and sum(r['runoff_cm'] for r in budget)>0 and sum(r['pond_evaporation_cm'] for r in budget)>0
    for r in state:
     want=1.3*.2*r['concentration_mg_cm3']**exponent*r['dz_cm'];assert abs(r['sorbed_mg_cm2']-want)<1e-11
    if per_day==4:
     common=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',exe,'--input',source]
     run(common+['--output',case/'split','--stop-after',n//2],case)
     run(common+['--output',case/'resumed','--restart',case/'split'],case)
     for name in ['restart.bin','state.csv','temperature.csv','endpoint.csv']:assert (case/'full'/name).read_bytes()==(case/'resumed'/name).read_bytes(),name
    value={'input_sha256':sha(source),'endpoint':endpoint,'heat':[r['temperature_c'] for r in heat],'inventory':[r['dissolved_mg_cm2']+r['sorbed_mg_cm2'] for r in state],'max_water':max(abs(r['water_residual_cm']) for r in budget),'max_solute':max(abs(r['solute_residual_mg_cm2']) for r in budget),'restart_sha256':sha(case/'full/restart.bin'),'accepted':sum(r['accepted_substeps'] for r in budget)}
    cases.append(value);report['runs'][f'{opt}-{exponent}-{per_day}']=value;persist();print(opt,exponent,per_day,'PASS',flush=True)
   errors=[sum(abs(a-b) for a,b in zip(cases[j]['inventory'],cases[j+1]['inventory']))+abs(cases[j]['endpoint']['pond_solute_mg_cm2']-cases[j+1]['endpoint']['pond_solute_mg_cm2']) for j in [0,1]]
   report.setdefault('refinement',{})[f'{opt}-{exponent}']=errors;persist()
 for e in [.5,1.,2.]:
  for mesh in [1,2,4]:assert report['runs'][f'O0-{e}-{mesh}']==report['runs'][f'O2-{e}-{mesh}'],'optimization difference'
 report['status']='PHYSICAL_LONG_FILE_RUNS_PASS_ACCURACY_ASSESSMENT_REQUIRED';persist()
if __name__=='__main__':main()
