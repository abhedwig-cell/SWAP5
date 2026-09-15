module mod_drainage_hooghoudt_ipos23_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_hooghoudt_equivalent_depth, only: hooghoudt_equivalent_depth_prepared_t
  implicit none
  private

  integer, parameter, public :: DRAIN_IPOS23_OK = 0
  integer, parameter, public :: DRAIN_IPOS23_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_IPOS23_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_IPOS23_INVALID_PREPARED_GEOMETRY = 3
  integer, parameter, public :: DRAIN_IPOS23_NUMERICAL_DOMAIN = 4
  integer, parameter, public :: DRAIN_IPOS2 = 2
  integer, parameter, public :: DRAIN_IPOS3 = 3
  real(real64), parameter, public :: DRAIN_IPOS23_B110_DIFFL_CUTOFF = 1.0e-10_real64

  type, public :: drainage_hooghoudt_ipos2_parameters_t
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: horizontal_conductivity_top = 0.0_real64
    real(real64) :: entry_resistance = 0.0_real64
  end type drainage_hooghoudt_ipos2_parameters_t

  type, public :: drainage_hooghoudt_ipos3_parameters_t
    real(real64) :: shape_factor = 0.0_real64
    real(real64) :: horizontal_conductivity_top = 0.0_real64
    real(real64) :: horizontal_conductivity_bottom = 0.0_real64
    real(real64) :: entry_resistance = 0.0_real64
  end type drainage_hooghoudt_ipos3_parameters_t

  type, public :: drainage_hooghoudt_ipos23_result_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_hooghoudt_ipos23_result_t

  type, public :: drainage_hooghoudt_ipos23_diagnostics_t
    integer :: status = DRAIN_IPOS23_OK
    integer :: ipos = 0
    logical :: evaluated = .false.
    logical :: inactive_below_compatibility_cutoff = .false.
    logical :: active = .false.
    logical :: at_exact_compatibility_cutoff = .false.
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: difference = 0.0_real64
    real(real64) :: conductance_denominator = 0.0_real64
    real(real64) :: horizontal_resistance = 0.0_real64
    real(real64) :: total_resistance = 0.0_real64
    logical :: prepared_equivalent_depth_is_shared_immutable = .true.
    logical :: mass_is_authoritative_external_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_hooghoudt_ipos23_diagnostics_t

  public :: evaluate_drainage_hooghoudt_ipos2_response
  public :: evaluate_drainage_hooghoudt_ipos3_response

