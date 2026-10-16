module mod_fmr_crop_weather_day_preflight
  use iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_weather_day_owner, only: weather_day_owner_t, WEATHER_DAY_OK
  use mod_fmr_crop_certified_daily_preflight, only: &
       crop_certified_daily_preflight_t, propose_certified_crop_daily_preflight, CROP_CERT_DAILY_OK
  implicit none
  private
  integer,parameter,public :: CROP_WEATHER_PREFLIGHT_OK=0, &
       CROP_WEATHER_PREFLIGHT_WEATHER=1,CROP_WEATHER_PREFLIGHT_SOIL=2
  public :: propose_weather_day_crop_preflight
contains
  ! No caller-supplied TAV. This bridge is READ-ONLY and STAGING-ONLY.
  ! A weather_day_owner_t can still be initialized by a caller; its record
  ! does not establish an authenticated external meteorological producer.
  ! This is not physical crop event publication authority.
  subroutine propose_weather_day_crop_preflight(committed,lineage,revision,time, &
       weather,source,epoch,weather_revision,day, &
       zprep,zsow,ztempsow,zgerm,swprep,swsow, &
       hprep_threshold,hsow_threshold,sow_temperature, &
       prep_delay,sow_delay,max_prep_delay,max_sow_delay, &
       germ_mode,temperature_sum,optimal_sum,base_temperature, &
       max_effective_temperature,dry_head,wet_head,water_response_a, &
       candidate,status)
    type(kernel_committed_state_t),intent(in)::committed
    integer(int64),intent(in)::lineage,revision,source,epoch,weather_revision
    type(weather_day_owner_t),intent(in)::weather
    real(real64),intent(in)::time,day,zprep,zsow,ztempsow,zgerm
    integer,intent(in)::swprep,swsow,prep_delay,sow_delay,max_prep_delay,max_sow_delay,germ_mode
    real(real64),intent(in)::hprep_threshold,hsow_threshold,sow_temperature, &
         temperature_sum,optimal_sum,base_temperature,max_effective_temperature, &
         dry_head,wet_head,water_response_a
    type(crop_certified_daily_preflight_t),intent(out)::candidate
    integer,intent(out)::status
    integer::weather_status,soil_status
    real(real64)::tav
    candidate=crop_certified_daily_preflight_t()
    status=CROP_WEATHER_PREFLIGHT_WEATHER
    ! Historical crop processing is day-start. Demand exact day-start time;
    ! do not infer validity from the accepted end of this same day.
    if(time/=day) return
    call weather%read_day(source,epoch,weather_revision,day,tav,weather_status)
    if(weather_status/=WEATHER_DAY_OK) return
    status=CROP_WEATHER_PREFLIGHT_SOIL
    call propose_certified_crop_daily_preflight(committed,lineage,revision,time, &
         zprep,zsow,ztempsow,zgerm,swprep,swsow, &
         hprep_threshold,hsow_threshold,sow_temperature, &
         prep_delay,sow_delay,max_prep_delay,max_sow_delay, &
         germ_mode,temperature_sum,optimal_sum,base_temperature, &
         max_effective_temperature,tav,dry_head,wet_head,water_response_a, &
         candidate,soil_status)
    if(soil_status/=CROP_CERT_DAILY_OK.or..not.candidate%valid) then
      candidate=crop_certified_daily_preflight_t()
      return
    end if
    status=CROP_WEATHER_PREFLIGHT_OK
  end subroutine
end module
