subroutine jac24_calibrate()
use,intrinsic::ieee_exceptions,only:ieee_status_type,ieee_get_status,ieee_set_status
use SENSE23_TRANSACTION,only:snapshot
use MOD_arrays,only:macp
use MOD_grid,only:numnod
implicit none
integer::u
real(8)::a(macp),b(macp),d(macp),meta(12)
type(ieee_status_type)::fp
call ieee_get_status(fp)
call snapshot('jac24_current.bin',1)
call snapshot('calibration_base.bin',2)
call jac24_terms(numnod,a,b,d,meta)
open(newunit=u,file='jac24_calibration.txt',status='replace')
write(u,*) 'meta',meta
write(u,*) 'u',a(1:numnod)
write(u,*) 'v',b(1:numnod)
write(u,*) 'base_q_derivative',d(1:numnod)
close(u)
call snapshot('jac24_current.bin',2)
call snapshot('jac24_restored.bin',1)
call ieee_set_status(fp)
end subroutine

subroutine jac24_solve(n,a,b,c,r,x,ierror)
use MOD_arrays,only:macp
use DIAG19,only:attempts,iter_index,active_in_attempt,active_total,apply37
implicit none
integer,intent(in)::n
real(8),intent(in)::a(n),b(n),c(n),r(n)
real(8),intent(out)::x(n)
integer,intent(out)::ierror
real(8)::uu(macp),vv(macp),d(macp),meta(12),z(macp),denom,alpha,res(n)
integer::u,i,e
logical::handled37
logical,save::opened=.false.
integer,save::trace_u
if(apply37) then
 call jac37_solve(n,a,b,c,r,x,ierror,handled37)
 if(handled37) return
end if
call jac24_terms(n,uu,vv,d,meta)
call tridag(n,a,b,c,r,x,ierror)
if(ierror/=0) then
 if(meta(1)==1d0) error stop 'JAC24 active base solve failed'
 return
end if
denom=1d0;alpha=0d0
if(meta(1)==1d0) then
 active_in_attempt=active_in_attempt+1;active_total=active_total+1
 call tridag(n,a,b,c,uu,z,e)
 if(e/=0) error stop 'JAC24 update solve failed'
 denom=1d0+dot_product(vv(1:n),z(1:n))
 if(abs(denom)<1d-12) error stop 'JAC24 rank update singular'
 alpha=dot_product(vv(1:n),x(1:n))/denom
 x=x-alpha*z(1:n)
end if
res=b*x-r
do i=2,n
 res(i)=res(i)+a(i)*x(i-1)
end do
do i=1,n-1
 res(i)=res(i)+c(i)*x(i+1)
end do
res=res+uu(1:n)*dot_product(vv(1:n),x)
if(.not.opened) then
 open(newunit=trace_u,file='jac24_trace.txt',status='replace')
 opened=.true.
end if
write(trace_u,*) attempts,iter_index,meta,denom,alpha,maxval(abs(res)),maxval(abs(x)), &
 uu(52),vv(50:52),d(52),uu(52)*vv(50:52)
if(mod(iter_index,16)==0) flush(trace_u)
end subroutine
