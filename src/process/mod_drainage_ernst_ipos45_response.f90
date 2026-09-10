module mod_drainage_ernst_ipos45_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_ernst_ipos45_preparation, only: ernst_ipos4_prepared_t, ernst_ipos5_prepared_t
  implicit none
  private

  integer, parameter, public :: DRAIN_ERNST_OK = 0
  integer, parameter, public :: DRAIN_ERNST_INVALID_HYDRAULIC_VIEW = 1
  integer, parameter, public :: DRAIN_ERNST_INVALID_PREPARED_GEOMETRY = 2
  integer, parameter, public :: DRAIN_ERNST_NUMERICAL_DOMAIN = 3
  integer, parameter, public :: DRAIN_ERNST_IPOS4 = 4
  integer, parameter, public :: DRAIN_ERNST_IPOS5 = 5
  real(real64), parameter, public :: DRAIN_ERNST_B110_DIFFL_CUTOFF = 1.0e-10_real64

  type, public :: drainage_ernst_response_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_ernst_response_t

  type, public :: drainage_ernst_diagnostics_t
    integer :: status = DRAIN_ERNST_OK
    integer :: ipos = 0
    logical :: evaluated = .false.
    logical :: inactive_below_compatibility_cutoff = .false.
    logical :: active = .false.
    logical :: at_exact_compatibility_cutoff = .false.
    logical :: at_ipos4_interface_kink = .false.
    logical :: negative_radial_resistance = .false.
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: difference = 0.0_real64
    real(real64) :: vertical_resistance = 0.0_real64
    real(real64) :: vertical_resistance_derivative = 0.0_real64
    real(real64) :: total_resistance = 0.0_real64
    logical :: prepared_geometry_is_shared_immutable = .true.
    logical :: mass_is_authoritative_external_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_ernst_diagnostics_t

  public :: evaluate_drainage_ernst_ipos4_response
  public :: evaluate_drainage_ernst_ipos5_response

