module mod_pub_gc_gc_ref
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: GC_REF_OK = 0
  integer, parameter, public :: GC_REF_INVALID_INPUT = 1
  integer, parameter, public :: GC_REF_BRACKET_INVALID = 2
  integer, parameter, public :: GC_REF_EVALUATION_FAILED = 3
  integer, parameter, public :: GC_REF_OUTER_NOT_CONVERGED = 4

  type, public :: gc_ref_eval_t
    logical :: valid = .false.
    real(real64) :: h_m = 0.0_real64
    real(real64) :: residual_m = 0.0_real64
    real(real64) :: q_whole_cm = 0.0_real64
  end type gc_ref_eval_t

  type, public :: gc_ref_solution_t
    logical :: converged = .false.
    real(real64) :: h_star_m = 0.0_real64
    real(real64) :: residual_m = 0.0_real64
    real(real64) :: q_whole_cm = 0.0_real64
    real(real64) :: final_bracket_width_m = 0.0_real64
    real(real64) :: final_exchange_bracket_width_cm = 0.0_real64
    integer :: evaluations = 0
  end type gc_ref_solution_t

  type, public :: gc_ref_stability_t
    logical :: stable = .false.
    real(real64) :: delta_terminal_head_m = 0.0_real64
    real(real64) :: delta_cumulative_exchange_cm = 0.0_real64
    real(real64) :: delta_swap_state_norm = 0.0_real64
  end type gc_ref_stability_t

  abstract interface
    subroutine gc_ref_eval_proc(h_m, evaluation, status)
      import :: real64, gc_ref_eval_t
      real(real64), intent(in) :: h_m
      type(gc_ref_eval_t), intent(out) :: evaluation
      integer, intent(out) :: status
    end subroutine gc_ref_eval_proc
  end interface

  public :: gc_ref_bisect
  public :: gc_ref_adjudicate_three_level_stability

