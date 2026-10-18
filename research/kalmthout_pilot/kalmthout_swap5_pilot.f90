program kalmthout_swap5_daily_pilot
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_RUTTER
  use mod_interception_source_window_runtime, only: interception_source_window_t, initialize_interception_window, INTWIN_OK
  use mod_rutter_interception_process, only: rutter_interval_input_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_reference_et_demand_process, only: daily_atmospheric_demand_parameters_t, traditional_pm_weather_t, &
       reference_et_demand_canopy_view_t, reference_et_demand_result_t, evaluate_daily_atmospheric_demand, REF_ET_DEMAND_OK
  implicit none

  real(real64), parameter :: HARD_MASS_GATE=1.0e-10_real64
  real(real64), parameter :: H0_CM=-75.0_real64
  integer, parameter :: UNIT_MET=10, UNIT_OUT=20, NSUB=1
  character(len=256) :: met_path, out_path, line, ds, max_hours_arg, evap_scale_arg
  type(fmr_production_application_config_t) :: config
  type(fmr_production_application_bootstrap_t) :: app
  type(fmr_b110_physical_forcing_t), allocatable :: forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  type(kernel_committed_state_t) :: accepted_snapshot
  class(transaction_state_t), allocatable :: accepted_physical
  logical :: snapshot_ok
  integer :: snapshot_status
  type(interception_source_window_t) :: window
  type(rutter_interval_input_t) :: rp
  type(daily_atmospheric_demand_parameters_t) :: demand_parameters
  type(traditional_pm_weather_t) :: pm_weather
  type(reference_et_demand_canopy_view_t) :: demand_canopy
  type(reference_et_demand_result_t) :: atmospheric_demand
  integer :: ios,status,day_index,failures,wstatus,max_hours,expected_hours,isub,demand_status,day_of_year
  real(real64) :: precip_mm,temp_c,dew_c,shortwave_mj_m2,wind10,et0,t0,t1,max_residual,dt_day,evap_scale
  real(real64) :: tmin_day,tmax_day,radiation_kj_day,vapour_pressure_kpa,wind2
  real(real64) :: hour_t0,hour_t1,segment_dt,hour_residual,hour_in,hour_out
  real(real64) :: total_precip,total_et0,total_in,total_out
  integer :: hour_accepted,hour_solver_rejections,hour_temporal_rejections

  call get_command_argument(1,met_path)
  call get_command_argument(2,out_path)
  call get_command_argument(3,max_hours_arg)
  call get_command_argument(4,evap_scale_arg)
  max_hours=0
  evap_scale=1.0_real64
  if(len_trim(max_hours_arg)>0) then
    read(max_hours_arg,*,iostat=ios) max_hours
    if(ios/=0 .or. max_hours<0) error stop 'invalid max_hours'
  end if
  if(len_trim(evap_scale_arg)>0) then
    read(evap_scale_arg,*,iostat=ios) evap_scale
    if(ios/=0 .or. evap_scale<0.0_real64 .or. evap_scale>1.0_real64) error stop 'invalid evap_scale'
  end if
  if(len_trim(met_path)==0 .or. len_trim(out_path)==0) error stop 'usage: pilot weather.csv output.csv [max_hours] [evap_scale]'

  demand_parameters%mode=0
  demand_parameters%soil_factor_enabled=.false.
  demand_parameters%soil_factor=1.0_real64
  demand_parameters%crop_factor=1.0_real64
  demand_parameters%pond_factor=1.0_real64
  demand_parameters%site%latitude_degrees=51.359254426505835_real64
  demand_parameters%site%altitude_m=25.0_real64
  demand_parameters%site%wind_measurement_height_m=2.0_real64
  demand_parameters%site%humidity_measurement_height_m=2.0_real64
  demand_parameters%site%angstrom_a=0.25_real64
  demand_parameters%site%angstrom_b=0.50_real64
  demand_parameters%site%wind_function_factor=1.0_real64
  demand_parameters%site%soil_surface_resistance_s_m=0.0_real64
  demand_parameters%canopy%crop_emerged=.false.
  demand_parameters%canopy%lai=0.0_real64
  demand_parameters%canopy%vegetation_cover_fraction=0.0_real64
  demand_parameters%canopy%cofab_cm=0.0_real64
  demand_parameters%canopy%albedo=0.23_real64
  demand_parameters%canopy%dry_canopy_resistance_s_m=70.0_real64
  demand_parameters%canopy%wet_canopy_resistance_s_m=0.0_real64
  demand_parameters%canopy%co2_transpiration_factor=1.0_real64
  demand_parameters%canopy%use_crop_height_for_aerodynamics=.false.
  demand_parameters%canopy%crop_height_cm=0.0_real64
  call require(demand_parameters%ready(),'daily PM demand parameters')
  demand_canopy%crop_emerged=.false.
  demand_canopy%vegetation_cover_fraction=0.0_real64
  demand_canopy%crop_factor=0.0_real64
  demand_canopy%co2_transpiration_factor=1.0_real64

  call initialize_config(config)
  call app%initialize(config,status)
  call require(status==FMR_APP_BOOT_OK,'bootstrap initialize')

  open(UNIT_MET,file=trim(met_path),status='old',action='read',iostat=ios); call require(ios==0,'open weather')
  open(UNIT_OUT,file=trim(out_path),status='replace',action='write',iostat=ios); call require(ios==0,'open output')
  read(UNIT_MET,'(A)',iostat=ios) line; call require(ios==0,'read weather header')
  write(UNIT_OUT,'(A)') 'time,precip_mm_hour,et0_mm_day,accepted_substeps,solver_rejections,temporal_rejections,mass_residual_cm,total_in_cm,total_out_cm'
  dt_day=1.0_real64/24.0_real64

  day_index=0; failures=0; max_residual=0.0_real64
  total_precip=0.0_real64; total_et0=0.0_real64; total_in=0.0_real64; total_out=0.0_real64
  do
    read(UNIT_MET,'(A)',iostat=ios) line
    if(ios<0) exit
    call require(ios==0,'read weather row')
    read(line,*,iostat=ios) ds,precip_mm,temp_c,dew_c,shortwave_mj_m2,wind10,et0, &
         tmin_day,tmax_day,radiation_kj_day,vapour_pressure_kpa,wind2,day_of_year
    call require(ios==0,'parse weather row')
    pm_weather%day_of_year=day_of_year
    pm_weather%radiation_j_m2_d=radiation_kj_day*1000.0_real64
    pm_weather%minimum_air_temperature_c=tmin_day
    pm_weather%maximum_air_temperature_c=tmax_day
    pm_weather%vapour_pressure_kpa=vapour_pressure_kpa
    pm_weather%wind_speed_m_s=wind2
    pm_weather%gross_rain_cm_d=0.0_real64
    call evaluate_daily_atmospheric_demand(demand_parameters,pm_weather,et0,demand_canopy,atmospheric_demand,demand_status)
    call require(demand_status==REF_ET_DEMAND_OK,'SWAP traditional PM daily demand')
    day_index=day_index+1
    hour_t0=real(day_index-1,real64)*dt_day
    hour_t1=real(day_index,real64)*dt_day
    segment_dt=dt_day/real(NSUB,real64)
    call initialize_interception_window(int(1000000+day_index,int64),hour_t0,hour_t1,precip_mm/10.0_real64,window,wstatus)
    call require(wstatus==INTWIN_OK,'hourly precipitation source window')

    rp%gross_rain_cm_per_day=(precip_mm/10.0_real64)/dt_day
    rp%surface_irrigation_cm_per_day=0.0_real64
    rp%surface_irrigation_is_intercepted=.false.
    rp%vegetation_cover_fraction=0.0_real64
    rp%canopy_storage_capacity_cm=0.0_real64
    rp%interception_evaporation_capacity_cm_per_day=0.0_real64
    rp%potential_transpiration_dry_cm_per_day=0.0_real64
    rp%potential_transpiration_wet_cm_per_day=0.0_real64
    rp%interval_days=segment_dt

    hour_residual=0.0_real64
    hour_in=0.0_real64
    hour_out=0.0_real64
    hour_accepted=0
    hour_solver_rejections=0
    hour_temporal_rejections=0

    do isub=1,NSUB
      t0=hour_t0+real(isub-1,real64)*segment_dt
      if(isub==NSUB) then
        t1=hour_t1
      else
        t1=hour_t0+real(isub,real64)*segment_dt
      end if
      allocate(forcing(1))
      forcing(1)=config%tiles(1)%base_forcing
      allocate(forcing(1)%rutter)
      forcing(1)%rutter%source_window=window
      forcing(1)%rutter%process=rp
      forcing(1)%rutter%potential_bare_soil_evaporation_cm_per_day=evap_scale*atmospheric_demand%potential_soil_evaporation_cm_per_day
      forcing(1)%rutter%potential_pond_evaporation_cm_per_day=evap_scale*atmospheric_demand%potential_pond_evaporation_cm_per_day
      forcing(1)%rutter%ponding_max_cm=1.0_real64
      forcing(1)%rutter%runoff_resistance_day=0.1_real64
      forcing(1)%rutter%runoff_exponent=1.0_real64

      call app%run_standalone_with_forcing(t0,t1,forcing,results,status)
      if(status/=FMR_APP_BOOT_OK .or. .not.allocated(results) .or. size(results)/=1) then
        failures=failures+1
        call app%copy_committed_for_crop(1,accepted_snapshot,snapshot_status)
        if(snapshot_status==FMR_APP_BOOT_OK) then
          call accepted_snapshot%snapshot(accepted_physical,snapshot_ok)
          if(snapshot_ok) then
            select type(accepted=>accepted_physical)
            class is(fmr_b110_physical_state_t)
              if(accepted%active_nodes>0.and.allocated(accepted%pressure_head).and.allocated(accepted%water_content)) then
                write(*,'(A,1X,A,5(1X,ES24.16))') 'KALMTHOUT_ACCEPTED_DRY_STATE', trim(ds), &
                     accepted%pressure_head(1),accepted%water_content(1),accepted%ponding_depth, &
                     accepted%groundwater_level,atmospheric_demand%potential_soil_evaporation_cm_per_day
              end if
            end select
          end if
        end if
        write(*,'(A,1X,A,1X,I0,1X,I0,6(1X,F12.6))') 'KALMTHOUT_SUBHOUR_FAIL',trim(ds),isub,status, &
             precip_mm,temp_c,dew_c,shortwave_mj_m2,wind10,et0
        if(allocated(results)) then
          write(*,'(A,1X,I0,1X,A,3(1X,L1),4(1X,I0),3(1X,ES18.10),1X,A,1X,I0)') &
               'KALMTHOUT_RESULT_DEBUG',size(results),trim(results(1)%admission_status), &
               results(1)%admitted,results(1)%completed,results(1)%committed,results(1)%accepted_substeps, &
               results(1)%solver_rejections,results(1)%temporal_rejections,results(1)%mass_rejections, &
               results(1)%mass%residual,results(1)%mass%total_in,results(1)%mass%total_out, &
               trim(results(1)%solver_route),results(1)%solver_status
        end if
        if(allocated(forcing)) deallocate(forcing)
        if(allocated(results)) deallocate(results)
        exit
      end if
      hour_residual=max(hour_residual,abs(results(1)%mass%residual))
      hour_in=hour_in+results(1)%mass%total_in
      hour_out=hour_out+results(1)%mass%total_out
      hour_accepted=hour_accepted+results(1)%accepted_substeps
      hour_solver_rejections=hour_solver_rejections+results(1)%solver_rejections
      hour_temporal_rejections=hour_temporal_rejections+results(1)%temporal_rejections
      deallocate(forcing)
      if(allocated(results)) deallocate(results)
    end do
    if(failures>0) exit

    max_residual=max(max_residual,hour_residual)
    total_precip=total_precip+precip_mm
    total_et0=total_et0+et0*dt_day
    total_in=total_in+hour_in
    total_out=total_out+hour_out
    write(UNIT_OUT,'(A,",",F12.6,",",F12.6,",",I0,",",I0,",",I0,",",ES18.10,",",ES18.10,",",ES18.10)') &
         trim(ds),precip_mm,et0,hour_accepted,hour_solver_rejections,hour_temporal_rejections, &
         hour_residual,hour_in,hour_out
    if(max_hours>0 .and. day_index>=max_hours) exit
  end do
  close(UNIT_MET); close(UNIT_OUT)
  call app%close(status); call require(status==FMR_APP_BOOT_OK,'clean close')
  call require(failures==0,'no failed days')
  expected_hours=24120
  if(max_hours>0) expected_hours=max_hours
  call require(day_index==expected_hours,'complete requested hourly forcing window')
  call require(max_residual<=HARD_MASS_GATE,'hard mass gate')
  write(*,'(A,I0)') 'KALMTHOUT_HOURS=',day_index
  write(*,'(A,F14.3)') 'KALMTHOUT_TOTAL_PRECIP_MM=',total_precip
  write(*,'(A,F14.3)') 'KALMTHOUT_TOTAL_ET0_MM=',total_et0
  write(*,'(A,F10.4)') 'KALMTHOUT_EVAP_SCALE=',evap_scale
  write(*,'(A,ES18.10)') 'KALMTHOUT_MAX_MASS_RESIDUAL_CM=',max_residual
  write(*,'(A,ES18.10)') 'KALMTHOUT_LEDGER_TOTAL_IN_CM=',total_in
  write(*,'(A,ES18.10)') 'KALMTHOUT_LEDGER_TOTAL_OUT_CM=',total_out
  write(*,'(A)') 'KALMTHOUT_SWAP5_PILOT=PASS'

