program test_bordered_drain_control
 use iso_fortran_env,only:real64,real128
 use mod_reference_linear_solver
 implicit none
 real(real64)::a(5),b(5),c(5),rhs(5),direction(5),truth(5),delta(5),gamma(5),saved(5),scale,dlambda
 real(real128)::res,term
 integer::n,node,power,i,st,cases
 cases=0
 do n=3,5,2
 do node=1,n
 do power=-12,12,12
  scale=10.0_real64**power;a=-scale;c=-scale;b=4*scale
  a(1)=0;c(n)=0
  direction=0.2_real64*scale
  truth=[(0.1_real64*i,i=1,5)]
  do i=1,n
   rhs(i)=b(i)*truth(i)+direction(i)*(-0.3_real64)
   if(i>1)rhs(i)=rhs(i)+a(i)*truth(i-1)
   if(i<n)rhs(i)=rhs(i)+c(i)*truth(i+1)
  end do
  call reference_tridag(n,a,b,c,rhs,delta,gamma,st)
  call check(st==0,'primary solve')
  call reference_constraint_correction(n,a,b,c,direction,node,truth(node),delta,dlambda,st)
  call check(st==0,'bordered correction')
  call check(maxval(abs(delta(:n)-truth(:n)))<2e-14_real64,'known pressure correction')
  call check(abs(dlambda+0.3_real64)<2e-14_real64,'known flux multiplier')
  res=0
  do i=1,n
   term=real(b(i),real128)*real(delta(i),real128)+real(direction(i),real128)*real(dlambda,real128)-real(rhs(i),real128)
   if(i>1)term=term+real(a(i),real128)*real(delta(i-1),real128)
   if(i<n)term=term+real(c(i),real128)*real(delta(i+1),real128)
   res=max(res,abs(term))
  end do
  call check(res<real(scale,real128)*2e-14_real128,'independent real128 equation residual')
  cases=cases+1
 end do
 end do
 end do
 saved=delta;direction=0
 call reference_constraint_correction(5,a,b,c,direction,2,1.0_real64,delta,dlambda,st)
 call check(st/=0.and.all(delta==saved),'singular control rejects atomically')
 call reference_constraint_correction(5,a,b,c,direction,0,1.0_real64,delta,dlambda,st)
 call check(st/=0.and.all(delta==saved),'invalid node rejects atomically')
 print *,'BORDERED_DRAIN_CONTROL_PASS',cases
contains
 subroutine check(ok,msg)
 logical,intent(in)::ok
 character(*),intent(in)::msg
 if(.not.ok)then
 print *,msg
 error stop 1
 end if
 end subroutine
end program