contains

  subroutine gc_ref_bisect(evaluate, h_lo_m, h_hi_m, tau_residual_m, tau_bracket_m, tau_q_cm, &
                           max_evaluations, solution, status)
    procedure(gc_ref_eval_proc) :: evaluate
    real(real64), intent(in) :: h_lo_m, h_hi_m
    real(real64), intent(in) :: tau_residual_m, tau_bracket_m, tau_q_cm
    integer, intent(in) :: max_evaluations
    type(gc_ref_solution_t), intent(out) :: solution
    integer, intent(out) :: status

    type(gc_ref_eval_t) :: e_lo, e_hi, e_mid
    real(real64) :: lo, hi, mid
    integer :: eval_status

    solution = gc_ref_solution_t()
    status = GC_REF_INVALID_INPUT

    if (.not. ieee_is_finite(h_lo_m) .or. .not. ieee_is_finite(h_hi_m)) return
    if (.not. ieee_is_finite(tau_residual_m) .or. tau_residual_m <= 0.0_real64) return
    if (.not. ieee_is_finite(tau_bracket_m) .or. tau_bracket_m <= 0.0_real64) return
    if (.not. ieee_is_finite(tau_q_cm) .or. tau_q_cm <= 0.0_real64) return
    if (h_hi_m <= h_lo_m .or. max_evaluations < 3) return

    lo = h_lo_m
    hi = h_hi_m
    call evaluate(lo, e_lo, eval_status)
    solution%evaluations = solution%evaluations + 1
    if (.not. evaluation_ok(e_lo, eval_status)) then
      status = GC_REF_EVALUATION_FAILED
      return
    end if
    if (e_lo%residual_m == 0.0_real64) then
      call accept_exact_endpoint(e_lo, solution)
      status = GC_REF_OK
      return
    end if

    call evaluate(hi, e_hi, eval_status)
    solution%evaluations = solution%evaluations + 1
    if (.not. evaluation_ok(e_hi, eval_status)) then
      status = GC_REF_EVALUATION_FAILED
      return
    end if
    if (e_hi%residual_m == 0.0_real64) then
      call accept_exact_endpoint(e_hi, solution)
      status = GC_REF_OK
      return
    end if

    if (same_sign(e_lo%residual_m, e_hi%residual_m)) then
      status = GC_REF_BRACKET_INVALID
      return
    end if

    do while (solution%evaluations < max_evaluations)
      mid = lo + 0.5_real64*(hi-lo)
      call evaluate(mid, e_mid, eval_status)
      solution%evaluations = solution%evaluations + 1
      if (.not. evaluation_ok(e_mid, eval_status)) then
        status = GC_REF_EVALUATION_FAILED
        return
      end if

      if (e_mid%residual_m == 0.0_real64) then
        e_lo = e_mid
        e_hi = e_mid
        lo = mid
        hi = mid
      else if (same_sign(e_lo%residual_m, e_mid%residual_m)) then
        lo = mid
        e_lo = e_mid
      else
        hi = mid
        e_hi = e_mid
      end if

      solution%h_star_m = e_mid%h_m
      solution%residual_m = e_mid%residual_m
      solution%q_whole_cm = e_mid%q_whole_cm
      solution%final_bracket_width_m = abs(hi-lo)
      solution%final_exchange_bracket_width_cm = abs(e_hi%q_whole_cm-e_lo%q_whole_cm)

      if (abs(e_mid%residual_m) <= tau_residual_m .and. &
          solution%final_bracket_width_m <= tau_bracket_m .and. &
          solution%final_exchange_bracket_width_cm <= tau_q_cm) then
        solution%converged = .true.
        status = GC_REF_OK
        return
      end if
    end do

    status = GC_REF_OUTER_NOT_CONVERGED
  end subroutine gc_ref_bisect

  subroutine gc_ref_adjudicate_three_level_stability(terminal_head_m, cumulative_exchange_cm, swap_state_norm, &
                                                       tau_head_m, tau_exchange_cm, tau_state, result, status)
    real(real64), intent(in) :: terminal_head_m(3), cumulative_exchange_cm(3), swap_state_norm(3)
    real(real64), intent(in) :: tau_head_m, tau_exchange_cm, tau_state
    type(gc_ref_stability_t), intent(out) :: result
    integer, intent(out) :: status

    result = gc_ref_stability_t()
    status = GC_REF_INVALID_INPUT
    if (any(.not. ieee_is_finite(terminal_head_m))) return
    if (any(.not. ieee_is_finite(cumulative_exchange_cm))) return
    if (any(.not. ieee_is_finite(swap_state_norm))) return
    if (.not. ieee_is_finite(tau_head_m) .or. tau_head_m <= 0.0_real64) return
    if (.not. ieee_is_finite(tau_exchange_cm) .or. tau_exchange_cm <= 0.0_real64) return
    if (.not. ieee_is_finite(tau_state) .or. tau_state <= 0.0_real64) return

    result%delta_terminal_head_m = abs(terminal_head_m(3)-terminal_head_m(2))
    result%delta_cumulative_exchange_cm = abs(cumulative_exchange_cm(3)-cumulative_exchange_cm(2))
    result%delta_swap_state_norm = abs(swap_state_norm(3)-swap_state_norm(2))
    result%stable = result%delta_terminal_head_m <= tau_head_m .and. &
                    result%delta_cumulative_exchange_cm <= tau_exchange_cm .and. &
                    result%delta_swap_state_norm <= tau_state
    status = GC_REF_OK
  end subroutine gc_ref_adjudicate_three_level_stability

  logical function evaluation_ok(evaluation, status) result(ok)
    type(gc_ref_eval_t), intent(in) :: evaluation
    integer, intent(in) :: status
    ok = status == GC_REF_OK .and. evaluation%valid .and. &
         ieee_is_finite(evaluation%h_m) .and. ieee_is_finite(evaluation%residual_m) .and. &
         ieee_is_finite(evaluation%q_whole_cm)
  end function evaluation_ok

  logical function same_sign(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = (a < 0.0_real64 .and. b < 0.0_real64) .or. &
            (a > 0.0_real64 .and. b > 0.0_real64)
  end function same_sign

  subroutine accept_exact_endpoint(evaluation, solution)
    type(gc_ref_eval_t), intent(in) :: evaluation
    type(gc_ref_solution_t), intent(inout) :: solution
    solution%converged = .true.
    solution%h_star_m = evaluation%h_m
    solution%residual_m = 0.0_real64
    solution%q_whole_cm = evaluation%q_whole_cm
    solution%final_bracket_width_m = 0.0_real64
    solution%final_exchange_bracket_width_cm = 0.0_real64
  end subroutine accept_exact_endpoint

end module mod_pub_gc_gc_ref
