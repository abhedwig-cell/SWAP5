module mod_fmr_crop_weather_physical_event_composition
  use iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_crop_weather_day_owner, only: weather_day_owner_t
  use mod_fmr_crop_weather_day_preflight, only: &
       propose_weather_day_crop_preflight,CROP_WEATHER_PREFLIGHT_OK
  use mod_fmr_crop_certified_daily_preflight, only: crop_certified_daily_preflight_t
  use mod_crop_lifecycle_daily_composition, only: &
       crop_daily_lifecycle_candidate_t,compose_crop_lifecycle_daily_candidate,CROP_DAILY_OK
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, &
       prepare_wofost_crop_event_delivery,identify_wofost_crop_event, &
       export_wofost_crop_event_identity_persistence,FMR_WOFOST_LINEAGE_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t
  use mod_fmr_wofost_crop_transaction, only: &
       fmr_wofost_crop_event_forcing_t,prepare_fmr_wofost_crop_event_forcing,FMR_WOF38_OK
  implicit none
  private
  integer,parameter,public :: CROP_EVENT_COMPOSE_OK=0,CROP_EVENT_COMPOSE_WEATHER=1, &
       CROP_EVENT_COMPOSE_ORDER=2,CROP_EVENT_COMPOSE_PHYSICAL=3
  public :: propose_weather_crop_physical_event
contains
  ! Staging-only composition. The weather record is caller-initializable and
  ! therefore not an authenticated producer receipt. The incoming accepted
  ! window is verified only by its existing physical event owner.
  ! Never directly mutate committed F-KT, crop state, or the weather register.
  subroutine propose_weather_crop_physical_event(committed,lineage,revision,time, &
       weather,source,epoch,weather_revision,day,window,crop_forcing, &
       lifecycle_revision,zprep,zsow,ztempsow,zgerm,swprep,swsow, &
       hprep_threshold,hsow_threshold,sow_temperature, &
       prep_delay,sow_delay,max_prep_delay,max_sow_delay, &
       germ_mode,temperature_sum,optimal_sum,base_temperature, &
       max_effective_temperature,dry_head,wet_head,water_response_a,forcing,status)
    type(kernel_committed_state_t),intent(in)::committed
    integer(int64),intent(in)::lineage,revision,source,epoch,weather_revision,lifecycle_revision
    real(real64),intent(in)::time,day,zprep,zsow,ztempsow,zgerm
    type(weather_day_owner_t),intent(in)::weather
    type(fmr_wofost_accepted_window_t),intent(in)::window
    type(wofost_one_day_forcing_t),intent(in)::crop_forcing
    integer,intent(in)::swprep,swsow,prep_delay,sow_delay,max_prep_delay,max_sow_delay,germ_mode
    real(real64),intent(in)::hprep_threshold,hsow_threshold,sow_temperature, &
         temperature_sum,optimal_sum,base_temperature,max_effective_temperature, &
         dry_head,wet_head,water_response_a
    type(fmr_wofost_crop_event_forcing_t),intent(out)::forcing
    integer,intent(out)::status
    type(crop_certified_daily_preflight_t)::daily
    type(crop_daily_lifecycle_candidate_t)::plan
    integer::s
    logical::available
    type(fmr_wofost_crop_event_token_t)::event_token
    type(fmr_wofost_crop_event_identity_t)::event_identity
    type(fmr_wofost_crop_event_identity_persistence_t)::event_view
    type(wofost_accepted_window_aggregates_t)::aggregates
    status=CROP_EVENT_COMPOSE_WEATHER
    ! Reject at the earliest boundary; all output remains uninitialized.
    call propose_weather_day_crop_preflight(committed,lineage,revision,time, &
         weather,source,epoch,weather_revision,day, &
         zprep,zsow,ztempsow,zgerm,swprep,swsow, &
         hprep_threshold,hsow_threshold,sow_temperature, &
         prep_delay,sow_delay,max_prep_delay,max_sow_delay, &
         germ_mode,temperature_sum,optimal_sum,base_temperature, &
         max_effective_temperature,dry_head,wet_head,water_response_a,daily,s)
    if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.daily%valid) return
    status=CROP_EVENT_COMPOSE_ORDER
    call compose_crop_lifecycle_daily_candidate(daily%preparation,daily%germination,plan,s)
    if(s/=CROP_DAILY_OK.or..not.plan%valid) return
    status=CROP_EVENT_COMPOSE_PHYSICAL
    ! A valid but foreign accepted crop window is not an event for this
    ! certified committed soil daystart. The opaque event owner derives the
    ! receipt, not a caller-constructed tuple.
    call prepare_wofost_crop_event_delivery(window,aggregates,event_token,available,s)
    if(s/=FMR_WOFOST_LINEAGE_OK.or..not.available) return
    call identify_wofost_crop_event(event_token,event_identity,s)
    if(s/=FMR_WOFOST_LINEAGE_OK.or..not.event_identity%ready()) return
    call export_wofost_crop_event_identity_persistence(event_identity,event_view,available)
    if(.not.available.or..not.event_view%ready()) return
    if(event_view%lineage_id/=lineage.or.event_view%final_revision/=revision) return
    if(transfer(event_view%t1,0_int64)/=transfer(day,0_int64)) return
    call prepare_fmr_wofost_crop_event_forcing(window,crop_forcing,forcing,s, &
         lifecycle_plan=plan,lifecycle_germination=daily%germination, &
         lifecycle_expected_revision=lifecycle_revision)
    if(s/=FMR_WOF38_OK.or..not.forcing%ready()) return
    status=CROP_EVENT_COMPOSE_OK
  end subroutine
end module
