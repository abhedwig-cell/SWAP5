! Nine restored, real-provider evaluations at live attempt357 iteration10.
subroutine contract43_probe()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status,ieee_all,ieee_get_flag
use SENSE23_TRANSACTION,only:snapshot
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz,layer
use MOD_MvG,only:watcon,hconduc
use MOD_frost,only:rfcp
use MOD_macropore,only:NumDm,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,QExcMtxDmCp,QOutMtxUnsDmCp,QOutMtxSatDmCp, &
 QInMtxSatDmCp,QInIntSatDmCp,ZWaLevDm,ICpTpWaSrDm,PpDmCp,ShapeFacMp,SorpFacParl,SorpAlfa,FrMpWalWet,FrReduQ,SwDarcy
use MOD_swap_mp,only:FrArMtrx,DiPoCp,GwlFlCpZo
use variables,only:h,theta,k,thetas,thetar,swkimpl,pegwl,dt
use DIAG19,only:probe_busy,probe_u,point_id,point_node,point_delta,attempts,iter_index
implicit none
integer::u,pu,ru,du,cu,nbytes,ncache,lev,sgn,d,pid,old_unit,old_id,old_node,ic,lay
real(8)::targetg,eps,old_delta,cm(24,madm),ins(macp,madm),outs(macp,madm),uns(macp,madm),rapid(macp,madm)
real(8)::hm,del,rec,sf,qd,unsatfr,base_h47
logical::old_busy,flags_before(size(ieee_all)),flags_after(size(ieee_all)),same,csame
type(ieee_status_type)::fp
integer(1),allocatable::original(:),restored(:),cache_original(:),cache_restored(:)
if(attempts/=357.or.iter_index/=10) error stop 'CONTRACT42 outside preregistered point'
old_busy=probe_busy;old_unit=probe_u;old_id=point_id;old_node=point_node;old_delta=point_delta
call ieee_get_status(fp);call ieee_get_flag(ieee_all,flags_before)
call snapshot('probe42_base.bin',1)
open(newunit=u,file='probe42_cache_base.bin',status='replace',access='stream',form='unformatted')
call contract42_cache_io(u,1);close(u)
inquire(file='probe42_base.bin',size=nbytes);inquire(file='probe42_cache_base.bin',size=ncache)
allocate(original(nbytes),restored(nbytes),cache_original(ncache),cache_restored(ncache))
open(newunit=u,file='probe42_base.bin',status='old',access='stream',form='unformatted');read(u) original;close(u)
open(newunit=u,file='probe42_cache_base.bin',status='old',access='stream',form='unformatted');read(u) cache_original;close(u)
open(newunit=pu,file='probe42_points.txt',status='replace')
open(newunit=du,file='probe42_domains.txt',status='replace')
open(newunit=ru,file='probe42_restore.txt',status='replace')
open(newunit=probe_u,file='probe42_limit.txt',status='replace')
pid=0;base_h47=h(47);probe_busy=.true.
call evaluate(0d0,.false.)
do lev=1,3
 eps=10d0**(-2*lev-2)
 do sgn=-1,1,2
  targetg=-60d0+dble(sgn)*eps
  call evaluate(targetg,.true.)
 end do
end do
call evaluate(-60d0,.true.)
call evaluate(0d0,.false.)
call restore()
close(pu);close(du);close(ru);close(probe_u)
probe_busy=old_busy;probe_u=old_unit;point_id=old_id;point_node=old_node;point_delta=old_delta
call ieee_set_status(fp)
deallocate(original,restored,cache_original,cache_restored)
contains
subroutine restore()
call snapshot('probe42_base.bin',2)
open(newunit=u,file='probe42_cache_base.bin',status='old',access='stream',form='unformatted')
call contract42_cache_io(u,2);close(u)
call snapshot('probe42_restored.bin',1)
open(newunit=u,file='probe42_cache_restored.bin',status='replace',access='stream',form='unformatted')
call contract42_cache_io(u,1);close(u)
open(newunit=u,file='probe42_restored.bin',status='old',access='stream',form='unformatted');read(u) restored;close(u)
open(newunit=u,file='probe42_cache_restored.bin',status='old',access='stream',form='unformatted');read(u) cache_restored;close(u)
same=all(original==restored);csame=all(cache_original==cache_restored)
call ieee_set_status(fp);call ieee_get_flag(ieee_all,flags_after)
write(ru,*) pid,nbytes,ncache,merge(1,0,same),merge(1,0,csame),merge(1,0,all(flags_before.eqv.flags_after))
if(.not.same.or..not.csame.or..not.all(flags_before.eqv.flags_after)) error stop 'CONTRACT42 selected transaction restore failed'
end subroutine
subroutine evaluate(g,perturb)
real(8),intent(in)::g
logical,intent(in)::perturb
call restore()
pid=pid+1;point_id=pid;point_node=47;point_delta=0d0
if(perturb) then
 ! Invert the ORIGINAL zero-head interpolation while holding h48 and all other heads.
 h(47)=h(48)*(1d0-(z(47)-z(48))/(g-z(48)))
 point_delta=h(47)-base_h47
 theta(47)=watcon(47,h(47))
 if(swkimpl==1) k(47)=FrArMtrx(47)*hconduc(47,h(47),theta(47),rfcp(47))
