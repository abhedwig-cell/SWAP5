"""Target existing NoSnow analytical water with the original output clock."""
import argparse,json,re,shutil,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
from original_output_baseline import assignment
from water_snow_groundwater_period import cold
m=original.m
CASES={'vapor8-nprint2':(8,True,2,False,1,0),'vapor11-nprint3':(11,True,3,False,1,0),
       'model7-nprint2':(7,False,2,False,1,0),'feddes3-nprint3':(3,False,3,False,1,0),
       'vapor8-perstep':(8,True,1,True,0,0),'vapor8-limit1440':(8,True,1440,False,1,0),
       'vapor8-monthly':(8,True,1,False,1,1),'mixed7-8-nprint2':((7,8),True,2,False,1,0)}


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--case',choices=CASES,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
 p.add_argument('--days',type=int,choices=(2,35,367),required=True);a=p.parse_args();a.output.mkdir()
 selector,vapor,nprint,perstep,reset,monthly=CASES[a.case]
 models=(selector,) if isinstance(selector,int) else selector;model=models[0]
 inputs=a.output/'input';shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',inputs)
 path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
 for key,value in dict(SWSOLU=0,SWSNOW=0,SWCSV=3,NPRINTDAY=nprint,SWMONTH=monthly,PERIOD=1,SWODAT=0,SWRES=reset,FLPRINTDT='.TRUE.' if perstep else '.FALSE.').items():
  text=assignment(text,key,value) if re.search(r'(?mi)^[ \t]*'+key+r'[ \t]*=',text) else text+'\n'+key+' = '+str(value)+'\n'
 text+='\niHWCKmodel = '+' '.join(map(str,models))+'\nALFA_2 = .005 .003\nNPAR_2 = 1.5 1.6\nOMEGA_1 = .8 .8\nH0 = -1e6 -1e6\nHA = -10.0 -10.0\nAPAR = -1.5 -1.5\nOMEGA_K = .01 .01\nSWVAPOR = '+('1 1' if vapor else '0 0')+'\n'
 path.write_text(text,encoding='cp1252')
 for crop in inputs.glob('*.crp'):
  body=assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0)
  if model==3:body=assignment(body,'SWOXYGEN',1)
  crop.write_text(body,encoding='cp1252')
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),case=a.case,hydraulic_model=model,layer_models=list(models),active_vapor=vapor,kind='water',optimization=a.optimization,days=a.days,input_root=str(inputs),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');q['input_inventory']=m.e.inventory(inputs);save();build=a.build_root/'bundle'
  command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  start=time.perf_counter();run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
  (a.output/'build.stdout').write_text(run.stdout);(a.output/'build.stderr').write_text(run.stderr);q['build']=dict(command=command,returncode=run.returncode,seconds=time.perf_counter()-start);save();run.check_returncode()
  meta,_=m.validate_bundle(build,a.reference_work,project);clock=meta['identity']['model7_terminal_water'].get('existing_output_trial_receipt_composed',False)
  assert clock==(nprint>1 or perstep)
  windows=[(1,2)] if a.days==2 else [(2,4),(19,23),(30,34)]
  if a.days==367:windows += [(199,201),(364,367)]
  cuts={a.days}|{day for pair in windows for day in pair};full=a.output/'trajectory'
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,a.days,cuts,300);q['trajectory_root']=str(full);save();q['cold']=[]
  for start,end in windows:q['cold'].append(cold(build,a.reference_work,project,full,data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CLOCK_AND_TERMINAL_COMPOSITION_POSTIMAGE_EXACT_COLD_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.case,a.optimization,a.days,flush=True)


if __name__=='__main__':main()
