"""Actual Windows public writer precommit failures and before/after publication termination."""
import argparse,ctypes,hashlib,json,os,subprocess,time,uuid
from pathlib import Path
import generation_publication_policy as policy
sha=policy.sha;ROOT=policy.ROOT
FAULT='''
 subroutine publication_failure_mode()
  type(crop_ext_state_t)::o
  type(crop_ext_row_t),allocatable::rows(:)
  character(10),allocatable::dates(:)
  character(512)::after
  integer::code
SAVED_DECL
  call get_command_argument(5,after)
  call READ_ROUTINE(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   9101_int64,sp,cp,water,state,o,SAVED_ARG dates,rows,code)
  call require(code==0,'publication fault seed reconstructs')
  call WRITE_ROUTINE(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
   water,state,o,SAVED_ARG dates,rows,code)
  call require(code/=0,'actual public writer reports precommit publication failure')
  call WRITE_ROUTINE(trim(after),column,cfg%tiles(1)%template,670001_int64, &
   water,state,o,SAVED_ARG dates,rows,code)
  call require(code==0,'failed publication preserves complete input authority')
  print '(A)','PUBLIC_GENERATION_PRECOMMIT_FAILURE_AND_AUTHORITY=PASS'
 end subroutine
'''
def build(base,out,opt,family,fc):
 ledger=json.loads((base/(family+'-EFFECTIVE_COMPILER.json')).read_text());name='joint-output'if family=='joint'else'saved'
 link=next(e['effective_command']for e in ledger if '-o'in e['effective_command']and'-c'not in e['effective_command']and Path(e['effective_command'][-1]).name==name and '/'+opt+'/'in e['effective_command'][-1].replace('\\','/'))
 commands=[]
 def run(cmd):
  r=subprocess.run(list(map(str,cmd)),capture_output=True,cwd=out);i=len(commands)
  for stream in ('stdout','stderr'):(out/(str(i)+'.'+stream)).write_bytes(getattr(r,stream))
  commands.append(dict(command=list(map(str,cmd)),returncode=r.returncode));(out/'BUILD_EVENTS.json').write_text(json.dumps(commands,indent=2)+'\n');assert r.returncode==0,r.stderr[-4000:]
 cc=subprocess.check_output([str(fc),'-print-prog-name=gcc'],text=True).strip();c=out/'production.c';c.write_text(policy.candidate_c(),encoding='utf-8',newline='\n')
 real=out/'production.o';shim=out/'shim.o';run([cc,'-'+opt,'-std=c11','-DSWAP5_RESTART_TESTING','-Dswap5_generation_publish=swap5_generation_publish_real','-c',c,'-o',real]);run([cc,'-'+opt,'-std=c11','-c',ROOT/'tests/nut-output/generation_publication_windows_test.c','-o',shim])
 flags=link[1:];index=next(i for i,x in enumerate(flags)if x.endswith('.o'));flags=flags[:index]
 for folder in ('nut-output','nut-crop','nut-reactive','nut-sol','nut-material'):flags+=['-I'+str(ROOT/'tests'/folder)]
 for folder in (base/family/opt,base/'accepted'/opt,base/'cold'/opt,base/'saved',base/'accepted'):flags+=['-I'+str(folder)]
 source=(base/family/'driver.f90').read_text();anchor=" if(trim(mode)=='generation-read'.or.trim(mode)=='generation-reject')then"if family=='joint'else" if(trim(mode)=='saved-resume'.or.trim(mode)=='saved-reject'.or.trim(mode)=='saved-reject-live')then"
 assert source.count(anchor)==1;source=source.replace(anchor," if(trim(mode)=='publication-fail')then\n  call publication_failure_mode()\n  stop\n end if\n"+anchor,1)
 routine=FAULT.replace('SAVED_DECL','  type(crop_ext_saved_residue_t)::saved'if family=='saved'else'').replace('SAVED_ARG','saved,'if family=='saved'else'').replace('READ_ROUTINE','read_crop_n_saved_generation'if family=='saved'else'read_crop_n_output_generation').replace('WRITE_ROUTINE','write_crop_n_saved_generation'if family=='saved'else'write_crop_n_output_generation')
 assert source.count('\ncontains\n')==1;source=source.replace('\ncontains\n','\ncontains\n'+routine,1);f=out/'fault-driver.f90';f.write_text(source,encoding='utf-8',newline='\n');obj=out/'fault-driver.o';run([fc,*flags,'-c',f,'-o',obj])
 for kind in ('ordinary','fault'):
  args=link[1:].copy();old_pub=str(base/'publication'/(opt+'.o'));assert args.count(old_pub)==1;i=args.index(old_pub);args[i:i+1]=[str(real),str(shim)]
  if kind=='fault':
   old_driver=str(base/family/opt/'driver.o');assert args.count(old_driver)==1;args[args.index(old_driver)]=str(obj)
  exe=out/(kind+'.exe');args[-1]=str(exe);response=out/(kind+'.args');response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n',encoding='utf-8');run([fc,'@'+str(response)])
 return out/'ordinary.exe',out/'fault.exe'
