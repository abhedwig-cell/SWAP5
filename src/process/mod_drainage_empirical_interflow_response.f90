module mod_drainage_empirical_interflow_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: INTERFLOW_OK = 0
  integer, parameter, public :: INTERFLOW_INVALID_PARAMETERS = 1
  integer, parameter, public :: INTERFLOW_INVALID_CONTROL = 2
  integer, parameter, public :: INTERFLOW_INVALID_HYDRAULIC_VIEW = 3
  integer, parameter, public :: INTERFLOW_NUMERICAL_DOMAIN = 4

  real(real64), parameter, public :: INTERFLOW_COEFFICIENT_MIN = 0.01_real64
  real(real64), parameter, public :: INTERFLOW_COEFFICIENT_MAX = 10.0_real64
  real(real64), parameter, public :: INTERFLOW_EXPONENT_MIN = 0.1_real64
  real(real64), parameter, public :: INTERFLOW_EXPONENT_MAX = 1.0_real64

  type, public :: empirical_interflow_parameters_t
    real(real64) :: coefficient = 0.0_real64
    real(real64) :: exponent = 0.0_real64
  end type empirical_interflow_parameters_t

  type, public :: empirical_interflow_control_t
    real(real64) :: drain_head = 0.0_real64
  end type empirical_interflow_control_t

  type, public :: empirical_interflow_response_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
  end type empirical_interflow_response_t

  type, public :: empirical_interflow_diagnostics_t
    integer :: status = INTERFLOW_OK
    logical :: evaluated = .false.
    logical :: active = .false.
    logical :: inactive_below_activation = .false.
    logical :: at_activation = .false.
    logical :: singular_activation_tangent = .false.
    logical :: drainage_side_activation_tangent_defined = .false.
    real(real64) :: drainage_side_activation_tangent = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: drain_head = 0.0_real64
    real(real64) :: activation_difference = 0.0_real64
    logical :: contribution_is_interflow_only = .true.
    logical :: negative_side_exchange_out_of_scope = .true.
    logical :: mass_is_authoritative_external_transfer_contribution = .true.
    logical :: persistent_process_state = .false.
    logical :: process_side_tangent_regularization = .false.
  end type empirical_interflow_diagnostics_t

  public :: evaluate_empirical_interflow_response

contains

  subroutine evaluate_empirical_interflow_response(parameters, control, hydraulic_view, response, diagnostics)
    type(empirical_interflow_parameters_t), intent(in) :: parameters
    type(empirical_interflow_control_t), intent(in) :: control
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(empirical_interflow_response_t), intent(out) :: response
    type(empirical_interflow_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: difference, flux, tangent
    logical :: exponent_is_one

    response = empirical_interflow_response_t()
    diagnostics = empirical_interflow_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = INTERFLOW_INVALID_PARAMETERS
      return
    end if

    if (.not. ieee_is_finite(control%drain_head)) then
      diagnostics%status = INTERFLOW_INVALID_CONTROL
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = INTERFLOW_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = hydraulic_view%groundwater_level - control%drain_head
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = INTERFLOW_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    diagnostics%drain_head = control%drain_head
    diagnostics%activation_difference = difference
    diagnostics%evaluated = .true.

    if (difference < 0.0_real64) then
      diagnostics%inactive_below_activation = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    if (.not. (difference > 0.0_real64)) then
      diagnostics%at_activation = .true.
      exponent_is_one = .not. (parameters%exponent < 1.0_real64) .and. &
           .not. (parameters%exponent > 1.0_real64)
      if (exponent_is_one) then
        diagnostics%drainage_side_activation_tangent_defined = .true.
        diagnostics%drainage_side_activation_tangent = parameters%coefficient
      else
        diagnostics%singular_activation_tangent = .true.
      end if
      return
    end if

    flux = parameters%coefficient * difference**parameters%exponent
    tangent = parameters%coefficient * parameters%exponent * difference**(parameters%exponent - 1.0_real64)

    if (.not. ieee_is_finite(flux) .or. .not. ieee_is_finite(tangent)) then
      diagnostics%status = INTERFLOW_NUMERICAL_DOMAIN
      diagnostics%evaluated = .false.
      response = empirical_interflow_response_t()
      return
    end if

    response%signed_soil_to_drain_rate = flux
    response%dq_dgroundwater_level = tangent
    response%derivative_defined = .true.
    diagnostics%active = .true.
  end subroutine evaluate_empirical_interflow_response

  logical function valid_parameters(parameters) result(valid)
    type(empirical_interflow_parameters_t), intent(in) :: parameters

    valid = ieee_is_finite(parameters%coefficient) .and. ieee_is_finite(parameters%exponent)
    if (.not. valid) return
    valid = parameters%coefficient >= INTERFLOW_COEFFICIENT_MIN .and. &
         parameters%coefficient <= INTERFLOW_COEFFICIENT_MAX .and. &
         parameters%exponent >= INTERFLOW_EXPONENT_MIN .and. &
         parameters%exponent <= INTERFLOW_EXPONENT_MAX
  end function valid_parameters

end module mod_drainage_empirical_interflow_response
