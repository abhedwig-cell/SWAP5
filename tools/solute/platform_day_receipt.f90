! Private discriminator: forecast existing published day receipt without mutation.
! Not installed in the supported host; no tolerance or process change.
module rc1_day_receipt_probe
  use MOD_grid, only: numnod,dz
  use MOD_swap_base, only: swmacro,swsnow
  use MOD_integral, only: igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &
    iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo
  use MOD_meteo, only: graidt,aintcdt
  use MOD_irrigation, only: gird,qssdi
  use MOD_drain, only: qdrtot
  use MOD_re_global, only: qrosum
  use MOD_snow, only: ssnow
  use plant_interface, only: sicact,sw_inter,crsflx_out
  use variables, only: swbotb,theta,dt,qbot,pond,ivolbeg,ipondbeg,issnowbeg,isicbeg, &
    runon,runots,epd,reva
  implicit none
  private
  public :: projected_day_receipt
contains
  real(8) function projected_day_receipt() result(residual)
    integer,parameter :: wide=selected_real_kind(33)
    real(8) :: terms(28),drip,interception,bottom,stock
    integer :: node
    if(swmacro/=0.or.swsnow/=0.or.swbotb/=6) error stop 'Private day receipt probe domain'
    ! Match the original binary64 integration order, including per-node drip.
    drip=iqssdi
    do node=1,numnod
      drip=drip+qssdi(node)*dt
    end do
    interception=aintcdt
    if(sw_inter==3) interception=crsflx_out
    bottom=qbot*dt
    stock=sum(theta(1:numnod)*dz(1:numnod))
    terms(1:16)=[igrai+graidt*dt,isnrai,igsnow,igird+gird*dt,irunon+runon*dt, &
      drip,iqbup+max(bottom,0d0),-(iintc+interception*dt),-(iruno+runots), &
      -(iqrot+qrosum*dt),-(iepd+epd*dt),-(ievap+reva*dt),-isubl, &
      -(iqdra+qdrtot*dt),0d0,-(iqbdo-min(bottom,0d0))]
    terms(17:22)=[ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0]
    terms(23:28)=[-stock,-pond,-ssnow,-sicact,0d0,0d0]
    ! Resolve the independent fsum-like receipt, not cancellation of step deltas.
    residual=-real(sum(real(terms,kind=wide)),kind=8)
  end function
end module
