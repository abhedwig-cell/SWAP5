"""Reproduce the actual unqualified AGE state blocker through the real interface."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
 sys.path.insert(0,str(ROOT/'app/hybrid_water'));from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
 provider=ROOT/'src/process/mod_b111_surface_age_budget.f90';driver=Path(__file__).with_name('implicit_age_dryout_driver.f90');fixture=Path(__file__).with_name('implicit_age_dryout_inputs.json');inputs=json.loads(fixture.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 assert hashlib.sha256(provider.read_bytes().replace(b'\r\n',b'\n')).hexdigest()==inputs['provider_lf_sha256']
 numeric=a.output/'actual-input.dat';numeric.write_text(' '.join(map(repr,inputs['actual_request']))+'\n')
 q=dict(status='RUNNING',scope='Scientific/state blocker reproduction only; no implicit AGE admission, solver substitute or change to qualified old AGE contracts.',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,actual_provider_raw_sha256=sha(provider),actual_provider_lf_sha256=inputs['provider_lf_sha256'],driver_sha256=sha(driver),fixture_sha256=sha(fixture),compile_link_closure=[str(provider.relative_to(ROOT)),str(driver.relative_to(ROOT))],floating_point_profile=no_macro_fp_profile())
 try:
  exe=a.output/('blocker.exe' if os.name=='nt' else 'blocker');t=time.perf_counter();r=subprocess.run(['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all',*NO_MACRO_FP_FLAGS,str(provider),str(driver),'-o',str(exe)],cwd=a.output,capture_output=True,text=True,timeout=30);q['compile_link_seconds']=time.perf_counter()-t;(a.output/'compile.log').write_text(r.stdout+r.stderr);r.check_returncode()
  t=time.perf_counter();r=subprocess.run([str(exe),str(numeric)],cwd=a.output,capture_output=True,text=True,timeout=10);q.update(native_seconds=time.perf_counter()-t,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr);r.check_returncode();assert 'ACTUAL_RETAINED_SURFACE_AGE_DRYOUT_REFUSAL_REPRODUCED' in r.stdout
  q['status']='REPRODUCED_RETAINED_SURFACE_AGE_DRYOUT_STATE_BLOCKER_NOT_QUALIFIED';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')


if __name__=='__main__':main()
