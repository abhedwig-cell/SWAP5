module mod_crop_previous_day_emergence_gate
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  private
  integer, parameter, public :: CROP_EMERGENCE_OK=0, CROP_EMERGENCE_INVALID=1, &
       CROP_EMERGENCE_INACTIVE=2, CROP_EMERGENCE_ALREADY_ACTIVE=3, &
       CROP_EMERGENCE_NOT_READY=4, CROP_EMERGENCE_SAME_EVENT=5
  public :: evaluate_previous_day_crop_emergence
contains
  ! B1.11 MOD_cropdevelopment cropemergence ordering: only previously
  ! accepted flags may authorize emergence. This routine NEVER commits or
  ! initializes a physical crop/root owner; F-KT remains sole commit authority.
  pure subroutine evaluate_previous_day_crop_emergence(calendar_active,harvested, &
       already_emerged,prior_prepared,prior_sown,prior_germinated, &
       accepted_prior_revision,prior_event_revision,current_event_revision, &
       eligible,status)
    logical, intent(in) :: calendar_active,harvested,already_emerged
    logical, intent(in) :: prior_prepared,prior_sown,prior_germinated
    integer(int64), intent(in) :: accepted_prior_revision,prior_event_revision,current_event_revision
    logical, intent(out) :: eligible
    integer, intent(out) :: status
    eligible=.false.
    status=CROP_EMERGENCE_INVALID
    if(accepted_prior_revision<0_int64.or.prior_event_revision<0_int64.or. &
         current_event_revision<0_int64) return
    if(prior_event_revision/=accepted_prior_revision) return
    if(current_event_revision<=accepted_prior_revision) then
      status=CROP_EMERGENCE_SAME_EVENT
      return
    end if
    if(.not.calendar_active.or.harvested) then
      status=CROP_EMERGENCE_INACTIVE
      return
    end if
    if(already_emerged) then
      status=CROP_EMERGENCE_ALREADY_ACTIVE
      return
    end if
    if(.not.(prior_prepared.and.prior_sown.and.prior_germinated)) then
      status=CROP_EMERGENCE_NOT_READY
      return
    end if
    eligible=.true.
    status=CROP_EMERGENCE_OK
  end subroutine
end module
