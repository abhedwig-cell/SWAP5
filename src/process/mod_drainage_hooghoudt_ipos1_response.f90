module mod_drainage_hooghoudt_ipos1_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_IPOS1_OK = 0
  integer, parameter, public :: DRAIN_IPOS1_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_IPOS1_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_IPOS1_NUMERICAL_DOMAIN = 3
  real(real64), parameter, public :: DRAIN_IPOS1_B110_DIFFL_CUTOFF = 1.0e-10_real64

  type, public :: drainage_hooghoudt_ipos1_parameters_t
    real(real64) :: drain_spacing = 0.0_real64
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: drain_bottom_level = 0.0_real64
    real(real64) :: horizontal_conductivity_top = 0.0_real64
    real(real64) :: entry_resistance = 0.0_real64
  end type drainage_hooghoudt_ipos1_parameters_t

  type, public :: drainage_hooghoudt_ipos1_result_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_hooghoudt_ipos1_result_t

  type, public :: drainage_hooghoudt_ipos1_diagnostics_t
    integer :: status = DRAIN_IPOS1_OK
    logical :: evaluated = .false.
    logical :: inactive_below_compatibility_cutoff = .false.
    logical :: active = .false.
    logical :: at_exact_compatibility_cutoff = .false.
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: difference = 0.0_real64
    real(real64) :: horizontal_resistance = 0.0_real64
    real(real64) :: total_resistance = 0.0_real64
    logical :: mass_is_authoritative_external_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_hooghoudt_ipos1_diagnostics_t

  public :: evaluate_drainage_hooghoudt_ipos1_response

contains

  subroutine evaluate_drainage_hooghoudt_ipos1_response(parameters, hydraulic_view, response, diagnostics)
    type(drainage_hooghoudt_ipos1_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_hooghoudt_ipos1_result_t), intent(out) :: response
    type(drainage_hooghoudt_ipos1_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: difference, horizontal_resistance, total_resistance, dd_dgwl

    response = drainage_hooghoudt_ipos1_result_t()
    diagnostics = drainage_hooghoudt_ipos1_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = DRAIN_IPOS1_INVALID_PARAMETERS
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_IPOS1_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = (hydraulic_view%groundwater_level - parameters%drain_bottom_level) / parameters%shape_factor
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = DRAIN_IPOS1_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    diagnostics%difference = difference

    if (difference < DRAIN_IPOS1_B110_DIFFL_CUTOFF) then
      diagnostics%evaluated = .true.
      diagnostics%inactive_below_compatibility_cutoff = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    horizontal_resistance = parameters%drain_spacing**2 / &
         (4.0_real64 * parameters%horizontal_conductivity_top * abs(difference))
    total_resistance = horizontal_resistance + parameters%entry_resistance

    if (.not. ieee_is_finite(horizontal_resistance) .or. .not. ieee_is_finite(total_resistance) .or. &
         .not. (total_resistance > 0.0_real64)) then
      diagnostics%status = DRAIN_IPOS1_NUMERICAL_DOMAIN
      return
    end if

    response%signed_soil_to_drain_rate = difference / total_resistance
    if (.not. ieee_is_finite(response%signed_soil_to_drain_rate)) then
      diagnostics%status = DRAIN_IPOS1_NUMERICAL_DOMAIN
      response = drainage_hooghoudt_ipos1_result_t()
      return
    end if

    diagnostics%evaluated = .true.
    diagnostics%active = .true.
    diagnostics%horizontal_resistance = horizontal_resistance
    diagnostics%total_resistance = total_resistance

    if (.not. (difference > DRAIN_IPOS1_B110_DIFFL_CUTOFF)) then
      diagnostics%at_exact_compatibility_cutoff = .true.
      return
    end if

    dd_dgwl = 1.0_real64 / parameters%shape_factor
    response%dq_dgroundwater_level = dd_dgwl * &
         (1.0_real64 + horizontal_resistance / total_resistance) / total_resistance
    if (.not. ieee_is_finite(response%dq_dgroundwater_level)) then
      diagnostics%status = DRAIN_IPOS1_NUMERICAL_DOMAIN
      diagnostics%evaluated = .false.
      response = drainage_hooghoudt_ipos1_result_t()
      return
    end if
    response%derivative_defined = .true.
  end subroutine evaluate_drainage_hooghoudt_ipos1_response

  logical function valid_parameters(parameters) result(valid)
    type(drainage_hooghoudt_ipos1_parameters_t), intent(in) :: parameters

    valid = ieee_is_finite(parameters%drain_spacing) .and. &
         ieee_is_finite(parameters%shape_factor) .and. &
         ieee_is_finite(parameters%drain_bottom_level) .and. &
         ieee_is_finite(parameters%horizontal_conductivity_top) .and. &
         ieee_is_finite(parameters%entry_resistance)
    if (.not. valid) return

    valid = parameters%drain_spacing > 0.0_real64 .and. &
         parameters%shape_factor > 0.0_real64 .and. &
         parameters%horizontal_conductivity_top > 0.0_real64 .and. &
         parameters%entry_resistance >= 0.0_real64
  end function valid_parameters

end module mod_drainage_hooghoudt_ipos1_response
