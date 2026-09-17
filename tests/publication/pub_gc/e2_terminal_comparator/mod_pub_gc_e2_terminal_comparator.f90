module mod_pub_gc_e2_terminal_comparator
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_trial_result_t, &
       groundwater_trial_from_checkpoint, groundwater_discard_candidate, GW_EXCHANGE_OK
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  implicit none
  private

  real(real64), parameter :: DAY_TO_S = 86400.0_real64
  integer, parameter, public :: PUB_GC_E2_OK = 0
  integer, parameter, public :: PUB_GC_E2_INVALID_INPUT = 1
  integer, parameter, public :: PUB_GC_E2_GROUNDWATER_REJECTED = 2

  type, public :: pub_gc_e2_comparison_t
    logical :: valid = .false.
    real(real64) :: q_whole_cm = 0.0_real64
    real(real64) :: q_terminal_flux_cm_per_day = 0.0_real64
    real(real64) :: duration_days = 0.0_real64
    real(real64) :: q_terminal_cm = 0.0_real64
    real(real64) :: interface_residual_whole_cm = 0.0_real64
    real(real64) :: interface_residual_terminal_cm = 0.0_real64
    real(real64) :: gw_head_whole_m = 0.0_real64
    real(real64) :: gw_head_terminal_m = 0.0_real64
    real(real64) :: gw_head_difference_m = 0.0_real64
    integer(int64) :: gw_origin_revision = -1_int64
  end type pub_gc_e2_comparison_t

  public :: pub_gc_e2_compare

contains

  subroutine pub_gc_e2_compare(gw, checkpoint, q_whole_cm, q_terminal_flux_cm_per_day, duration_days, result, status)
    type(pub_gc_gw_a_service_t), intent(inout) :: gw
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: q_whole_cm, q_terminal_flux_cm_per_day, duration_days
    type(pub_gc_e2_comparison_t), intent(out) :: result
    integer, intent(out) :: status
    type(groundwater_coupling_window_t) :: window
    real(real64) :: accepted_head_before, accepted_time_before
    integer(int64) :: revision_before
    logical :: origin_time_available

    result = pub_gc_e2_comparison_t()
    status = PUB_GC_E2_INVALID_INPUT

    if (.not. ieee_is_finite(q_whole_cm)) return
    if (.not. ieee_is_finite(q_terminal_flux_cm_per_day)) return
    if (.not. ieee_is_finite(duration_days) .or. duration_days <= 0.0_real64) return
    if (.not. gw%is_configured() .or. .not. checkpoint%ready()) return

    result%q_whole_cm = q_whole_cm
    result%q_terminal_flux_cm_per_day = q_terminal_flux_cm_per_day
    result%duration_days = duration_days
    result%q_terminal_cm = q_terminal_flux_cm_per_day * duration_days
    if (.not. ieee_is_finite(result%q_terminal_cm)) return

    result%interface_residual_whole_cm = q_whole_cm - q_whole_cm
    result%interface_residual_terminal_cm = q_whole_cm - result%q_terminal_cm
    result%gw_origin_revision = checkpoint%origin_revision()

    accepted_head_before = gw%accepted_head_m()
    accepted_time_before = gw%accepted_time_day()
    revision_before = gw%current_revision()

    call checkpoint%origin_time(window%t0, origin_time_available)
    if (.not. origin_time_available) return
    window%t1 = window%t0 + duration_days
    if (.not. window%valid()) return

    call evaluate_arm(gw, checkpoint, window, q_whole_cm, result%gw_head_whole_m, status)
    if (status /= PUB_GC_E2_OK) return
    call evaluate_arm(gw, checkpoint, window, result%q_terminal_cm, result%gw_head_terminal_m, status)
    if (status /= PUB_GC_E2_OK) return

    if (gw%current_revision() /= revision_before) then
      status = PUB_GC_E2_GROUNDWATER_REJECTED
      return
    end if
    if (transfer(gw%accepted_head_m(), 0_int64) /= transfer(accepted_head_before, 0_int64)) then
      status = PUB_GC_E2_GROUNDWATER_REJECTED
      return
    end if
    if (transfer(gw%accepted_time_day(), 0_int64) /= transfer(accepted_time_before, 0_int64)) then
      status = PUB_GC_E2_GROUNDWATER_REJECTED
      return
    end if

    result%gw_head_difference_m = result%gw_head_whole_m - result%gw_head_terminal_m
    result%valid = .true.
    status = PUB_GC_E2_OK
  end subroutine pub_gc_e2_compare

  subroutine evaluate_arm(gw, checkpoint, window, exchange_cm, head_m, status)
    type(pub_gc_gw_a_service_t), intent(inout) :: gw
    type(groundwater_exchange_checkpoint_t), intent(in) :: checkpoint
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: exchange_cm
    real(real64), intent(out) :: head_m
    integer, intent(out) :: status
    type(groundwater_exchange_candidate_t) :: candidate
    type(groundwater_exchange_trial_result_t) :: trial
    real(real64) :: q_groundwater_m_per_s
    integer :: gw_status

    head_m = 0.0_real64
    status = PUB_GC_E2_GROUNDWATER_REJECTED
    q_groundwater_m_per_s = -(exchange_cm * 0.01_real64) / ((window%t1-window%t0) * DAY_TO_S)
    if (.not. ieee_is_finite(q_groundwater_m_per_s)) return

    call groundwater_trial_from_checkpoint(gw, checkpoint, window, q_groundwater_m_per_s, candidate, trial, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. candidate%ready()) return
    head_m = trial%h_groundwater_m
    if (.not. ieee_is_finite(head_m)) then
      call groundwater_discard_candidate(gw, candidate, gw_status)
      return
    end if
    call groundwater_discard_candidate(gw, candidate, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. candidate%ready()) return
    status = PUB_GC_E2_OK
  end subroutine evaluate_arm

end module mod_pub_gc_e2_terminal_comparator
