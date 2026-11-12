from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parent
OBSERVER=r'''
subroutine audit_accept()
 use iso_c_binding, only: c_int
 use MOD_macropore, only: FlEndSrpEvt, NumDm, WaUnMpDmCp, FrMpWalWet, TimAbsCumDmCp
 integer, save :: samples=0
 integer :: status,u
 real(8) :: oldf(macp),oldq(macp),firstf(macp),firstq(macp),oldh(macp),oldtheta(macp),oldgrad(macp+1)
 real(8) :: oldwall(size(FrMpWalWet,1),size(FrMpWalWet,2)),oldstore(size(WaUnMpDmCp,1),size(WaUnMpDmCp,2))
 logical :: oldevent(size(FlEndSrpEvt,1),size(FlEndSrpEvt,2))
 interface
  integer(c_int) function fork_begin() bind(C,name='audit_fork_begin')
   import c_int
  end function
  subroutine fork_end() bind(C,name='audit_fork_end')
  end subroutine
 end interface
 if(swmacro/=1.or..not.flunsatok(3).or.samples>=20) return
 samples=samples+1
 status=fork_begin()
 if(status/=0) then
  if(status<0) error stop 'audit child failed'
  return
 end if
 oldf=F;oldq=QExcMpMtx;oldh=h;oldtheta=theta;oldgrad=hgrad
 oldevent=FlEndSrpEvt;oldwall=FrMpWalWet;oldstore=WaUnMpDmCp
 open(newunit=u,file='audit_samples.txt',position='append',status='unknown')
 write(u,*) 'META',samples,t1900,dt,numbit,NN,IDecMpRat,CritDevBalCp,CritDevBalTot
 call vector_F(1,hgrad)
 firstf=F;firstq=QExcMpMtx
 write(u,*) 'RESIDUAL',maxval(abs(oldf(1:NN))),sum(oldf(1:NN)),maxval(abs(F(1:NN))),sum(F(1:NN))
 write(u,*) 'EXCHANGE',maxval(abs(QExcMpMtx(1:NN)-oldq(1:NN))), &
 maxval(abs(F(1:NN)-oldf(1:NN)+QExcMpMtx(1:NN)-oldq(1:NN)))
 write(u,*) 'REFRESH_STATE',count(oldevent.neqv.FlEndSrpEvt),maxval(abs(oldwall-FrMpWalWet)),maxval(abs(oldstore-WaUnMpDmCp))
 write(u,*) 'OLD_F',oldf(1:NN)
 write(u,*) 'NEW_F',F(1:NN)
 write(u,*) 'OLD_Q',oldq(1:NN)
 write(u,*) 'NEW_Q',QExcMpMtx(1:NN)
 call vector_F(1,hgrad)
 write(u,*) 'REPEAT',maxval(abs(F(1:NN)-firstf(1:NN))),maxval(abs(QExcMpMtx(1:NN)-firstq(1:NN)))
 ! A saturation excursion in a child, then restore the identical hydraulic input.
 h(81)=-oldh(81)
 if(abs(h(81))<1d-4) h(81)=1d-4
 theta(81)=watcon(81,h(81))
 hgrad(81)=(h(80)-h(81))/disnod(81)+1d0
 hgrad(82)=(h(81)-h(82))/disnod(82)+1d0
 call vector_F(1,hgrad)
 h=oldh;theta=oldtheta;hgrad=oldgrad
 call vector_F(1,hgrad)
 write(u,*) 'ROUNDTRIP',maxval(abs(F(1:NN)-firstf(1:NN))),maxval(abs(QExcMpMtx(1:NN)-firstq(1:NN))), &
 count(oldevent.neqv.FlEndSrpEvt),maxval(abs(oldwall-FrMpWalWet)),maxval(abs(oldstore-WaUnMpDmCp))
 close(u)
 call fork_end()
end subroutine audit_accept
'''
C=r'''
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
int audit_fork_begin(void){pid_t p=fork();int s=0;if(p==0){alarm(3);return 0;}if(p<0)return -1;while(waitpid(p,&s,0)<0){if(errno!=EINTR)return -2;}return WIFEXITED(s)&&WEXITSTATUS(s)==0?1:-3;}
void audit_fork_end(void){_exit(0);}
'''
s=(ROOT/'build/swap-selected/headcalc.f90').read_text(encoding='cp1252')
assert s.count('!        special case for macropores')==1
s=s.replace('!        special case for macropores','         call audit_accept()\n!        special case for macropores')
assert s.count('\ncontains\n')==1
s=s.replace('\ncontains\n','\ncontains\n'+OBSERVER)
p=ROOT/'observer';p.mkdir(exist_ok=True)
(p/'headcalc.f90').write_text(s,encoding='cp1252');(p/'fork.c').write_text(C)
prereg={
 'work_unit':'SWAP431-MACRO-AUDIT01','baseline':'f2377211d2be58d03d96e50fb0a6bc35ced3c90f',
 'source_archive_sha256':'1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151',
 'H1':'First 20 frozen-flux converged B0 steps: fresh coupled residual may fail unchanged original local/total criteria.',
 'H2':'Repeated evaluation and node81 saturation roundtrip may alter same-input residual/history.',
 'selection':'First two original Andelst days from cold initialization; only TEND changed from 1999-04-26 to 1998-01-02. No imported hybrid state.',
 'cap_seconds_each':20,'max_observed_accepts':20,'child_cap_seconds':3,
 'acceptance':'Uninstrumented and instrumented complete physical output files must match bytes, ignoring timestamp headers; record exact exclusions. No new physics/tolerance.',
 'qualification':'Observation only. No B1 correction, no general rejected-step rollback claim, no whole trajectory accuracy claim.'}
(ROOT/'PREREGISTRATION.json').write_text(json.dumps(prereg,indent=2)+'\n')
