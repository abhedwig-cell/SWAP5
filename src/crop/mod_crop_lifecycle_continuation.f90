module mod_crop_lifecycle_continuation
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_lifecycle_daily_composition, only: crop_daily_lifecycle_candidate_t
  use mod_crop_germination_preflight, only: crop_germination_candidate_t
  implicit none
  private
  integer, parameter, public :: CROP_CONT_OK=0, CROP_CONT_INVALID=1, CROP_CONT_STALE=2, &
       CROP_CONT_DUPLICATE=3, CROP_CONT_ORDER=4
  type, public :: crop_lifecycle_continuation_t
    logical :: valid=.false.
    integer(int64) :: revision=0_int64
    integer(int64) :: crop_identity=0_int64
    integer(int64) :: last_event_identity=0_int64
    logical :: prepared=.false., sown=.false., germinated=.false., emerged=.false., harvested=.false.
    integer :: preparation_delay=0, sowing_delay=0
    real(real64) :: germination_temperature_sum=0.0_real64
  contains
    procedure :: ready => continuation_ready
  end type
  public :: propose_crop_lifecycle_continuation
contains
  pure logical function continuation_ready(self) result(ok)
    class(crop_lifecycle_continuation_t), intent(in) :: self
    ok=.false.
    if(.not.self%valid.or.self%revision<0_int64.or.self%crop_identity<=0_int64) return
    if(self%last_event_identity<0_int64.or.self%preparation_delay<0.or.self%sowing_delay<0) return
    if(.not.ieee_is_finite(self%germination_temperature_sum)) return
    if(self%germination_temperature_sum<0.0_real64) return
    if(self%sown.and..not.self%prepared) return
    if(self%germinated.and..not.self%sown) return
    if(self%emerged.and..not.self%germinated) return
    ok=.true.
  end function

  ! A candidate value, never a physical publication. F-KT must match the
  ! accepted receipt and publish transactionally after physical acceptance.
  pure subroutine propose_crop_lifecycle_continuation(current,plan,germination, &
       expected_revision,event_identity,candidate,status)
    type(crop_lifecycle_continuation_t), intent(in) :: current
    type(crop_daily_lifecycle_candidate_t), intent(in) :: plan
    type(crop_germination_candidate_t), intent(in) :: germination
    integer(int64), intent(in) :: expected_revision,event_identity
    type(crop_lifecycle_continuation_t), intent(out) :: candidate
    integer, intent(out) :: status
    candidate=current
    status=CROP_CONT_INVALID
    if(.not.current%ready()) return
    if(expected_revision/=current%revision) then
      status=CROP_CONT_STALE
      return
    end if
    if(event_identity<=0_int64) return
    if(event_identity==current%last_event_identity) then
      status=CROP_CONT_DUPLICATE
      return
    end if
    if(current%harvested.or.current%emerged) then
      status=CROP_CONT_ORDER
      return
    end if
    if(.not.plan%valid) return
    if(plan%preparation_delay<current%preparation_delay.or. &
         plan%sowing_delay<current%sowing_delay) return
    if(plan%sown.and..not.plan%prepared) return
    if(plan%germinated.and..not.plan%sown) return
    if(plan%emergence_eligible.neqv.plan%germinated) return
    if(current%prepared.and..not.plan%prepared) return
    if(current%sown.and..not.plan%sown) return
    if(current%germinated.and..not.plan%germinated) return
    if(plan%germination_evaluated) then
      if(.not.(plan%prepared.and.plan%sown)) return
      if(.not.germination%valid) return
      if(plan%germinated.neqv.germination%complete) return
      if(.not.ieee_is_finite(germination%next_temperature_sum)) return
      if(germination%next_temperature_sum<current%germination_temperature_sum) return
    else
      if(plan%germinated.or.plan%emergence_eligible) return
    end if
    if(current%revision==huge(current%revision)) return
    candidate%prepared=plan%prepared
    candidate%sown=plan%sown
    candidate%germinated=plan%germinated
    candidate%preparation_delay=plan%preparation_delay
    candidate%sowing_delay=plan%sowing_delay
    if(plan%germination_evaluated) &
         candidate%germination_temperature_sum=germination%next_temperature_sum
    ! Emergence is not published by a preflight plan.
    candidate%last_event_identity=event_identity
    candidate%revision=current%revision+1_int64
    if(.not.candidate%ready()) then
      candidate=current
      return
    end if
    status=CROP_CONT_OK
  end subroutine
end module
