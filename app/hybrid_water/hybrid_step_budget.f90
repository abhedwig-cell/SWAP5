module hybrid_step_budget
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swsnow, swmacro, swdra
  use MOD_macropore, only: NumDm, ICpBtDm, WaSrMpDm, QExcMtxDmCp, QInTopLatDm, QInTopVrtDm, QOutDrRapCp
  use MOD_swap_mp, only: ICTopMP, FrArMtrx, swmbf
  use MOD_drain, only: qdrtot
  use MOD_irrigation, only: nird, qssdisum, gird, qssdi
  use MOD_meteo, only: nraidt, graidt, aintcdt
  use MOD_snow, only: melt, ssnow
  use plant_interface, only: sw_inter, sicact, siccap, crsflx_in, crsflx_out
  use MOD_integral, only: igrai, isnrai, igsnow, igird, irunon, iqssdi, iqbup, &
       iintc, iruno, iqrot, iepd, ievap, isubl, iqdra, iqbdo
  use MOD_re_global, only: qrosum
  use variables, only: dt, theta, thetm1, pond, pondm1, qbot, swbotb, epd, reva, runon, runots, &
       ivolbeg, ipondbeg, issnowbeg, isicbeg
  implicit none
  private
  public :: projected_water_residual, projected_daily_receipt_error, apply_surface_lateral_limit
contains
  real(8) function projected_daily_receipt_error() result(error)
    ! Predict the *exported* receipt using the original WatStor and Integral(3)
    ! arithmetic, without changing a state or counter. Sum-of-step residuals
    ! alone miss rounding in the independently integrated daily counters.
    ! Snow and reconstructed-bottom receipts retain their existing contracts.
    integer, parameter :: wide = selected_real_kind(33)
    real(8) :: stocks(4), origin(4), flow(16), ending, initial, incoming, outgoing
    real(8) :: qbotts, canopy_out, independent, kernel_left, kernel_grouped
    integer :: node

    error=0d0
    if (swmacro/=0 .or. swsnow/=0) return
    if (.not.(abs(swbotb)==2 .or. swbotb==4 .or. swbotb==6 .or. swbotb==7)) return
    stocks=[sum(theta(1:numnod)*dz(1:numnod)),pond,ssnow, &
            min(max(0d0,sicact+(crsflx_in-crsflx_out)*dt),siccap)]
    origin=[ivolbeg,ipondbeg,issnowbeg,isicbeg]
    flow=[igrai+graidt*dt,isnrai,igsnow,igird+gird*dt,irunon+runon*dt,iqssdi,iqbup, &
          iintc,iruno+runots,iqrot+qrosum*dt,iepd+epd*dt,ievap+reva*dt,isubl,iqdra,0d0,iqbdo]
    ! Integral(3) deliberately adds subsurface irrigation node by node.
    do node=1,numnod
      flow(6)=flow(6)+qssdi(node)*dt
    end do
    qbotts=qbot*dt
    if(qbotts<0d0) flow(16)=flow(16)-qbotts
    if(qbotts>0d0) flow(7)=flow(7)+qbotts
    canopy_out=aintcdt
    if(sw_inter==3) canopy_out=crsflx_out
    flow(8)=flow(8)+canopy_out*dt
    if(swdra>0) flow(14)=flow(14)+qdrtot*dt
    ! The host faithfully exports these binary64 quantities, using math.fsum.
    ! Wider reduction reproduces those sums before applying both binary64
    ! kernel associations; it does not raise the binary64 physical tolerance.
    ending=real(sum(real(stocks,wide)),8)
    initial=real(sum(real(origin,wide)),8)
    incoming=real(sum(real(flow(:7),wide)),8)
    outgoing=real(sum(real(flow(8:),wide)),8)
    independent=real(sum(real(flow(:7),wide))-sum(real(flow(8:),wide)) &
                     +sum(real(origin,wide))-sum(real(stocks,wide)),8)
    kernel_left=ending-initial-incoming+outgoing
    kernel_grouped=ending-initial-(incoming-outgoing)
    error=max(abs(independent),abs(kernel_left),abs(kernel_grouped))
  end function

  real(8) function projected_water_residual() result(residual)
    real(8) :: delta_matrix, delta_macro, new_stock, rapid, external
    integer :: domain, bottom

    ! Original nonmacro explicit bottom fluxes share the same candidate balance.
    ! Modes1/5 reconstruct qbot after HeadCalc and cannot use this receipt.
    ! Mode-2 is the original prescribed-flux fallback to free drainage.
    if (swmacro==0 .and. &
        (abs(swbotb)==2 .or. swbotb==4 .or. swbotb==6 .or. swbotb==7 .or. (swbotb==3 .and. swsnow==1))) then
      delta_matrix=sum((theta(1:numnod)-thetm1(1:numnod))*dz(1:numnod))
      external=dt*(nraidt+nird+runon+qssdisum+qbot-qrosum-epd-reva-qdrtot)-runots
      ! Snow updates its native ssnow/slw state once at day start, outside the
      ! water trial. The soil+pond receipt receives its melt flux explicitly;
      ! the independent complete-day receipt still includes the snow store.
      if (swsnow==1) external=external+dt*melt
      residual=delta_matrix+pond-pondm1-external
      return
    end if
    ! This receipt uses the instantaneous-bypass and original Cauchy routes.
    ! Snow, other macro models and reconstructed bottom fluxes need their own receipt.
    if (swmbf /= 1 .or. swsnow /= 0 .or. swbotb /= 3) error stop 'Unsupported day-budget donor configuration'
    delta_matrix = sum((theta(1:numnod)-thetm1(1:numnod))*FrArMtrx(1:numnod)*dz(1:numnod))
    rapid = sum(QOutDrRapCp(ICTopMP:ICpBtDm(1)))
    delta_macro = 0d0
    do domain = 1, NumDm
      bottom = ICpBtDm(domain)
      new_stock = WaSrMpDm(domain) + dt*(QInTopLatDm(domain) + QInTopVrtDm(domain) &
                  - sum(QExcMtxDmCp(domain,ICTopMP:bottom)))
      if (domain == 1) new_stock = new_stock - rapid*dt
      delta_macro = delta_macro + (max(0d0,new_stock) - WaSrMpDm(domain))
    end do
    external = dt*(nraidt+nird+runon+qssdisum+qbot-qrosum-epd-reva-qdrtot-rapid)-runots
    residual = delta_matrix + delta_macro + pond - pondm1 - external
  end function

  subroutine apply_surface_lateral_limit(volume)
    real(8), intent(in) :: volume
    real(8) :: booked

    booked = dt*sum(QInTopLatDm(1:NumDm))
    if (volume >= 0d0 .and. booked > volume) then
      QInTopLatDm(1:NumDm) = QInTopLatDm(1:NumDm)*(volume/booked)
    end if
  end subroutine
end module hybrid_step_budget
