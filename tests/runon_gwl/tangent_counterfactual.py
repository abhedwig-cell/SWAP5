"""Keep original forcing/tolerances; change only Newton's pond derivative."""
from pathlib import Path
import json,shutil,subprocess,time
from refine import OUT,sha,rows
from trace_reference import P,run
def main():
 result={}
 for mode in ('original','exact-tangent'):
  build=OUT/(mode+'-attempt-build');build.mkdir()
  s=(OUT/'trace-original-build/swap.f90').read_text(encoding='cp1252')
  anchor='         if (fldecdt .OR. (swmacro == 1 .AND. FlDecMpRat)) then';assert s.count(anchor)==1
  s=s.replace(anchor,"         if(t1900-tstart>=4d0) write(*,'(a,2(1x,es25.17e3),1x,l1)') 'GWL_ATTEMPT',t1900-tstart,dt,fldecdt\n"+anchor)
  (build/'swap.f90').write_text(s,encoding='cp1252')
  flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic','-I',P/'swap-obj','-I',P/'ttutil-obj']
  commands=[['gfortran',*flags,'-c',build/'swap.f90']];run(commands[-1],build)
  if mode=='exact-tangent':
   s=(P/'swap-selected/headcalc.f90').read_text(encoding='cp1252');s=s.replace('subroutine headcalc \n','subroutine headcalc\n   use variables,only:pondmx,rsro,rsroexp\n')
   anchor='   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)';assert s.count(anchor)==1
   s=s.replace(anchor,"""   if(ftoph)then
      if(FlRunoff.and.rsroexp==1d0.and.rsro>=1d-3)then
         dFdhM(1)=dFdhM(1)+(kmean(1)/disnod(1))*(1d0+merge(dt/rsro,0d0,pond>pondmx))/ &
            (1d0+dt*kmean(1)/disnod(1)+merge(dt/rsro,0d0,pond>pondmx))
      else
         dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)
      end if
   end if""")
   (build/'headcalc.f90').write_text(s,encoding='cp1252');commands.append(['gfortran',*flags,'-c',build/'headcalc.f90']);run(commands[-1],build)
  exe=build/'original_diagnostic.exe';commands.append(['gfortran','-o',exe,*[build/p.name if (build/p.name).exists() else p for p in sorted((P/'swap-obj').glob('*.o'))],P/'ttutil-obj/libttutil.a']);run(commands[-1],build)
  case=OUT/(mode+'-attempt-run');case.mkdir();inventory=json.loads((OUT/'RESULT.json').read_text())['runs']['nominal']['inputs']
  for name in inventory:shutil.copy2(OUT/'nominal'/name,case/name)
  start=time.perf_counter()
  with (case/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=case,stdout=log,stderr=subprocess.STDOUT,timeout=20)
  data=rows(case/'result_output.csv');assert len(data)==6 and (case/'swap.ok').exists()
  if mode=='original':assert data==rows(OUT/'nominal/result_output.csv')
  attempts=[x for x in (case/'stdout').read_text().splitlines() if x.startswith('GWL_ATTEMPT')]
  result[mode]=dict(seconds=time.perf_counter()-start,executable_sha256=sha(exe),sources={p.name:sha(p) for p in build.glob('*.f90')},commands=[list(map(str,c)) for c in commands],end=data[-1],first_attempts=attempts[:8],tolerances_changed=False)
  (OUT/'TANGENT_COUNTERFACTUAL.json').write_text(json.dumps(result,indent=2));print(mode,result[mode]['first_attempts'][:4],{k:data[-1][k] for k in ('GWL','RUNOFF','WTOT','DRN')},flush=True)
if __name__=='__main__':main()
