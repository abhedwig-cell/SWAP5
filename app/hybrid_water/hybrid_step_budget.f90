module hybrid_step_budget
  use MOD_grid, only: numnod, dz
  use MOD_swap_base, only: swsnow, swmacro
  use MOD_macropore, only: NumDm, ICpBtDm, WaSrMpDm, QExcMtxDmCp, QInTopLatDm, QInTopVrtDm, QOutDrRapCp
  use MOD_swap_mp, only: ICTopMP, FrArMtrx, swmbf
  use MOD_drain, only: qdrtot
  use MOD_irrigation, only: nird, qssdisum
  use MOD_meteo, only: nraidt
  use MOD_re_global, only: qrosum
  use variables, only: dt, theta, thetm1, pond, pondm1, qbot, swbotb, epd, reva, runon, runots
  implicit none
  private
  public :: projected_water_residual, apply_surface_lateral_limit
contains
  real(8) function projected_water_residual() result(residual)
    real(8) :: delta_matrix, delta_macro, new_stock, rapid, external
    integer :: domain, bottom

    ! Nonmacro closed-bottom Hupsel uses the same original candidate/rollback.
    if (swmacro==0 .and. swsnow==0 .and. swbotb==6) then
      delta_matrix=sum((theta(1:numnod)-thetm1(1:numnod))*dz(1:numnod))
      external=dt*(nraidt+nird+runon+qssdisum+qbot-qrosum-epd-reva-qdrtot)-runots
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
