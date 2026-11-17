"""Trace original accepted steps without changing their calculation order."""
from pathlib import Path
import hashlib,json,shutil,subprocess,time
from refine import OUT,sha,rows
P=Path('C:/SWAP5-RC2/provider/build')
def run(cmd,cwd):
 r=subprocess.run([str(x) for x in cmd],cwd=cwd,capture_output=True,text=True,timeout=30)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r
def main():
 build=OUT/'trace-original-build';build.mkdir();s=(P/'swap-selected/swap.f90').read_text(encoding='cp1252')
 old='use MOD_irrigation,      only: irrigation, flirrigate';assert s.count(old)==1
 s=s.replace(old,old+', gird,nird,dt_irr_event\nuse MOD_top,only:q0,hsurf,FlRunoff,ftoph')
 s=s.replace('daynr, gwl, gwlm1, dt, t1900','daynr, gwl, gwlm1, dt, t1900, h,pond,pondm1,pondmx,runots,qtop,volact')
 anchor='      call integral(3)';assert s.count(anchor)==1
 trace="""
      write(*,'(a,13(1x,es25.17e3),2(1x,l1))') 'GWL_STEP', &
        t1900-tstart,dt,gird,nird,dt_irr_event,pond,pondm1,pondmx,runots,qtop,h(1),gwl,volact,FlRunoff,ftoph
"""
 (build/'swap.f90').write_text(s.replace(anchor,anchor+trace),encoding='cp1252')
 flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic']
 cmd=['gfortran',*flags,'-I',P/'swap-obj','-I',P/'ttutil-obj','-c',build/'swap.f90','-o',build/'swap.o'];run(cmd,build)
 exe=build/'original_trace.exe';link=['gfortran','-o',exe,*[build/'swap.o' if p.name=='swap.o' else p for p in sorted((P/'swap-obj').glob('*.o'))],P/'ttutil-obj/libttutil.a'];run(link,build)
 result={'original_source_sha256':sha(P/'swap-selected/swap.f90'),'trace_source_sha256':sha(build/'swap.f90'),'executable_sha256':sha(exe),'compile':list(map(str,cmd)),'link':list(map(str,link)),'runs':{}}
 for name in ('nominal','dt0004'):
  case=OUT/('trace-'+name);case.mkdir()
  for p in (OUT/name).iterdir():
   if p.name in json.loads((OUT/'RESULT.json').read_text())['runs'][name]['inputs']:shutil.copy2(p,case/p.name)
  start=time.perf_counter()
  with (case/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=case,stdout=log,stderr=subprocess.STDOUT,timeout=20)
  exact=rows(case/'result_output.csv')==rows(OUT/name/'result_output.csv');assert exact
  lines=[x for x in (case/'stdout').read_text().splitlines() if x.startswith('GWL_STEP')]
  result['runs'][name]=dict(seconds=time.perf_counter()-start,returncode=r.returncode,exact_uninstrumented_csv=exact,steps=len(lines),trace_sha256=sha(case/'stdout'))
  (OUT/'TRACE.json').write_text(json.dumps(result,indent=2));print(name,result['runs'][name],flush=True)
if __name__=='__main__':main()