end if
call MACRORATE(1)
call diagnose36_get(cm,ins,outs,uns,rapid)
write(pu,*) pid,merge(1,0,perturb),g,h(47),h(48),GwlFlCpZo,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon,pegwl, &
 theta(47),thetas(47),k(47),z(47),dz(47),FrReduQ,dt, &
 QExcMtxDmCp(1:NumDm,47),QOutMtxUnsDmCp(1:NumDm,47),QOutMtxSatDmCp(1:NumDm,47),QInMtxSatDmCp(1:NumDm,47),QInIntSatDmCp(1:NumDm,47)
ic=47;lay=layer(ic)
unsatfr=1d0-min(1d0,max(0d0,(GwlFlCpZo-(z(ic)-.5d0*dz(ic)))/dz(ic)))
do d=1,NumDm
 hm=max(0d0,ZWaLevDm(d)-z(ic));del=max(0d0,hm-h(ic));rec=0d0;sf=0d0;qd=0d0
 if(SwDarcy>0.and.ic>ICpTpWaSrDm(d).and.hm>1d-8) then
  rec=ShapeFacMp*8d0*PpDmCp(d,ic)*dz(ic)*k(ic)/DiPoCp(ic)**2
  sf=SorpFacParl(lay)+(1d0-SorpFacParl(lay))*(1d0-(max(0d0,thetas(ic)-theta(ic))/(thetas(ic)-thetar(ic)))**SorpAlfa(lay))
  qd=FrReduQ*rec*del*sf
 end if
 write(du,*) pid,d,cm(:,d),ICpTpWaSrDm(d),hm,del,rec,sf,qd,unsatfr,PpDmCp(d,ic),DiPoCp(ic), &
 ShapeFacMp,SorpFacParl(lay),SorpAlfa(lay),thetar(ic),FrMpWalWet(d,ic),ins(ic,d),outs(ic,d),uns(ic,d),rapid(ic,d)
end do
end subroutine
end subroutine

subroutine contract43_calibrate()
use SENSE23_TRANSACTION,only:snapshot
use DIAG19,only:attempts,iter_index,nvec
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status
implicit none
integer::u,old_attempt,old_iter,old_vec
type(ieee_status_type)::fp
old_attempt=attempts;old_iter=iter_index;old_vec=nvec
call ieee_get_status(fp)
call snapshot('host43_before.bin',1)
open(newunit=u,file='host43_cache_before.bin',status='replace',access='stream',form='unformatted')
call contract42_cache_io(u,1);close(u)
call snapshot('frozen42_base.bin',2)
open(newunit=u,file='frozen42_cache.bin',status='old',access='stream',form='unformatted')
call contract42_cache_io(u,2);close(u)
attempts=357;iter_index=10;nvec=0
call contract43_probe()
call snapshot('host43_before.bin',2)
open(newunit=u,file='host43_cache_before.bin',status='old',access='stream',form='unformatted')
call contract42_cache_io(u,2);close(u)
attempts=old_attempt;iter_index=old_iter;nvec=old_vec
call snapshot('host43_after.bin',1)
open(newunit=u,file='host43_cache_after.bin',status='replace',access='stream',form='unformatted')
call contract42_cache_io(u,1);close(u)
call ieee_set_status(fp)
end subroutine
