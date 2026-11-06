"""Private complete S5PT writer faults, retained pending files and actual crashes."""
import argparse
import ctypes
import hashlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import tarfile
import time
import uuid

import pond_thermal_native as native
import pond_thermal_native_layouts as layouts
import pond_thermal_native_evidence as previous

ROOT=native.ROOT


def injected_source():
    source=native.CANDIDATE.read_text()
    declaration='  integer::u,io,code,n,slash,micro_present'
    assert source.count(declaration)==1
    source=source.replace(declaration,declaration+',test_unit',1)
    anchor='\n interface\n';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'''  integer(c_int) function bad_logical()bind(C,name='matrix_bad_logical')
   import c_int
  end function
''',1)
    anchor='  if(.not.logical_value_valid(b%records(1)%time_bound))return'
    assert source.count(anchor)==1
    injection='''  code=bad_logical()
  if(code>0)then
   open(newunit=test_unit,status='scratch',access='stream',form='unformatted')
   write(test_unit)2
   select case(code)
   case(1)
    read(test_unit,pos=1)b%records(1)%time_bound
    print '(A,I0)','RAW_WORD=',transfer(b%records(1)%time_bound,0)
   case(2)
    if(.not.rutter)error stop 'wrong Rutter injection scope'
    read(test_unit,pos=1)rutter_record%parameters%bound
    print '(A,I0)','RAW_WORD=',transfer(rutter_record%parameters%bound,0)
   case(3)
    if(.not.rutter)error stop 'wrong Rutter injection scope'
    read(test_unit,pos=1)rutter_record%parameters%surface_irrigation_is_intercepted
    print '(A,I0)','RAW_WORD=',transfer(rutter_record%parameters%surface_irrigation_is_intercepted,0)
   end select
   close(test_unit)
   print '(A,I0)','RAW_SITE=',code
  end if
'''
    return source.replace(anchor,injection+anchor,1)


def probe_driver(layout):
    if layout in (1,4):
        source=subprocess.check_output(['git','show','8428323b15b126ba2a3422ef32d4d914b070db2f:tests/nut-sol/test_pond_thermal.f90'],cwd=ROOT).decode()
        anchor=" if(index(trim(mode),'reject')==1)then"
        branch=''' if(trim(mode)=='probe-writer')then
  call read_pond_thermal_restart(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   cfg%tiles(1)%parameters,p,water,chemical,status)
  call require(status==0.and.water%ready().and.chemical%ready(),'proper writer origin')
  call write_pond_thermal_restart(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,water,chemical,status)
  print '(A,I0)','WRITE_STATUS=',status
  call get_command_argument(6,arg)
  call write_pond_thermal_restart(trim(arg),column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,water,chemical,status)
  call require(status==0,'unchanged owner after writer attempt')
  stop
 end if
'''
        assert source.count(anchor)==1
        return source.replace(anchor,branch+anchor,1)
    source=layouts.driver(layout)
    source=source.replace(' logical::ok',' logical::ok,seed_old',1)
    source=source.replace(' character(512)::mode,path,target',' character(512)::mode,path,target,recovery',1)
    anchor=" if(trim(mode)=='create')then"
    assert source.count(anchor)==1
    branch=''' seed_old=trim(mode)=='create-old'
 if(seed_old)mode='create'
 if(trim(mode)=='probe-writer')then
  call read_pond_thermal_restart(trim(path),column,t,670001_int64,9001_int64,p,f,w,c,code)
  call require(code==0.and.w%ready().and.c%ready(),'proper writer origin')
  call write_pond_thermal_restart(trim(target),column,t,670001_int64,p,w,c,code)
  print '(A,I0)','WRITE_STATUS=',code
  call get_command_argument(4,recovery)
  call write_pond_thermal_restart(trim(recovery),column,t,670001_int64,p,w,c,code)
  call require(code==0,'unchanged owner after writer attempt')
  stop
 end if
'''
    source=source.replace(anchor,branch+anchor,1)
    vector='[.2d0,.3d0,.4d0,.5d0]';assert source.count(vector)==1
    return source.replace(vector,'merge([.1d0,.2d0,.3d0,.4d0],'+vector+',seed_old)',1)


