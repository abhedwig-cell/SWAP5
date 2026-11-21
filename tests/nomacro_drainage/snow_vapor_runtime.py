"""Target original Snow with the existing Kelvin-corrected vapor process."""
import argparse,json,shutil,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as thermal
from original_output_baseline import assignment
from water_snow_groundwater_period import cold
m=thermal.m


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--kind',choices=('water','cde'),required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True)
 p.add_argument('--layer-models',type=int,nargs='+',required=True)
 p.add_argument('--vapor-flags',type=int,nargs='+',default=[1,1])
 p.add_argument('--days',type=int,choices=(35,1096),required=True)
 a=p.parse_args();a.output.mkdir();inputs=a.output/'input'
 shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',inputs)
 path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
 for key,value in dict(SWSOLU=int(a.kind=='cde'),SWSNOW=1,SWCSV=3,NPRINTDAY=1,SWMONTH=0,PERIOD=1,SWODAT=0,SWRES=1).items():text=assignment(text,key,value)
 if a.kind=='cde':text=assignment(text,'CPRE','0.01')
 text+='\niHWCKmodel = '+' '.join(map(str,a.layer_models))+'\nALFA_2 = .005 .003\nNPAR_2 = 1.5 1.6\nOMEGA_1 = .8 .8\nH0 = -1e6 -1e6\nHA = -10.0 -10.0\nAPAR = -1.5 -1.5\nOMEGA_K = .01 .01\nSWVAPOR = '+' '.join(map(str,a.vapor_flags))+'\n'
 path.write_text(text,encoding='cp1252')
 if a.kind=='water':
  for crop in inputs.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),kind=a.kind,optimization=a.optimization,layer_models=a.layer_models,vapor_flags=a.vapor_flags,days=a.days,input_root=str(inputs),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');q['input_inventory']=m.e.inventory(inputs);save()
  build=a.build_root/'bundle'
  command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  start=time.perf_counter();run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
  (a.output/'build.stdout').write_text(run.stdout);(a.output/'build.stderr').write_text(run.stderr);q['build']=dict(command=command,returncode=run.returncode,seconds=time.perf_counter()-start);save();run.check_returncode()
  meta,_=m.validate_bundle(build,a.reference_work,project)
  assert meta['identity']['hydraulic_vapor']['snow_composition']['native_domain_version']==4
  assert meta['identity']['hydraulic_vapor']['native_codec']==('S5HSC004' if project.solute else 'S5HSW004')
  windows=[(2,4),(19,23),(30,34)]
  if a.days==1096:windows += [(199,201),(364,367),(530,532),(1094,1096)]
  cuts={a.days}|{d for pair in windows for d in pair};full=a.output/'trajectory'
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,full,a.days,cuts,240);q['trajectory_root']=str(full);save()
  q['cold']=[]
  for start,end in windows:q['cold'].append(cold(build,a.reference_work,project,full,data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_SNOW_VAPOR_WATER_CDE_POSTIMAGE_SHORT_OR_FULL_EXACT_COLD_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.kind,a.optimization,a.layer_models,a.days,flush=True)


if __name__=='__main__':main()
