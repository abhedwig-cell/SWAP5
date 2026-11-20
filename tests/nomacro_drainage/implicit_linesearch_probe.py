"""Research comparison of original backtracking below DTMIN, no admission.

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
 old_step='         if (fldtmin .AND. numbit > MaxIt) then'
 assert source.count(old_step)==1
 source=source.replace(old_step,'         if (fldtmin .AND. numbit > MaxIt .AND. .not.(swmacro==0.and.swkimpl==1)) then',1)
 path.write_text(source.replace(anchor,anchor+added,1),encoding='cp1252')
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
 else:
  rows=m.rows(a.output/'trajectory');m.check(rows)
  import implicit_forensics as science
  result=dict(status='RESEARCH_ORIGINAL_BACKTRACKING_BELOW_DTMIN_COMPLETES_PREVIOUS_FAILURE_WINDOW',actual_days=len(rows),actual_debug_executable_sha256=m.sha(exe),actual_debug_source_sha256=m.sha(path),original_BUILD_sha256=m.sha(old/'BUILD.json'),original_input_native_binding_retained_for_research_only=True,qualification=False,source=q['source'],independent_conservation=science.inventory(rows),seconds=time.monotonic()-start)
  (a.output/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['status'])
if __name__=='__main__':main()
