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

  type, public :: drainage_empirical_interflow_parameters_t
    real(real64) :: coefficient = 0.0_real64
    real(real64) :: exponent = 0.0_real64
  end type drainage_empirical_interflow_parameters_t

  type, public :: drainage_empirical_interflow_control_t
    real(real64) :: resolved_drain_head = 0.0_real64
  end type drainage_empirical_interflow_control_t

  type, public :: drainage_empirical_interflow_result_t
    real(real64) :: signed_soil_to_drain_rate = 0.0_real64
    logical :: derivative_defined = .false.
    real(real64) :: dq_dgroundwater_level = 0.0_real64
    logical :: right_tangent_defined_at_activation = .false.
    real(real64) :: right_dq_dgroundwater_level_at_activation = 0.0_real64
  end type drainage_empirical_interflow_result_t

  type, public :: drainage_empirical_interflow_diagnostics_t
    integer :: status = INTERFLOW_OK
    logical :: evaluated = .false.
    logical :: active = .false.
    logical :: inactive_below_activation = .false.
    logical :: at_activation = .false.
    logical :: negative_branch_not_evaluated = .false.
    logical :: right_tangent_singular = .false.
    logical :: finite_right_tangent_but_two_sided_kink = .false.
    logical :: tangent_numerically_unrepresentable = .false.
    real(real64) :: groundwater_level = 0.0_real64
    real(real64) :: resolved_drain_head = 0.0_real64
    real(real64) :: difference = 0.0_real64
    logical :: drainage_side_only = .true.
    logical :: mass_is_authoritative_external_transfer = .true.
    logical :: persistent_process_state = .false.
  end type drainage_empirical_interflow_diagnostics_t

  public :: evaluate_drainage_empirical_interflow_response

contains

  subroutine evaluate_drainage_empirical_interflow_response(parameters, control, hydraulic_view, response, diagnostics)
    type(drainage_empirical_interflow_parameters_t), intent(in) :: parameters
    type(drainage_empirical_interflow_control_t), intent(in) :: control
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(drainage_empirical_interflow_result_t), intent(out) :: response
    type(drainage_empirical_interflow_diagnostics_t), intent(out) :: diagnostics

    real(real64) :: difference

    response = drainage_empirical_interflow_result_t()
    diagnostics = drainage_empirical_interflow_diagnostics_t()

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = INTERFLOW_INVALID_PARAMETERS
      return
    end if
    if (.not. ieee_is_finite(control%resolved_drain_head)) then
      diagnostics%status = INTERFLOW_INVALID_CONTROL
      return
    end if
    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = INTERFLOW_INVALID_HYDRAULIC_VIEW
      return
    end if

    difference = hydraulic_view%groundwater_level - control%resolved_drain_head
    if (.not. ieee_is_finite(difference)) then
      diagnostics%status = INTERFLOW_NUMERICAL_DOMAIN
      return
    end if

    diagnostics%groundwater_level = hydraulic_view%groundwater_level
    diagnostics%resolved_drain_head = control%resolved_drain_head
    diagnostics%difference = difference
    diagnostics%evaluated = .true.

    if (difference < 0.0_real64) then
      diagnostics%inactive_below_activation = .true.
      diagnostics%negative_branch_not_evaluated = .true.
      response%derivative_defined = .true.
      response%dq_dgroundwater_level = 0.0_real64
      return
    end if

    if (difference > 0.0_real64) then
      diagnostics%active = .true.
      response%signed_soil_to_drain_rate = parameters%coefficient * difference**parameters%exponent
      if (.not. ieee_is_finite(response%signed_soil_to_drain_rate)) then
        diagnostics%status = INTERFLOW_NUMERICAL_DOMAIN
        diagnostics%evaluated = .false.
        response = drainage_empirical_interflow_result_t()
        return
      end if

      if (parameters%exponent < INTERFLOW_EXPONENT_MAX) then
        response%dq_dgroundwater_level = parameters%exponent * &
             response%signed_soil_to_drain_rate / difference
      else
        response%dq_dgroundwater_level = parameters%coefficient
      end if

      if (ieee_is_finite(response%dq_dgroundwater_level)) then
        response%derivative_defined = .true.
      else
        response%dq_dgroundwater_level = 0.0_real64
        diagnostics%tangent_numerically_unrepresentable = .true.
      end if
      return
    end if

    diagnostics%at_activation = .true.
    if (parameters%exponent < INTERFLOW_EXPONENT_MAX) then
      diagnostics%right_tangent_singular = .true.
    else
      diagnostics%finite_right_tangent_but_two_sided_kink = .true.
      response%right_tangent_defined_at_activation = .true.
      response%right_dq_dgroundwater_level_at_activation = parameters%coefficient
    end if
  end subroutine evaluate_drainage_empirical_interflow_response

  logical function valid_parameters(parameters) result(valid)
    type(drainage_empirical_interflow_parameters_t), intent(in) :: parameters

    valid = ieee_is_finite(parameters%coefficient) .and. ieee_is_finite(parameters%exponent)
    if (.not. valid) return

    valid = parameters%coefficient >= INTERFLOW_COEFFICIENT_MIN .and. &
         parameters%coefficient <= INTERFLOW_COEFFICIENT_MAX .and. &
         parameters%exponent >= INTERFLOW_EXPONENT_MIN .and. &
         parameters%exponent <= INTERFLOW_EXPONENT_MAX
  end function valid_parameters

end module mod_drainage_empirical_interflow_response
