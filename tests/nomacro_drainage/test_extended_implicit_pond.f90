! Controlled K(head) perturbations exercise the real complete PondRunoff.
! This tests the numerical interface; it is not an invented hydraulic model.
program extended_implicit_pond_probe
use MOD_top,only:pondrunoff,q0,h0max,k1max,hsurf,extended_pond_top_jacobian,extended_implicit_top_jacobian
use MOD_swap_base,only:swdra,swmacro,swpondmx
use MOD_grid,only:disnod
use MOD_drain,only:wls,swst,sttab
use variables,only:dt,rsro,rsroexp,pondmx,pondm1,pond,h
implicit none
integer::i,j,mode,trial,count
real(8)::base,epsilon,plus,minus,tangent,observed,partial,gradient,kprime,old,again,other
real(8)::saved(7),table(22,2)
real(8),parameter::primes(4)=[0d0,.02d0,.5d0,2d0]
swdra=2;swmacro=0;swpondmx=0;disnod(1)=1d0
q0=.5d0;rsro=.02d0;pondmx=.2d0;pondm1=.21d0
do i=1,22
 sttab(i,1)=100d0-200d0*dble(i-1)/21d0
 sttab(i,2)=.5d0*sttab(i,1)
end do
epsilon=1d-4;count=0
do trial=1,2
 dt=.01d0*dble(2*trial-1)
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
  do mode=1,size(primes)
   kprime=primes(mode)
   call evaluate(base,observed)
   gradient=(hsurf-base)/disnod(1)+1d0
   partial=k1max/disnod(1)-kprime*gradient
   saved=[pond,pondmx,swst,wls,dt,rsro,rsroexp];table=sttab(1:22,1:2)
   tangent=extended_implicit_top_jacobian(k1max/disnod(1),partial,dt)
   other=extended_implicit_top_jacobian(k1max/disnod(1),-partial,dt)
   again=extended_implicit_top_jacobian(k1max/disnod(1),partial,dt)
   if(tangent/=again.or.any(saved/=[pond,pondmx,swst,wls,dt,rsro,rsroexp]).or.any(table/=sttab(1:22,1:2))) &
     error stop 'implicit pond tangent mutated physical inputs or failed A/B/A'
   old=extended_pond_top_jacobian(k1max/disnod(1),dt)
   if(kprime==0d0.and.old/=tangent)error stop 'implicit pond tangent changed exact fixed-K limit'
   call evaluate(base+epsilon,plus)
   call evaluate(base-epsilon,minus)
   observed=(plus-minus)/(2d0*epsilon)
   if(abs(observed-tangent)>1d-8)error stop 'original pond conductivity chain rule differs'
   count=count+1
   write(*,'(a,3(1x,i0),5(1x,es25.17e3))')'ACTUAL_IMPLICIT_POND_TANGENT',trial,j,mode,partial,tangent,observed,observed-tangent,old
  end do
 end do
end do
if(count/=40)error stop 'implicit pond derivative denominator differs'
write(*,'(a,1x,i0)')'ACTUAL_ORIGINAL_IMPLICIT_EXTENDED_POND_CHAIN_RULE_PASS',count
contains
subroutine evaluate(head,flux)
real(8),intent(in)::head
real(8),intent(out)::flux
h(1)=head;k1max=1d0+kprime*(head-base)
if(k1max<=0d0)error stop 'nonpositive controlled conductivity'
h0max=(pondm1+q0*dt-k1max*dt+k1max/disnod(1)*dt*h(1))/(1d0+k1max/disnod(1)*dt)
pond=h0max
call pondrunoff()
flux=-k1max*((hsurf-h(1))/disnod(1)+1d0)
end subroutine
end program
