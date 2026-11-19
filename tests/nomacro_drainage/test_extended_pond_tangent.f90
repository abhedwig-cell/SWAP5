! Derivative is checked against actual original PondRunoff evaluations.
program extended_pond_tangent
use MOD_top,only:pondrunoff,q0,h0max,k1max,hsurf,extended_pond_top_jacobian
use MOD_swap_base,only:swdra,swmacro,swpondmx
use MOD_grid,only:disnod
use MOD_drain,only:wls,swst,sttab
use variables,only:dt,rsro,rsroexp,pondmx,pondm1,pond,h,runots
implicit none
integer::i,j
real(8)::base,epsilon,plus,minus,tangent,actual
swdra=2;swmacro=0;swpondmx=0;disnod(1)=1d0;k1max=1d0
q0=.5d0;dt=.01d0;rsro=.02d0;pondmx=.2d0;pondm1=.21d0
do i=1,22
 sttab(i,1)=100d0-200d0*dble(i-1)/21d0
 sttab(i,2)=.5d0*sttab(i,1)
end do
epsilon=1d-4
do j=1,5
 rsroexp=1d0;swst=1d0;wls=-10d0;base=1d0
 select case(j)
 case(2)
  wls=2d0;base=.71d0
 case(3)
  wls=2d0;base=.71d0;swst=10d0
 case(4)
  rsroexp=1.5d0;base=10d0
 case(5)
  wls=.25d0;base=50d0
 end select
 call evaluate(base,actual)
 tangent=extended_pond_top_jacobian(1d0,dt)
 call evaluate(base+epsilon,plus)
 call evaluate(base-epsilon,minus)
 actual=(plus-minus)/(2d0*epsilon)
 if(abs(actual-tangent)>1d-8)error stop 'original pond implicit derivative differs'
 write(*,'(a,1x,i0,3(1x,es25.17e3))')'ACTUAL_POND_TANGENT',j,tangent,actual,actual-tangent
end do
contains
subroutine evaluate(head,flux)
real(8),intent(in)::head
real(8),intent(out)::flux
h(1)=head
h0max=(pondm1+q0*dt-k1max*dt+k1max/disnod(1)*dt*h(1))/(1d0+k1max/disnod(1)*dt)
pond=h0max
call pondrunoff()
flux=-k1max*((hsurf-h(1))/disnod(1)+1d0)
end subroutine
end program
