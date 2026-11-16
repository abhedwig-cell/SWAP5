program original_prescribed_head_receipt
use hybrid_step_budget,only:projected_water_residual
use MOD_grid,only:numnod,dz
use MOD_swap_base,only:swmacro,swsnow
use MOD_drain,only:qdrtot
use MOD_irrigation,only:nird,qssdisum
use MOD_meteo,only:nraidt
use MOD_re_global,only:qrosum
use variables,only:dt,theta,thetm1,pond,pondm1,qbot,swbotb,epd,reva,runon,runots
use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
implicit none
real(8)::closed,reference,opened,candidate
character(32)::mode
call get_command_argument(1,mode)
swmacro=0;swsnow=0;swbotb=5;numnod=2
dz(1:2)=[10d0,20d0];theta(1:2)=[.30d0,.40d0];thetm1(1:2)=[.299d0,.401d0]
pond=.015d0;pondm1=.02d0;dt=.1d0
nraidt=.1d0;nird=.02d0;runon=0d0;qssdisum=0d0
qrosum=.03d0;epd=.01d0;reva=.02d0;qdrtot=.01d0;runots=0d0
qbot=123d0
if(trim(mode)=='missing')then
  opened=projected_water_residual()
  error stop 'Missing trial receipt was accepted'
end if
candidate=-.2d0
if(trim(mode)=='nan')candidate=ieee_value(0d0,ieee_quiet_nan)
if(trim(mode)=='infinity')candidate=ieee_value(0d0,ieee_positive_inf)
opened=projected_water_residual(candidate)
if(abs(opened)>1d-14)error stop 'Open prescribed-head receipt differs'
if(qbot/=123d0.or.candidate/=-.2d0)error stop 'Trial receipt changed original boundary state'
if(abs(projected_water_residual(.2d0)+.04d0)>1d-14)error stop 'Inward prescribed-head receipt differs'
closed=projected_water_residual(0d0)
if(abs(closed+.02d0)>1d-14)error stop 'Closed prescribed-head receipt differs'
qbot=-123d0
if(projected_water_residual(0d0)/=closed)error stop 'Reconstructed flux leaked into trial receipt'
swbotb=6;qbot=0d0
reference=projected_water_residual()
if(reference/=closed)error stop 'Original explicit zero-flux receipt changed'
if(any(theta(1:2)/=[.30d0,.40d0]).or.any(thetm1(1:2)/=[.299d0,.401d0]).or.pond/=.015d0.or.pondm1/=.02d0) &
  error stop 'Trial receipt changed physical stocks'
print *,'ORIGINAL_PRESCRIBED_HEAD_RECEIPT_PASS',opened,closed,reference
end program
