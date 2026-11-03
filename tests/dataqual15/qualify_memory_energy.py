"""Small action-memory and conservative macro liquid thermal research gates."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
 sources=['src/runtime/mod_macropore_continuation_state.f90','src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90','src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90','src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90','src/solver/mod_reference_linear_solver.f90','tests/dataqual15/research/mod_contact_action_memory.f90','tests/dataqual15/research/mod_macro_liquid_thermal.f90']
 drivers=['contact_memory_driver','macro_thermal_driver'];paths=sources+['tests/dataqual15/research/'+d+'.f90' for d in drivers]+['tests/dataqual15/qualify_memory_energy.py']
 git=lambda *x:subprocess.check_output(['git',*x],cwd=ROOT,text=True).strip()
 assert not git('diff','HEAD','--',*paths),'persist first';report=dict(measurement_commit=git('rev-parse','HEAD'),source_git_blob={n:git('rev-parse','HEAD:'+n) for n in paths},compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],builds={},full_energy_balance_complete=False)
 for opt in ['O0','O2']:
  build=out/opt;build.mkdir();flags=['-'+opt,'-g','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)];objects=[];start=time.monotonic()
  for i,name in enumerate(sources):
   obj=build/(str(i)+'.o');cp=subprocess.run(['gfortran',*flags,'-c',ROOT/name,'-o',obj],cwd=build,capture_output=True);(build/('compile-'+str(i)+'.stderr')).write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();objects.append(obj)
  entries={}
  for driver in drivers:
   exe=build/(driver+'.exe');cp=subprocess.run(['gfortran',*flags,ROOT/('tests/dataqual15/research/'+driver+'.f90'),*objects,'-o',exe],cwd=build,capture_output=True);(build/(driver+'.compile.stderr')).write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();cp=subprocess.run([exe],cwd=build,capture_output=True);(build/(driver+'.stdout')).write_bytes(cp.stdout);(build/(driver+'.stderr')).write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode();entries[driver]=dict(stdout=cp.stdout.decode().replace('\r\n','\n'),executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
  report['builds'][opt]=dict(seconds=time.monotonic()-start,tests=entries)
 for driver in drivers:assert report['builds']['O0']['tests'][driver]['stdout']==report['builds']['O2']['tests'][driver]['stdout']
 report['status']='SMALL_ACTION_MEMORY_AND_MACRO_LIQUID_THERMAL_O0_O2_PASS';(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report['status'])
if __name__=='__main__':main()
