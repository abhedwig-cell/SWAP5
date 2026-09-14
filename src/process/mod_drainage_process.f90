module mod_drainage_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAINAGE_OK = 0
  integer, parameter, public :: DRAINAGE_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAINAGE_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAINAGE_INVALID_CONTROL = 3

  type, public :: drainage_linear_parameters_t
    real(real64) :: drainage_resistance = 0.0_real64
  end type drainage_linear_parameters_t

  type, public :: drainage_control_t
    real(real64) :: drain_head = 0.0_real64
  end type drainage_control_t

  type, public :: drainage_transfer_t
    real(real64) :: soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type drainage_transfer_t

  type, public :: drainage_diagnostics_t
    integer :: status = DRAINAGE_OK
    logical :: evaluated = .false.
    logical :: active = .false.
    logical :: activation_kink = .false.
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: drain_head = 0.0_real64
    real(real64) :: head_difference = 0.0_real64
    logical :: mass_is_authoritative_external_transfer = .true.
  end type drainage_diagnostics_t

  public :: evaluate_single_level_linear_drainage

contains

  subroutine evaluate_single_level_linear_drainage(parameters, hydraulic_view, control, transfer, diagnostics)
    type(drainage_linear_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_control_t), intent(in) :: control
    type(drainage_transfer_t), intent(out) :: transfer
    type(drainage_diagnostics_t), intent(out) :: diagnostics
    real(real64) :: diffl

    transfer = drainage_transfer_t()
    diagnostics = drainage_diagnostics_t()

    if (.not. ieee_is_finite(parameters%drainage_resistance) .or. parameters%drainage_resistance <= 0.0_real64) then
      diagnostics%status = DRAINAGE_INVALID_PARAMETERS
      return
    end if
    if (.not. ieee_is_finite(control%drain_head)) then
      diagnostics%status = DRAINAGE_INVALID_CONTROL
      return
    end if
    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAINAGE_INVALID_HYDRAULIC_VIEW
      return
    end if

    diagnostics%evaluated = .true.
    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    diagnostics%drain_head = control%drain_head
    diffl = hydraulic_view%groundwater_level - control%drain_head
    diagnostics%head_difference = diffl

    if (diffl > 0.0_real64) then
      transfer%soil_to_drain_rate = diffl / parameters%drainage_resistance
      transfer%dq_dgroundwater_level = 1.0_real64 / parameters%drainage_resistance
      transfer%derivative_defined = .true.
      diagnostics%active = .true.
    else if (diffl < 0.0_real64) then
      transfer%soil_to_drain_rate = 0.0_real64
      transfer%dq_dgroundwater_level = 0.0_real64
      transfer%derivative_defined = .true.
    else
      transfer%soil_to_drain_rate = 0.0_real64
      transfer%dq_dgroundwater_level = 0.0_real64
      transfer%derivative_defined = .false.
      diagnostics%activation_kink = .true.
    end if
  end subroutine evaluate_single_level_linear_drainage

end module mod_drainage_process
