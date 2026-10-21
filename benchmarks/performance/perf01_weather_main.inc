  real(real64),parameter::T0=0.0_real64,T1=1.0_real64,H0_CM=-75.0_real64,HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t)::config,tc
  type(fmr_production_application_bootstrap_t)::ta
  type(fmr_application_crop_daystart_controls_t)::c
  type(kernel_committed_state_t)::cs,ss
  type(kernel_executor_t)::ck
  type(fmr_wofost_crop_transaction_model_t),target::cm
  type(fmr_wofost_crop_transaction_parameters_t)::cp
  type(canonical_numerical_config_t)::cn
  type(kernel_result_t)::cr
  type(swap_daily_weather_record_t)::wr
  type(fmr_serialized_column_result_t),allocatable::rr(:)
  type(wofost_crop_owner_state_t)::empty_owner,wo
  type(wofost_rate_parameter_bundle_t)::bundle
  type(wofost_one_day_update_parameters_t)::update
  type(fmr_weather_crop_application_continuation_t)::saved
  type(fmr_weather_crop_native_view_t)::view
  type(wofost_accepted_window_aggregates_t)::aggregates
  type(fmr_wofost_crop_event_token_t)::token
  type(ppa_wu03_common_forcing_config_t)::forcing_config
  type(reference_et_demand_canopy_view_t)::canopy
  class(transaction_state_t),allocatable::ps
  real(real64),allocatable::dist(:),temps(:)
  character(1024)::path,arg,restart_mode,profile_mode
  real(real64)::k,budget,wd,tmn,tmx,rain,etref,uptake,waterin,waterout,residual,initial_storage,storage
  real(real64)::startcpu,endcpu,previous_storage,weight,lai,head(4),theta(4)
  integer::st,q,d,j,iday,month,dom,year,days,windows,unit,pu,accepted,heads,rejections
  logical::ok,dayend=.false.
  call get_command_argument(1,path)
  call get_command_argument(2,arg);read(arg,*)budget
  call get_command_argument(3,arg);read(arg,*)days
  call get_command_argument(4,arg);read(arg,*)windows
  call get_command_argument(5,restart_mode);call get_command_argument(6,profile_mode)
  call require(budget>0d0.and.budget<=1d0.and.days>=1.and.days<=97.and.windows>=1,'explicit bounded run arguments')
  call initialize_application_config(config,k)
  config%file_weather_daystart=.true.
  config%file_weather_epoch_day=swap_weather_calendar_day(1999,1,20)
  config%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  allocate(config%tiles(1)%initial_right_derivative(numnod));config%tiles(1)%initial_right_derivative=0d0
  config%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  config%numerical%transaction%temporal_tolerance=0d0
  config%numerical%model_temporal_indicator_budget_available=.true.
  config%numerical%model_temporal_indicator_budget=budget
  config%numerical%transaction%max_retries=32
  config%numerical%max_committed_substeps=262144
  config%tiles(1)%parameters%head_abs_tolerance=1d-9
  config%tiles(1)%parameters%head_rel_tolerance=1d-9
  config%tiles(1)%parameters%ponding_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%max_iterations=20
  config%tiles(1)%parameters%max_backtracking=8
  config%tiles(1)%parameters%min_step_duration=1d-10
  config%tiles(1)%parameters%compartment_balance_tolerance=1d-10
  config%tiles(1)%parameters%total_balance_tolerance=1d-10
  ! ROOTED_SETUP
  if(trim(profile_mode)=='sensitive')then
    tc%file_weather_root_parameters%hlim3l=-100d0
    tc%file_weather_root_parameters%hlim3h=-150d0
    tc%file_weather_root_parameters%hlim4=-500d0
  end if
  call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'live weather crop bootstrap')
  call initialize_crop(cs,cp,cn,leaf_lifespan=40d0);call ck%bind_model(cm)
  c=fmr_application_crop_daystart_controls_t();c%initialization_profile=CROP_PROFILE_B111_TASK2
  c%swprep=0;c%swsow=1;c%germ_mode=2;c%optimal_sum=1d0
  c%hsow_threshold=100d0;c%sow_temperature=.0001d0
  c%zprep=-1d0;c%zsow=-1d0;c%ztempsow=-1d0;c%zgerm=-1d0
  open(newunit=unit,file='daily.csv',status='new')
  write(unit,'(a)') 'day,rain_mm,etref_mm,transpiration_mm,storage_mm,water_in_mm,water_out_mm,residual_mm,biomass,dvs,lai,head1_cm,head2_cm,head3_cm,head4_cm,theta1,theta2,theta3,theta4,potential_transpiration_mm,accepted,headcalc_calls,temporal_rejections,core_cpu_s'
  dom=20;month=1;year=1999
  print *, 'PERF01_INITIAL_STORAGE_CM',sum(tc%tiles(1)%initial_state%water_content*tc%tiles(1)%parameters%dz)
  do d=0,days-1
    call read_swap_daily_weather_file(trim(path),year,month,dom,wr,st)
    call require(st==SWAP_WEATHER_FILE_OK,'authentic daily weather record')
    call wr%values(wd,tmn,tmx,rain,etref,ok);call require(ok,'weather values available')
    call cpu_time(startcpu)
    if(d==0)then
      call ta%initialize_weather_crop_daystart(wr,c,empty_owner,19_int64,941_int64,cs,st)
    else
      call ta%run_weather_crop_daystart(wr,c,ck,cp,cn,cs,cr,st)
    end if
    if(st/=FMR_APP_BOOT_OK)print *, 'DAYSTART_REJECTED',d,st
    call require(st==FMR_APP_BOOT_OK,'live daily crop commit')
    uptake=0d0;waterin=0d0;waterout=0d0;residual=0d0;accepted=0;heads=0;rejections=0
    do q=0,windows-1
      call ta%run_weather_interval(wr,real(d,real64)+real(q,real64)/windows, &
        real(d,real64)+real(q+1,real64)/windows,forcing_config,canopy,rr,st,crop_committed=cs)
      if(st/=FMR_APP_BOOT_OK)print *, 'HYDRO_REJECTED',d,q,st
      call require(st==FMR_APP_BOOT_OK,'live weather hydrology')
      call require(rr(1)%committed.and.rr(1)%mass%complete,'accepted complete water accounting')
      call require(abs(rr(1)%mass%residual)<=HARD_MASS_GATE,'unchanged hard water budget')
      call require(rr(1)%actual_transpiration_available,'physical transpiration available')
      uptake=uptake+rr(1)%actual_transpiration_amount
      waterin=waterin+rr(1)%mass%total_in;waterout=waterout+rr(1)%mass%total_out
      residual=residual+rr(1)%mass%residual
      accepted=accepted+rr(1)%accepted_substeps;heads=heads+rr(1)%solver_headcalc_calls
      rejections=rejections+rr(1)%temporal_rejections
    end do
    call cpu_time(endcpu)
    call ta%capture_weather_crop_continuation(cs,saved,st)
    call require(st==FMR_APP_BOOT_OK,'accepted daily crop water window')
    call export_weather_crop_native_view(saved,view,st)
    call require(st==FMR_APP_BOOT_OK,'read-only daily continuation view')
    call prepare_wofost_crop_event_delivery(view%current_window,aggregates,token,ok,st)
    call require(ok,'complete daily uptake and demand aggregates')
    call require(aggregates%actual_root_uptake==uptake,'independent uptake publication agrees with window')
    call ta%copy_committed_for_crop(1,ss,st);call require(st==FMR_APP_BOOT_OK,'accepted soil snapshot')
    call ss%snapshot(ps,ok);call require(ok,'soil owner available')
    select type(ps)
    type is(fmr_b110_temporal_indicator_state_t)
      storage=sum(ps%water_content*tc%tiles(1)%parameters%dz)+ps%ponding_depth
      head=ps%pressure_head;theta=ps%water_content
    class default
      call require(.false.,'existing Richards history state')
    end select
    call cs%snapshot(ps,ok);call require(ok,'crop owner available')
    select type(ps)
    type is(fmr_wofost_crop_transaction_state_t)
      call ps%snapshot_owner(wo,ok);call require(ok,'live biomass')
    class default
      call require(.false.,'existing crop state')
    end select
    weight=0d0;lai=0d0
    if(allocated(wo%biomass))then
      weight=wo%biomass%root_biomass+wo%biomass%stem_biomass+wo%biomass%storage_biomass
      if(allocated(wo%biomass%leaf_biomass))weight=weight+sum(wo%biomass%leaf_biomass)
      lai=wo%biomass%leaf_area_sum()
    end if
    write(unit,'(i0,19(",",es25.17e3),3(",",i0),",",es25.17e3)') &
      d+1,rain,etref,10d0*uptake,10d0*storage,10d0*waterin,10d0*waterout,10d0*residual,weight, &
      wo%development_stage,lai,head,theta,10d0*aggregates%potential_transpiration,accepted,heads,rejections,endcpu-startcpu
    flush(unit)
    print *, 'COMPLETED_DAY',d+1,10d0*storage,10d0*uptake
    if(trim(restart_mode)=='restart'.and.d==days/2-1)then
      call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close midpoint accepted application')
      cs=kernel_committed_state_t()
      call ta%restore_weather_crop_continuation(saved,cs,st)
      call require(st==FMR_APP_BOOT_OK,'reconstruct complete soil weather crop history at midpoint')
    end if
    dom=dom+1
    if((month==1.or.month==3).and.dom>31)then
      month=month+1;dom=1
    else if(month==2.and.dom>28)then
      month=3;dom=1
    end if
  end do
  close(unit)
  call ta%close(st);call require(st==FMR_APP_BOOT_OK,'close completed live application')
  print *, 'PERF01_LIVE_WEATHER_COMPLETE',days,budget
