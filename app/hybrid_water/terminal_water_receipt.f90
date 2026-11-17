module hybrid_terminal_water_receipt
  use iso_fortran_env, only: real128
  implicit none
  private
  public :: terminal_water_terms, terminal_water_residual
contains
  subroutine terminal_water_terms(terms)
    ! Project the native double ledger exported after original Integral(3).
    ! This is a trial-only receipt: no assignment to original physical state.
    use MOD_grid, only: numnod, dz
    use MOD_swap_base, only: swmacro, swsnow, swdra
    use MOD_integral, only: igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &
      iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo
    use MOD_meteo, only: graidt,nraidt,aintcdt
    use MOD_irrigation, only: gird,qssdi
    use MOD_snow, only: gsnow,snrai,subl,ssnow
    use MOD_drain, only: qdrtot
    use MOD_re_global, only: qrosum
    use plant_interface, only: sw_inter,sicact,siccap,crsflx_in,crsflx_out
    use variables, only: theta,pond,dt,runon,runots,qbot,epd,reva, &
      ivolbeg,ipondbeg,issnowbeg,isicbeg
    real(8), intent(out) :: terms(28)
    real(8) :: ssdi,interception,canopy,qbotts
    integer :: node
    if(swmacro/=0.or.swsnow/=1.or.swdra/=1)error stop 'Unsupported terminal water receipt domain'
    ssdi=iqssdi
    do node=1,numnod
      ssdi=ssdi+qssdi(node)*dt
    end do
    qbotts=qbot*dt
    interception=iintc+aintcdt*dt
    if(sw_inter==3)interception=iintc+crsflx_out*dt
    canopy=min(max(0d0,sicact+(crsflx_in-crsflx_out)*dt),siccap)
    terms(1:7)=[igrai+graidt*dt,isnrai+snrai*dt,igsnow+gsnow*dt, &
      igird+gird*dt,irunon+runon*dt,ssdi,iqbup+max(0d0,qbotts)]
    terms(8:16)=-[interception,iruno+runots,iqrot+qrosum*dt,iepd+epd*dt, &
      ievap+reva*dt,isubl+subl*dt,iqdra+qdrtot*dt,0d0,iqbdo-min(0d0,qbotts)]
    terms(17:22)=[ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0]
    terms(23:28)=-[sum(theta(1:numnod)*dz(1:numnod)),pond,ssnow,canopy,0d0,0d0]
  end subroutine

  real(8) function terminal_water_residual() result(residual)
    real(8) :: terms(28)
    call terminal_water_terms(terms)
    ! Original double operations above remain separate. Extended precision only
    ! sums their exported values, independently of the hydraulic step sum.
    residual=real(sum(real(terms,real128)),8)
  end function
end module
