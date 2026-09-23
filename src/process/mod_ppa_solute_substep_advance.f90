module mod_ppa_solute_substep_advance
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_SUBSTEP_OK=0
  integer, parameter, public :: PPA_SOLUTE_SUBSTEP_INVALID_INPUT=1
  integer, parameter, public :: PPA_SOLUTE_SUBSTEP_NO_PROGRESS=2
  public :: ppa_solute_substep_advance
contains
  pure subroutine ppa_solute_substep_advance(interval_days,minimum_step,candidate_step,elapsed_days, &
       solute_step,next_elapsed_days,continue_interval,status)
    real(real64),intent(in)::interval_days,minimum_step,candidate_step,elapsed_days
    real(real64),intent(out)::solute_step,next_elapsed_days
    logical,intent(out)::continue_interval
    integer,intent(out)::status

    solute_step=0.0_real64
    next_elapsed_days=elapsed_days
    continue_interval=.false.
    status=PPA_SOLUTE_SUBSTEP_INVALID_INPUT
    if(.not.all(ieee_is_finite([interval_days,minimum_step,candidate_step,elapsed_days])))return
    if(interval_days<=0.0_real64.or.minimum_step<=0.0_real64.or.candidate_step<=0.0_real64.or. &
         elapsed_days<0.0_real64.or.elapsed_days>=interval_days)return

    ! Source: B1.11 solute.f90 task 2 subcycling loop. Keep MIN then MAX order:
    ! dtmin may intentionally take the final step slightly beyond the interval.
    solute_step=min(candidate_step,(interval_days-elapsed_days))
    solute_step=max(solute_step,minimum_step)
    if(solute_step>huge(1.0_real64)-elapsed_days)then
      solute_step=0.0_real64
      return
    end if
    next_elapsed_days=elapsed_days+solute_step
    if(.not.ieee_is_finite(next_elapsed_days))then
      solute_step=0.0_real64
      next_elapsed_days=elapsed_days
      return
    end if
    if(next_elapsed_days<=elapsed_days)then
      solute_step=0.0_real64
      next_elapsed_days=elapsed_days
      status=PPA_SOLUTE_SUBSTEP_NO_PROGRESS
      return
    end if
    continue_interval=(interval_days-next_elapsed_days)>1.0e-15_real64
    status=PPA_SOLUTE_SUBSTEP_OK
  end subroutine ppa_solute_substep_advance
end module mod_ppa_solute_substep_advance
