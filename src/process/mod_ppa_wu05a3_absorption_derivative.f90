module mod_ppa_wu05a3_absorption_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DERIVATIVE_OK = 0
  integer, parameter, public :: PPA_WU05A3_ABSORPTION_DERIVATIVE_INVALID_INPUT = 1

  public :: ppa_wu05a3_absorption_derivative

contains

  pure subroutine ppa_wu05a3_absorption_derivative(in_derivative_zone, outflow, sorptivity_selected, &
       sorptivity_method, sorptivity_alpha, sorptivity_reference, theta, moisture_capacity, theta_s, &
       saved_head_difference, derivative_in, derivative_out, status)
    logical, intent(in) :: in_derivative_zone, sorptivity_selected, sorptivity_method
    real(real64), intent(in) :: outflow, sorptivity_alpha, sorptivity_reference, theta
    real(real64), intent(in) :: moisture_capacity, theta_s, saved_head_difference, derivative_in
    real(real64), intent(out) :: derivative_out
    integer, intent(out) :: status
    real(real64) :: derivative_term

    derivative_out=derivative_in
    status=PPA_WU05A3_ABSORPTION_DERIVATIVE_INVALID_INPUT
    if (.not. ieee_is_finite(outflow) .or. .not. ieee_is_finite(sorptivity_alpha) .or. &
        .not. ieee_is_finite(sorptivity_reference) .or. .not. ieee_is_finite(theta) .or. &
        .not. ieee_is_finite(moisture_capacity) .or. .not. ieee_is_finite(theta_s) .or. &
        .not. ieee_is_finite(saved_head_difference) .or. .not. ieee_is_finite(derivative_in)) return
    if (outflow < 0.0_real64 .or. moisture_capacity < 0.0_real64) return

    ! Source: B1.11 SWAP/macrorate.f90 ABSORPTION task 2, lines 1811-1835.
    if (in_derivative_zone .and. outflow > 1.0e-7_real64) then
      if (sorptivity_selected) then
        if (sorptivity_method) then
          if (sorptivity_alpha <= 0.0_real64 .or. sorptivity_reference <= theta) return
          derivative_term=-outflow*sorptivity_alpha/(sorptivity_reference-theta)
          derivative_term=derivative_term*moisture_capacity
        else
          if (theta_s <= theta) return
          derivative_term=-outflow*moisture_capacity/(theta_s-theta)
        end if
      else
        derivative_term=0.0_real64
        if (abs(saved_head_difference) > 1.0e-14_real64) then
          derivative_term=-outflow/saved_head_difference
        end if
      end if
      derivative_out=derivative_out+derivative_term
    end if
    if (.not. ieee_is_finite(derivative_out)) then
      derivative_out=derivative_in
      return
    end if
    status=PPA_WU05A3_ABSORPTION_DERIVATIVE_OK
  end subroutine ppa_wu05a3_absorption_derivative

end module mod_ppa_wu05a3_absorption_derivative
