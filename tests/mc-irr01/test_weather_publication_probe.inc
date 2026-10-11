  subroutine test_weather_publication_probe()
    type(fmr_production_application_config_t)::limited
    type(fmr_production_application_bootstrap_t)::trial_app,clean_app
    type(kernel_committed_state_t)::trial_crop,clean_crop,origin,actual,expected
    type(fmr_weather_crop_application_continuation_t)::before,after
    type(fmr_application_crop_daystart_controls_t)::c
    type(crop_certified_daily_preflight_t)::daily
    type(wofost_crop_owner_state_t)::owner
    type(swap_daily_weather_record_t)::wr
    type(fmr_serialized_column_result_t),allocatable::rr(:),cr(:)
    integer::st,j,kernel_status
    logical::ok
    real(real64),parameter::short_end=1.0e-6_real64
    limited=config
    limited%numerical%max_committed_substeps=1
    c%germ_mode=2;c%optimal_sum=9.5_real64
    c%zprep=-1.0_real64;c%zsow=-1.0_real64
    c%ztempsow=-1.0_real64;c%zgerm=-1.0_real64
    call read_swap_daily_weather_file(trim(path),1999,1,20,wr,st)
    call require(st==SWAP_WEATHER_FILE_OK,'probe authentic day record')
    call trial_app%initialize(limited,st)
    call require(st==FMR_APP_BOOT_OK,'probe actual application initialization')
    call trial_app%begin_weather_day(wr,c,daily,st)
    call require(st==FMR_APP_BOOT_OK,'probe same weather daystart')
    call trial_app%initialize_weather_crop_daystart(wr,c,owner,1_int64,931_int64,trial_crop,st)
    call require(st==FMR_APP_BOOT_OK,'probe accepted initial crop owner')
    call trial_app%copy_committed_for_crop(1,origin,st)
    call require(st==FMR_APP_BOOT_OK,'probe before physical origin')
    call trial_app%capture_weather_crop_continuation(trial_crop,before,st)
    call require(st==FMR_APP_BOOT_OK,'probe before joint continuation')
    do j=1,2
      call trial_app%run_weather_interval(wr,T0,T0+0.5_real64,forcing_config,canopy,rr,st)
      call require(st/=FMR_APP_BOOT_OK.and.allocated(rr),'probe incomplete actual dispatch')
      call require(size(rr)==1,'probe single-column admission')
      ! This is NOT a zero-progress rejection: one internal accepted substep
      ! has actually occurred, but the incomplete outer candidate is discarded.
      call require(rr(1)%accepted_substeps==1,'probe positive internal accepted prefix')
      call require(.not.rr(1)%completed.and..not.rr(1)%committed,'probe no outer prefix publication')
      call require(rr(1)%final_revision==0_int64,'probe result reports original revision')
      kernel_status=rr(1)%kernel_status
      call trial_app%copy_committed_for_crop(1,actual,st)
      call require(st==FMR_APP_BOOT_OK,'probe after physical origin')
      call compare_probe_hydrology(origin,actual)
      call require(trial_crop%current_revision()==0_int64,'probe crop owner not advanced')
      call trial_app%capture_weather_crop_continuation(trial_crop,after,st)
      call require(st==FMR_APP_BOOT_OK,'probe failed prefix leaves coherent joint continuation')
    enddo
    call clean_app%restore_weather_crop_continuation(before,clean_crop,st)
    call require(st==FMR_APP_BOOT_OK,'probe independent clean origin restart')
    if(trim(continuation_mode)=='restart') then
      call trial_app%close(st)
      call require(st==FMR_APP_BOOT_OK,'probe close failed attempt application')
      trial_crop=kernel_committed_state_t()
      call trial_app%restore_weather_crop_continuation(after,trial_crop,st)
      call require(st==FMR_APP_BOOT_OK,'probe restore after internally accepted failed prefix')
    endif
    call trial_app%run_weather_interval(wr,T0,short_end,forcing_config,canopy,rr,st)
    call require(st==FMR_APP_BOOT_OK.and.allocated(rr),'probe actual short retry succeeds')
    call require(rr(1)%completed.and.rr(1)%committed.and.rr(1)%accepted_substeps==1,'probe retry atomic commit')
    call require(rr(1)%mass%complete.and.abs(rr(1)%mass%residual)<=HARD_MASS_GATE,'probe unchanged hard mass')
    call clean_app%run_weather_interval(wr,T0,short_end,forcing_config,canopy,cr,st)
    call require(st==FMR_APP_BOOT_OK.and.allocated(cr),'probe clean origin same physical interval')
    call require(cr(1)%completed.and.cr(1)%committed,'probe clean interval commits')
    call trial_app%copy_committed_for_crop(1,actual,st)
    call require(st==FMR_APP_BOOT_OK,'probe actual retry state')
    call clean_app%copy_committed_for_crop(1,expected,st)
    call require(st==FMR_APP_BOOT_OK,'probe clean state')
    call compare_probe_hydrology(actual,expected)
    ! A completed earlier segment is real committed authority. A failed
    ! next segment must retain that common soil/weather prefix, not reset
    ! the whole application to daystart or publish its own incomplete tail.
    call trial_app%run_weather_interval(wr,short_end,T0+0.5_real64,forcing_config,canopy,rr,st)
    call require(st/=FMR_APP_BOOT_OK.and.allocated(rr),'probe next-segment incomplete dispatch')
    call require(rr(1)%accepted_substeps==1.and..not.rr(1)%completed.and..not.rr(1)%committed, &
         'probe next-segment internal acceptance is not outer publication')
    call require(rr(1)%final_revision==1_int64,'probe first completed segment stays committed')
    call trial_app%copy_committed_for_crop(1,actual,st)
    call require(st==FMR_APP_BOOT_OK,'probe retained accepted prefix')
    call compare_probe_hydrology(actual,expected)
    call trial_app%capture_weather_crop_continuation(trial_crop,after,st)
    call require(st==FMR_APP_BOOT_OK,'probe joint continuation at retained accepted prefix')
    if(trim(continuation_mode)=='restart') then
      call trial_app%close(st);call require(st==FMR_APP_BOOT_OK,'probe close accepted prefix')
      trial_crop=kernel_committed_state_t()
      call trial_app%restore_weather_crop_continuation(after,trial_crop,st)
      call require(st==FMR_APP_BOOT_OK,'probe restore accepted prefix after failed next segment')
    endif
    call trial_app%run_weather_interval(wr,short_end,2.0_real64*short_end,forcing_config,canopy,rr,st)
    call require(st==FMR_APP_BOOT_OK.and.allocated(rr),'probe retry from common accepted prefix')
    call require(rr(1)%completed.and.rr(1)%committed.and.rr(1)%final_revision==2_int64, &
         'probe exactly second completed segment')
    call require(rr(1)%mass%complete.and.abs(rr(1)%mass%residual)<=HARD_MASS_GATE,'probe second hard mass')
    call clean_app%run_weather_interval(wr,short_end,2.0_real64*short_end,forcing_config,canopy,cr,st)
    call require(st==FMR_APP_BOOT_OK.and.allocated(cr),'probe clean second interval')
    call trial_app%copy_committed_for_crop(1,actual,st);call require(st==FMR_APP_BOOT_OK,'probe final actual')
    call clean_app%copy_committed_for_crop(1,expected,st);call require(st==FMR_APP_BOOT_OK,'probe final clean')
    call compare_probe_hydrology(actual,expected)
    call trial_app%capture_weather_crop_continuation(trial_crop,after,st)
    call require(st==FMR_APP_BOOT_OK,'probe actual retry joint continuation')
    call trial_app%run_weather_interval(wr,T0,short_end,forcing_config,canopy,rr,st)
    call require(st==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(rr),'probe successful retry delivered once')
    call trial_app%copy_committed_for_crop(1,actual,st)
    call compare_probe_hydrology(actual,expected)
    call trial_app%close(st);call require(st==FMR_APP_BOOT_OK,'probe close trial application')
    call clean_app%close(st);call require(st==FMR_APP_BOOT_OK,'probe close clean application')
    print '(a,i0)', 'MC_IRR01_WEATHER_INCOMPLETE_KERNEL_STATUS=',kernel_status
    print '(a)', 'MC_IRR01_WEATHER_ONE_INTERNAL_ACCEPTED_PREFIX_OUTER_ROLLBACK=PASS'
    print '(a)', 'MC_IRR01_WEATHER_FAILED_PREFIX_JOINT_RESTART=PASS'
    print '(a)', 'MC_IRR01_WEATHER_RETRY_EQUALS_CLEAN_ORIGIN=PASS'
    print '(a)', 'MC_IRR01_WEATHER_RETRY_EXACTLY_ONCE=PASS'
    print '(a)', 'MC_IRR01_WEATHER_COMPLETED_PREFIX_SURVIVES_NEXT_SEGMENT_FAILURE=PASS'
  end subroutine

  subroutine compare_probe_hydrology(a,b)
    type(kernel_committed_state_t),intent(in)::a,b
    class(transaction_state_t),allocatable::pa,pb
    real(real64),allocatable::da(:),db(:)
    real(real64)::ta,tb
    logical::ok
    call require(a%current_lineage_id()==b%current_lineage_id().and. &
         a%current_revision()==b%current_revision(),'probe same soil provenance')
    call a%current_time(ta,ok);call require(ok,'probe first accepted time')
    call b%current_time(tb,ok);call require(ok,'probe second accepted time')
    call require(transfer(ta,0_int64)==transfer(tb,0_int64),'probe exact accepted time')
    call a%snapshot(pa,ok);call require(ok,'probe first soil snapshot')
    call b%snapshot(pb,ok);call require(ok,'probe second soil snapshot')
    select type(pa)
    type is(fmr_b110_temporal_indicator_state_t)
      select type(pb)
      type is(fmr_b110_temporal_indicator_state_t)
        call require(pa%active_nodes==pb%active_nodes,'probe exact node geometry')
        call require(all(transfer(pa%pressure_head,[0_int64])==transfer(pb%pressure_head,[0_int64])), &
             'probe pressure bits retained')
        call require(all(transfer(pa%water_content,[0_int64])==transfer(pb%water_content,[0_int64])), &
             'probe water bits retained')
        call require(transfer(pa%ponding_depth,0_int64)==transfer(pb%ponding_depth,0_int64), &
             'probe ponding bits retained')
        call require(transfer(pa%groundwater_level,0_int64)==transfer(pb%groundwater_level,0_int64), &
             'probe groundwater carrier bits retained')
        call pa%temporal_history_snapshot(da,ok);call require(ok,'probe first retained history')
        call pb%temporal_history_snapshot(db,ok);call require(ok,'probe second retained history')
        call require(size(da)==size(db),'probe history extent')
        call require(all(transfer(da,[0_int64])==transfer(db,[0_int64])),'probe derivative bits retained')
      class default
        call require(.false.,'probe second physical type')
      end select
    class default
      call require(.false.,'probe first physical type')
    end select
  end subroutine