def shim_source(platform=None):
    platform=platform or os.name
    name='matrix_thermal_windows_test.c' if platform=='nt' else 'matrix_thermal_posix_test.c'
    source=(ROOT/'tests/nut-sol'/name).read_text()
    if platform!='nt':
        source=source.replace('#include <stdlib.h>','#include <stdlib.h>\n#include <signal.h>',1)
        old=' return selected&&fault?swap5_restart_publish_test(pending,target,atoi(fault)):swap5_restart_publish_real(pending,target);'
        assert source.count(old)==1
        source=source.replace(old,''' const char *action=getenv("MTPUB_ACTION");
 int code;
 if(selected&&action&&!strcmp(action,"before"))raise(SIGSTOP);
 code=selected&&fault?swap5_restart_publish_test(pending,target,atoi(fault)):swap5_restart_publish_real(pending,target);
 if(selected&&!code&&action&&!strcmp(action,"after"))raise(SIGSTOP);
 return code;''',1)
    return source


def command(exe,layout,source,target,recovery):
    if layout in (1,4):return [exe,('rutter-' if layout==4 else '')+'probe-writer',source,target,2,1,recovery]
    return [exe,'probe-writer',source,target,recovery]


def execute(cmd,cwd,label,env=None):
    environment={k:v for k,v in os.environ.items() if not k.startswith('MTPUB_') and k!='MT_BAD_LOGICAL'}
    environment.update(OMP_NUM_THREADS='1',**(env or {}))
    start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,
              env=environment,timeout=180)
    for stream in ('stdout','stderr'):(cwd/(label+'.'+stream)).write_bytes(getattr(cp,stream))
    event=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start,
               stdout=label+'.stdout',stderr=label+'.stderr')
    assert cp.returncode==0,cp.stderr[-3000:]
    return event