contains
  subroutine initialize_config(value)
    type(fmr_production_application_config_t),intent(out)::value
    real(real64)::conductivity0
    value%initial_time=0.0_real64
    value%numerical%transaction%temporal_tolerance=0.03_real64
    value%numerical%transaction%mass_tolerance=HARD_MASS_GATE
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=40
    value%numerical%max_committed_substeps=10000
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(1))
    value%tiles(1)%tile_id=6007305690770_int64
    value%tiles(1)%ledger_id=7101001_int64
    value%tiles(1)%template%template_id=6102001_int64
    value%tiles(1)%template%physics_topology_id=6102101_int64
    value%tiles(1)%template%vertical_layout_id=6102201_int64
    value%tiles(1)%template%state_layout_id=6102301_int64
    value%tiles(1)%template%solver_interface_id=6102401_int64
    value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RUTTER
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters,value%tiles(1)%initial_state,value%tiles(1)%base_forcing,conductivity0)
    value%tiles(1)%initial_rutter_canopy_storage_cm=0.0_real64
  end subroutine

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=6200001_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine

  subroutine initialize_state_and_forcing(p,state,base,conductivity0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::base
    real(real64),intent(out)::conductivity0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,1.0_real64)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh); conductivity0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    base%top_flux=0.0_real64; base%top_head=H0_CM; base%bottom_flux=0.0_real64; base%bottom_head=-100.0_real64
    allocate(base%drainage_flux_by_level(2,numnod),base%subsurface_irrigation_source(numnod),base%root_extraction_sink(numnod))
    base%drainage_flux_by_level=0.0_real64; base%subsurface_irrigation_source=0.0_real64; base%root_extraction_sink=0.0_real64
  end subroutine

  subroutine require(ok,msg)
    logical,intent(in)::ok; character(len=*),intent(in)::msg
    if(.not.ok) then; write(*,'(A,1X,A)') 'KALMTHOUT_FAIL',trim(msg); error stop 1; end if
  end subroutine
end program kalmthout_swap5_daily_pilot
