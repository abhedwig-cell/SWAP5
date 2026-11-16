module hybrid_step_budget
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  pure real(8) function receipt_sum(values) result(total)
    ! Error-free binary64 expansion with a final half-even collapse, matching
    ! the finite math.fsum contract used by the host. At most24 receipt terms.
    ! This avoids software binary128 in every converged Richards candidate.
    real(8), intent(in) :: values(:)
    real(8) :: partial(24), carry, term, upper, lower, swap, recovered
    integer :: count, kept, item, part
    count=0
    do item=1,size(values)
      carry=values(item);kept=0
      do part=1,count
        term=partial(part)
        if(abs(carry)<abs(term)) then
          swap=carry;carry=term;term=swap
        end if
        upper=carry+term
        recovered=upper-carry
        lower=term-recovered
        if(lower/=0d0) then
          kept=kept+1;partial(kept)=lower
        end if
        carry=upper
      end do
      count=kept
      if(carry/=0d0) then
        count=count+1;partial(count)=carry
      end if
    end do
    total=0d0;lower=0d0
    if(count==0) return
    total=partial(count);count=count-1
    do while(count>0)
      carry=total;term=partial(count);count=count-1
      total=carry+term
      recovered=total-carry
      lower=term-recovered
      if(lower/=0d0) exit
    end do
    if(count>0) then
      if((lower<0d0.and.partial(count)<0d0).or.(lower>0d0.and.partial(count)>0d0)) then
        term=2d0*lower;carry=total+term
        recovered=carry-total
        if(recovered==term) total=carry
      end if
    end if
  end function

  real(8) function projected_daily_receipt_error() result(error)
    ! Predict the *exported* receipt using the original WatStor and Integral(3)
    ! arithmetic, without changing a state or counter. Sum-of-step residuals
    ! alone miss rounding in the independently integrated daily counters.
    ! Snow and reconstructed-bottom receipts retain their existing contracts.
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
    if(.not.all(ieee_is_finite(stocks)).or..not.all(ieee_is_finite(origin)).or. &
       .not.all(ieee_is_finite(flow))) then
      error=huge(1d0)
      return
    end if
    ! Reduce the exported binary64 quantities just as the host does, then
    ! apply both binary64 kernel associations without a tolerance allowance.
    ending=receipt_sum(stocks)
    initial=receipt_sum(origin)
    incoming=receipt_sum(flow(:7))
    outgoing=receipt_sum(flow(8:))
    independent=receipt_sum([flow(:7),-flow(8:),origin,-stocks])
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
