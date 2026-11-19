"""Explicitly refuse the not-qualified compatibility-output numerical route."""
import argparse,json,subprocess,sys,time
from pathlib import Path
import implicit_conductivity_runtime as c
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),optimization=a.optimization,cases={},selection='Earlier actual compatibility35day/native prototypes are retained as observations. Full groundwater failures show this is not complete daily-trial qualification. Actual new public SWKIMPL1 execution now explicitly requires --original-output; no silent fallback or rebinding.')
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 save()
 try:
  for name,solute,hys,bottom,k in [('water-groundwater',0,0,1,5),('cde-groundwater-history',1,2,1,4),('age-air-history',2,1,8,2)]:
   out=a.output/name;out.mkdir();inputs=out/'input';c.fixture(inputs,solute,hys,bottom,False,k,'daily',1,0,1)
   try:c.m.e.load(inputs,original_output=False)
   except ValueError as error:assert str(error)=='Original implicit conductivity requires explicit --original-output daily trial and state qualification'
   else:raise AssertionError('Not-qualified implicit compatibility route accepted')
   build=out/'public-build';cmd=[sys.executable,'-B',str(c.ROOT/'tools/solute/run_water.py'),'--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--output',str(build)]
   t=time.perf_counter();r=subprocess.run(cmd,cwd=c.ROOT,capture_output=True,text=True,timeout=60);elapsed=time.perf_counter()-t;(out/'public.stdout').write_text(r.stdout,encoding='utf8');(out/'public.stderr').write_text(r.stderr,encoding='utf8')
   assert r.returncode!=0 and 'Original implicit conductivity requires explicit --original-output daily trial and state qualification' in r.stderr
   assert not list(build.glob('*.exe')) and not (build/'BUILD.json').exists()
   q['cases'][name]=dict(status='REFUSED_BEFORE_COMPILATION',input_root=str(inputs),public_returncode=r.returncode,public_seconds=elapsed,command=cmd);save();print(name,'ACTUAL_UNQUALIFIED_COMPATIBILITY_REFUSED',flush=True)
  q['status']='THREE_ACTUAL_IMPLICIT_CONDUCTIVITY_UNQUALIFIED_COMPATIBILITY_REFUSALS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
