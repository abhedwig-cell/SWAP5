! Bounded real-provider derivative qualification; never used by the linear solve.
subroutine factor60_probe()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status,ieee_all,ieee_get_flag
use SENSE23_TRANSACTION,only:snapshot
use MOD_arrays,only:macp,madm
use MOD_grid,only:numnod,z,dz
use MOD_MvG,only:watcon,hconduc
use MOD_frost,only:rfcp
use MOD_macropore,only:VlMpDmCp,ZBtDm,ICpBtDm,QExcMtxDmCp
use MOD_swap_mp,only:FrArMtrx
use variables,only:h,theta,k,swkimpl
use DIAG19,only:probe_busy,probe_u,point_id,point_node,point_delta,attempts,iter_index
implicit none
integer::u,pu,ru,oldunit,oldid,oldnode,nbytes,ncache,pid,lev,j,sgn,node
integer,parameter::nodes(3)=[50,51,52]
real(8)::olddelta,eps,delta,cm(24,madm),ins(macp,madm),outs(macp,madm),uns(macp,madm),rapid(macp,madm)
logical::oldbusy,same,csame,flags0(size(ieee_all)),flags1(size(ieee_all))
character(120)::base,rest,cache,crest,points,receipt,limits
integer(1),allocatable::original(:),restored(:),coriginal(:),crestored(:)
type(ieee_status_type)::fp
if(attempts/=2.or.(iter_index/=53.and.iter_index/=54)) error stop 'FACTOR60 outside selected point'
write(base,'(a,i0,a)') 'factor60_i',iter_index,'_base.bin'
write(rest,'(a,i0,a)') 'factor60_i',iter_index,'_restored.bin'
write(cache,'(a,i0,a)') 'factor60_i',iter_index,'_cache.bin'
write(crest,'(a,i0,a)') 'factor60_i',iter_index,'_cache_restored.bin'
write(points,'(a,i0,a)') 'factor60_i',iter_index,'_points.txt'
write(receipt,'(a,i0,a)') 'factor60_i',iter_index,'_restore.txt'
write(limits,'(a,i0,a)') 'factor60_i',iter_index,'_limits.txt'
oldbusy=probe_busy;oldunit=probe_u;oldid=point_id;oldnode=point_node;olddelta=point_delta
call ieee_get_status(fp);call ieee_get_flag(ieee_all,flags0)
call snapshot(trim(base),1)
open(newunit=u,file=trim(cache),status='replace',access='stream',form='unformatted');call contract42_cache_io(u,1);close(u)
inquire(file=trim(base),size=nbytes);inquire(file=trim(cache),size=ncache)
allocate(original(nbytes),restored(nbytes),coriginal(ncache),crestored(ncache))
open(newunit=u,file=trim(base),status='old',access='stream',form='unformatted');read(u) original;close(u)
open(newunit=u,file=trim(cache),status='old',access='stream',form='unformatted');read(u) coriginal;close(u)
open(newunit=pu,file=trim(points),status='replace');open(newunit=ru,file=trim(receipt),status='replace')
open(newunit=probe_u,file=trim(limits),status='replace')
probe_busy=.true.;pid=0
call record(0,0d0)
do lev=1,2
 eps=1d-7/dble(lev)
 do j=1,3
  node=nodes(j)
  do sgn=-1,1,2
   call restore()
   pid=pid+1;delta=dble(sgn)*eps;point_id=pid;point_node=node;point_delta=delta
   h(node)=h(node)+delta;theta(node)=watcon(node,h(node))
   if(swkimpl==1) k(node)=FrArMtrx(node)*hconduc(node,h(node),theta(node),rfcp(node))
   call MACRORATE(1)
   call record(node,delta)
  end do
 end do
end do
call restore();pid=pid+1;call record(0,0d0)
close(pu);close(ru);close(probe_u)
probe_busy=oldbusy;probe_u=oldunit;point_id=oldid;point_node=oldnode;point_delta=olddelta
call ieee_set_status(fp)
deallocate(original,restored,coriginal,crestored)
contains
subroutine restore()
call snapshot(trim(base),2)
open(newunit=u,file=trim(cache),status='old',access='stream',form='unformatted');call contract42_cache_io(u,2);close(u)
call snapshot(trim(rest),1)
open(newunit=u,file=trim(crest),status='replace',access='stream',form='unformatted');call contract42_cache_io(u,1);close(u)
open(newunit=u,file=trim(rest),status='old',access='stream',form='unformatted');read(u) restored;close(u)
open(newunit=u,file=trim(crest),status='old',access='stream',form='unformatted');read(u) crestored;close(u)
same=all(original==restored);csame=all(coriginal==crestored)
call ieee_set_status(fp);call ieee_get_flag(ieee_all,flags1)
write(ru,*) pid,nbytes,ncache,merge(1,0,same),merge(1,0,csame),merge(1,0,all(flags0.eqv.flags1))
if(.not.same.or..not.csame.or..not.all(flags0.eqv.flags1)) error stop 'FACTOR60 restore failed'
end subroutine
subroutine record(n,dx)
integer,intent(in)::n
real(8),intent(in)::dx
call diagnose36_get(cm,ins,outs,uns,rapid)
write(pu,*) pid,n,dx,iter_index,cm(:,3),h(50:52),z(50:51),ZBtDm(3),ICpBtDm(3),swkimpl
write(pu,*) outs(1:numnod,3)
write(pu,*) uns(1:numnod,3)
write(pu,*) VlMpDmCp(3,1:numnod)
write(pu,*) dz(1:numnod)
write(pu,*) QExcMtxDmCp(3,1:numnod)
write(pu,*) h(1:numnod)
end subroutine
end subroutine
