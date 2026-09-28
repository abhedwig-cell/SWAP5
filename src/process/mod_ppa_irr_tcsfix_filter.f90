module mod_ppa_irr_tcsfix_filter
  implicit none
  private

  integer, parameter, public :: IRR_TCSFIX_OK = 0
  integer, parameter, public :: IRR_TCSFIX_INVALID_INPUT = 1

  public :: evaluate_tcsfix_filter

contains

  pure subroutine evaluate_tcsfix_filter(dayfix, interval_days, candidate_event, next_dayfix, event_allowed, status)
    integer, intent(in) :: dayfix, interval_days
    logical, intent(in) :: candidate_event
    integer, intent(out) :: next_dayfix, status
    logical, intent(out) :: event_allowed

    next_dayfix = dayfix
    event_allowed = .false.
    status = IRR_TCSFIX_INVALID_INPUT
    if (dayfix < 0 .or. dayfix > 366) return
    if (interval_days < 1 .or. interval_days > 366) return

    if (candidate_event .and. dayfix >= interval_days) then
      event_allowed = .true.
      next_dayfix = 1
    else
      if (next_dayfix < interval_days) next_dayfix = next_dayfix + 1
    end if
    status = IRR_TCSFIX_OK
  end subroutine evaluate_tcsfix_filter

end module mod_ppa_irr_tcsfix_filter
