module mod_ppa_low03_implicit_row
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_LOW03_ROW_OK = 0
  integer, parameter, public :: PPA_LOW03_ROW_INVALID_INPUT = 1
  public :: evaluate_ppa_low03_implicit_row

contains

  ! Source-shaped SWBOTB=3 / SWBOTB3IMPL=1 bottom residual and diagonal-Jacobian terms.
  subroutine evaluate_ppa_low03_implicit_row(sw_res_vert, sw_extra_flux, head, elevation, deepgw, &
      half_cell_spacing, bottom_conductivity, rimlay, extra_flux, qbot, residual_increment, &
      jacobian_increment, status)
    integer, intent(in) :: sw_res_vert, sw_extra_flux
    real(real64), intent(in) :: head, elevation, deepgw, half_cell_spacing
    real(real64), intent(in) :: bottom_conductivity, rimlay, extra_flux
    real(real64), intent(out) :: qbot, residual_increment, jacobian_increment
    integer, intent(out) :: status
    real(real64) :: resistance

    qbot = 0.0_real64
    residual_increment = 0.0_real64
    jacobian_increment = 0.0_real64
    status = PPA_LOW03_ROW_INVALID_INPUT
    if (sw_res_vert < 0 .or. sw_res_vert > 1 .or. sw_extra_flux < 0 .or. sw_extra_flux > 1) return
    if (.not. all(ieee_is_finite([head, elevation, deepgw, half_cell_spacing, &
                                  bottom_conductivity, rimlay, extra_flux]))) return
    if (half_cell_spacing <= 0.0_real64 .or. bottom_conductivity <= 0.0_real64) return
    if (rimlay < 0.0_real64 .or. rimlay > 100000.0_real64) return
    if (sw_extra_flux == 1) then
      if (extra_flux < -100.0_real64 .or. extra_flux > 100.0_real64) return
    end if

    resistance = rimlay
    if (sw_res_vert == 0) resistance = half_cell_spacing / bottom_conductivity + rimlay
    if (.not. ieee_is_finite(resistance) .or. resistance <= 0.0_real64) return

    qbot = -(head + elevation - deepgw) / resistance
    if (sw_extra_flux == 1) qbot = qbot + extra_flux
    residual_increment = -qbot
    jacobian_increment = 1.0_real64 / resistance
    if (.not. all(ieee_is_finite([qbot, residual_increment, jacobian_increment]))) then
      qbot = 0.0_real64
      residual_increment = 0.0_real64
      jacobian_increment = 0.0_real64
      return
    end if
    status = PPA_LOW03_ROW_OK
  end subroutine evaluate_ppa_low03_implicit_row

end module mod_ppa_low03_implicit_row
