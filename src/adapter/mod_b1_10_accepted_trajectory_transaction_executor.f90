module mod_b1_10_accepted_trajectory_transaction_executor
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_accepted_trajectory_transaction_binding, only: bind_accepted_trajectory_to_transaction
  use mod_b1_10_reference_model, only: b1_10_reference_model_t
  implicit none
  private

  public :: execute_b1_10_reference_interval_with_trajectory

contains

  subroutine execute_b1_10_reference_interval_with_trajectory(model, committed, t0, t1, policy, &
                                                               control_coordinate, transaction_result, trajectory_result)
    class(b1_10_reference_model_t), intent(inout) :: model
    class(transaction_state_t), allocatable, intent(inout) :: committed
    real(real64), intent(in) :: t0, t1
    type(transaction_policy_t), intent(in) :: policy
    integer, intent(in) :: control_coordinate
    type(transaction_result_t), intent(out) :: transaction_result
    type(accepted_trajectory_direction_result_t), intent(out) :: trajectory_result

    if (.not. associated(model%worker)) &
      error stop 'F-KT21 B1.10 executor: worker not bound'

    ! Configure before execute_reference_interval captures its checkpoint
    ! context. This makes every full/half/retry candidate start from the same
    ! trajectory origin while the model-local generation counter remains
    ! monotone across rejected attempts.
    call model%configure_trajectory_direction(.true., control_coordinate)
    call execute_reference_interval(model, committed, t0, t1, policy, transaction_result)

    ! Atomic publication: the exact worker scratch left by the transaction
    ! core's accepted context is bound to that same transaction result. A
    ! rejected transaction cannot publish a trajectory response.
    call bind_accepted_trajectory_to_transaction(transaction_result, model%worker%trajectory_direction, &
         trajectory_result)

    ! Numerical trajectory scratch is worker/job-local and never persistent
    ! committed state. Clear it only after the immutable result is copied.
    call model%configure_trajectory_direction(.false., control_coordinate)
  end subroutine execute_b1_10_reference_interval_with_trajectory

end module mod_b1_10_accepted_trajectory_transaction_executor
