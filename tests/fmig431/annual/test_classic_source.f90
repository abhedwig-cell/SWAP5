program annual_source_probe
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_wofost_crop_owner_state
 use mod_wofost_rate_table
 use mod_wofost_rate_parameters
 use mod_wofost_one_day_structural_evolution
 use mod_wofost_two_phase_crop_window
 use mod_fmr_wofost_crop_transaction
 use b111_oracle, only: p,p_wof,s_act,r_act,m_act,sw_wofost,fl_anthesis, &
   update_dvs_rate,update_wofost,totass
 use atmosphere_interface, only: tav,rad
 use plant_interface, only: dvs,tsum,kdif
 implicit none
 type(wofost_crop_owner_state_t):: state,next,before,replayed
 type(fmr_wofost_crop_transaction_state_t):: tx,restored
 type(fmr_wofost_crop_transaction_persistence_t):: persisted
 type(wofost_rate_parameter_bundle_t):: bundle
 type(wofost_one_day_forcing_t):: forcing
 type(wofost_one_day_update_parameters_t):: upd
 type(wofost_accepted_window_aggregates_t):: agg
 type(wofost_two_phase_crop_window_t):: window
 type(wofost_crop_window_begin_diagnostics_t):: bd
 type(wofost_crop_window_complete_diagnostics_t):: cd
 type(wofost_one_day_rate_packet_t):: rates
 real(real64):: pgass,dtga,reltr,maxerr,delta,dead_before,live_before,live_after,gross
 integer:: day,st,i,phase,run
 logical:: available,exported,reconstructed
 maxerr=0
 do run=1,3
 call seed_active_owner(state)
 call configure_forcing(forcing)
 call make_bundle(bundle)
 upd%development_stage_end=2; upd%leaf_lifespan=30
 agg%potential_transpiration=5
 ! The independent source model receives the same initial living state and parameters.
 ! Dead source organs start at zero, and remain independently cumulative.
 sw_wofost=1; fl_anthesis=.false.
 p_wof%idsl=0; p_wof%tsumea=1000; p_wof%tsumam=800; p_wof%dtsmtb=[0d0,10d0]
 p%rfsetb=[0d0,1d0];p%frtb=[0d0,0.2d0];p%fltb=[0d0,0.4d0]
 p%fstb=[0d0,0.4d0];p%fotb=[0d0,0.2d0];p%rdrrtb=[0d0,0.01d0]
 p%rdrstb=[0d0,0.01d0];p%slatb=[0d0,0.02d0]
 p%rmr=0.01d0;p%rml=0.02d0;p%rms=0.015d0;p%rmo=0.005d0;p%q10=2
 p%cvr=0.7d0;p%cvs=0.65d0;p%cvl=0.72d0;p%cvo=0.8d0
 p%perdl=0.03d0;p%tbase=0;p%rgrlai=0.04d0;p%span=30;p%ssa=0.005d0;p%spa=0.002d0;p%dvsend=2
 s_act%fl_potential=.false.;s_act%ilv=2
 s_act%lv=0;s_act%sla=0;s_act%lvage=0
 s_act%lv(1:2)=[100d0,80d0];s_act%sla(1:2)=[0.02d0,0.03d0];s_act%lvage(1:2)=[0d0,1d0]
 s_act%wrt=1000;s_act%wst=800;s_act%wso=100;s_act%wlv=180
 s_act%lasum=4.4d0;s_act%lai=8.6d0;s_act%laiexp=4
 s_act%dwrt=0;s_act%dwst=0;s_act%dwlv=0;r_act%glaiex=0
 dvs=0.5d0;tsum=100;kdif=0.6d0;tav=20;rad=forcing%global_radiation
 phase=0
 do day=1,200
   reltr=1d0
   if(run==2) reltr=0.6d0
   if(run==3) reltr=real(mod(day,5),real64)/4d0
   agg%actual_root_uptake=5*reltr
   before=state
   call begin_wofost_one_day_crop_window(state,forcing,real(day,real64),real(day+1,real64), &
      0.005_real64,0.002_real64,bundle,window,bd,st)
   call require(st==0,'production begin')
   call window%read_prepared_actual_pgass(pgass,available)
   call require(available,'production assimilation available')
   call totass(forcing%daylength_hours,31.5d0,0.495d0,s_act%lai, &
      forcing%diffuse_perpendicular_radiation,forcing%daily_sine_solar_elevation_integral, &
      forcing%sinld,forcing%cosld,dtga)
   dtga=dtga*30d0*(0.4d0/0.4d0)/44d0
   dtga=dtga*0.9d0
   call check(pgass,dtga,'assimilation')
   r_act%pgass=dtga
   dead_before=s_act%dwrt+s_act%dwst+s_act%dwlv
   live_before=s_act%wrt+s_act%wst+s_act%wso+s_act%wlv
   call update_dvs_rate()
   call update_wofost(s_act,r_act,m_act,reltr)
   live_after=s_act%wrt+s_act%wst+s_act%wso+s_act%wlv
   gross=r_act%grrt+r_act%grst+r_act%grso+r_act%grlv
   call check(live_after-live_before+s_act%dwrt+s_act%dwst+s_act%dwlv-dead_before,gross,'source organ balance')
   call complete_wofost_one_day_crop_window(window,bundle,upd,agg,next,rates,cd,st)
   call require(st==0,'production complete')
   call check(next%development_stage,dvs,'phenology')
   call check(next%evolution_continuation%temperature_sum,tsum,'temperature sum')
   call check(next%biomass%root_biomass,s_act%wrt,'root')
   call check(next%biomass%stem_biomass,s_act%wst,'stem')
   call check(next%biomass%storage_biomass,s_act%wso,'storage')
   call check(next%biomass%living_leaf_biomass(),s_act%wlv,'leaf')
   call check(next%biomass%leaf_area_sum(),s_act%lasum,'leaf area')
   call check(next%biomass%exponential_leaf_area_index,s_act%laiexp,'exponential LAI')
   call require(size(next%biomass%leaf_biomass)==s_act%ilv,'cohort count')
   do i=1,s_act%ilv
     call check(next%biomass%leaf_biomass(i),s_act%lv(i),'cohort mass')
     call check(next%biomass%specific_leaf_area(i),s_act%sla(i),'cohort SLA')
     call check(next%biomass%leaf_age(i),s_act%lvage(i),'cohort age')
   enddo
   call require(next%evolution_continuation%anthesis_reached.eqv.fl_anthesis,'anthesis')
   call require(state%development_stage==before%development_stage,'begin/complete immutable input')
   ! Same prepared checkpoint can be completed again without consuming state.
   call complete_wofost_one_day_crop_window(window,bundle,upd,agg,replayed,rates,cd,st)
   call require(st==0,'candidate replay')
   call require(replayed%biomass%root_biomass==next%biomass%root_biomass,'replay identity')
   if(mod(day,17)==0)then
    call initialize_fmr_wofost_crop_transaction_state(next,tx,st)
    call require(st==0.and.tx%ready(),'classic transaction initialization')
    call export_fmr_wofost_crop_transaction_persistence(tx,persisted,exported,st)
    call require(st==0.and.exported,'actual production persistence export')
    call reconstruct_fmr_wofost_crop_transaction_from_persistence(persisted,restored,reconstructed,st)
    call require(st==0.and.reconstructed,'actual production persistence reconstruction')
    call restored%snapshot_owner(replayed,available)
    call require(available,'restored owner')
    call require(all(replayed%biomass%leaf_biomass==next%biomass%leaf_biomass),'restored leaf cohorts')
    call require(replayed%biomass%root_biomass==next%biomass%root_biomass,'restored living roots')
    call require(replayed%development_stage==next%development_stage,'restored DVS')
    next=replayed
   endif
   state=next
 enddo
 call require(dvs==2d0.and.fl_anthesis,'anthesis and maturity traversed')
 call require(s_act%dwrt>0.and.s_act%dwst>0.and.s_act%dwlv>0,'source dead organs exercised')
 print '(a,i0,a,3es24.15)', 'TRAJECTORY ',run,' SOURCE_DEAD_ORGANS ',s_act%dwrt,s_act%dwst,s_act%dwlv
 enddo
 print '(a,es24.15)','MAX_ABS_LIVING_SOURCE_ERROR ',maxerr
 print '(a)','CLASSIC_LIVING_SOURCE_TRAJECTORIES_O0_O2_PROBE=PASS'
 print '(a)','CLASSIC_EXISTING_LIVING_PERSISTENCE_CONTINUATION=PASS'
 print '(a)','FULL_CLASSIC_ORGAN_RESTART_QUALIFICATION=BLOCKED_MISSING_DEAD_ORGAN_STATE'
