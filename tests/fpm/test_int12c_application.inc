  subroutine verify_int12c_application()
    use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
         fmr_production_application_bootstrap_t,FMR_APP_BOOT_OK,FMR_APP_BOOT_INTERCEPTION_REJECTED
    use mod_fmr_interception_source_window_binding
    use mod_pmdirect_swetr0_process
    type(fmr_production_application_config_t) :: cfg
    type(fmr_production_application_bootstrap_t) :: app
    type(fmr_interception_source_window_t) :: owners(1), wrong(1), stale(1), restored
    type(fmr_interception_source_window_restart_t) :: restart
    type(fmr_b110_physical_forcing_t) :: forcing(1)
    type(fmr_serialized_column_result_t),allocatable :: results(:)
    type(kernel_committed_state_t) :: snapshot
    type(pmdirect_swetr0_weather_t) :: weather
    type(pmdirect_swetr0_site_t) :: site
    type(pmdirect_swetr0_canopy_t) :: canopy
    type(pmdirect_swetr0_daily_result_t) :: daily
    type(pmdirect_swetr0_interval_result_t) :: interval
    type(pmdirect_swetr0_diagnostics_t) :: pd
    real(real64),allocatable :: amounts(:)
    real(real64) :: endpoints(4), t0, amount, time, source, canopy_sum, soil_sum
    integer :: status, i
    integer(int64) :: revision
    logical :: complete
    weather=pmdirect_swetr0_weather_t(161,1.2450e7_real64,11.0_real64,18.1_real64, &
         1.315514_real64,4.92_real64,0.47_real64)
    site%latitude_degrees=52.0_real64;site%altitude_m=10.0_real64
    site%wind_measurement_height_m=10.0_real64;site%humidity_measurement_height_m=1.5_real64
    site%angstrom_a=0.25_real64;site%angstrom_b=0.5_real64;site%wind_function_factor=1.0_real64
    site%soil_surface_resistance_s_m=600.0_real64
    canopy=pmdirect_swetr0_canopy_t(.true.,3.12683333333333335_real64, &
         0.755141552325116483_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
    call evaluate_pmdirect_swetr0_daily(weather,site,canopy,daily,pd)
    call require(pd%daily_result_produced,'application admitted daily source')
    call apply_swinter1_daily_interval(weather,canopy,daily,interval,pd)
    call require(pd%interval_result_produced,'application SWINTER1 interval')
    endpoints=[0.002_real64,0.004_real64,0.007_real64,0.01_real64]
    source=interval%interception_rate_cm_per_day*endpoints(4)
    allocate(cfg%tiles(1))
    cfg%initial_time=0.0_real64
    cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%numerical%transaction%temporal_tolerance=0.0_real64
    cfg%numerical%transaction%mass_tolerance=hard_mass_gate
    cfg%numerical%transaction%max_retries=24
    cfg%numerical%transaction%retry_scale=0.5_real64
    cfg%numerical%max_committed_substeps=4096
    cfg%numerical%model_temporal_indicator_budget_available=.true.
    cfg%numerical%model_temporal_indicator_budget=1.0e-6_real64
    cfg%tiles(1)%tile_id=column_id
    cfg%tiles(1)%template%template_id=440001_int64
    cfg%tiles(1)%template%physics_topology_id=440002_int64
    cfg%tiles(1)%template%vertical_layout_id=440003_int64
    cfg%tiles(1)%template%state_layout_id=440004_int64
    cfg%tiles(1)%template%solver_interface_id=440005_int64
    cfg%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    call initialize_parameters(cfg%tiles(1)%parameters,2)
    cfg%tiles(1)%parameters%min_step_duration=1.0e-12_real64
    call initialize_physical_state(cfg%tiles(1)%parameters,.true.,cfg%tiles(1)%initial_state)
    allocate(cfg%tiles(1)%initial_right_derivative(numnod))
    cfg%tiles(1)%initial_right_derivative=0.0_real64
    call initialize_forcing(forcing(1),-interval%net_rain_cm_per_day,0.0_real64,-999.0_real64)
    cfg%tiles(1)%base_forcing=forcing(1)
    call app%initialize(cfg,status)
    call require(status==FMR_APP_BOOT_OK,'real application initialized')
    call initialize_fmr_interception_source_window(column_id,10091009_int64,0.0_real64, &
         endpoints(4),source,owners(1),status)
    call require(status==FMR_INTWIN_OK,'application companion initialized')
    call initialize_fmr_interception_source_window(column_id+1_int64,10091009_int64,0.0_real64, &
         endpoints(4),source,wrong(1),status)
    call app%run_interception_window_interval(wrong,0.0_real64,endpoints(1),forcing,results,amounts,status)
    call require(status==FMR_APP_BOOT_INTERCEPTION_REJECTED,'wrong companion identity rejected')
    call require(.not.allocated(results).and.all(amounts==0.0_real64),'rejected application publishes nothing')
    call app%copy_committed_for_crop(1,snapshot,status)
    call require(status==FMR_APP_BOOT_OK.and.snapshot%current_revision()==0_int64,'application preflight physical unchanged')
    t0=0.0_real64;canopy_sum=0.0_real64;soil_sum=0.0_real64
    do i=1,4
      stale=owners
      call app%run_interception_window_interval(owners,t0,endpoints(i),forcing,results,amounts,status)
      if(status/=FMR_APP_BOOT_OK) write(*,'(A,I0)') 'INT12C_APPLICATION_STATUS=',status
      call require(status==FMR_APP_BOOT_OK,'application physical and source call committed')
      call require(allocated(results),'application publishes real result')
      call require(results(1)%completed.and.results(1)%committed,'application real endpoint complete')
      call require(results(1)%solver_headcalc_calls>0,'application actually executes HeadCalc')
      call require(results(1)%mass%complete.and.abs(results(1)%mass%residual)<=hard_mass_gate, &
           'application hard mass unchanged')
      call fmr_interception_source_window_progress(owners(1),time,amount,complete,status)
      call require(status==FMR_INTWIN_OK.and.same_bits(time,endpoints(i)),'application progress follows actual endpoint')
      canopy_sum=canopy_sum+amounts(1);soil_sum=soil_sum+results(1)%mass%total_in
      call app%copy_committed_for_crop(1,snapshot,status)
      revision=snapshot%current_revision()
      call require(revision==results(1)%final_revision,'application physical revision matches publication')
      write(*,'(A,I2,4(1X,ES23.15))') 'INT12C_APPLICATION_ENDPOINT=',i,time,amounts(1), &
           results(1)%mass%total_in,results(1)%mass%residual
      call app%run_interception_window_interval(stale,endpoints(i),endpoints(i)+0.001_real64, &
           forcing,results,amounts,status)
      call require(status==FMR_APP_BOOT_INTERCEPTION_REJECTED,'stale companion rejected before next physical call')
      call app%copy_committed_for_crop(1,snapshot,status)
      call require(snapshot%current_revision()==revision,'stale companion cannot advance physical state')
      if(i==2)then
        call export_fmr_interception_source_window_restart(owners(1),endpoints(i),restart,status)
        call require(status==FMR_INTWIN_OK,'application companion continuation export')
        call restore_fmr_interception_source_window(restart,restored,status)
        call require(status==FMR_INTWIN_OK,'application companion continuation restore')
        owners(1)=restored
      end if
      t0=endpoints(i)
    end do
    call require(complete.and.same_bits(amount,source),'application final source aggregate bitwise')
    call require(abs(canopy_sum-source)<1.0e-14_real64,'application canopy exactly once')
    call require(abs(soil_sum+canopy_sum-weather%gross_rain_cm_d*endpoints(4))<hard_mass_gate, &
         'application combined source mass closes')
    call verify_int12c_batch_rollback(cfg,forcing(1),source,endpoints(1))
    call verify_int12c_direct(cfg,weather,site,canopy)
    call app%close(status)
    call require(status==FMR_APP_BOOT_OK,'application owner released')
    write(*,'(A)') 'INT12C_REAL_APPLICATION_PHYSICAL_AND_COMPANION_COMMIT=PASS'
    write(*,'(A)') 'INT12C_REAL_APPLICATION_PREFLIGHT_AND_STALE_CURSOR_NONMUTATION=PASS'
    write(*,'(A)') 'INT12C_REAL_APPLICATION_COMPANION_CONTINUATION=PASS'
    write(*,'(A)') 'INT12C_REAL_APPLICATION_EXACT_ONCE_SOURCE_MASS=PASS'
  end subroutine verify_int12c_application

  subroutine verify_int12c_batch_rollback(cfg,good_forcing,source,endpoint)
    use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
         fmr_production_application_bootstrap_t,FMR_APP_BOOT_OK
    use mod_fmr_interception_source_window_binding
    use mod_transaction_reference, only: transaction_state_t
    type(fmr_production_application_config_t),intent(in) :: cfg
    type(fmr_b110_physical_forcing_t),intent(in) :: good_forcing
    real(real64),intent(in) :: source,endpoint
    type(fmr_production_application_config_t) :: batch
    type(fmr_production_application_bootstrap_t) :: raw,atomic
    type(fmr_b110_physical_forcing_t) :: forcing(2)
    type(fmr_interception_source_window_t) :: owners(2)
    type(fmr_serialized_column_result_t),allocatable :: results(:)
    type(kernel_committed_state_t) :: snapshot
    class(transaction_state_t),allocatable :: physical
    real(real64),allocatable :: amounts(:)
    real(real64) :: time,amount
    integer :: status,i
    logical :: complete,ok
    batch=cfg
    deallocate(batch%tiles);allocate(batch%tiles(2))
    batch%tiles(1)=cfg%tiles(1);batch%tiles(2)=cfg%tiles(1)
    batch%tiles(2)%tile_id=column_id+1_int64
    batch%tiles(2)%template%template_id=cfg%tiles(1)%template%template_id+1_int64
    forcing=good_forcing
    deallocate(forcing(2)%root_extraction_sink)
    allocate(forcing(2)%root_extraction_sink(numnod+1))
    forcing(2)%root_extraction_sink=0.0_real64
    ! The unwrapped incumbent proves this fixture really commits column1
    ! before rejecting column2; a preflight-only failure would not suffice.
    call raw%initialize(batch,status)
    call require(status==FMR_APP_BOOT_OK,'raw batch initialized')
    call raw%run_standalone_with_forcing(0.0_real64,endpoint,forcing,results,status)
    call require(status/=FMR_APP_BOOT_OK,'raw batch rejects invalid second forcing')
    call require(allocated(results),'raw batch exposes attempted results')
    call require(results(1)%committed.and..not.results(2)%committed,'rollback fixture actually has a committed first column')
    call raw%copy_committed_for_crop(1,snapshot,status)
    call require(snapshot%current_revision()>0_int64,'unwrapped first column actually changed')
    call raw%close(status)
    call atomic%initialize(batch,status)
    call require(status==FMR_APP_BOOT_OK,'atomic batch initialized')
    do i=1,2
      call initialize_fmr_interception_source_window(batch%tiles(i)%tile_id,10091009_int64, &
           0.0_real64,0.01_real64,source,owners(i),status)
      call require(status==FMR_INTWIN_OK,'atomic batch companion initialized')
    end do
    call atomic%run_interception_window_interval(owners,0.0_real64,endpoint,forcing,results,amounts,status)
    call require(status/=FMR_APP_BOOT_OK,'atomic batch rejects invalid second forcing')
    call require(.not.allocated(results).and.all(amounts==0.0_real64),'atomic rejection publishes no receipts')
    do i=1,2
      call atomic%copy_committed_for_crop(i,snapshot,status)
      call require(snapshot%current_revision()==0_int64,'atomic rollback restores every revision')
      call snapshot%current_time(time,ok)
      call require(ok.and.same_bits(time,0.0_real64),'atomic rollback restores every physical time')
      call snapshot%snapshot(physical,ok)
      call require(ok,'atomic rollback snapshot available')
      select type(physical)
      class is(fmr_b110_physical_state_t)
        call require(all(physical%pressure_head==batch%tiles(i)%initial_state%pressure_head).and. &
             all(physical%water_content==batch%tiles(i)%initial_state%water_content), &
             'atomic rollback restores actual pressure and water arrays')
      class default
        call require(.false.,'atomic rollback physical state type')
      end select
      call fmr_interception_source_window_progress(owners(i),time,amount,complete,status)
      call require(status==FMR_INTWIN_OK.and.same_bits(time,0.0_real64).and.same_bits(amount,0.0_real64), &
           'atomic rollback preserves every source cursor')
    end do
    forcing=good_forcing
    call atomic%run_interception_window_interval(owners,0.0_real64,endpoint,forcing,results,amounts,status)
    call require(status==FMR_APP_BOOT_OK,'atomic same-origin valid retry succeeds')
    call require(all(results%committed).and.all(amounts>0.0_real64),'atomic retry jointly publishes physical/source receipts')
    call atomic%close(status)
    write(*,'(A)') 'INT12C_REAL_APPLICATION_TWO_COLUMN_ROLLBACK_AND_RETRY=PASS'
  end subroutine verify_int12c_batch_rollback

  subroutine verify_int12c_direct(cfg,weather,site,canopy)
    use mod_fmr_production_application_bootstrap
    use mod_fmr_interception_source_window_binding
    use mod_pmdirect_swetr0_process
    use mod_root_uptake_compensation, only: ROOT_COMP_OFF
    type(fmr_production_application_config_t),intent(in) :: cfg
    type(pmdirect_swetr0_weather_t),intent(in) :: weather
    type(pmdirect_swetr0_site_t),intent(in) :: site
    type(pmdirect_swetr0_canopy_t),intent(in) :: canopy
    type(fmr_production_application_config_t) :: rooted,badcfg
    type(fmr_production_application_bootstrap_t) :: app,legacy,bad
    type(fmr_pmdirect_interception_input_t) :: input(1),invalid(1)
    type(fmr_pmdirect_interception_receipt_t),allocatable :: receipts(:)
    type(fmr_interception_source_window_t) :: owner(1),wrong(1),restored
    type(fmr_interception_source_window_restart_t) :: restart
    type(fmr_serialized_column_result_t),allocatable :: results(:)
    type(kernel_committed_state_t) :: snapshot
    type(pmdirect_swetr0_daily_result_t) :: daily
    type(pmdirect_swetr0_interval_result_t) :: interval
    type(pmdirect_swetr0_diagnostics_t) :: diag
    real(real64),allocatable :: amounts(:)
    real(real64) :: endpoint(4),t0,dt,source,time,amount,canopy_sum,expected_root,expected_top
    integer :: status,i,j,case_index
    integer(int64) :: revision
    logical :: complete
    rooted=cfg;rooted%tiles(1)%parameters%root_extraction_active=.true.
    rooted%tiles(1)%parameters%root_compensation%method=ROOT_COMP_OFF
    call legacy%initialize(rooted,status)
    call require(status==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.legacy%ready(), &
         'incumbent plain Feddes initialization still rejected without opt-in')
    rooted%explicit_pmdirect_interception=.true.
    badcfg=rooted;badcfg%tiles(1)%parameters%bottom_mode=7
    call bad%initialize(badcfg,status)
    call require(status==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.bad%ready(),'opt-in rejects unsupported bottom mode')
    endpoint=[0.002_real64,0.004_real64,0.007_real64,0.01_real64]
    input(1)%weather=weather;input(1)%site=site;input(1)%canopy=canopy
    input(1)%roots%crop_emerged=.true.;input(1)%roots%rooted_nodes=numnod
    allocate(input(1)%roots%cumulative_root_fraction(numnod+1))
    do j=1,numnod+1
      input(1)%roots%cumulative_root_fraction(j)=real(j-1,real64)/real(numnod,real64)
    end do
    input(1)%root_parameters%active_nodes=numnod
    input(1)%root_parameters%hlim3l=-500.0_real64
    input(1)%root_parameters%hlim3h=-300.0_real64
    input(1)%root_parameters%hlim4=-8000.0_real64
    input(1)%root_parameters%adcrl=0.1_real64
    input(1)%root_parameters%adcrh=0.5_real64
    do case_index=1,2
      if(case_index==2) input(1)%weather%gross_rain_cm_d=0.0_real64
      call evaluate_pmdirect_swetr0_daily(input(1)%weather,site,canopy,daily,diag)
      call require(diag%daily_result_produced,'direct oracle daily')
      call apply_swinter1_daily_interval(input(1)%weather,canopy,daily,interval,diag)
      call require(diag%interval_result_produced,'direct oracle interval')
      call require(daily%potential_transpiration_dry_cm_per_day>0.0_real64.and. &
           daily%potential_transpiration_wet_cm_per_day>0.0_real64,'both physical canopy demands nonzero')
      call require(abs(interval%potential_transpiration_cm_per_day- &
           ((1.0_real64-interval%wet_canopy_fraction)*daily%potential_transpiration_dry_cm_per_day+ &
            interval%wet_canopy_fraction*daily%potential_transpiration_wet_cm_per_day))<1e-14_real64, &
           'direct wet/dry demand call order unchanged')
      if(case_index==1) call require(interval%wet_canopy_fraction>0.0_real64.and. &
           interval%wet_canopy_fraction<1.0_real64,'wet case actually blends canopy demand')
      if(case_index==2) call require(same_bits(interval%wet_canopy_fraction,0.0_real64),'dry case selects dry demand')
      source=interval%interception_rate_cm_per_day*endpoint(4)
      call app%initialize(rooted,status)
      call require(status==FMR_APP_BOOT_OK,'explicit direct crop-root application initialized')
      call initialize_fmr_interception_source_window(column_id,10091010_int64,0.0_real64,endpoint(4),source,owner(1),status)
      call initialize_fmr_interception_source_window(column_id,10091010_int64,0.0_real64,endpoint(4), &
           source+0.001_real64,wrong(1),status)
      call app%run_pmdirect_interception_interval(wrong,0.0_real64,endpoint(1),input,results,amounts,receipts,status)
      call require(status==FMR_APP_BOOT_INTERCEPTION_REJECTED.and..not.allocated(results).and. &
           .not.allocated(receipts).and.all(amounts==0.0_real64),'inconsistent aggregate fails before publication')
      invalid=input;invalid(1)%roots%cumulative_root_fraction(numnod+1)=0.5_real64
      call app%run_pmdirect_interception_interval(owner,0.0_real64,endpoint(1),invalid,results,amounts,receipts,status)
      call require(status==FMR_APP_BOOT_INTERCEPTION_REJECTED.and..not.allocated(results).and. &
           .not.allocated(receipts),'invalid root geometry fails before physical execution')
      call app%copy_committed_for_crop(1,snapshot,status)
      call require(snapshot%current_revision()==0_int64,'upstream rejection preserves actual physical revision')
      t0=0.0_real64;canopy_sum=0.0_real64
      do i=1,4
        dt=endpoint(i)-t0
        call app%run_pmdirect_interception_interval(owner,t0,endpoint(i),input,results,amounts,receipts,status)
        if(status/=FMR_APP_BOOT_OK) write(*,'(A,3I6)') 'INT12C_DIRECT_STATUS=',case_index,i,status
        call require(status==FMR_APP_BOOT_OK,'direct physical soil and source interval committed')
        call require(allocated(receipts).and.allocated(results),'direct only publishes accepted receipts')
        call require(receipts(1)%accepted.and.results(1)%completed.and.results(1)%committed,'direct actual commit')
        call require(results(1)%solver_headcalc_calls>0,'direct actually invokes Richards HeadCalc')
        call require(results(1)%mass%complete.and.abs(results(1)%mass%residual)<=hard_mass_gate,'direct unchanged hard mass')
        call require(same_bits(receipts(1)%interval%net_rain_cm_per_day,interval%net_rain_cm_per_day).and. &
             same_bits(receipts(1)%interval%potential_transpiration_cm_per_day,interval%potential_transpiration_cm_per_day), &
             'direct actual call retains exact source rain and crop demand')
        expected_root=receipts(1)%roots%actual_uptake_total*dt
        call require(expected_root>0.0_real64,'direct root uptake is physically nonzero')
        call require(abs(results(1)%mass%total_out-max(0.0_real64,receipts(1)%top%actual_top_flux_cm_per_day)*dt- &
             expected_root)<hard_mass_gate,'actual physical mass includes accepted root extraction')
        expected_top=interval%net_rain_cm_per_day-receipts(1)%top%bare_soil_evaporation_cm_per_day
        call require(abs(receipts(1)%top%actual_top_flux_cm_per_day+expected_top)<1e-14_real64, &
             'dynamic top receives net rainfall exactly once and resolves actual evaporation')
        call require(abs(results(1)%mass%total_in-max(expected_top,0.0_real64)*dt)<hard_mass_gate, &
             'actual physical rain input follows dynamic top')
        canopy_sum=canopy_sum+amounts(1)
        call fmr_interception_source_window_progress(owner(1),time,amount,complete,status)
        call require(same_bits(time,endpoint(i)),'direct source follows actual endpoint')
        call app%copy_committed_for_crop(1,snapshot,status);revision=snapshot%current_revision()
        call require(revision==results(1)%final_revision,'direct physical revision is authoritative')
        if(i==2) then
          call export_fmr_interception_source_window_restart(owner(1),endpoint(i),restart,status)
          call restore_fmr_interception_source_window(restart,restored,status);owner(1)=restored
        end if
        write(*,'(A,2I3,5(1X,ES23.15))') 'INT12C_DIRECT_ENDPOINT=',case_index,i,time,amounts(1), &
             receipts(1)%interval%wet_canopy_fraction,expected_root,results(1)%mass%residual
        t0=endpoint(i)
      end do
      call require(complete.and.same_bits(amount,source),'direct source final bitwise closure')
      call require(abs(canopy_sum-source)<1e-14_real64,'direct exactly-once interception')
      call app%close(status)
      call require(status==FMR_APP_BOOT_OK,'direct application closes')
    end do
    write(*,'(A)') 'INT12C_DIRECT_PMDIRECT_DYNAMIC_TOP_ACTIVE_ROOT_COMMITS=PASS'
    write(*,'(A)') 'INT12C_DIRECT_WET_DRY_DEMAND_AND_PHYSICAL_MASS=PASS'
    write(*,'(A)') 'INT12C_DIRECT_UPSTREAM_REJECTION_AND_OPTIN_BOUNDARY=PASS'
  end subroutine verify_int12c_direct
