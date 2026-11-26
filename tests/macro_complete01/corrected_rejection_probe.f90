subroutine macro_replay_dump(tag,flux)
use MOD_macropore,only:NumDm,ICpBtDm,VlMpDmCp,WaUnMpDmCp,FlEndSrpEvt,ThtSrpRefDmCp,SorpDmCp,TimAbsCumDmCp, &
 VlMpDyCp,SubsidCp,FrMpWalWet,ICpBtDmPot,ICpTpWaSrDm,ZWaLevDm,ZBtDm,VlMpDm,VlMp,ArMpTp,ArMpTpDm, &
 ArMpSs,KsMpSs,FrArMtrx,WaSrMp,WaSrMpDm,WaUnMpDm,WaUnsat,QOutMtxSatDmCp,QOutMtxUnsDmCp, &
 QInMtxSatDmCp,QInIntSatDmCp,QInTopLatDm,QInTopVrtDm,QExcMpMtx
use MOD_grid,only:numnod
use variables,only:h,theta,gwl,pond,qrot,volact
implicit none
character(*),intent(in)::tag
logical,intent(in)::flux
integer::u
open(newunit=u,file='replay_'//tag//'_physical.bin',access='stream',form='unformatted',status='replace')
write(u)numnod,NumDm
@PHYSICAL_WRITES@
close(u)
open(newunit=u,file='replay_'//tag//'_matrix.bin',access='stream',form='unformatted',status='replace')
write(u)h(1:numnod),theta(1:numnod),gwl,pond
close(u)
if(flux)then
 open(newunit=u,file='replay_'//tag//'_flux.bin',access='stream',form='unformatted',status='replace')
 write(u)QOutMtxSatDmCp(1:NumDm,1:numnod),QOutMtxUnsDmCp(1:NumDm,1:numnod), &
 QInMtxSatDmCp(1:NumDm,1:numnod),QInIntSatDmCp(1:NumDm,1:numnod),QInTopLatDm(1:NumDm),QInTopVrtDm(1:NumDm), &
 QExcMpMtx(1:numnod),qrot(1:numnod),volact
 close(u)
end if
end subroutine

subroutine macro_replay_event(stage)
use variables,only:t1900,dt,fldecdt,numbit
use MOD_swap_mp,only:FlDecMpRat,IDecMpRat
use MOD_macropore,only:FrReduQ
implicit none
integer,intent(in)::stage
logical,save::ready=.false.,direct=.false.
character(20)::mode
integer,save::u=0
if(abs(t1900-35797.82600000001d0)>1d-10)return
if(stage==0)then
 if(ready.or.dt/=2d-3)return
 ready=.true.;call get_environment_variable('MACRO_REPLAY_MODE',mode)
 direct=trim(mode)=='DIRECT'
 open(newunit=u,file='replay_events.txt',status='replace')
 call macro_replay_dump('begin',.false.)
 write(u,*)stage,t1900,dt,numbit,fldecdt,FlDecMpRat,FrReduQ,IDecMpRat,direct
 if(direct)then
  fldecdt=.true.;call TimeControl(5)
  call macro_replay_dump('restored',.false.)
 end if
 return
end if
if(.not.ready)return
write(u,*)stage,t1900,dt,numbit,fldecdt,FlDecMpRat,FrReduQ,IDecMpRat,direct
if(stage==1.and.dt<2d-3)call macro_replay_dump('small_begin',.false.)
if(stage==2)then
 if(dt==2d-3)then
  call macro_replay_dump('rejected',.true.)
 else
  call macro_replay_dump('small_return',.true.)
 end if
end if
if(stage==3)call macro_replay_dump('restored',.false.)
if(stage==4)call macro_replay_dump('committed',.true.)
end subroutine
