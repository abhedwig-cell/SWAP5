module mod_ppa_wu05a3_satflow_task1
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a3_satflow_exchange, only: ppa_wu05a3_satflow_exchange, PPA_WU05A3_SATFLOW_OK
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_SATFLOW_TASK1_OK = 0
  integer, parameter, public :: PPA_WU05A3_SATFLOW_TASK1_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_SATFLOW_TASK1_INACTIVE = 2
  integer, parameter, public :: PPA_WU05A3_SATFLOW_TASK1_COMPONENT_FAILURE = 3

  public :: ppa_wu05a3_satflow_task1

contains

  pure subroutine ppa_wu05a3_satflow_task1(domain_bottom_compartment, matrix_top_compartment, &
       matrix_bottom_compartment, saturated_compartment, reference_level, matrix_saturated_level, &
       matrix_head, node_elevation, compartment_thickness, saturation_fraction, darcy_reciprocal_resistance, &
       seepage_switch, ksat_horizontal, pore_diameter, domain_volume_fraction, shape_factor, pi, flow_reduction, &
       time_step, head_difference, signed_exchange_potential, incoming_by_compartment, total_incoming, status)
    integer, intent(in) :: domain_bottom_compartment, matrix_top_compartment, matrix_bottom_compartment
    integer, intent(in) :: saturated_compartment, seepage_switch
    real(real64), intent(in) :: reference_level, matrix_saturated_level, saturation_fraction
    real(real64), intent(in) :: matrix_head(:), node_elevation(:), compartment_thickness(:)
    real(real64), intent(in) :: darcy_reciprocal_resistance(:), ksat_horizontal(:), pore_diameter(:)
    real(real64), intent(in) :: domain_volume_fraction(:), shape_factor(:), pi, flow_reduction, time_step
    real(real64), intent(out) :: head_difference(:), signed_exchange_potential(:), incoming_by_compartment(:)
    real(real64), intent(out) :: total_incoming
    integer, intent(out) :: status
    real(real64) :: term_head, term_flux
    integer :: ic, n, term_status

    head_difference = 0.0_real64
    signed_exchange_potential = 0.0_real64
    incoming_by_compartment = 0.0_real64
    total_incoming = 0.0_real64
    status = PPA_WU05A3_SATFLOW_TASK1_INVALID_INPUT
    n = size(matrix_head)
    if (n <= 0 .or. size(node_elevation) /= n .or. size(compartment_thickness) /= n .or. &
        size(darcy_reciprocal_resistance) /= n .or. size(ksat_horizontal) /= n .or. &
        size(pore_diameter) /= n .or. size(domain_volume_fraction) /= n .or. size(shape_factor) /= n .or. &
        size(head_difference) /= n .or. size(signed_exchange_potential) /= n .or. &
        size(incoming_by_compartment) /= n) return
    if (domain_bottom_compartment < 1 .or. matrix_top_compartment < 1 .or. matrix_bottom_compartment < 0 .or. &
        matrix_bottom_compartment > n .or. saturated_compartment < 0 .or. seepage_switch < 0 .or. seepage_switch > 1) return
    if (.not. ieee_is_finite(reference_level) .or. .not. ieee_is_finite(matrix_saturated_level) .or. &
        .not. ieee_is_finite(saturation_fraction) .or. .not. ieee_is_finite(pi) .or. &
        .not. ieee_is_finite(flow_reduction) .or. .not. ieee_is_finite(time_step)) return
    if (.not. all(ieee_is_finite(node_elevation)) .or. .not. all(ieee_is_finite(compartment_thickness)) .or. &
        .not. all(ieee_is_finite(darcy_reciprocal_resistance)) .or. &
        .not. all(ieee_is_finite(ksat_horizontal)) .or. .not. all(ieee_is_finite(pore_diameter)) .or. &
        .not. all(ieee_is_finite(domain_volume_fraction)) .or. .not. all(ieee_is_finite(shape_factor))) return
    if (domain_bottom_compartment > n .or. matrix_top_compartment > n) return

    ! Source: B1.11 SWAP/macrorate.f90 SATFLOW task 1, lines 1499-1574.
    if (domain_bottom_compartment < matrix_top_compartment .or. matrix_bottom_compartment <= 0) then
      status = PPA_WU05A3_SATFLOW_TASK1_INACTIVE
      return
    end if
    do ic = matrix_top_compartment, min(domain_bottom_compartment, matrix_bottom_compartment)
      call ppa_wu05a3_satflow_exchange(matrix_head(ic), reference_level, node_elevation(ic), &
           compartment_thickness(ic), matrix_saturated_level, saturated_compartment, matrix_top_compartment, ic, &
           saturation_fraction, darcy_reciprocal_resistance(ic), seepage_switch, ksat_horizontal(ic), &
           pore_diameter(ic), domain_volume_fraction(ic), shape_factor(ic), pi, flow_reduction, time_step, &
           term_head, term_flux, term_status)
      if (term_status /= PPA_WU05A3_SATFLOW_OK) then
        head_difference = 0.0_real64
        signed_exchange_potential = 0.0_real64
        incoming_by_compartment = 0.0_real64
        total_incoming = 0.0_real64
        status = PPA_WU05A3_SATFLOW_TASK1_COMPONENT_FAILURE
        return
      end if
      head_difference(ic) = term_head
      signed_exchange_potential(ic) = term_flux
      if (term_flux > 0.0_real64) then
        incoming_by_compartment(ic) = term_flux
        total_incoming = total_incoming + incoming_by_compartment(ic)
      end if
    end do
    status = PPA_WU05A3_SATFLOW_TASK1_OK
  end subroutine ppa_wu05a3_satflow_task1

end module mod_ppa_wu05a3_satflow_task1
