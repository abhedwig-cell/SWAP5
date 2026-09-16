module mod_accepted_trajectory_transaction_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_result_t, TX_STATUS_ACCEPTED
  use mod_accepted_trajectory_directional_sensitivity, only: accepted_trajectory_direction_t
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t, &
       publish_accepted_trajectory_direction
  implicit none
  private

  public :: bind_accepted_trajectory_to_transaction

contains

  subroutine bind_accepted_trajectory_to_transaction(transaction_result, state, result)
    type(transaction_result_t), intent(in) :: transaction_result
    type(accepted_trajectory_direction_t), intent(in) :: state
    type(accepted_trajectory_direction_result_t), intent(out) :: result
    type(accepted_trajectory_direction_result_t) :: candidate
    real(real64) :: guard

    result = accepted_trajectory_direction_result_t()
    result%requested = state%requested

    ! Transaction acceptance is the sole publication authority. A trajectory
    ! may have been numerically composed during a rejected candidate, but that
    ! scratch is never a valid accepted result.
    if (transaction_result%status /= TX_STATUS_ACCEPTED) then
      result%route = 'transaction-not-accepted'
      return
    end if
    if (transaction_result%commits /= 1) then
      result%route = 'transaction-commit-count-invalid'
      return
    end if

    call publish_accepted_trajectory_direction(state, candidate)
    result = candidate
    if (.not. candidate%available) return

    guard = 64.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
         abs(transaction_result%requested_t0), abs(transaction_result%accepted_t1), &
         abs(candidate%origin_t0), abs(candidate%accepted_t1))

    if (abs(candidate%origin_t0-transaction_result%requested_t0) > guard .or. &
        abs(candidate%accepted_t1-transaction_result%accepted_t1) > guard) then
      result = accepted_trajectory_direction_result_t()
      result%requested = state%requested
      result%worker_id = state%worker_id
      result%generation = state%generation
      result%control_coordinate = state%control_coordinate
      result%origin_t0 = state%origin_t0
      result%accepted_t1 = state%current_t1
      result%method = 'unavailable'
      result%route = 'accepted-transaction-provenance-mismatch'
      return
    end if

    ! A transaction may legitimately accept a shortened retry interval. The
    ! result remains an accepted trajectory for [requested_t0,accepted_t1]; a
    ! later coupling owner must not call it a whole requested-window response
    ! unless accepted_t1 also equals requested_t1.
    if (transaction_result%accepted_t1 > transaction_result%requested_t1 + guard .or. &
        transaction_result%accepted_t1 <= transaction_result%requested_t0) then
      result = accepted_trajectory_direction_result_t()
      result%requested = state%requested
      result%worker_id = state%worker_id
      result%generation = state%generation
      result%control_coordinate = state%control_coordinate
      result%origin_t0 = state%origin_t0
      result%accepted_t1 = state%current_t1
      result%method = 'unavailable'
      result%route = 'accepted-transaction-interval-invalid'
      return
    end if
  end subroutine bind_accepted_trajectory_to_transaction

end module mod_accepted_trajectory_transaction_binding
