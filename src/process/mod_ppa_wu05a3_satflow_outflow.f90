module mod_ppa_wu05a3_satflow_outflow
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SATFLOW_OUTFLOW_OK = 0
  integer, parameter, public :: PPA_WU05A3_SATFLOW_OUTFLOW_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_SATFLOW_OUTFLOW_INACTIVE = 2

  public :: ppa_wu05a3_satflow_outflow

contains

  pure subroutine ppa_wu05a3_satflow_outflow(macropore_bottom_compartment, top_compartment, &
       signed_exchange_potential, compartment_outflow, total_outflow, status)
    integer, intent(in) :: macropore_bottom_compartment, top_compartment
    real(real64), intent(in) :: signed_exchange_potential(:)
    real(real64), intent(out) :: compartment_outflow(:), total_outflow
    integer, intent(out) :: status
    integer :: ic, n

    compartment_outflow = 0.0_real64
    total_outflow = 0.0_real64
    status = PPA_WU05A3_SATFLOW_OUTFLOW_INVALID_INPUT
    n = size(signed_exchange_potential)
    if (n <= 0 .or. size(compartment_outflow) /= n) return
    if (top_compartment < 1 .or. macropore_bottom_compartment < 1) return
    if (.not. all(ieee_is_finite(signed_exchange_potential))) return

    ! Source: B1.11 SWAP/macrorate.f90 SATFLOW task 2, lines 1576-1596.
    if (macropore_bottom_compartment < top_compartment) then
      status = PPA_WU05A3_SATFLOW_OUTFLOW_INACTIVE
      return
    end if
    if (macropore_bottom_compartment > n .or. top_compartment > n) return
    do ic = top_compartment, macropore_bottom_compartment
      if (signed_exchange_potential(ic) < 0.0_real64) then
        compartment_outflow(ic) = -signed_exchange_potential(ic)
        total_outflow = total_outflow + compartment_outflow(ic)
      end if
    end do
    status = PPA_WU05A3_SATFLOW_OUTFLOW_OK
  end subroutine ppa_wu05a3_satflow_outflow

end module mod_ppa_wu05a3_satflow_outflow
