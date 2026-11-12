"""Read-only fork observers for the two already registered numerical variants."""
from pathlib import Path
import argparse,json,subprocess,os,time,shutil,hashlib
P=argparse.ArgumentParser();P.add_argument('action',choices=['prepare','run']);P.add_argument('--optimization',choices=['O0','O2'],default='O2')
A=P.parse_args();ROOT=Path(__file__).resolve().parent;R=ROOT/'b1-accept01';OLD=Path('/workspace/scratch/847fc052fa43')

FRESH=r'''
subroutine audit_fresh()
 use iso_c_binding, only:c_int
 integer :: status,u,jj,sgn,scale,node
 integer,save :: early=0,late=0
 integer,parameter :: nodes(4)=[1,34,56,81]
 real(8) :: oldf(macp),oldq(macp),oldh(macp),oldtheta(macp),oldgrad(macp+1),baseq(macp),analytic(macp),eps,qp,qm
 logical :: selected,derivative
 interface
  integer(c_int) function begin_fork() bind(C,name='audit_fork_begin')
   import c_int
  end function
  subroutine end_fork() bind(C,name='audit_fork_end')
  end subroutine
 end interface
 selected=.false.;derivative=.false.
 if(t1900<35796.9d0.and.early<20) then
  early=early+1;selected=.true.
 end if
 if(t1900>=35796.919999d0.and.late<20) then
  late=late+1;selected=.true.;derivative=(late==1)
 end if
 if(t1900+dt>=35797d0-1d-10) selected=.true.
 if(.not.selected) return
 status=begin_fork()
 if(status/=0) then
  if(status<0) error stop 'fresh child failure'
  return
 end if
 oldf=F;oldq=QExcMpMtx
 call vector_F(1,hgrad)
 open(newunit=u,file='fresh.txt',status='unknown',position='append')
 write(u,*) t1900,dt,numbit,IDecMpRat,maxval(abs(oldf(1:NN))),sum(oldf(1:NN)), &
  maxval(abs(F(1:NN))),sum(F(1:NN)),CritDevBalCp,CritDevBalTot, &
  maxval(abs(F(1:NN)-oldf(1:NN)+QExcMpMtx(1:NN)-oldq(1:NN)))
 close(u)
 if(derivative) then
  oldh=h;oldtheta=theta;oldgrad=hgrad;baseq=QExcMpMtx
  call jacobian_F()
  analytic=dFdhMp
  open(newunit=u,file='derivative.txt',status='replace')
  write(u,*) 'TASKS',maxval(abs(baseq(1:NN)-QExcMpMtx(1:NN)))
  do scale=1,2
   eps=1d-4/dble(scale)
   do jj=1,4
    node=nodes(jj)
    do sgn=-1,1,2
     h=oldh;theta=oldtheta;hgrad=oldgrad
     h(node)=oldh(node)+dble(sgn)*eps
     theta(node)=watcon(node,h(node))
     if(node>1) hgrad(node)=(h(node-1)-h(node))/disnod(node)+1d0
     if(node<NN) hgrad(node+1)=(h(node)-h(node+1))/disnod(node+1)+1d0
     call vector_F(1,hgrad)
     if(sgn==-1) qm=QExcMpMtx(node)
     if(sgn==1) qp=QExcMpMtx(node)
    end do
    write(u,*) 'COLUMN',node,eps,(qp-qm)/(2d0*eps),analytic(node),abs((qp-qm)/(2d0*eps)-analytic(node))
   end do
  end do
  h=oldh;theta=oldtheta;hgrad=oldgrad
  call vector_F(1,hgrad)
  write(u,*) 'RETURN',maxval(abs(QExcMpMtx(1:NN)-baseq(1:NN)))
  close(u)
 end if
 call end_fork()
end subroutine audit_fresh
'''

