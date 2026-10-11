program test_crop_file_weather_production
  use iso_fortran_env, only: real64,int64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE,FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t,fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t,fmr_application_crop_daystart_controls_t,FMR_APP_BOOT_OK, &
       FMR_APP_BOOT_WEATHER_REJECTED,FMR_APP_BOOT_CROP_PREFLIGHT_FAILED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_swap_daily_weather_file_adapter, only: swap_daily_weather_record_t,read_swap_daily_weather_file, &
       swap_weather_calendar_day,SWAP_WEATHER_FILE_OK
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_crop_certified_daily_preflight, only: crop_certified_daily_preflight_t
  use mod_fmr_crop_certified_germination_moisture, only: sample_certified_committed_germination_head,CROP_CERT_GERM_OK
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t
  use mod_reference_et_demand_process, only: reference_et_demand_canopy_view_t
  implicit none
  real(real64),parameter::T0=729774.0_real64,T1=T0+1.0_real64,H0_CM=-75.0_real64,HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t)::config
  type(fmr_production_application_bootstrap_t)::app
  type(fmr_application_crop_daystart_controls_t)::controls,bad_controls
  type(swap_daily_weather_record_t)::record,old_record,altered,empty
  type(kernel_committed_state_t)::soil
  type(crop_certified_daily_preflight_t)::candidate,repeated
  type(ppa_wu03_common_forcing_config_t)::forcing_config
  type(reference_et_demand_canopy_view_t)::canopy
  type(fmr_serialized_column_result_t),allocatable::results(:)
  integer(int64),allocatable::revisions(:)
  character(1024)::path,altered_path,bad_path
  real(real64)::k,day,tmin,tmax,rain,etref,hgerm,before_time,previous_storage,initial_head
  integer::s,d,i
  logical::available
  call get_command_argument(1,path);call get_command_argument(2,altered_path);call get_command_argument(3,bad_path)
  call require(swap_weather_calendar_day(1999,1,20)==int(T0),'explicit Gregorian epoch')
  call require(swap_weather_calendar_day(2000,2,29)>0.and.swap_weather_calendar_day(1900,2,29)==0,'leap calendar')
  call read_swap_daily_weather_file(trim(bad_path),1999,1,20,record,s)
  call require(s/=SWAP_WEATHER_FILE_OK.and..not.record%ready(),'malformed daily record rejected')
  call initialize_application_config(config,k)
  config%file_weather_daystart=.true.
  ! Use the admitted nonsteady Richards history certificate (ROOT-HYD01),
  ! not the base full/half bit-identity comparator used by steady WU03.
  config%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  allocate(config%tiles(1)%initial_right_derivative(numnod))
  config%tiles(1)%initial_right_derivative=0.0_real64
  config%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  config%numerical%transaction%temporal_tolerance=0.0_real64
  config%numerical%model_temporal_indicator_budget_available=.true.
  config%numerical%model_temporal_indicator_budget=1.0e-5_real64
  config%numerical%transaction%max_retries=16
  config%tiles(1)%parameters%head_abs_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%head_rel_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%ponding_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%max_iterations=16
  config%tiles(1)%parameters%max_backtracking=8
  config%tiles(1)%parameters%min_step_duration=1.0e-8_real64
  config%tiles(1)%parameters%compartment_balance_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%total_balance_tolerance=HARD_MASS_GATE
  ! Real atmospheric forcing is nonsteady. The accepted production mass
  ! threshold remains unchanged; no forcing is reverse-engineered to steady.
  config%numerical%max_committed_substeps=128
  call app%initialize(config,s);call require(s==FMR_APP_BOOT_OK,'production bootstrap')
  controls%germ_mode=2
  controls%zprep=-1.0_real64;controls%zsow=-1.0_real64
  controls%ztempsow=-1.0_real64;controls%zgerm=-1.0_real64
  call app%begin_weather_day(empty,controls,candidate,s)
  call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.candidate%valid,'unconstructed file record rejected')
  initial_head=H0_CM;previous_storage=0.0_real64
  do d=20,23
    call read_swap_daily_weather_file(trim(path),1999,1,d,record,s)
    call require(s==SWAP_WEATHER_FILE_OK.and.record%ready(),'actual historical daily weather file read')
    call record%values(day,tmin,tmax,rain,etref,available)
    call require(available.and.day==T0+real(d-20,real64),'calendar record time binding')
    if(d==20) call require(tmin==3.2_real64.and.tmax==7.7_real64.and.rain==0.0_real64.and. &
         etref==0.2355_real64,'authentic Andelst first day input')
    call app%copy_committed_for_crop(1,soil,s)
    call require(s==FMR_APP_BOOT_OK,'read-only actual committed carrier')
    call soil%current_time(before_time,available)
    call require(available.and.before_time==day,'previous accepted soil at current daystart')
    call sample_certified_committed_germination_head(soil,soil%current_lineage_id(), &
         soil%current_revision(),day,controls%zgerm,hgerm,s)
    call require(s==CROP_CERT_GERM_OK,'certified real production daystart head')
    if(d==20) then
      bad_controls=controls;bad_controls%swsow=1
      call app%begin_weather_day(record,bad_controls,candidate,s)
      call require(s==FMR_APP_BOOT_CROP_PREFLIGHT_FAILED.and..not.candidate%valid,'heat-off simulated sowing fails closed')
    end if
    call app%begin_weather_day(record,controls,candidate,s)
    call require(s==FMR_APP_BOOT_OK.and.candidate%valid,'production meteorology before future hydrology acceptance')
    call require(candidate%hgerm==hgerm,'crop reads actual same-owner accepted soil')
    call require(candidate%germination%next_temperature_sum>0.0_real64,'file TAV drives germination calculation')
    call app%begin_weather_day(record,controls,repeated,s)
    call require(s==FMR_APP_BOOT_OK.and.repeated%germination%next_temperature_sum== &
         candidate%germination%next_temperature_sum,'retry daystart does not double-add')
    if(d==20) then
      call read_swap_daily_weather_file(trim(altered_path),1999,1,d,altered,s)
      call require(s==SWAP_WEATHER_FILE_OK,'altered input parse remains valid')
      call app%begin_weather_day(altered,controls,repeated,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'same TAV different Tmin Tmax input conflict')
      call app%run_weather_interval(altered,day,day+0.5_real64,forcing_config,canopy,results,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(results),'alternate file cannot drive hydrology')
    end if
    do i=0,1
      call app%run_weather_interval(record,day+real(i,real64)*0.5_real64, &
           day+real(i+1,real64)*0.5_real64,forcing_config,canopy,results,s)
      if(s/=FMR_APP_BOOT_OK) then
        print *, 'RUN_STATUS',s,d,i
        if(allocated(results)) then
          print *, 'RUNTIME_COMPLETED',results(1)%completed,results(1)%committed
          print *, 'RUNTIME_DIAGNOSTICS',results(1)%kernel_status,results(1)%admission_status, &
               results(1)%solver_status,results(1)%solver_rejections,results(1)%temporal_rejections, &
               results(1)%mass_rejections,results(1)%mass%residual
        end if
      end if
      call require(s==FMR_APP_BOOT_OK,'file-derived hydrological production interval')
      call require(size(results)==1.and.results(1)%completed.and.results(1)%committed,'actual FKT accept')
      call require(abs(results(1)%mass%residual)<=HARD_MASS_GATE,'unchanged hard water mass gate')
      if(d/=20.or.i/=0) call require(abs(results(1)%mass%storage_start-previous_storage)<=HARD_MASS_GATE, &
           'continuous hydrological accepted storage')
      previous_storage=results(1)%mass%storage_end
      call app%copy_committed_revisions(revisions,s)
      call require(s==FMR_APP_BOOT_OK.and.revisions(1)>=int((d-20)*2+i+1,int64),'actual accepted revisions')
    end do
    call app%run_weather_interval(record,day,day+0.5_real64,forcing_config,canopy,results,s)
    call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(results),'accepted interval duplicate rejected')
    call app%begin_weather_day(record,controls,repeated,s)
    call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'daystart cannot be applied after same-day hydrology')
    if(d>20) then
      call app%run_weather_interval(old_record,day+1.0_real64,day+1.5_real64,forcing_config,canopy,results,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'old meteorology rejected after accepted midnight')
    end if
    old_record=record
    write(*,'(a,i2,a,f10.5,a,f12.7)') 'CROP_FILE_WEATHER_DAY=',d,' TAV=',(tmax+tmin)*0.5_real64, &
         ' HEAD=',hgerm
  end do
  call app%copy_committed_for_crop(1,soil,s)
  call sample_certified_committed_germination_head(soil,soil%current_lineage_id(), &
       soil%current_revision(),T0+4.0_real64,controls%zgerm,hgerm,s)
  call require(s==CROP_CERT_GERM_OK.and.abs(hgerm-initial_head)>1.0e-6_real64,'physical soil trajectory actually changes')
  call app%close(s);call require(s==FMR_APP_BOOT_OK,'production owner close')
  print '(a)', 'CROP_FILE_WEATHER_AUTHENTIC_SHARED_RECORD=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PRIOR_ACCEPTED_DAYSTART=PASS'
  print '(a)', 'CROP_FILE_WEATHER_FOUR_DAY_PHYSICAL_MASS_CONTINUITY=PASS'
  print '(a)', 'CROP_FILE_WEATHER_RETRY_CONFLICT_DUPLICATE=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PRODUCTION=PASS'
contains
  subroutine initialize_application_config(value, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 630101_int64
    value%tiles(1)%ledger_id = 730101_int64
    value%tiles(1)%template%template_id = 630201_int64
    value%tiles(1)%template%physics_topology_id = 630210_int64
    value%tiles(1)%template%vertical_layout_id = 630220_int64
    value%tiles(1)%template%state_layout_id = 630230_int64
    value%tiles(1)%template%solver_interface_id = 630240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 640001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = H0_CM
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok) then
      print *, 'CROP_FILE_WEATHER_FAIL ',message
      error stop 1
    end if
  end subroutine
end program