contains

  subroutine evaluate_drainage_hooghoudt_ipos2_response(parameters, prepared, hydraulic_view, response, diagnostics)
    type(drainage_hooghoudt_ipos2_parameters_t), intent(in) :: parameters
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: prepared
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_hooghoudt_ipos23_result_t), intent(out) :: response
    type(drainage_hooghoudt_ipos23_diagnostics_t), intent(out) :: diagnostics

    if (.not. valid_ipos2_parameters(parameters)) then
      response = drainage_hooghoudt_ipos23_result_t()
      diagnostics = drainage_hooghoudt_ipos23_diagnostics_t()
      diagnostics%ipos = DRAIN_IPOS2
      diagnostics%status = DRAIN_IPOS23_INVALID_PARAMETERS
      return
    end if

    call evaluate_common(DRAIN_IPOS2, parameters%shape_factor, parameters%horizontal_conductivity_top, &
         parameters%horizontal_conductivity_top, parameters%entry_resistance, prepared, hydraulic_view, &
         response, diagnostics)
  end subroutine evaluate_drainage_hooghoudt_ipos2_response

  subroutine evaluate_drainage_hooghoudt_ipos3_response(parameters, prepared, hydraulic_view, response, diagnostics)
    type(drainage_hooghoudt_ipos3_parameters_t), intent(in) :: parameters
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: prepared
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_hooghoudt_ipos23_result_t), intent(out) :: response
    type(drainage_hooghoudt_ipos23_diagnostics_t), intent(out) :: diagnostics

    if (.not. valid_ipos3_parameters(parameters)) then
      response = drainage_hooghoudt_ipos23_result_t()
      diagnostics = drainage_hooghoudt_ipos23_diagnostics_t()
      diagnostics%ipos = DRAIN_IPOS3
      diagnostics%status = DRAIN_IPOS23_INVALID_PARAMETERS
      return
    end if

    call evaluate_common(DRAIN_IPOS3, parameters%shape_factor, parameters%horizontal_conductivity_top, &
         parameters%horizontal_conductivity_bottom, parameters%entry_resistance, prepared, hydraulic_view, &
         response, diagnostics)
  end subroutine evaluate_drainage_hooghoudt_ipos3_response

  subroutine evaluate_common(ipos, shape_factor, conductivity_top, conductivity_equivalent_depth, &
       entry_resistance, prepared, hydraulic_view, response, diagnostics)
    integer, intent(in) :: ipos
    real(real64), intent(in) :: shape_factor, conductivity_top, conductivity_equivalent_depth, entry_resistance
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: prepared
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_hooghoudt_ipos23_result_t), intent(out) :: response
    type(drainage_hooghoudt_ipos23_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: difference, denominator, horizontal_resistance, total_resistance
    real(real64) :: dd_dgwl, dden_dgwl, dresistance_dgwl

    response = drainage_hooghoudt_ipos23_result_t()
    diagnostics = drainage_hooghoudt_ipos23_diagnostics_t()
    diagnostics%ipos = ipos

    if (.not. valid_prepared(prepared)) then
      diagnostics%status = DRAIN_IPOS23_INVALID_PREPARED_GEOMETRY
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_IPOS23_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = (hydraulic_view%groundwater_level - prepared%drain_bottom_level) / shape_factor
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = DRAIN_IPOS23_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    diagnostics%difference = difference

    if (difference < DRAIN_IPOS23_B110_DIFFL_CUTOFF) then
      diagnostics%evaluated = .true.
      diagnostics%inactive_below_compatibility_cutoff = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    denominator = 8.0_real64 * conductivity_equivalent_depth * prepared%equivalent_depth + &
         4.0_real64 * conductivity_top * abs(difference)
    if (.not. ieee_is_finite(denominator) .or. .not. (denominator > 0.0_real64)) then
      diagnostics%status = DRAIN_IPOS23_NUMERICAL_DOMAIN
      return
    end if

    horizontal_resistance = prepared%drain_spacing**2 / denominator
    total_resistance = horizontal_resistance + entry_resistance
    if (.not. ieee_is_finite(horizontal_resistance) .or. .not. ieee_is_finite(total_resistance) .or. &
         .not. (total_resistance > 0.0_real64)) then
      diagnostics%status = DRAIN_IPOS23_NUMERICAL_DOMAIN
      return
    end if

    response%signed_soil_to_drain_rate = difference / total_resistance
    if (.not. ieee_is_finite(response%signed_soil_to_drain_rate)) then
      diagnostics%status = DRAIN_IPOS23_NUMERICAL_DOMAIN
      response = drainage_hooghoudt_ipos23_result_t()
      return
    end if

    diagnostics%evaluated = .true.
    diagnostics%active = .true.
    diagnostics%conductance_denominator = denominator
    diagnostics%horizontal_resistance = horizontal_resistance
    diagnostics%total_resistance = total_resistance

    if (.not. (difference > DRAIN_IPOS23_B110_DIFFL_CUTOFF)) then
      diagnostics%at_exact_compatibility_cutoff = .true.
      return
    end if

    dd_dgwl = 1.0_real64 / shape_factor
    dden_dgwl = 4.0_real64 * conductivity_top * dd_dgwl
    dresistance_dgwl = -horizontal_resistance * dden_dgwl / denominator
    response%dq_dgroundwater_level = dd_dgwl / total_resistance - &
         difference * dresistance_dgwl / (total_resistance * total_resistance)
    if (.not. ieee_is_finite(response%dq_dgroundwater_level)) then
      diagnostics%status = DRAIN_IPOS23_NUMERICAL_DOMAIN
      diagnostics%evaluated = .false.
      response = drainage_hooghoudt_ipos23_result_t()
      return
    end if
    response%derivative_defined = .true.
  end subroutine evaluate_common

  logical function valid_prepared(prepared) result(valid)
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: prepared
    valid = prepared%is_valid .and. ieee_is_finite(prepared%drain_spacing) .and. &
         ieee_is_finite(prepared%drain_bottom_level) .and. ieee_is_finite(prepared%equivalent_depth)
    if (.not. valid) return
    valid = prepared%drain_spacing > 0.0_real64 .and. prepared%equivalent_depth >= 0.0_real64
  end function valid_prepared

  logical function valid_ipos2_parameters(parameters) result(valid)
    type(drainage_hooghoudt_ipos2_parameters_t), intent(in) :: parameters
    valid = ieee_is_finite(parameters%shape_factor) .and. &
         ieee_is_finite(parameters%horizontal_conductivity_top) .and. &
         ieee_is_finite(parameters%entry_resistance)
    if (.not. valid) return
    valid = parameters%shape_factor > 0.0_real64 .and. &
         parameters%horizontal_conductivity_top > 0.0_real64 .and. parameters%entry_resistance >= 0.0_real64
  end function valid_ipos2_parameters

  logical function valid_ipos3_parameters(parameters) result(valid)
    type(drainage_hooghoudt_ipos3_parameters_t), intent(in) :: parameters
    valid = ieee_is_finite(parameters%shape_factor) .and. &
         ieee_is_finite(parameters%horizontal_conductivity_top) .and. &
         ieee_is_finite(parameters%horizontal_conductivity_bottom) .and. &
         ieee_is_finite(parameters%entry_resistance)
    if (.not. valid) return
    valid = parameters%shape_factor > 0.0_real64 .and. &
         parameters%horizontal_conductivity_top > 0.0_real64 .and. &
         parameters%horizontal_conductivity_bottom >= 0.0_real64 .and. &
         parameters%entry_resistance >= 0.0_real64
  end function valid_ipos3_parameters

end module mod_drainage_hooghoudt_ipos23_response