def main():
 p=argparse.ArgumentParser();p.add_argument('--models',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();assert os.name=='nt';policy.guard();base=a.models.resolve();out=a.output.resolve();out.mkdir(parents=True);events=[];reports=[]
 def run(cmd,case,env,label):
  r=subprocess.run(list(map(str,cmd)),cwd=case,capture_output=True,env=env,timeout=180);stem=str(len(events))
  for stream in ('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,stdout=stem+'.stdout',stderr=stem+'.stderr'));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0 and b'PUBLIC_GENERATION_PRECOMMIT_FAILURE_AND_AUTHORITY=PASS'in r.stdout,(label,r.stdout,r.stderr)
 k=ctypes.WinDLL('kernel32',use_last_error=True);k.CreateEventA.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_char_p];k.CreateEventA.restype=ctypes.c_void_p;k.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32];k.CloseHandle.argtypes=[ctypes.c_void_p]
 for opt in ('O0','O2'):
  for family in ('joint','saved'):
   folder=out/(opt+'-'+family);folder.mkdir();ordinary,fault=build(base,folder,opt,family,a.compiler.resolve())
   if family=='joint':old=base/family/opt/'model.restart.generation';good=base/family/opt/'model.endpoint.generation'
   else:
    prefix=base/family/opt/'endpoint.stages.saved'
    if not Path(str(prefix)+'.phase-3').exists():prefix=base/family/opt/'endpoint.saved'
    old=Path(str(prefix)+'.phase-2');good=Path(str(prefix)+'.phase-3')
   failures=[]
   for stage in (2,3,4,5,6):
    case=folder/('failure-'+str(stage));case.mkdir();target=case/'authority';after=case/'after';target.write_bytes(old.read_bytes());env=dict(os.environ,OMP_NUM_THREADS='1',GPUB_TARGET=str(target),GPUB_FAIL=str(stage))
    run([fault,'publication-fail',good,target,'',after],case,env,family+'-'+opt+'-'+str(stage));assert target.read_bytes()==old.read_bytes()and after.read_bytes()==good.read_bytes();failures.append(stage)
   crashes=[]
   for phase in ('before','after'):
    case=folder/('terminate-'+phase);case.mkdir();target=case/'authority';target.write_bytes(old.read_bytes());nonce=uuid.uuid4().hex;ready=('Local\\s5-gen-ready-'+nonce).encode();release=('Local\\s5-gen-release-'+nonce).encode();h=k.CreateEventA(None,1,0,ready);g=k.CreateEventA(None,1,0,release);assert h and g
    mode='generation-read'if family=='joint'else'saved-resume';cmd=[str(ordinary),mode,str(good),str(target)]+([]if family=='joint'else['','roundtrip']);env=dict(os.environ,OMP_NUM_THREADS='1',GPUB_TARGET=str(target),GPUB_ACTION=phase,GPUB_READY=ready.decode(),GPUB_RELEASE=release.decode())
    try:
     with(case/'stdout').open('wb')as so,(case/'stderr').open('wb')as se:
      child=subprocess.Popen(cmd,cwd=case,env=env,stdout=so,stderr=se);assert k.WaitForSingleObject(h,30000)==0,(phase,child.poll());child.kill();child.wait(timeout=10);assert child.returncode!=0
     expected=old.read_bytes()if phase=='before'else good.read_bytes();assert target.read_bytes()==expected
     recovered=case/'recovered';recover=[str(ordinary),mode,str(target),str(recovered)]+([]if family=='joint'else['','roundtrip']);r=subprocess.run(recover,cwd=case,capture_output=True,timeout=180,env=dict(os.environ,OMP_NUM_THREADS='1'));assert r.returncode==0 and recovered.read_bytes()==expected,(r.stdout,r.stderr)
     crashes.append(dict(phase=phase,actual_termination_returncode=child.returncode,complete_authority_sha256=sha(expected),fresh_reconstruction=True))
    finally:k.CloseHandle(h);k.CloseHandle(g)
   reports.append(dict(optimization=opt,family=family,precommit_failures=failures,termination=crashes))
 (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_WINDOWS_PUBLIC_GENERATION_FAILURES_AND_NATIVE_TERMINATION_PASS',reports=reports,events=events,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_WINDOWS_PUBLIC_GENERATION_FAILURES_AND_NATIVE_TERMINATION_PASS')
if __name__=='__main__':main()
