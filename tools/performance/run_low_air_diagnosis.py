#!/usr/bin/env python3
"""Bounded B15 highest low-air observation. Never a qualification receipt.

Uses the unchanged initial physical fixture and production interfaces. Only the
observation horizon and terminal driver are shortened; mandatory owner is intact.
"""
import argparse, re, hashlib, importlib.util, json, os, pathlib, platform, resource, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--horizon',default='1.e-7_real64');a.add_argument('--profile',action='store_true');a.add_argument('--policy',action='store_true');a.add_argument('--full-driver',action='store_true');a.add_argument('--opt',type=int,choices=[0,2],default=2);a.add_argument('--timeout',type=float,default=60);args=a.parse_args()
 out=args.output.resolve();out.mkdir(exist_ok=False,parents=True)
 report={'scope':'DIAGNOSTIC_NOT_QUALIFICATION','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'host':platform.uname()._asdict(),'horizon':args.horizon,'events':[],'sources':{},'profile':args.profile}
 def run(cmd,label,cwd=out,timeout=None):
  before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
  try:
   cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'});exitcode=cp.returncode;stdout=cp.stdout;stderr=cp.stderr
  except subprocess.TimeoutExpired as e:exitcode=None;stdout=e.stdout or b'';stderr=e.stderr or b''
  after=resource.getrusage(resource.RUSAGE_CHILDREN)
  (out/(label+'.stdout')).write_bytes(stdout);(out/(label+'.stderr')).write_bytes(stderr)
  event={'label':label,'command':list(map(str,cmd)),'wall_seconds':time.monotonic()-start,'cpu_seconds':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'exit':exitcode}
  report['events'].append(event);(out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
  return exitcode
 stub=out/'consistent_grid_stubs.f90';s=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
 old='  real(8), parameter :: disnod(numnod+1) = 1.0d0';text=s.read_text();assert text.count(old)==1
 stub.write_text(text.replace(old,'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'))
 driver=out/'low_air_driver.f90';original=ROOT/'tests/frost/test_ppa_wu05b15_low_air_runtime.f90';text=original.read_text()
 needle='      call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,result,observation,'
 assert text.count(needle)==1;text=text.replace(needle,needle.replace('1.e-4_real64',args.horizon))
 needle="      call require(result%completed.and.result%committed,'signed single-level exchange commits')"
 text=text.replace(needle,"      print *, 'LOW_AIR_DIAG',result%completed,result%committed,result%accepted_substeps,result%temporal_rejections,result%mass%residual\n      stop\n"+needle);
 if args.full_driver:text=original.read_text()
 if args.policy:
  text=text.replace('    config%transaction%retry_scale = 0.5_real64','    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64')
  text=text.replace('    cfg%numerical%transaction%retry_scale=.5_real64','    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64')
 driver.write_text(text)
 # Observational transaction records, in a generated provider; production unchanged.
 runtime=out/'mod_canonical_interval_runtime.f90';orig=ROOT/'src/runtime/mod_canonical_interval_runtime.f90';text=orig.read_text()
 needle='      call accumulate_transaction(result, tx)';assert text.count(needle)==1
 text=text.replace(needle,needle+"\n      if(isub<=64.or.mod(isub,1000)==0)print *, 'LOW_AIR_TX',isub,cursor,transaction_t1,tx%accepted_dt,tx%attempts, &\n           tx%solver_rejections,tx%mass_rejections,tx%temporal_rejections,tx%headcalc_calls,tx%nonlinear_iterations,tx%temporal_error")
 runtime.write_text(orig.read_text() if args.full_driver else text)
 spec=importlib.util.spec_from_file_location('identity',ROOT/'tools/performance/irrigation_build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
 files=[p for p in sorted((ROOT/'src').rglob('*.f90')) if p!=orig]+[runtime,stub]+list((ROOT/'tests/frost').glob('mod_*fixture.f90'))
 identity.USE=re.compile(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(?!ieee_arithmetic\b|ieee_exceptions\b|iso_c_binding\b|omp_lib\b)(\w+)',re.I|re.M)
 ordered=identity.discover(files,[driver]);ordered+=[ROOT/'src/legacy/b1_10_port/headcalc.f90',driver]
 report['sources']={str(p):sha(p) for p in ordered+[s,original,orig]};report['ordered_sources']=list(map(str,ordered))
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{args.opt}']+(['-pg'] if args.profile else [])
 report['flags']=flags;report['compiler']=subprocess.check_output(['gfortran','--version'],text=True)
 objects=[]
 for i,p in enumerate(ordered):
  obj=out/f'{i}.o'
  if run(['gfortran',*flags,'-J',out,'-I',out,'-c',p,'-o',obj],f'compile-{i}')!=0:raise RuntimeError('compile failed '+str(p))
  objects.append(obj)
 if run(['gfortran',*flags,*objects,'-o',out/'test'],'link')!=0:raise RuntimeError('link failed')
 report['binary_sha256']=sha(out/'test')
 code=run([out/'test','1'],'native',timeout=args.timeout)
 report['terminal_status']='CENSORED_NOT_QUALIFICATION' if code is None else 'DIAGNOSTIC_COMPLETED' if code==0 else 'DIAGNOSTIC_FAILED'
 if args.profile and code==0:run(['gprof',out/'test',out/'gmon.out'],'gprof')
 (out/'RESULTS.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:report[k] for k in ['terminal_status','binary_sha256','horizon']}))
if __name__=='__main__':main()