def build(inputs,opt,out,fc):
    report=json.loads((inputs/'candidate/base/result.json').read_text())
    actual=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];assert actual==report['compiler']
    prefix=json.loads((inputs/'candidate/RESULT.json').read_text())['events'][0]['command'][2].replace('\\','/').split('/source/')[0]+'/'
    def remap(p):
        q=p.replace('\\','/');return str(inputs/'candidate'/q[len(prefix):]) if q.startswith(prefix) else p
    old_driver=next(e['command'] for e in report['events'] if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/test_pond_thermal.f90') and '-'+opt in e['command'])
    old_module=next(e['command'] for e in report['events'] if e['category']=='compile' and e['command'][-3].replace('\\','/').endswith('/'+native.SOURCE) and '-'+opt in e['command'])
    link=next(e['command'] for e in report['events'] if e['category']=='link' and '-'+opt in e['command'])
    flags=[p[:2]+remap(p[2:]) if p.startswith(('-I','-J')) else p for p in old_driver[1:old_driver.index('-c')]]
    flags=[p for p in flags if not p.startswith('-J')]+['-J'+str(out),'-I'+str(out)]
    events=[]
    def run(cmd,label):
        events.append(execute(cmd,out,label))
        (out/'BUILD.json').write_text(json.dumps(events,indent=2)+'\n')
    f=out/'writer-test.f90';f.write_text(injected_source());obj=out/'writer-test.o'
    run([fc,*flags,'-c',f,'-o',obj],'codec')
    cc=subprocess.check_output([fc,'-print-prog-name=gcc'],text=True).strip()
    c=out/'publication.c';c.write_bytes((ROOT/'app/support/restart_publish.c').read_bytes());real=out/'real.o'
    shim=out/'shim.c';shim.write_text(shim_source());shim_obj=out/'shim.o'
    run([cc,'-'+opt,'-std=c11','-DSWAP5_RESTART_TESTING','-Dswap5_restart_publish=swap5_restart_publish_real','-c',c,'-o',real],'publisher')
    run([cc,'-'+opt,'-std=c11','-c',shim,'-o',shim_obj],'shim')
    executables={}
    for layout in (1,2,3):
        driver=out/f'driver-{layout}.f90';driver.write_text(probe_driver(layout));main=out/f'driver-{layout}.o'
        run([fc,*flags,'-c',driver,'-o',main],f'driver-{layout}')
        cmd=[fc]+[remap(p) for p in link[1:]]
        for old,new in [(remap(old_module[-1]),str(obj)),(remap(old_driver[-1]),str(main))]:
            assert cmd.count(old)==1;cmd[cmd.index(old)]=new
        pub=str(inputs/'candidate/base'/opt/'restart_publish.o');assert cmd.count(pub)==1
        i=cmd.index(pub);cmd[i:i+1]=[str(real),str(shim_obj)]
        exe=out/(f'writer-{layout}'+('.exe' if os.name=='nt' else ''));cmd[-1]=str(exe)
        if os.name=='nt':
            response=out/f'link-{layout}.args';response.write_text('\n'.join('"'+p.replace('\\','/')+'"' for p in cmd[1:])+'\n');run([fc,'@'+str(response)],f'link-{layout}')
        else:run(cmd,f'link-{layout}')
        executables[layout]=exe
    executables[4]=executables[1]
    (out/'BUILD.json').write_text(json.dumps(events,indent=2)+'\n')
    return executables


def terminate(cmd,case,phase,target):
    env={k:v for k,v in os.environ.items() if not k.startswith('MTPUB_') and k!='MT_BAD_LOGICAL'}
    env.update(OMP_NUM_THREADS='1',MTPUB_TARGET=str(target),MTPUB_ACTION=phase)
    handles=[];child=None
    if os.name=='nt':
        k=ctypes.WinDLL('kernel32',use_last_error=True)
        k.CreateEventA.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_char_p];k.CreateEventA.restype=ctypes.c_void_p
        k.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32];k.CloseHandle.argtypes=[ctypes.c_void_p]
        nonce=uuid.uuid4().hex;ready='Local\\pt-ready-'+nonce;release='Local\\pt-release-'+nonce
        handles=[k.CreateEventA(None,1,0,ready.encode()),k.CreateEventA(None,1,0,release.encode())];assert all(handles)
        env.update(MTPUB_READY=ready,MTPUB_RELEASE=release)
    try:
        with (case/'crash.stdout').open('wb') as so,(case/'crash.stderr').open('wb') as se:
            child=subprocess.Popen(list(map(str,cmd)),cwd=case,env=env,stdout=so,stderr=se)
            if os.name=='nt':assert k.WaitForSingleObject(handles[0],30000)==0,child.poll()
            else:
                limit=time.monotonic()+30
                while True:
                    pid,status=os.waitpid(child.pid,os.WNOHANG|os.WUNTRACED)
                    if pid:
                        assert os.WIFSTOPPED(status),status
                        break
                    assert time.monotonic()<limit
                    time.sleep(.01)
            child.kill();child.wait(timeout=10);assert child.returncode!=0
        return dict(command=list(map(str,cmd)),phase=phase,termination_returncode=child.returncode,
                    actual_process_terminated=True,stop_observed='Windows named event' if os.name=='nt' else 'SIGSTOP',
                    termination_method='TerminateProcess' if os.name=='nt' else 'SIGKILL')
    finally:
        if child is not None and child.poll() is None:child.kill();child.wait(timeout=10)
        if os.name=='nt':
            for h in handles:k.CloseHandle(h)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reuse-prepared',type=Path);a=p.parse_args()
    native.guard();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    if a.reuse_prepared:
        inputs=a.reuse_prepared.resolve();stem='POND_THERMAL_NATIVE_'+('WINDOWS' if os.name=='nt' else 'POSIX')+'_20261106'
        manifest=json.loads((previous.STORE/(stem+'.json')).read_text())
        def prepared_guard():
            seen=set()
            for path in inputs.rglob('*'):
                if path.is_file():
                    key=path.relative_to(inputs).as_posix();seen.add(key)
                    assert key in manifest['members'] and native.sha(path)==manifest['members'][key],key
            required={key for key in manifest['members'] if len(Path(key).parts)>1 and Path(key).parts[0] in ('baseline','candidate') and Path(key).parts[1] in ('source','base','RESULT.json')}
            assert required<=seen
        for part in manifest['parts']:
            assert native.sha(previous.STORE/part['path'])==part['sha256']
        prepared_guard()
    else:inputs,stem=layouts.unpack(out)
    manifest=json.loads((previous.STORE/(stem+'.json')).read_text());raw=b''.join((previous.STORE/x['path']).read_bytes() for x in manifest['parts'])
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as tar:
        for member in tar.getmembers():
            if member.name.startswith('candidate/rutter/') and member.name.endswith(('/2/full.bin','/2/restart.bin')):
                blob=tar.extractfile(member).read();assert hashlib.sha256(blob).hexdigest()==manifest['members'][member.name]
                dest=inputs/member.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(blob)
    result=dict(status='RUNNING',platform=os.name,provider_capsule=stem,events=[],crashes=[],production_admission=False,whole_scientific_admission=False)
    for opt in ('O0','O2'):
        builddir=out/opt;builddir.mkdir();exes=build(inputs,opt,builddir,os.environ.get('FC','gfortran'))
        for layout in (1,2,3,4):
            directory=builddir/str(layout);directory.mkdir();exe=exes[layout]
            if layout in (1,4):
                original=inputs/'candidate'/('rutter' if layout==4 else 'base')/opt/'2'
                old=(original/'restart.bin').read_bytes();goodpath=original/'full.bin'
            else:
                goodpath=directory/'good.bin';oldpath=directory/'old.bin'
                execute([exe,'create',goodpath,goodpath],directory,'create-good')
                execute([exe,'create-old',oldpath,oldpath],directory,'create-old');old=oldpath.read_bytes()
            good=goodpath.read_bytes();assert old!=good
            (directory/'expected-old.bin').write_bytes(old);(directory/'expected-good.bin').write_bytes(good)
            cases=[('normal',0),('logical',1),*([('logical',2),('logical',3)] if layout==4 else []),*[('io',i) for i in (2,3,4,5,6)]]
            for kind,value in cases:
                case=directory/(kind+'-'+str(value));case.mkdir();target=case/'authority';target.write_bytes(old);recovery=case/'recovered'
                env={'MTPUB_TARGET':str(target)}
                if kind!='normal':env['MT_BAD_LOGICAL' if kind=='logical' else 'MTPUB_FAIL']=str(value)
                event=execute(command(exe,layout,goodpath,target,recovery),case,'writer',env)
                success=kind=='normal' or (kind=='io' and value==6 and os.name=='nt')
                published=kind=='normal' or (kind=='io' and value==6)
                stdout=(case/event['stdout']).read_bytes()
                assert (b'WRITE_STATUS=0' in stdout)==success and (b'WRITE_STATUS=1' in stdout)==(not success)
                if kind=='logical':assert b'RAW_WORD=2' in stdout and ('RAW_SITE='+str(value)).encode() in stdout
                assert target.read_bytes()==(good if published else old) and recovery.read_bytes()==good
                pending=Path(str(target)+'.pending')
                retained=kind=='io' and value in (2,3,4,5)
                assert pending.exists()==retained
                if retained:
                    assert pending.read_bytes()==good
                    retry=execute(command(exe,layout,goodpath,target,case/'retry-recovered'),case,'retry')
                    assert b'WRITE_STATUS=1' in (case/retry['stdout']).read_bytes()
                    assert target.read_bytes()==old and pending.read_bytes()==good and (case/'retry-recovered').read_bytes()==good
                    event['retained_pending_retry']=retry
                result['events'].append(dict(optimization=opt,layout=layout,kind=kind,value=value,published=published,retained_pending=retained,event=event))
            for phase in ('before','after'):
                case=directory/('terminate-'+phase);case.mkdir();target=case/'authority';target.write_bytes(old)
                event=terminate(command(exe,layout,goodpath,target,case/'never'),case,phase,target)
                expected=old if phase=='before' else good;assert target.read_bytes()==expected
                recovery=execute(command(exe,layout,target,case/'fresh',case/'fresh-again'),case,'fresh')
                assert (case/'fresh').read_bytes()==(case/'fresh-again').read_bytes()==expected
                pending=Path(str(target)+'.pending');assert pending.exists()==(phase=='before')
                if pending.exists():assert pending.read_bytes()==good
                crash=dict(optimization=opt,layout=layout,phase=phase,event=event,fresh=recovery)
                if phase=='before':
                    retry=execute(command(exe,layout,goodpath,target,case/'pending-retry-recovered'),case,'pending-retry')
                    assert b'WRITE_STATUS=1' in (case/retry['stdout']).read_bytes()
                    assert target.read_bytes()==old and pending.read_bytes()==good and (case/'pending-retry-recovered').read_bytes()==good
                    crash['pending_retry']=retry
                result['crashes'].append(crash)
            (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(opt,'S5PT000'+str(layout),'writer/refusal/pending/crash PASS',flush=True)
    assert len(result['events'])==60 and len(result['crashes'])==16
    result['status']='PRIVATE_COMPLETE_S5PT_WRITER_FAULTS_AND_ACTUAL_CRASHES_PASS'
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');native.guard()
    if a.reuse_prepared:prepared_guard()


if __name__=='__main__':main()
