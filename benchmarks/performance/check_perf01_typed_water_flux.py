"""Small real production estimator and unchanged transaction/context contracts."""
import argparse,hashlib,json,os,shlex,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--incumbent',type=Path);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 fc=shlex.split(os.environ.get('FC','gfortran'));events=[]
 groups={
  'water_flux':['src/process/mod_pond_water_temporal_difference.f90','tests/nut-sol/test_water_flux_temporal_policy.f90'],
  'incumbent_pond':['src/process/mod_pond_water_temporal_difference.f90','tests/nut-sol/test_pond_water_temporal_difference.f90'],
  'transaction':['src/transaction/mod_transaction_reference.f90','tests/transaction/test_transaction_reference.f90'],
  'context':['src/transaction/mod_transaction_reference.f90','tests/transaction/test_transaction_attempt_context.f90']}
 report=dict(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  compiler=subprocess.check_output(fc+['--version'],text=True).splitlines()[0],
  inputs={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for files in groups.values()for p in files},events=events,status='RUNNING')
 def run(cmd,cwd,kind,expected_success=True):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=60);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),category=kind,seconds=time.perf_counter()-start,returncode=r.returncode,expected_success=expected_success))
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
  if (r.returncode==0)!=expected_success:raise RuntimeError(r.stderr.decode()+r.stdout.decode())
  return r.stdout
 for opt in ['O0','O2']:
  for name,files in groups.items():
   folder=out/(opt+'-'+name);folder.mkdir();exe=folder/'driver'
   run([*fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror','-Wno-error=compare-reals',
    '-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*[ROOT/p for p in files],'-o',exe],folder,'compile_link')
   result=run([exe],folder,'native')
   if opt=='O0':(out/(name+'.oracle')).write_bytes(result)
   else:assert result==(out/(name+'.oracle')).read_bytes(),name+' O0/O2 mismatch'
 if a.incumbent:
  paths=['src/transaction/mod_transaction_reference.f90','tests/transaction/test_transaction_attempt_context.f90']
  report['incumbent_inputs']={p:hashlib.sha256((a.incumbent/p).read_bytes()).hexdigest()for p in paths}
  for opt in ['O0','O2']:
   for arm in ['stale','explicit_accounting']:
    folder=out/(opt+'-incumbent-context-'+arm);folder.mkdir();exe=folder/'driver'
    driver=a.incumbent/paths[1]if arm=='stale'else ROOT/paths[1]
    run([*fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-J'+str(folder),a.incumbent/paths[0],driver,'-o',exe],folder,'compile_link')
    result=run([exe],folder,'native',arm!='stale')
    if arm!='stale':assert result==(out/'context.oracle').read_bytes()
 report['status']='TYPED_WATER_FLUX_AND_INCUMBENT_TRANSACTION_CONTEXT_O0_O2_PASS'
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()
