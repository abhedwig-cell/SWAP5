#!/usr/bin/env python3
"""Run unchanged original transaction/macropore assertions with live module closure.

Repairs source selection only; all original drivers and assertions remain intact.
"""
import argparse,hashlib,importlib.util,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 spec=importlib.util.spec_from_file_location('identity',ROOT/'tools/performance/irrigation_build_identity.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 class NonIntrinsicImports:
  def findall(self,text):return [n for n in pattern.findall(text) if n.lower() not in {'iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'}]
 pattern=m.USE;m.USE=NonIntrinsicImports()
 drivers=[ROOT/'tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90',ROOT/'tests/fpm/test_migmac11_pond_donor.f90',ROOT/'tests/fmig431/test_swap431_low3_explicit_application.f90',ROOT/'tests/fmig431/test_swap431_low3_explicit_progress_restart.f90']
 head=ROOT/'src/legacy/b1_10_port/headcalc.f90';files=sorted((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']
 sources=m.discover(files,[*drivers,head])+[head];report=dict(source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in sources+drivers},events=[],runs=[])
 def run(cmd,cwd,label):
  t=time.monotonic();p=subprocess.run(cmd,cwd=cwd,capture_output=True);(out/(label+'.stdout')).write_bytes(p.stdout);(out/(label+'.stderr')).write_bytes(p.stderr);report['events'].append(dict(command=cmd,wall=time.monotonic()-t,exit=p.returncode))
  (out/'CONTROL.json').write_text(json.dumps(report,indent=2))
  if p.returncode:raise RuntimeError(label)
  return p
 for opt in ['O0','O2']:
  b=out/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objs=[]
  for i,p in enumerate(sources):
   o=b/f'{i}.o';run(['gfortran',*flags,'-c',str(p),'-o',str(o)],b,f'{opt}-compile-{i}');objs.append(str(o))
  for i,p in enumerate(drivers):
   o=b/'test.o';run(['gfortran',*flags,'-c',str(p),'-o',str(o)],b,f'{opt}-driver-{i}');exe=b/f'test{i}';run(['gfortran',*flags,*objs,str(o),'-o',str(exe)],b,f'{opt}-link-{i}');v=run([str(exe)],b,f'{opt}-run-{i}')
   report['runs'].append(dict(opt=opt,driver=str(p.relative_to(ROOT)),stdout=v.stdout.decode(),sha256=hashlib.sha256(v.stdout).hexdigest()));print(opt,p.name,v.stdout.decode(),flush=True)
 for i in range(len(drivers)):
  if report['runs'][i]['sha256']!=report['runs'][i+len(drivers)]['sha256']:raise RuntimeError('O0/O2 semantic drift')
 report['pass']=True;(out/'CONTROL.json').write_text(json.dumps(report,indent=2));print('PERF01_ORIGINAL_PRESERVATION=PASS')
if __name__=='__main__':main()
