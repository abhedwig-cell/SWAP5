! Isolated two-cell nonlinear contact subproblem, not a full Richards solve.
module mod_nonlinear_contact_pair
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_reference_linear_solver,only:reference_tridag
 implicit none
 private
 abstract interface
  subroutine contact_residual_i(x,fraction,residual,ok)
   import real64
   real(real64),intent(in)::x,fraction
   real(real64),intent(out)::residual(2)
   logical,intent(out)::ok
  end subroutine
 end interface
 type,public::nonlinear_contact_pair_result_t
  logical::produced=.false.
  integer::iterations=0,evaluations=0
  real(real64)::head=0d0,fraction=0d0,residual(2)=0d0
 end type
 public::trial_nonlinear_contact_pair
contains
 subroutine trial_nonlinear_contact_pair(evaluate,x0,fraction0,tolerance,result)
  procedure(contact_residual_i)::evaluate
  real(real64),intent(in)::x0,fraction0,tolerance
  type(nonlinear_contact_pair_result_t),intent(out)::result
  real(real64)::x,l,f(2),fp(2),fm(2),j(2,2),a(2),b(2),c(2),step(2),gamma(2),scale,dh,lo,hi
  integer::iteration,backtrack,status
  logical::ok,improved
  result=nonlinear_contact_pair_result_t()
  if(.not.all(ieee_is_finite([x0,fraction0,tolerance])).or.tolerance<=0d0.or. &
     fraction0<0d0.or.fraction0>1d0)return
  x=x0;l=fraction0
  do iteration=0,30
   call evaluate(x,l,f,ok);result%evaluations=result%evaluations+1
   if(.not.ok.or.any(.not.ieee_is_finite(f)))return
   result%iterations=iteration;result%residual=f
   if(maxval(abs(f))<=tolerance)then
    result%head=x;result%fraction=l;result%produced=.true.;return
   end if
   dh=1d-5*max(1d0,abs(x))
   call evaluate(x+dh,l,fp,ok);result%evaluations=result%evaluations+1;if(.not.ok)return
   call evaluate(x-dh,l,fm,ok);result%evaluations=result%evaluations+1;if(.not.ok)return
   j(:,1)=(fp-fm)/(2d0*dh)
   lo=max(0d0,l-1d-4);hi=min(1d0,l+1d-4)
   call evaluate(x,hi,fp,ok);result%evaluations=result%evaluations+1;if(.not.ok)return
   call evaluate(x,lo,fm,ok);result%evaluations=result%evaluations+1;if(.not.ok)return
   j(:,2)=(fp-fm)/(hi-lo)
   if(any(.not.ieee_is_finite(j)))return
   a=[0d0,j(2,1)];b=[j(1,1),j(2,2)];c=[j(1,2),0d0]
   call reference_tridag(2,a,b,c,f,step,gamma,status)
   if(status/=0.or.any(.not.ieee_is_finite(step)))return
   improved=.false.;scale=1d0
   do backtrack=1,32
    if(l-scale*step(2)>=0d0.and.l-scale*step(2)<=1d0)then
     call evaluate(x-scale*step(1),l-scale*step(2),fp,ok);result%evaluations=result%evaluations+1
     if(ok)then
      if(all(ieee_is_finite(fp)))then
       if(maxval(abs(fp))<maxval(abs(f)))then
        improved=.true.;exit
       end if
      end if
     end if
    end if
    scale=.5d0*scale
   end do
   if(.not.improved)return
   x=x-scale*step(1);l=l-scale*step(2)
  end do
 end subroutine
end module
