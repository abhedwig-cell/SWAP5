"""Passive current full/two-half error components; production criteria unchanged."""
import argparse,hashlib,json,os,runpy,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='src/process/mod_pond_water_temporal_difference.f90'
APP='app/solute_project/main.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--compiler',required=True);ap.add_argument('--previous',type=Path,required=True)
 ap.add_argument('--bundle-prefix',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 r=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_sha256=sha(Path(__file__)),events=[],builds={},physical_outputs_exact=True)
 def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
 def run(cmd,cwd,label):
  cmd=list(map(str,cmd));t=time.perf_counter();x=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(x,s))
  r['events'].append(dict(label=label,command=cmd,seconds=time.perf_counter()-t,returncode=x.returncode));save();x.check_returncode()
 fc=['sh',a.compiler];core=min(os.sched_getaffinity(0));r['core']=core
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());exe=Path(bundle['exe']);m=json.loads((exe.parent/'build-complete.json').read_text())
  assert sha(exe)==m['executable_sha256']
  for p,h in m['input_sha256'].items():assert sha(ROOT/p)==h,p
  for p,h in m['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
  assert subprocess.check_output(fc+['--version'],text=True).splitlines()[0]==m['compiler']
  r['builds'][opt]=dict(input_sha256=m['input_sha256'],reused_artifact_sha256=m['reused_artifact_sha256'])
  folder=out/opt;folder.mkdir();flags=[v for v in m['flags']if not v.startswith('-J')]
  objects=[e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')];assert len(objects)==193
  archive=next(p for p in m['reused_artifact_sha256']if p.endswith('/libttutil.a'))
  d=folder/'temporal_diag.f90';d.write_text('''module temporal_diag
 use iso_fortran_env,only:int64,real64
 implicit none
 integer::day=1,phase=1
 real(real64)::tol=0d0
 real(real64),allocatable::dz(:)
 integer(int64)::counts(10,97,2)=0
 real(real64)::maxima(4,97,2)=0d0
 contains
 subroutine record_error(hf,hh,wf,wh,pf,ph,gf,gh)
 real(real64),intent(in)::hf(:),hh(:),wf(:),wh(:),pf,ph,gf,gh
 real(real64)::h,p,g,w,v
 h=maxval(abs(hf-hh));p=abs(pf-ph);g=abs(gf-gh)
 w=10d0*(sum(abs(wf-wh)*dz)+p)
 v=max(h,p,g)
 counts(1,day,phase)=counts(1,day,phase)+1
 maxima(:,day,phase)=max(maxima(:,day,phase),[h,p,g,w])
 if(v<=tol)return
 counts(2,day,phase)=counts(2,day,phase)+1
 if(h==v)counts(3,day,phase)=counts(3,day,phase)+1
 if(p==v)counts(4,day,phase)=counts(4,day,phase)+1
 if(g==v)counts(5,day,phase)=counts(5,day,phase)+1
 if(w<1d-4)counts(6,day,phase)=counts(6,day,phase)+1
 if(w<1d-3)counts(7,day,phase)=counts(7,day,phase)+1
 if(w<1d-2)counts(8,day,phase)=counts(8,day,phase)+1
 if(w<1d-1)counts(9,day,phase)=counts(9,day,phase)+1
 if(all(wf==wh).and.pf==ph)counts(10,day,phase)=counts(10,day,phase)+1
 end subroutine
 subroutine report_errors()
 integer::u,d,a
 open(newunit=u,file='temporal_components.csv',status='new')
 write(u,'(A)')'day,phase,assessments,rejects,head_max,pond_max,gwl_max,water_below_0.0001mm,water_below_0.001mm,water_below_0.01mm,water_below_0.1mm,water_identical,max_head_cm,max_pond_cm,max_gwl_cm,max_water_l1_mm'
 do a=1,2
 do d=1,97
 if(counts(1,d,a)>0)write(u,'(I0,11(A,I0),4(A,ES25.17E3))')d,',',a,',',counts(:,d,a),',',maxima(:,d,a)
 enddo
 enddo
 close(u)
 end subroutine
 end module
''')
  # Array-valued WRITE needs explicit separators for each element.
  text=d.read_text().replace("',',counts(:,d,a),',',maxima(:,d,a)","',',counts(1,d,a),',',counts(2,d,a),',',counts(3,d,a),',',counts(4,d,a),',',counts(5,d,a),',',counts(6,d,a),',',counts(7,d,a),',',counts(8,d,a),',',counts(9,d,a),',',counts(10,d,a),',',maxima(1,d,a),',',maxima(2,d,a),',',maxima(3,d,a),',',maxima(4,d,a)")
  d.write_text(text);run([*fc,*flags,'-J'+str(folder),'-c',d,'-o',folder/'diag.o'],folder,opt+'-diag-build')
  raw=(ROOT/SOURCE).read_text();anchor='    real(real64),intent(in)::hf(:)'
  assert raw.count(anchor)==1;raw=raw.replace(anchor,'    use temporal_diag,only:record_error\n'+anchor)
  anchor='    available=.true.';assert raw.count(anchor)==1
  raw=raw.replace(anchor,anchor+'\n    call record_error(hf,hh,wf,wh,pf,ph,gf,gh)')
  p=folder/'difference.f90';p.write_text(raw);obj=folder/'difference.o'
  run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),'-c',p,'-o',obj],folder,opt+'-difference-build')
  old=next(e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+SOURCE));objects[objects.index(old)]=str(obj)
  raw=(ROOT/APP).read_text();anchor='  use iso_fortran_env,';assert raw.count(anchor)==1
  raw=raw.replace(anchor,'  use temporal_diag,only:diag_day=>day,diag_phase=>phase,diag_tol=>tol,diag_dz=>dz,report_errors\n'+anchor)
  anchor='  do j=first,stop_after';assert raw.count(anchor)==1;raw=raw.replace(anchor,'  diag_tol=temporal_tolerance;diag_dz=dz\n'+anchor+'\n    diag_day=j;diag_phase=1')
  anchor='      numerical%retain_accepted_step_proposal=.false.';assert raw.count(anchor)==1;raw=raw.replace(anchor,'      diag_phase=2\n'+anchor)
  anchor="  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'";assert raw.count(anchor)==1;raw=raw.replace(anchor,'  call report_errors()\n'+anchor)
  p=folder/'main.f90';p.write_text(raw);binary=folder/'observer';run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),p,*objects,folder/'diag.o',archive,'-o',binary],folder,opt+'-link')
  for rain in [1,4]:
   label=f'{opt}-{rain}x';case=out/label;case.mkdir();previous=a.previous/f'{opt}-{rain}x-ordinary-0'
   for n in ['input.nml','input.swp']:(case/n).write_bytes((previous/n).read_bytes())
   run(['taskset','-c',core,binary,'input.nml','-','97','input.swp'],case,label)
   for n in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (case/n).read_bytes()==(previous/n).read_bytes(),(label,n)
 r['status']='CURRENT_TEMPORAL_COMPONENT_OBSERVER_O0_O2_PHYSICAL_BYTES_EXACT';save();print(r['status'])
if __name__=='__main__':main()
