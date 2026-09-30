module mod_fmr_mode7_temporal_head_envelope
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  real(real64), parameter, public :: FMR_MODE7_HEAD_ALPHA = 0.17320259355765216_real64

  integer, parameter, public :: FMR_MODE7_HEAD_ENVELOPE_OK = 0
  integer, parameter, public :: FMR_MODE7_HEAD_ENVELOPE_INVALID = 1

  type, public :: fmr_mode7_head_envelope_assessment_t
    integer :: status = FMR_MODE7_HEAD_ENVELOPE_INVALID
    logical :: complete = .false.
    logical :: accepted = .false.
    real(real64) :: estimated_head_error_cm = huge(0.0_real64)
    real(real64) :: normalized_error = huge(0.0_real64)
  end type fmr_mode7_head_envelope_assessment_t

  public :: assess_fmr_mode7_temporal_head_envelope

contains

  pure subroutine assess_fmr_mode7_temporal_head_envelope(head_inf_bound_cm, head_budget_cm, assessment)
    real(real64), intent(in) :: head_inf_bound_cm
    real(real64), intent(in) :: head_budget_cm
    type(fmr_mode7_head_envelope_assessment_t), intent(out) :: assessment

    assessment = fmr_mode7_head_envelope_assessment_t()

    if (.not. ieee_is_finite(head_inf_bound_cm) .or. head_inf_bound_cm < 0.0_real64) return
    if (.not. ieee_is_finite(head_budget_cm) .or. head_budget_cm < 0.0_real64) return

    assessment%estimated_head_error_cm = FMR_MODE7_HEAD_ALPHA * head_inf_bound_cm
    if (.not. ieee_is_finite(assessment%estimated_head_error_cm) .or. &
        assessment%estimated_head_error_cm < 0.0_real64) return

    if (head_budget_cm == 0.0_real64) then
      if (assessment%estimated_head_error_cm == 0.0_real64) then
        assessment%normalized_error = 0.0_real64
        assessment%accepted = .true.
      else
        assessment%normalized_error = huge(0.0_real64)
        assessment%accepted = .false.
      end if
    else
      assessment%normalized_error = assessment%estimated_head_error_cm / head_budget_cm
      if (.not. ieee_is_finite(assessment%normalized_error) .or. assessment%normalized_error < 0.0_real64) return
      assessment%accepted = assessment%normalized_error <= 1.0_real64
    end if

    assessment%status = FMR_MODE7_HEAD_ENVELOPE_OK
    assessment%complete = .true.
  end subroutine assess_fmr_mode7_temporal_head_envelope

end module mod_fmr_mode7_temporal_head_envelope
