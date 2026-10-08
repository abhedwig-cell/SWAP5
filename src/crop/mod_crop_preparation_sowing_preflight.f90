module mod_crop_preparation_sowing_preflight
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_PREP_SOW_OK=0, CROP_PREP_SOW_INVALID=1
  type, public :: crop_preparation_sowing_candidate_t
    logical :: valid=.false.
    logical :: preparation_complete=.false.
    logical :: sowing_complete=.false.
    logical :: blocked_preparation=.false.
    logical :: blocked_sowing=.false.
    integer :: next_preparation_delay=0
    integer :: next_sowing_delay=0
  end type
  public :: propose_preparation_sowing
contains
  ! Read-only daily proposal from explicit B1.11 sampled forcing and accepted delay counts.
  pure subroutine propose_preparation_sowing(swprep,swsow,heat_enabled, &
       hprep_avg,hprep_threshold,hsow_avg,hsow_threshold,soil_temperature,sow_temperature, &
       prep_delay,sow_delay,max_prep_delay,max_sow_delay,candidate,status)
    integer, intent(in) :: swprep,swsow,prep_delay,sow_delay,max_prep_delay,max_sow_delay
    logical, intent(in) :: heat_enabled
    real(real64), intent(in) :: hprep_avg,hprep_threshold,hsow_avg,hsow_threshold, &
         soil_temperature,sow_temperature
    type(crop_preparation_sowing_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status
    candidate=crop_preparation_sowing_candidate_t()
    status=CROP_PREP_SOW_INVALID
    if(swprep<0.or.swprep>1.or.swsow<0.or.swsow>1) return
    if(prep_delay<0.or.sow_delay<0.or.max_prep_delay<1.or.max_sow_delay<1) return
    if(swprep==1) then
      if(.not.ieee_is_finite(hprep_avg).or..not.ieee_is_finite(hprep_threshold)) return
    end if
    if(swsow==1) then
      if(.not.heat_enabled) return
      if(.not.ieee_is_finite(hsow_avg).or..not.ieee_is_finite(hsow_threshold)) return
      if(.not.ieee_is_finite(soil_temperature).or..not.ieee_is_finite(sow_temperature)) return
    end if
    candidate%preparation_complete=.true.
    candidate%next_preparation_delay=prep_delay
    if(swprep==1.and.hprep_avg>hprep_threshold.and.prep_delay<max_prep_delay) then
      candidate%preparation_complete=.false.
      candidate%blocked_preparation=.true.
      candidate%next_preparation_delay=prep_delay+1
    end if
    candidate%next_sowing_delay=sow_delay
    candidate%sowing_complete=.true.
    if(.not.candidate%preparation_complete) then
      candidate%sowing_complete=.false.
    else
      if(swprep==1) candidate%next_sowing_delay=candidate%next_preparation_delay
      if(swsow==1) then
        if((soil_temperature<sow_temperature.or.hsow_avg>hsow_threshold).and. &
             candidate%next_sowing_delay<max_sow_delay) then
          candidate%sowing_complete=.false.
          candidate%blocked_sowing=.true.
          candidate%next_sowing_delay=candidate%next_sowing_delay+1
        end if
      end if
    end if
    candidate%valid=.true.
    status=CROP_PREP_SOW_OK
  end subroutine
end module mod_crop_preparation_sowing_preflight
