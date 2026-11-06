"""Real Windows thermal writer authority faults, poisoned native flags and termination."""
import argparse,ctypes,json,os,subprocess,uuid
from pathlib import Path
import matrix_thermal_native_policy as policy
from matrix_thermal_native_controls import BRANCH
ROOT=policy.ROOT;sha=policy.sha

def build(base,opt,out,fc):
 ledger=json.loads((base/'COMPILER.json').read_text());link=next(e['effective']for e in ledger if '-c'not in e['effective']and'-o'in e['effective']and'-'+opt in e['effective']and e['returncode']==0)
 report=json.loads((base/'physical/result.json').read_text());driver=next(e['command']for e in report['events']if e['category']=='compile'and'-'+opt in e['command']and e['command'][-3].replace('\\','/').endswith('/tests/nut-sol/test_matrix_thermal.f90'))
 module=next(e['command']for e in report['events']if e['category']=='compile'and'-'+opt in e['command']and e['command'][-3].replace('\\','/').endswith('/'+policy.SOURCE))
 flags=[x for x in driver[1:driver.index('-c')]if not x.startswith('-J')]+['-J'+str(out),'-I'+str(base/'physical'/opt),'-I'+str(base/'physical')];events=[]
 def run(cmd):
  cp=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True);index=len(events)
  for stream in ('stdout','stderr'):(out/(str(index)+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(command=list(map(str,cmd)),returncode=cp.returncode));(out/'BUILD.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr[-4000:]
 cc=subprocess.check_output([str(fc),'-print-prog-name=gcc'],text=True).strip();c=out/'publication.c';c.write_text(policy.before('app/support/restart_publish.c'),encoding='utf-8',newline='\n');real=out/'real.o';shim=out/'shim.o'
 shim_source=ROOT/'tests/nut-sol'/('matrix_thermal_windows_test.c' if os.name=='nt' else 'matrix_thermal_posix_test.c')
 run([cc,'-'+opt,'-std=c11','-DSWAP5_RESTART_TESTING','-Dswap5_restart_publish=swap5_restart_publish_real','-c',c,'-o',real]);run([cc,'-'+opt,'-std=c11','-c',shim_source,'-o',shim])
 # Only this qualification derivative injects raw fields after trusted export.
 source=policy.candidate().replace('integer::u,io,code,n,slash','integer::u,io,code,n,slash,test_unit');anchor=' interface\n';source=source.replace(anchor,anchor+"  integer(c_int) function bad_logical()bind(C,name='matrix_bad_logical')\n   import c_int\n  end function\n",1)
 anchor='   associate(r=>b%records(1))\n    if(.not.logical_value_valid';assert source.count(anchor)==1;source=source.replace(anchor,'   associate(r=>b%records(1))\n'+"    code=bad_logical()\n    print *, 'INJECT_CODE',code\n    if(code>0)then\n     open(newunit=test_unit,status='scratch',access='stream',form='unformatted')\n     write(test_unit)2\n     if(code==1)read(test_unit,pos=1)r%time_bound\n     if(code==2)read(test_unit,pos=1)history\n     close(test_unit)\n     print *, 'INJECT_BITS',transfer(r%time_bound,0),transfer(history,0)\n    end if\n    if(.not.logical_value_valid",1);f=out/'writer-test.f90';f.write_text(source,encoding='utf-8',newline='\n');obj=out/'writer-test.o';run([fc,*flags,'-c',f,'-o',obj])
 source=policy.before('tests/nut-sol/test_matrix_thermal.f90');branch=BRANCH.replace("trim(mode)=='probe-export'","(trim(mode)=='probe-export'.or.trim(mode)=='probe-writer')")
 branch=branch.replace("    call require(status==0,'proper public reader reexport')", "    print '(A,I0)','WRITE_STATUS=',status\n    call get_command_argument(6,arg)\n    if(len_trim(arg)>0)then\n     call write_matrix_thermal_restart(trim(arg),column,cfg%tiles(1)%template,670001_int64, &\n      cfg%tiles(1)%parameters,water,chemical,status)\n     call require(status==0,'exact authority after refused writer')\n    end if")
 anchor=" if(index(trim(mode),'reject')==1)then";source=source.replace(anchor,branch+anchor,1);f=out/'driver.f90';f.write_text(source,encoding='utf-8',newline='\n');main=out/'driver.o';run([fc,*flags,'-c',f,'-o',main])
 args=link[1:].copy()
 for old,new in ((module[-1],str(obj)),(driver[-1],str(main))):assert args.count(old)==1;args[args.index(old)]=new
 old=str(base/'publication'/(opt+'.o'));assert args.count(old)==1;i=args.index(old);args[i:i+1]=[str(real),str(shim)]
 exe=out/('writer.exe' if os.name=='nt' else 'writer');args[-1]=str(exe)
 if os.name=='nt':
  response=out/'link.args';response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n',encoding='utf-8',newline='\n');run([fc,'@'+str(response)])
 else:run([fc,*args])
 return exe

def main():
 p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert os.name=='nt';policy.guard();base=a.candidate.resolve();out=a.output.resolve();out.mkdir(parents=True);events=[];results=[]
 k=ctypes.WinDLL('kernel32',use_last_error=True);k.CreateEventA.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_char_p];k.CreateEventA.restype=ctypes.c_void_p;k.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32];k.CloseHandle.argtypes=[ctypes.c_void_p]
 for opt in ('O0','O2'):
  builddir=out/opt;builddir.mkdir();exe=build(base,opt,builddir,a.compiler.resolve());old=(base/'physical'/opt/'2/restart.bin').read_bytes();goodpath=base/'physical'/opt/'2/full.bin';good=goodpath.read_bytes()
  for kind,value in [('logical',1),('logical',2),* [('io',i)for i in (2,3,4,5,6)]]:
   case=builddir/(kind+'-'+str(value));case.mkdir();target=case/'authority';after=case/'after';target.write_bytes(old);env=dict(os.environ,OMP_NUM_THREADS='1',MTPUB_TARGET=str(target));env['MT_BAD_LOGICAL'if kind=='logical'else'MTPUB_FAIL']=str(value)
   cmd=[str(exe),'probe-writer',str(goodpath),str(target),'2','1.0',str(after)];cp=subprocess.run(cmd,cwd=case,env=env,capture_output=True,timeout=180);index=len(events)
   for stream in ('stdout','stderr'):(out/(str(index)+'.'+stream)).write_bytes(getattr(cp,stream))
   assert cp.returncode==0,(cp.stdout,cp.stderr);success=kind=='io'and value==6;assert (b'WRITE_STATUS=0'in cp.stdout)==success;assert target.read_bytes()==(good if success else old)and after.read_bytes()==good
   events.append(dict(kind=kind,value=value,optimization=opt,returncode=cp.returncode,stdout=str(index)+'.stdout',stderr=str(index)+'.stderr',published=success));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  crashes=[]
  for phase in ('before','after'):
   case=builddir/('terminate-'+phase);case.mkdir();target=case/'authority';target.write_bytes(old);nonce=uuid.uuid4().hex;ready=('Local\\mt-ready-'+nonce).encode();release=('Local\\mt-release-'+nonce).encode();h=k.CreateEventA(None,1,0,ready);g=k.CreateEventA(None,1,0,release);assert h and g
   env=dict(os.environ,OMP_NUM_THREADS='1',MTPUB_TARGET=str(target),MTPUB_ACTION=phase,MTPUB_READY=ready.decode(),MTPUB_RELEASE=release.decode());cmd=[str(exe),'probe-export',str(goodpath),str(target),'2','1.0']
   try:
    with(case/'stdout').open('wb')as so,(case/'stderr').open('wb')as se:
     child=subprocess.Popen(cmd,cwd=case,env=env,stdout=so,stderr=se);assert k.WaitForSingleObject(h,30000)==0,child.poll();child.kill();child.wait(timeout=10)
    expected=old if phase=='before'else good;assert child.returncode!=0 and target.read_bytes()==expected
    recovered=case/'recovered';cp=subprocess.run([str(exe),'probe-export',str(target),str(recovered),'2','1.0'],cwd=case,capture_output=True,env=dict(os.environ,OMP_NUM_THREADS='1'));assert cp.returncode==0 and recovered.read_bytes()==expected
    crashes.append(dict(phase=phase,termination_returncode=child.returncode,authority_sha256=sha(expected),fresh_reconstructed=True))
   finally:k.CloseHandle(h);k.CloseHandle(g)
  results.append(dict(optimization=opt,terminations=crashes))
 (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_WINDOWS_MATRIX_THERMAL_WRITER_REFUSALS_AND_TERMINATION_PASS',events=events,results=results,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_WINDOWS_MATRIX_THERMAL_WRITER_REFUSALS_AND_TERMINATION_PASS')
if __name__=='__main__':main()