RETRY=r'''
subroutine audit_retry()
 use iso_c_binding, only:c_int
 use MOD_grid, only:numnod
 use MOD_swap_base, only:swdra,swfrost
 use MOD_drain, only:drain
 use MOD_macropore, only:macrostatevar,NumDm,WaUnMpDmCp,WaSrMpDm,WaUnMpDm,WaSrMp, &
  VlMpDmCp,ICpBtDm,FlEndSrpEvt,TimAbsCumDmCp,ThtSrpRefDmCp,SorpDmCp,FrMpWalWet,FrMpWalWetOld
 use MOD_swap_mp, only:QExcMpMtx,IDecMpRat,FlDecMpRat
 use variables, only:t1900,dt,h,theta,pond,gwl,k,kmean,fldecdt,fldtmin
 implicit none
 logical,save :: done=.false.
 integer :: kind,status
 interface
  integer(c_int) function retry_fork(knd) bind(C,name='audit_retry_fork')
   import c_int
   integer(c_int),value :: knd
  end function
  subroutine end_fork() bind(C,name='audit_fork_end')
  end subroutine
 end interface
 if(done.or.abs(t1900-35796.92d0)>1d-8.or.abs(dt-0.002d0)>1d-12) return
 done=.true.
 if(swdra/=1.or.swfrost/=0) error stop 'retry scope mismatch'
 do kind=1,2
  status=retry_fork(kind)
  if(status<0) error stop 'retry child failure'
  if(status/=0) cycle
  call dump('origin')
  if(kind==1) then
   call headcalc
   call dump('rejected')
   if(.not.fldecdt.or.FlDecMpRat) error stop 'expected ordinary actual rejection'
   call SoilWaterStateVar(2)
   call MacroStateVar(2)
  else
   ! Bypass the failed large trial from the identical live origin.
   fldecdt=.true.
  end if
  call TimeControl(5)
  call dump('rollback')
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
  call headcalc
  call dump('retry')
  call end_fork()
 end do
contains
 subroutine dump(label)
  character(*),intent(in)::label
  integer :: u
  open(newunit=u,file=label//'.txt',status='replace')
  write(u,*) 'controls',t1900,dt,IDecMpRat,merge(1,0,fldecdt),merge(1,0,fldtmin),merge(1,0,FlDecMpRat)
  write(u,*) 'h',h(1:numnod)
  write(u,*) 'theta',theta(1:numnod)
  write(u,*) 'surface_gwl',pond,gwl
  write(u,*) 'k',k(1:numnod)
  write(u,*) 'kmean',kmean(1:numnod+1)
  write(u,*) 'macro_total',WaSrMp
  write(u,*) 'sat_store',WaSrMpDm(1:NumDm)
  write(u,*) 'unsat_store',WaUnMpDm(1:NumDm)
  write(u,*) 'comp_store',WaUnMpDmCp(1:NumDm,1:numnod)
  write(u,*) 'volumes',VlMpDmCp(1:NumDm,1:numnod)
  write(u,*) 'bottom',ICpBtDm(1:NumDm)
  write(u,*) 'clock',TimAbsCumDmCp(1:NumDm,1:numnod)
  write(u,*) 'reference_theta',ThtSrpRefDmCp(1:NumDm,1:numnod)
  write(u,*) 'sorptivity',SorpDmCp(1:NumDm,1:numnod)
  write(u,*) 'event',merge(1,0,FlEndSrpEvt(1:NumDm,1:numnod))
  write(u,*) 'wet_wall',FrMpWalWet(1:NumDm,1:numnod)
  write(u,*) 'wet_wall_old',FrMpWalWetOld(1:NumDm,1:numnod)
  write(u,*) 'exchange',QExcMpMtx(1:numnod)
  close(u)
 end subroutine dump
end subroutine audit_retry
'''