contains

  subroutine evaluate_drainage_ernst_ipos4_response(prepared, hydraulic_view, response, diagnostics)
    type(ernst_ipos4_prepared_t), intent(in) :: prepared
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_ernst_response_t), intent(out) :: response
    type(drainage_ernst_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: gwl, difference, rver, drver_dgwl, dd_dgwl, total_resistance
    logical :: at_interface, branch_sensitive

    response = drainage_ernst_response_t()
    diagnostics = drainage_ernst_diagnostics_t()
    diagnostics%ipos = DRAIN_ERNST_IPOS4

    if (.not. valid_ipos4_prepared(prepared)) then
      diagnostics%status = DRAIN_ERNST_INVALID_PREPARED_GEOMETRY
      return
    end if

    gwl = hydraulic_view%groundwater_level
    if (.not. ieee_is_finite(gwl)) then
      diagnostics%status = DRAIN_ERNST_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = (gwl - prepared%drain_bottom_level) / prepared%shape_factor
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = gwl
    diagnostics%difference = difference
    diagnostics%negative_radial_resistance = prepared%radial_resistance < 0.0_real64

    if (difference < DRAIN_ERNST_B110_DIFFL_CUTOFF) then
      diagnostics%evaluated = .true.
      diagnostics%inactive_below_compatibility_cutoff = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    at_interface = .not. (gwl < prepared%interface_level) .and. .not. (gwl > prepared%interface_level)
    if (gwl > prepared%interface_level) then
      rver = (gwl - prepared%interface_level) / prepared%vertical_conductivity_top + &
           (prepared%interface_level - prepared%drain_bottom_level) / prepared%vertical_conductivity_bottom
      drver_dgwl = 1.0_real64 / prepared%vertical_conductivity_top
    else
      rver = (gwl - prepared%drain_bottom_level) / prepared%vertical_conductivity_bottom
      drver_dgwl = 1.0_real64 / prepared%vertical_conductivity_bottom
    end if

    total_resistance = prepared%fixed_resistance + rver
    if (.not. ieee_is_finite(rver) .or. .not. ieee_is_finite(drver_dgwl) .or. &
         .not. ieee_is_finite(total_resistance) .or. .not. (total_resistance > 0.0_real64)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      return
    end if

    response%signed_soil_to_drain_rate = difference / total_resistance
    if (.not. ieee_is_finite(response%signed_soil_to_drain_rate)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      response = drainage_ernst_response_t()
      return
    end if

    diagnostics%evaluated = .true.
    diagnostics%active = .true.
    diagnostics%vertical_resistance = rver
    diagnostics%vertical_resistance_derivative = drver_dgwl
    diagnostics%total_resistance = total_resistance
    diagnostics%at_ipos4_interface_kink = at_interface

    if (.not. (difference > DRAIN_ERNST_B110_DIFFL_CUTOFF)) then
      diagnostics%at_exact_compatibility_cutoff = .true.
      return
    end if

    branch_sensitive = abs(prepared%vertical_conductivity_top - prepared%vertical_conductivity_bottom) > 0.0_real64
    if (at_interface .and. branch_sensitive) return

    dd_dgwl = 1.0_real64 / prepared%shape_factor
    response%dq_dgroundwater_level = dd_dgwl / total_resistance - &
         difference * drver_dgwl / (total_resistance * total_resistance)
    if (.not. ieee_is_finite(response%dq_dgroundwater_level)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      diagnostics%evaluated = .false.
      response = drainage_ernst_response_t()
      return
    end if
    response%derivative_defined = .true.
  end subroutine evaluate_drainage_ernst_ipos4_response

  subroutine evaluate_drainage_ernst_ipos5_response(prepared, hydraulic_view, response, diagnostics)
    type(ernst_ipos5_prepared_t), intent(in) :: prepared
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_ernst_response_t), intent(out) :: response
    type(drainage_ernst_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: gwl, difference, rver, drver_dgwl, dd_dgwl, total_resistance

    response = drainage_ernst_response_t()
    diagnostics = drainage_ernst_diagnostics_t()
    diagnostics%ipos = DRAIN_ERNST_IPOS5

    if (.not. valid_ipos5_prepared(prepared)) then
      diagnostics%status = DRAIN_ERNST_INVALID_PREPARED_GEOMETRY
      return
    end if

    gwl = hydraulic_view%groundwater_level
    if (.not. ieee_is_finite(gwl)) then
      diagnostics%status = DRAIN_ERNST_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = (gwl - prepared%drain_bottom_level) / prepared%shape_factor
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = gwl
    diagnostics%difference = difference
    diagnostics%negative_radial_resistance = prepared%radial_resistance < 0.0_real64

    if (difference < DRAIN_ERNST_B110_DIFFL_CUTOFF) then
      diagnostics%evaluated = .true.
      diagnostics%inactive_below_compatibility_cutoff = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    rver = (gwl - prepared%drain_bottom_level) / prepared%vertical_conductivity_top
    drver_dgwl = 1.0_real64 / prepared%vertical_conductivity_top
    total_resistance = prepared%fixed_resistance + rver

    if (.not. ieee_is_finite(rver) .or. .not. ieee_is_finite(drver_dgwl) .or. &
         .not. ieee_is_finite(total_resistance) .or. .not. (total_resistance > 0.0_real64)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      return
    end if

    response%signed_soil_to_drain_rate = difference / total_resistance
    if (.not. ieee_is_finite(response%signed_soil_to_drain_rate)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      response = drainage_ernst_response_t()
      return
    end if

    diagnostics%evaluated = .true.
    diagnostics%active = .true.
    diagnostics%vertical_resistance = rver
    diagnostics%vertical_resistance_derivative = drver_dgwl
    diagnostics%total_resistance = total_resistance

    if (.not. (difference > DRAIN_ERNST_B110_DIFFL_CUTOFF)) then
      diagnostics%at_exact_compatibility_cutoff = .true.
      return
    end if

    dd_dgwl = 1.0_real64 / prepared%shape_factor
    response%dq_dgroundwater_level = dd_dgwl / total_resistance - &
         difference * drver_dgwl / (total_resistance * total_resistance)
    if (.not. ieee_is_finite(response%dq_dgroundwater_level)) then
      diagnostics%status = DRAIN_ERNST_NUMERICAL_DOMAIN
      diagnostics%evaluated = .false.
      response = drainage_ernst_response_t()
      return
    end if
    response%derivative_defined = .true.
  end subroutine evaluate_drainage_ernst_ipos5_response

  logical function valid_ipos4_prepared(prepared) result(valid)
    type(ernst_ipos4_prepared_t), intent(in) :: prepared
    valid = prepared%is_valid .and. ieee_is_finite(prepared%shape_factor) .and. &
         ieee_is_finite(prepared%drain_bottom_level) .and. ieee_is_finite(prepared%interface_level) .and. &
         ieee_is_finite(prepared%vertical_conductivity_top) .and. &
         ieee_is_finite(prepared%vertical_conductivity_bottom) .and. &
         ieee_is_finite(prepared%radial_resistance) .and. ieee_is_finite(prepared%fixed_resistance)
    if (.not. valid) return
    valid = prepared%shape_factor > 0.0_real64 .and. &
         prepared%vertical_conductivity_top > 0.0_real64 .and. &
         prepared%vertical_conductivity_bottom > 0.0_real64
  end function valid_ipos4_prepared

  logical function valid_ipos5_prepared(prepared) result(valid)
    type(ernst_ipos5_prepared_t), intent(in) :: prepared
    valid = prepared%is_valid .and. ieee_is_finite(prepared%shape_factor) .and. &
         ieee_is_finite(prepared%drain_bottom_level) .and. &
         ieee_is_finite(prepared%vertical_conductivity_top) .and. &
         ieee_is_finite(prepared%radial_resistance) .and. ieee_is_finite(prepared%fixed_resistance)
    if (.not. valid) return
    valid = prepared%shape_factor > 0.0_real64 .and. prepared%vertical_conductivity_top > 0.0_real64
  end function valid_ipos5_prepared

end module mod_drainage_ernst_ipos45_response
