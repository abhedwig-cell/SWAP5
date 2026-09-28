module mod_ppa_wu05a3_satflow_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SATFLOW_DERIVATIVE_OK = 0
  integer, parameter, public :: PPA_WU05A3_SATFLOW_DERIVATIVE_INVALID_INPUT = 1

  public :: ppa_wu05a3_satflow_derivative

contains

  pure subroutine ppa_wu05a3_satflow_derivative(top_compartment, bottom_compartment, top_macropore_compartment, &
       matrix_head, signed_head_difference, inflow, outflow, derivative_in, head_difference_out, derivative_out, status)
    integer, intent(in) :: top_compartment, bottom_compartment, top_macropore_compartment
    real(real64), intent(in) :: matrix_head(:), signed_head_difference(:), inflow(:), outflow(:), derivative_in(:)
    real(real64), intent(out) :: head_difference_out(:), derivative_out(:)
    integer, intent(out) :: status
    real(real64) :: critical_head, reference_head
    integer :: ic, n

    ! Do not copy nonconformable arrays before checking the caller's shapes.
    head_difference_out = 0.0_real64
    derivative_out = 0.0_real64
    status = PPA_WU05A3_SATFLOW_DERIVATIVE_INVALID_INPUT
    n = size(matrix_head)
    if (n <= 0 .or. size(signed_head_difference) /= n .or. size(inflow) /= n .or. &
        size(outflow) /= n .or. size(derivative_in) /= n .or. size(head_difference_out) /= n .or. &
        size(derivative_out) /= n) return
    head_difference_out = signed_head_difference
    derivative_out = derivative_in
    if (top_compartment < 1 .or. bottom_compartment < top_compartment .or. bottom_compartment > n) return
    if (top_macropore_compartment < 0 .or. top_macropore_compartment > n+1) return
    if (.not. all(ieee_is_finite(matrix_head)) .or. .not. all(ieee_is_finite(signed_head_difference)) .or. &
        .not. all(ieee_is_finite(inflow)) .or. .not. all(ieee_is_finite(outflow)) .or. &
        .not. all(ieee_is_finite(derivative_in))) return

    ! Source: B1.11 SWAP/macrorate.f90 SATFLOW task 4, lines 1603-1619.
    do ic = top_compartment, bottom_compartment
      if (abs(head_difference_out(ic)) > 1.0e-14_real64) then
        derivative_out(ic) = derivative_out(ic) - &
             (outflow(ic)-inflow(ic))/head_difference_out(ic)
      end if
    end do
    if (top_macropore_compartment > 1) then
      ic = top_macropore_compartment-1
      critical_head = 0.0_real64
      reference_head = critical_head
      if (matrix_head(ic) > critical_head) then
        head_difference_out(ic) = 0.0_real64-(matrix_head(ic)-reference_head)
        derivative_out(ic) = derivative_out(ic) + inflow(ic)/head_difference_out(ic)
      end if
    end if
    if (.not. all(ieee_is_finite(head_difference_out)) .or. .not. all(ieee_is_finite(derivative_out))) then
      head_difference_out = signed_head_difference
      derivative_out = derivative_in
      return
    end if
    status = PPA_WU05A3_SATFLOW_DERIVATIVE_OK
  end subroutine ppa_wu05a3_satflow_derivative

end module mod_ppa_wu05a3_satflow_derivative
