module mod_b1_10_reference_policy_candidate_model
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_b1_10_recoverable_reference_model, only: b1_10_recoverable_reference_model_t
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t, characterize_b1_10_temporal_difference
  use mod_b1_10_reference_temporal_policy, only: b1_10_reference_temporal_limits_t, &
       b1_10_reference_temporal_assessment_t, evaluate_b1_10_reference_temporal
  implicit none
  private

  type, extends(b1_10_recoverable_reference_model_t), public :: b1_10_reference_policy_candidate_model_t
    type(b1_10_reference_temporal_limits_t) :: temporal_limits
    logical :: temporal_limits_bound = .false.
    logical :: qualified_numeric_profile = .false.
  contains
    procedure :: bind_temporal_limits => b1_10_bind_temporal_limits
    procedure :: temporal_error => b1_10_candidate_temporal_error
    procedure :: reference_execution_admitted => b1_10_candidate_reference_execution_blocked
  end type b1_10_reference_policy_candidate_model_t

contains

  subroutine b1_10_bind_temporal_limits(self, limits)
    class(b1_10_reference_policy_candidate_model_t), intent(inout) :: self
    type(b1_10_reference_temporal_limits_t), intent(in) :: limits
    if (.not. limits%valid()) error stop 'B1.10 F-CI14 temporal policy: invalid or incomplete limits'
    self%temporal_limits = limits
    self%temporal_limits_bound = .true.
    self%capabilities%temporal_error_contract = .true.
    self%reference_capabilities%scalar_temporal_error_policy = .true.
    ! Numerical values supplied here are candidate/configuration data only.
    ! F-CI14 intentionally provides no production-qualified default profile.
    self%qualified_numeric_profile = .false.
  end subroutine b1_10_bind_temporal_limits

  function b1_10_candidate_temporal_error(self, full_state, half_state) result(value)
    class(b1_10_reference_policy_candidate_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state
    real(real64) :: value
    type(b1_10_temporal_characterization_t) :: delta
    type(b1_10_reference_temporal_assessment_t) :: assessment

    if (.not. self%temporal_limits_bound) error stop 'B1.10 F-CI14 temporal policy: limits not bound'

    select type (full_physical => full_state)
    type is (b1_10_process_state_t)
      select type (half_physical => half_state)
      type is (b1_10_process_state_t)
        call characterize_b1_10_temporal_difference(full_physical, half_physical, delta)
      class default
        error stop 'B1.10 F-CI14 temporal policy: unexpected half state'
      end select
    class default
      error stop 'B1.10 F-CI14 temporal policy: unexpected full state'
    end select

    call evaluate_b1_10_reference_temporal(delta, self%temporal_limits, assessment)
    if (.not. assessment%complete) &
      error stop 'B1.10 F-CI14 temporal policy: comparison scope incomplete'
    value = assessment%normalized_error
  end function b1_10_candidate_temporal_error

  pure logical function b1_10_candidate_reference_execution_blocked(self) result(admitted)
    class(b1_10_reference_policy_candidate_model_t), intent(in) :: self
    ! The contract and executable candidate norm exist, but no numerical
    ! tolerance profile has yet been independently qualified against B1.10.
    admitted = self%qualified_numeric_profile .and. self%temporal_limits_bound
  end function b1_10_candidate_reference_execution_blocked

end module mod_b1_10_reference_policy_candidate_model