contains
 subroutine check(a,b,label)
 real(real64),intent(in)::a,b
 character(*),intent(in)::label
 maxerr=max(maxerr,abs(a-b))
 if(abs(a-b)>1e-10_real64*max(1d0,abs(a),abs(b)))then
  print *,label,a,b
  error stop 'source comparison'
 endif
 end subroutine
  subroutine seed_active_owner(state)
    type(wofost_crop_owner_state_t), intent(out) :: state
    state%crop_emerged = .true.
    state%development_stage = 0.5_real64
    allocate(state%biomass)
    state%biomass%root_biomass = 1000.0_real64
    state%biomass%stem_biomass = 800.0_real64
    state%biomass%storage_biomass = 100.0_real64
    state%biomass%exponential_leaf_area_index = 4.0_real64
    state%biomass%leaf_biomass = [100.0_real64, 80.0_real64]
    state%biomass%specific_leaf_area = [0.02_real64, 0.03_real64]
    state%biomass%leaf_age = [0.0_real64, 1.0_real64]
    allocate(wofost_common_evolution_continuation_t :: state%evolution_continuation)
    state%evolution_continuation%temperature_sum = 100.0_real64
    state%evolution_continuation%anthesis_reached = .false.
    state%evolution_continuation%minimum_temperature_history_count = 2
    state%evolution_continuation%minimum_temperature_history = &
         [-1.0_real64, 1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
  end subroutine seed_active_owner

  subroutine configure_forcing(value)
    type(wofost_one_day_forcing_t), intent(out) :: value
    value%minimum_temperature = -2.0_real64
    value%average_temperature = 20.0_real64
    value%daytime_average_temperature = 20.0_real64
    value%global_radiation = 2000000.0_real64
    value%daylength_hours = 12.0_real64
    value%photoperiodic_daylength_hours = 12.0_real64
    value%sinld = 0.4_real64
    value%cosld = 0.5_real64
    value%diffuse_perpendicular_radiation = 10.0_real64
    value%daily_sine_solar_elevation_integral = 30000.0_real64
    value%co2_efficiency_factor = 1.1_real64
    value%co2_amax_factor = 1.05_real64
  end subroutine configure_forcing

  subroutine make_bundle(b)
    type(wofost_rate_parameter_bundle_t), intent(out) :: b
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: st

    s = wofost_rate_scalar_parameters_t()
    s%development_daylength_mode = 0
    s%daylength_upper_hours = 16.0_real64
    s%daylength_lower_hours = 8.0_real64
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 800.0_real64
    s%diffuse_extinction_coefficient = 0.6_real64
    s%initial_light_use_efficiency = 0.45_real64
    s%co2_to_dry_matter_fraction = 0.4_real64
    s%attainable_yield_multiplier = 0.9_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.65_real64
    s%conversion_efficiency_leaf = 0.72_real64
    s%conversion_efficiency_storage = 0.8_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.02_real64
    s%maintenance_respiration_stem = 0.015_real64
    s%maintenance_respiration_storage = 0.005_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.04_real64

    call constant_table(10.0_real64, t%temperature_sum_increment)
    call constant_table(30.0_real64, t%maximum_assimilation)
    call constant_table(1.0_real64, t%daytime_temperature_factor)
    call constant_table(1.0_real64, t%minimum_temperature_factor)
    call constant_table(1.0_real64, t%maintenance_respiration_factor)
    call constant_table(0.2_real64, t%root_partition_fraction)
    call constant_table(0.4_real64, t%leaf_partition_fraction)
    call constant_table(0.4_real64, t%stem_partition_fraction)
    call constant_table(0.2_real64, t%storage_partition_fraction)
    call constant_table(0.01_real64, t%relative_root_death_rate)
    call constant_table(0.01_real64, t%relative_stem_death_rate)
    call constant_table(0.02_real64, t%specific_leaf_area)

    call construct_wofost_rate_parameter_bundle(s, t, b, st)
    call require(st == WOFOST_RATE_PARAMETER_OK, 'test parameter bundle construction')
  end subroutine make_bundle

  subroutine constant_table(value, table)
    real(real64), intent(in) :: value
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(1), y(1)
    integer :: st
    x = [0.0_real64]
    y = [value]
    call construct_wofost_rate_table(x, y, table, st)
    call require(st == WOFOST_RATE_TABLE_OK, 'constant table construction')
  end subroutine constant_table

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require
end program
