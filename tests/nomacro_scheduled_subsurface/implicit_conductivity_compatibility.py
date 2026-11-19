"""Three actual compatibility-output native seams for the numerical selection."""
import argparse,json,subprocess,sys,time
from pathlib import Path
import implicit_conductivity_runtime as c
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,cases={},selection='Three actual35day compatibility-output native seams: new implicit water groundwater002layout and literal CDE groundwater/history and daily AGE/history owners. Existing original-output full periods select the changed numerical physics; do not repeat unrelated long physics for output flag alone.')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  for name,solute,hys,bottom,k in [('water-groundwater',0,0,1,5),('cde-groundwater-history',1,2,1,4),('age-air-history',2,1,8,2)]:
   out=a.output/name;out.mkdir();inputs=out/'input';c.fixture(inputs,solute,hys,bottom,False,k,'daily',1,0,1)
   project=c.m.e.load(inputs,original_output=False);build=out/'build'
   cmd=[sys.executable,'-B',str(c.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
   t=time.perf_counter();r=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=180);elapsed=time.perf_counter()-t;(out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');r.check_returncode()
   meta,_=c.m.validate_bundle(build,a.reference_work,project);assert meta['identity']['implicit_conductivity']['SWKIMPL']==1 and 'original_output' not in meta['identity']
   full=out/'trajectory';trajectory,data=c.m.trajectory(build,a.reference_work,project,full,35,{2,4,30,34,35},180)
   cold=[c.m.own(build,a.reference_work,project,full,data,s,e,out/f'own-{s}') for s,e in ((2,4),(30,34))]
   q['cases'][name]=dict(status='ACTUAL_COMPATIBILITY_IMPLICIT_PHYSICAL_NATIVE_PASS',input_root=str(inputs),build_root=str(build),build_seconds=elapsed,trajectory=trajectory,cold=cold,native_codec=c.m.e.auxiliary_magic(project).decode());save();print(name,'ACTUAL_COMPATIBILITY_COMPLETE_NATIVE_PASS',flush=True)
  q['status']='THREE_ACTUAL_IMPLICIT_CONDUCTIVITY_COMPATIBILITY_NATIVE_SEAMS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
