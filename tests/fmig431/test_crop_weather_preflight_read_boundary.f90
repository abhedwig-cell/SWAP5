program test_crop_weather_preflight
 use iso_fortran_env,only:real64,int64
 use mod_transaction_reference,only:transaction_state_t
 use mod_kernel_transactions,only:kernel_committed_state_t,kernel_parameter_identity_t, &
      kernel_reconstruct_committed_state_trusted,KERNEL_TRUSTED_RECONSTRUCTION_OK
 use mod_fmr_serialized_reference_backend,only:fmr_b110_physical_state_t, &
      fmr_b110_physical_parameters_t,fmr_new_b110_committed_state
 use mod_soil_temperature_contract,only:initialize_soil_temperature_state,SOIL_TEMP_OK
 use mod_crop_weather_day_owner
 use mod_fmr_crop_certified_daily_preflight,only:crop_certified_daily_preflight_t
 use mod_fmr_crop_weather_day_preflight
 use mod_fmr_crop_weather_physical_event_composition
 use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_event_forcing_t
 use mod_fmr_wofost_accepted_window_lineage,only:fmr_wofost_accepted_window_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_crop_lifecycle_daily_composition,only:crop_daily_lifecycle_candidate_t, &
      compose_crop_lifecycle_daily_candidate,CROP_DAILY_OK,CROP_DAILY_INVALID
 implicit none
 type(kernel_committed_state_t)::committed,heat_off,restarted,next_committed
 type(fmr_b110_physical_state_t)::state
 type(fmr_b110_physical_parameters_t)::pars,cold_pars
 type(kernel_parameter_identity_t)::identity
 class(transaction_state_t),allocatable::snapshot
 type(weather_day_owner_t)::weather,replayed
 type(crop_certified_daily_preflight_t)::result
 type(crop_daily_lifecycle_candidate_t)::plan
 type(fmr_wofost_crop_event_forcing_t)::event
 type(fmr_wofost_accepted_window_t)::window
 type(wofost_one_day_forcing_t)::cropforcing
 integer::s
 logical::ok,available,reconstructed
 state%active_nodes=2
 state%pressure_head=[-100.0_real64,-1000.0_real64]
 state%water_content=[0.2_real64,0.3_real64]
 allocate(state%soil_temperature)
 call initialize_soil_temperature_state([8.0_real64,12.0_real64],state%soil_temperature,s)
 if(s/=SOIL_TEMP_OK) error stop 1
 pars%parameter_set_id=101_int64
 pars%active_nodes=2
 pars%z=[-5.0_real64,-20.0_real64]
 pars%dz=[10.0_real64,20.0_real64]
 pars%soil_temperature_active=.true.
 call fmr_new_b110_committed_state(committed,41_int64,state,3.0_real64,ok,parameters=pars)
 if(.not.ok) error stop 2
 call initialize_weather_day_owner(weather,7_int64,9_int64,s)
 if(s/=WEATHER_DAY_OK) error stop 3
 call ingest_weather_day(weather,7_int64,9_int64,3.0_real64,10.0_real64,14.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 4
 call propose(41_int64,0_int64,3.0_real64,7_int64,9_int64,1_int64,3.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 5
 if(abs(result%germination%next_temperature_sum-7.0_real64)>1.0e-12_real64) error stop 6
 call propose(41_int64,0_int64,3.0_real64,7_int64,9_int64,0_int64,3.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_WEATHER.or.result%valid) error stop 7
 call propose(41_int64,0_int64,3.0_real64,8_int64,9_int64,1_int64,3.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_WEATHER.or.result%valid) error stop 8
 call propose(41_int64,0_int64,3.0_real64,7_int64,9_int64,1_int64,4.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_WEATHER.or.result%valid) error stop 9
 call propose(41_int64,1_int64,3.0_real64,7_int64,9_int64,1_int64,3.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_SOIL.or.result%valid) error stop 10
 call propose(42_int64,0_int64,3.0_real64,7_int64,9_int64,1_int64,3.0_real64)
 if(s/=CROP_WEATHER_PREFLIGHT_SOIL.or.result%valid) error stop 11
 ! Cross-feature path: certified SWHEA=0 must be permitted when SWSOW=0,
 ! with daystart TAV sourced exclusively from the weather register.
 deallocate(state%soil_temperature)
 cold_pars=pars
 cold_pars%soil_temperature_active=.false.
 call fmr_new_b110_committed_state(heat_off,52_int64,state,3.0_real64,ok,parameters=cold_pars)
 if(.not.ok) error stop 12
 call propose_weather_day_crop_preflight(heat_off,52_int64,0_int64,3.0_real64, &
      weather,7_int64,9_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 13
 if(result%soil_temperature/=0.0_real64.or.result%nodsow/=0) error stop 14
 if(abs(result%germination%next_temperature_sum-7.0_real64)>1.0e-12_real64) error stop 15
 ! Identical weather retry must be idempotent and cannot change the
 ! already accepted day or its revision.
 call ingest_weather_day(weather,7_int64,9_int64,3.0_real64,10.0_real64,14.0_real64,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 16
 call ingest_weather_day(weather,7_int64,9_int64,3.0_real64,11.0_real64,14.0_real64,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 17
 ! Trusted F-KT reconstruction and local weather-record restoration.
 call heat_off%certified_parameter_identity(identity,available)
 if(.not.available) error stop 18
 call heat_off%snapshot(snapshot,available)
 if(.not.available) error stop 19
 call kernel_reconstruct_committed_state_trusted(restarted,52_int64,0_int64,snapshot,3.0_real64, &
      .true.,reconstructed,s,parameters=cold_pars,persisted_identity=identity)
 if(.not.reconstructed.or.s/=KERNEL_TRUSTED_RECONSTRUCTION_OK) error stop 20
 call reconstruct_weather_day_owner(replayed,7_int64,9_int64,1_int64,3.0_real64, &
      10.0_real64,14.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 21
 call propose_weather_day_crop_preflight(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 22
 if(abs(result%germination%next_temperature_sum-7.0_real64)>1.0e-12_real64) error stop 23
 call propose_weather_day_crop_preflight(restarted,52_int64,1_int64,3.0_real64, &
      replayed,7_int64,9_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_SOIL.or.result%valid) error stop 24
 ! Compose historical preparation -> sowing -> germination ordering from
 ! the combined WEATHER+CERTIFIED F-KT preflight, never as a physical event.
 call propose_weather_day_crop_preflight(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 25
 call compose_crop_lifecycle_daily_candidate(result%preparation,result%germination,plan,s)
 if(s/=CROP_DAILY_OK.or..not.plan%valid) error stop 26
 if(.not.plan%prepared.or..not.plan%sown.or..not.plan%germination_evaluated) error stop 27
 if(plan%germinated.or.plan%emergence_eligible) error stop 28
 if(plan%preparation_delay/=0.or.plan%sowing_delay/=0) error stop 29
 ! A moisture-limited preparation must suppress all germination evaluation,
 ! even when a valid meteorological day is present.
 call propose_weather_day_crop_preflight(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,1_int64,3.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-200.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 30
 call compose_crop_lifecycle_daily_candidate(result%preparation,result%germination,plan,s)
 if(s/=CROP_DAILY_OK.or..not.plan%valid) error stop 31
 if(plan%prepared.or.plan%sown.or.plan%germination_evaluated.or. &
    plan%germinated.or.plan%emergence_eligible) error stop 32
 if(plan%preparation_delay/=1) error stop 33
 ! Reject a missing germination candidate once preparation and sowing hold.
 result%germination%valid=.false.
 result%preparation%preparation_complete=.true.
 result%preparation%sowing_complete=.true.
 call compose_crop_lifecycle_daily_candidate(result%preparation,result%germination,plan,s)
 if(s/=CROP_DAILY_INVALID.or.plan%valid) error stop 34
 ! The downstream F-WOF38 boundary cannot make a physical event from
 ! a correct daystart proposal without a real accepted crop window.
 call propose_weather_crop_physical_event(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,1_int64,3.0_real64,window,cropforcing,0_int64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,event,s)
 if(s/=CROP_EVENT_COMPOSE_PHYSICAL.or.event%ready()) error stop 35
 call propose_weather_crop_physical_event(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,0_int64,3.0_real64,window,cropforcing,0_int64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,event,s)
 if(s/=CROP_EVENT_COMPOSE_WEATHER.or.event%ready()) error stop 36
 ! Multi-day daystart chronology: the next meteorological record and the
 ! previously certified soil at the next start must agree. No same-day
 ! prospective hydraulic acceptance may substitute for committed soil.
 call ingest_weather_day(replayed,7_int64,9_int64,4.0_real64,12.0_real64,16.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 37
 call fmr_new_b110_committed_state(next_committed,52_int64,state,4.0_real64,ok,parameters=cold_pars)
 if(.not.ok) error stop 38
 call propose_weather_day_crop_preflight(next_committed,52_int64,0_int64,4.0_real64, &
      replayed,7_int64,9_int64,2_int64,4.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 39
 if(abs(result%germination%next_temperature_sum-9.0_real64)>1.0e-12_real64) error stop 40
 ! A previously accepted soil state cannot be used as tomorrow's daystart.
 call propose_weather_day_crop_preflight(restarted,52_int64,0_int64,3.0_real64, &
      replayed,7_int64,9_int64,2_int64,4.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_WEATHER.or.result%valid) error stop 41
 ! Once the weather owner advances, a stale meteorological revision must fail.
 call propose_weather_day_crop_preflight(next_committed,52_int64,0_int64,4.0_real64, &
      replayed,7_int64,9_int64,1_int64,4.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_WEATHER.or.result%valid) error stop 42
 call ingest_weather_day(replayed,7_int64,9_int64,4.0_real64,13.0_real64,15.0_real64,s)
 if(s/=WEATHER_DAY_CONFLICT) error stop 43
 ! Restart from the second accepted meteorological record: replay is
 ! idempotent and the next crop preflight must produce the identical sum.
 call reconstruct_weather_day_owner(weather,7_int64,9_int64,2_int64,4.0_real64, &
      12.0_real64,16.0_real64,s)
 if(s/=WEATHER_DAY_OK) error stop 44
 call ingest_weather_day(weather,7_int64,9_int64,4.0_real64,12.0_real64,16.0_real64,s)
 if(s/=WEATHER_DAY_DUPLICATE) error stop 45
 call propose_weather_day_crop_preflight(next_committed,52_int64,0_int64,4.0_real64, &
      weather,7_int64,9_int64,2_int64,4.0_real64, &
      -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
      1,0,-50.0_real64,-200.0_real64,10.0_real64, &
      0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
      -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 if(s/=CROP_WEATHER_PREFLIGHT_OK.or..not.result%valid) error stop 46
 if(abs(result%germination%next_temperature_sum-9.0_real64)>1.0e-12_real64) error stop 47
 print '(a)','CROP_WEATHER_TWO_DAY_DAYSTART_RESTART=PASS'
 print '(a)','CROP_WEATHER_PREFLIGHT_READ_BOUNDARY=PASS'
contains
 subroutine propose(lineage,revision,time,source,epoch,wrev,day)
 integer(int64),intent(in)::lineage,revision,source,epoch,wrev
 real(real64),intent(in)::time,day
 call propose_weather_day_crop_preflight(committed,lineage,revision,time, &
   weather,source,epoch,wrev,day,-10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64, &
   1,1,-50.0_real64,-200.0_real64,10.0_real64, &
   0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64,30.0_real64, &
   -1000.0_real64,-10.0_real64,20.0_real64,result,s)
 end subroutine
end program
