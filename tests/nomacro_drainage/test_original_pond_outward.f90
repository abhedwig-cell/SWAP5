! Calls the actual original MOD_top.PondRunoff. Only private fixture inputs
! h0max/k1max are exposed by the test build; no process body is copied here.
program original_pond_outward
use MOD_top,only:pondrunoff,q0,h0max,k1max,hsurf
use MOD_swap_base,only:swdra,swmacro,swpondmx
use MOD_grid,only:disnod
use MOD_drain,only:wls,swst
use variables,only:dt,rsro,rsroexp,pondmx,pondm1,pond,h,runots
implicit none
character(32)::mode
real(8)::residual,qtop,p1
call get_command_argument(1,mode)
swdra=2;swmacro=0;swpondmx=0
dt=.01d0;rsro=.02d0;rsroexp=1d0;pondmx=.2d0;pondm1=.2d0
wls=-10d0;swst=1d0;disnod(1)=1d0;h(1)=.7001d0
k1max=1d0;q0=.5d0
p1=k1max/disnod(1)*dt
h0max=(pondm1+q0*dt-k1max*dt+p1*h(1))/(1d0+p1)
pond=h0max
call pondrunoff()
qtop=-k1max*((hsurf-h(1))/disnod(1)+1d0)
residual=pond-pondm1+runots-dt*(q0+qtop)
write(*,'(a,6(1x,es25.17e3))')'ACTUAL_POND_SMALL_OUTFLOW',h0max,pond,runots,qtop,residual,wls
if(trim(mode)=='original')then
 if(abs(residual)<=1d-10.or.abs(runots)>=1d-6)error stop 'original small flux defect not reproduced'
else if(trim(mode)=='corrected')then
 if(abs(residual)>1d-10.or.runots<=0d0)error stop 'corrected pond balance failed'
else
 error stop 'mode required'
end if
end program
