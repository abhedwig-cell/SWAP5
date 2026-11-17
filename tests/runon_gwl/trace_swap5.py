"""Source-bound private accepted-step witness for the current five-day donor."""
from pathlib import Path
import contextlib,importlib.util,json,shutil,subprocess,sys
from refine import ROOT,OUT,OLD,sha,rows
from trace_reference import P,run
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def main():
 result={};project=m.e.load(OLD/'inputs/water-surface-history')
 for opt in ('O0','O2'):
  build=OUT/('current-'+opt+'-build');cmd=[sys.executable,'-B',ROOT/'tools/solute/run_water.py','--model',m.e.MODEL,'--experimental-project',project.input_directory,'--reference-work',P.parent,'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',build]
  run(cmd,ROOT);meta,case=m.validate_bundle(build,P.parent,project)
  plain=OUT/('current-'+opt+'-plain');record,data=m.trajectory(build,P.parent,project,plain,5,set(),30)
  old=[json.loads(x) for x in (OLD/('water-'+opt+'-warm201/daily.jsonl')).read_text().splitlines()]
  assert m.physical(data)==m.physical(old[:5]),'current frost0 generated path drift'
  trace=OUT/('current-'+opt+'-trace-build');shutil.copytree(build,trace)
  p=trace/'swap.f90';s=p.read_text(encoding='cp1252');anchor='      call integral(3)';assert s.count(anchor)==1
  s=s.replace('only: irrigation, flirrigate, hybrid_apply_irrigation','only: irrigation, flirrigate, hybrid_apply_irrigation, gird,nird,dt_irr_event\nuse MOD_top,only:q0,hsurf,FlRunoff,ftoph')
  s=s.replace('dtold, h, theta, pond, qrot','dtold, h, theta, pond, qrot, pondm1,pondmx,runots,qtop,volact')
  s=s.replace(anchor,anchor+"\n      write(*,'(a,13(1x,es25.17e3),2(1x,l1))') 'GWL_STEP', &\n        t1900-tstart,dt,gird,nird,dt_irr_event,pond,pondm1,pondmx,runots,qtop,h(1),gwl,volact,FlRunoff,ftoph\n")
  p.write_text(s,encoding='cp1252');flags=meta['identity']['donor_flags'];compile=['gfortran',*flags,'-I',P/'swap-obj','-I',P/'ttutil-obj','-c',p];run(compile,trace)
  exe=trace/'day_donor.exe';objects=[trace/x.name if (trace/x.name).exists() else x for x in sorted((P/'swap-obj').glob('*.o'))]
  link=['gfortran','-o',exe,*objects,trace/'hybrid_step_budget.o',P/'ttutil-obj/libttutil.a'];run(link,trace)
  output=OUT/('current-'+opt+'-trace');output.mkdir();traced=[]
  # No checkpoints/native promotion: this private diagnostic executable has
  # its own explicit SHA and provenance, not a forged production BUILD binding.
  def trial():
   with contextlib.ExitStack() as stack:
    host=m.h.DailyHost(stack,exe,build/'day_kernel.exe',case,output,[m.h.ColumnStart('original',0,None,None)],runtime=True,model=project.model,project=project)
    for _ in range(5):traced.append(host.step(1))
    host.close()
  m.bounded(30,trial);assert m.physical(traced)==m.physical(data)
  assert rows(output/'original/result_output.csv')==rows(plain/'original/result_output.csv')
  result[opt]=dict(current_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),production=record,exact_archived_prefix=True,exact_uninstrumented_csv=True,exact_uninstrumented_physical=True,trace_source_sha256=sha(p),diagnostic_executable_sha256=sha(exe),compile=list(map(str,compile)),link=list(map(str,link)),native_admission=False)
  (OUT/'SWAP5_TRACE.json').write_text(json.dumps(result,indent=2));print(opt,'FRESH_CURRENT_AND_TRACE_PREFIX_EXACT',flush=True)
if __name__=='__main__':main()
