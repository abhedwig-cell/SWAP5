"""Read-only nodal instrumentation of a retained failed executable, research only.

The original BUILD and accepted source binding are never rewritten. The debug
executable is separately hashed and cannot serve as qualification evidence.
"""
import argparse,json,os,shutil,subprocess,time
from pathlib import Path
import calendar_runtime as runtime
m=runtime.m

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('profile','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=json.loads((a.profile/'RESULT.json').read_text());old=Path(q['build_root']);meta=json.loads((old/'BUILD.json').read_text());a.output.mkdir();a.build_root.mkdir(exist_ok=True);(a.output/'trajectory').mkdir()
 for path in old.iterdir():
  if path.suffix.lower() in ('.o','.mod','.smod','.f90','.dll','.so'):shutil.copyfile(path,a.build_root/path.name)
 path=a.build_root/'headcalc.f90';source=path.read_text(encoding='cp1252');anchor='!     reset soil state variables'
 assert source.count(anchor)==1
 added="""
         if(dt<=dtmin)then
         do i=1,NN
            write(*,'(a,1x,i0,13(1x,es25.17e3))') 'DIAGNOSTIC_ORIGINAL_NODE', &
               i,F(i),h(i),hold(i),theta(i),thetm1(i),dimoca(i),difh(i),k(i),sink(i),source(i),qrot(i),hgrad(i),dFdhM(i)
         end do
         end if"""
 source=source.replace(anchor,anchor+added,1)
 anchor2='      call jacobian_F()';assert source.count(anchor2)==1
 fd="""
      if(dt<=dtmin.and.numbit==MaxIt1)then
      block
      integer::di,dj,ds
      real(8)::dh,hh(3),kk(3),tt,ff(2),fd(3),trialF,kmleft,kmright
      dh=1d-5
      do di=2,NN-1
         do dj=1,3
            do ds=1,2
               hh=h(di-1:di+1);hh(dj)=hh(dj)+real(2*ds-3,8)*dh
               kk=[hconduc(di-1,hh(1),watcon(di-1,hh(1)),rfcp(di-1)), &
                   hconduc(di,hh(2),watcon(di,hh(2)),rfcp(di)), &
                   hconduc(di+1,hh(3),watcon(di+1,hh(3)),rfcp(di+1))]
               if(di==22.and.dj==2)write(*,'(a,1x,es25.17e3,1x,i0,3(1x,es25.17e3))') &
                  'DIAGNOSTIC_ORIGINAL_K_CUTOFF',dt,ds,hh(2), &
                  (watcon(di,hh(2))-cofgen(1,di))/cofgen(25,di),kk(2)
               kmleft=hcomean(swkmean,kk(1),kk(2),dz(di-1),dz(di),di,hh(1),hh(2))
               kmright=hcomean(swkmean,kk(2),kk(3),dz(di),dz(di+1),di+1,hh(2),hh(3))
               ff(ds)=(watcon(di,hh(2))-thetm1(di))*FrArMtrx(di)*dz(di)/dt + sink(di)-source(di)+qrot(di) &
                   -kmleft*((hh(1)-hh(2))/disnod(di)+1d0)+kmright*((hh(2)-hh(3))/disnod(di+1)+1d0)
            end do
            fd(dj)=(ff(2)-ff(1))/(2d0*dh)
         end do
         write(*,'(a,1x,i0,1x,es25.17e3,7(1x,es25.17e3))')'DIAGNOSTIC_ORIGINAL_JACOBIAN_FD', &
            di,dt,dFdhU(di),dFdhM(di),dFdhL(di),fd,F(di)
      end do
      end block
      end if
"""
 source=source.replace(anchor2,anchor2+fd,1)
 path.write_text(source,encoding='cp1252')
 provider=a.reference_work/'build/swap-obj';ttutil=a.reference_work/'build/ttutil-obj';exe=a.build_root/'diagnostic_donor.exe'
 original=list(sorted(provider.glob('*.o')));known={p.name for p in original};actual=[a.build_root/p.name if (a.build_root/p.name).exists() else p for p in original];actual += [p for p in sorted(a.build_root.glob('*.o')) if p.name not in known]
 commands=[['gfortran',*meta['identity']['donor_flags'],'-I',str(a.build_root),'-I',str(provider),'-I',str(ttutil),'-c','headcalc.f90'],['gfortran','-o',str(exe),*map(str,actual),str(ttutil/'libttutil.a')]]
 logs=[]
 for command in commands:
  v=subprocess.run(command,cwd=a.build_root,capture_output=True,text=True,timeout=60);logs.append(dict(command=command,returncode=v.returncode,stdout=v.stdout,stderr=v.stderr));(a.output/'COMPILATION.json').write_text(json.dumps(logs,indent=2));v.check_returncode()
 shutil.copyfile(path,a.output/'actual-diagnostic-headcalc.f90');shutil.copyfile(exe,a.output/exe.name)
 project=m.e.load(a.profile/'input',original_output=True);_,case=m.validate_bundle(old,a.reference_work,project);origin=a.output/'origin';receipt=m.h.verify_checkpoint(a.profile/'trajectory/accepted-column-1-day-530.zip',530,meta['binding'],origin)
 start=time.monotonic()
 try:m.h.run(exe,m.h.executable(old,'day_kernel'),case,a.output/'trajectory',572,checkpoint_day=530,origin=origin,origin_receipt=receipt,runtime=True,publish_day=572,checkpoint_binding=meta['binding'],model=project.model,project=project)
 except RuntimeError as error:
  rows=m.rows(a.output/'trajectory');prior=m.rows(a.profile/'trajectory');assert m.physical(rows)==m.physical(prior[530:]);assert 'Implicit original retry reached clock resolution' in (a.output/'trajectory/original/donor.stderr').read_text()
  result=dict(status='ACTUAL_READ_ONLY_NODAL_FAILURE_DIAGNOSTIC_PREFIX_EXACT',actual_debug_executable_sha256=m.sha(exe),actual_debug_source_sha256=m.sha(path),original_BUILD_sha256=m.sha(old/'BUILD.json'),original_input_native_binding_retained=True,qualification=False,source=q['source'],exact_prefix_days=len(rows),seconds=time.monotonic()-start,error=str(error))
  (a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['status'])
 else:raise AssertionError('Read-only diagnostic changed failure')
if __name__=='__main__':main()