C=r'''
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
static int launch(int kind){pid_t p=fork();int s=0;if(p==0){alarm(3);if(kind){char path[64];snprintf(path,sizeof(path),"retry-shadow-%d",kind);if(mkdir(path,0700)&&errno!=EEXIST)_exit(81);if(chdir(path))_exit(82);}return 0;}if(p<0)return -1;while(waitpid(p,&s,0)<0){if(errno!=EINTR)return -2;}return WIFEXITED(s)&&WEXITSTATUS(s)==0?1:-3;}
int audit_fork_begin(void){return launch(0);}
int audit_retry_fork(int kind){return launch(kind);}
void audit_fork_end(void){_exit(0);}
'''
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if A.action=='prepare':
    for name in ['V1','V2']:
        d=R/name
        s=(d/'headcalc_metrics.f90').read_text(encoding='cp1252')
        s=s.replace('         call audit_attempt(0)','         call audit_fresh()\n         call audit_attempt(0)',1)
        s=s.replace('\ncontains\n','\ncontains\n'+FRESH,1)
        (d/'headcalc_observer.f90').write_text(s,encoding='cp1252')
    s=(OLD/'build/swap-selected/soilwater.f90').read_text(encoding='cp1252')
    s=s.replace('            call headcalc','            call audit_retry()\n            call headcalc',1)
    s=s.replace('end module MOD_SoilWater',RETRY+'\nend module MOD_SoilWater')
    (R/'soilwater_observer.f90').write_text(s,encoding='cp1252');(R/'fork_observer.c').write_text(C)
    q={'selection':'First20 accepted early steps, first20 accepted steps at/after actual rejection time35796.92, and final accepted step: fresh coupled residual in fork. At first actual V1/V2 rejection t1900=35796.92,dt=.002: compare real failed trial+original rollback+smaller solve against same-origin direct smaller solve. At first late selected step compare macro derivatives at1/34/56/81 with original analytic diagonal at perturbations1e-4/5e-5cm.',
       'cost_revision':'All-step fork observation exceeded20s after756/886 passing fresh checks. Preserve both censored profiles; only observational selection changes, no third physical variant or time-cap increase.',
       'origin':'Identical live process forks before original headcalc, immediately after original state save; no reconstructed checkpoint.',
       'scope':'No physical/criteria changes; child-only probes. Same two physical candidates; not a third repair. Three-second child alarm and20s per full route.',
       'rollback':'Record stocks, volumes, event flags, sorptivity refs/clocks, wall history, hydraulic fields and exchange before/after actual reject/restore/retry. Separate retry policy flags from physical state.',
       'sources':{str(p.relative_to(R)):sha(p) for p in [R/'soilwater_observer.f90',R/'fork_observer.c',R/'V1/headcalc_observer.f90',R/'V2/headcalc_observer.f90']}}
    (R/'OBSERVATION_SELECTION.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q,indent=2));raise SystemExit()

opt=A.optimization;provider=OLD/'build' if opt=='O2' else R/'O0-closure';obj=provider/'swap-obj';tt=provider/'ttutil-obj'
env=os.environ.copy();comp=OLD/'compiler'
env['PATH']=str(comp/'bin')+':'+env['PATH'];env['GCC_EXEC_PREFIX']=str(comp/'root/usr/lib/gcc/')
env['COMPILER_PATH']=str(comp/'root/usr/libexec/gcc/x86_64-linux-gnu/14')
env['LIBRARY_PATH']=str(comp/'root/usr/lib/gcc/x86_64-linux-gnu/14')+':/usr/lib/gcc/x86_64-linux-gnu/14'
baseflags=['gfortran','-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-I',str(obj),'-I',str(tt)]
build=R/opt;build.mkdir(exist_ok=True);logs=[];runs=[]
def execute(cmd,cwd,limit=40):
    start=time.monotonic()
    try:
        q=subprocess.run(list(map(str,cmd)),cwd=cwd,env=os.environ.copy() if cmd[0]=='gcc' else env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=limit)
        return dict(command=list(map(str,cmd)),returncode=q.returncode,seconds=time.monotonic()-start,stdout=q.stdout,censored=False)
    except subprocess.TimeoutExpired as e:
        return dict(command=list(map(str,cmd)),returncode=None,seconds=time.monotonic()-start,stdout=(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else e.stdout,censored=True)
def compile(cmd,cwd):
    q=execute(cmd,cwd);logs.append(q)
    (build/'OBS_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
    assert q['returncode']==0,q['stdout']
for name in ['B0','V1','V2']:
    # O2 metrics controls already exist. O0 builds have their own full closure.
    profiles=['metrics'] if name=='B0' else ['metrics','observer']
    for profile in profiles:
        if opt=='O2' and profile=='metrics':continue
        d=build/(name+'-'+profile);d.mkdir(exist_ok=True)
        f=R/name/('headcalc_'+profile+'.f90')
        compile(baseflags+['-c',str(f),'-o',str(d/'headcalc.o')],d)
        extras=[];exclude={'headcalc.o'}
        if profile=='observer':
            compile(baseflags+['-c',str(R/'soilwater_observer.f90'),'-o',str(d/'soilwater.o')],d)
            compile(['gcc','-'+opt,'-c',str(R/'fork_observer.c'),'-o',str(d/'fork.o')],d)
            extras=[d/'soilwater.o',d/'fork.o'];exclude.add('soilwater.o')
        objects=[p for p in sorted(obj.glob('*.o')) if p.name not in exclude]+[d/'headcalc.o']+extras
        compile(['gfortran','-B/usr/lib/gcc/x86_64-linux-gnu/14/','-o',d/'swap',*objects,tt/'libttutil.a'],d)
        case=d/'case';case.mkdir(exist_ok=True)
        for item in json.loads((OLD/'CASE_IDENTITY.json').read_text()):
            p=Path(item['path']);(case/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OLD/'run-control'/p,case/p)
        shutil.copy2(OLD/'run-control-output/swap.swp',case/'swap.swp')
        q=execute([d/'swap','./swap.swp'],case,20);(case/'stdout.txt').write_text(q.pop('stdout') or '')
        q.update(name=name,profile=profile,optimization=opt,exe_sha256=sha(d/'swap'),swap_ok=(case/'swap.ok').exists())
        runs.append(q);(build/'OBS_RUNS.json').write_text(json.dumps(runs,indent=2)+'\n');print(json.dumps(q),flush=True)
