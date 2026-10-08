module mod_crop_lifecycle_daily_composition
  use mod_crop_preparation_sowing_preflight, only: crop_preparation_sowing_candidate_t
  use mod_crop_germination_preflight, only: crop_germination_candidate_t
  implicit none
  private
  integer, parameter, public :: CROP_DAILY_OK=0, CROP_DAILY_INVALID=1
  type, public :: crop_daily_lifecycle_candidate_t
    logical :: valid=.false.
    logical :: prepared=.false.
    logical :: sown=.false.
    logical :: germinated=.false.
    logical :: emergence_eligible=.false.
    logical :: germination_evaluated=.false.
    integer :: preparation_delay=0
    integer :: sowing_delay=0
  end type
  public :: compose_crop_lifecycle_daily_candidate
contains
  ! Source ordering: a proposed germination step is never published as a
  ! physical event. It is eligible only after preparation and sowing.
  pure subroutine compose_crop_lifecycle_daily_candidate(prep_sow,germination,plan,status)
    type(crop_preparation_sowing_candidate_t), intent(in) :: prep_sow
    type(crop_germination_candidate_t), intent(in) :: germination
    type(crop_daily_lifecycle_candidate_t), intent(out) :: plan
    integer, intent(out) :: status
    plan=crop_daily_lifecycle_candidate_t()
    status=CROP_DAILY_INVALID
    if(.not.prep_sow%valid) return
    if(prep_sow%next_preparation_delay<0.or.prep_sow%next_sowing_delay<0) return
    plan%prepared=prep_sow%preparation_complete
    plan%sown=prep_sow%sowing_complete
    plan%preparation_delay=prep_sow%next_preparation_delay
    plan%sowing_delay=prep_sow%next_sowing_delay
    if(plan%prepared.and.plan%sown) then
      if(.not.germination%valid) return
      plan%germination_evaluated=.true.
      plan%germinated=germination%complete
      plan%emergence_eligible=germination%complete
    end if
    plan%valid=.true.
    status=CROP_DAILY_OK
  end subroutine compose_crop_lifecycle_daily_candidate
end module mod_crop_lifecycle_daily_composition
