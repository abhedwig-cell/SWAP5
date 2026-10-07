program kalmthout_swap5_daily_pilot
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_NONE
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: HARD_MASS_GATE=1.0e-10_real64
  real(real64), parameter :: H0_CM=-75.0_real64
  integer, parameter :: UNIT_MET=10, UNIT_OUT=20
  character(len=256) :: met_path, out_path, line, ds
  type(fmr_production_application_config_t) :: config
  type(fmr_production_application_bootstrap_t) :: app
  type(fmr_b110_physical_forcing_t), allocatable :: forcing(:)
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  integer :: ios,status,day_index,failures
  real(real64) :: precip_mm,temp_c,dew_c,shortwave_w_m2,wind10,et0,t0,t1,max_residual,dt_day
  real(real64) :: total_precip,total_et0,total_in,total_out

  call get_command_argument(1,met_path)
  call get_command_argument(2,out_path)
  if(len_trim(met_path)==0 .or. len_trim(out_path)==0) error stop 'usage: pilot weather.csv output.csv'

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
    read(line,*,iostat=ios) ds,precip_mm,temp_c,dew_c,shortwave_w_m2,wind10,et0
    call require(ios==0,'parse weather row')
    day_index=day_index+1; t0=real(day_index-1,real64)*dt_day; t1=real(day_index,real64)*dt_day
    allocate(forcing(1))
    forcing(1)=config%tiles(1)%base_forcing
    ! MVP smoke route: prescribed atmospheric water flux. In the Reference
    ! convention a downward infiltration flux is negative. This deliberately
    ! excludes ET/interception/runoff until the long Richards/state chain is
    ! shown to execute for the complete observed forcing period.
    forcing(1)%top_flux=-precip_mm/10.0_real64

    call app%run_standalone_with_forcing(t0,t1,forcing,results,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.allocated(results) .or. size(results)/=1) then
      failures=failures+1
      write(*,'(A,1X,A,1X,I0,6(1X,F12.6))') 'KALMTHOUT_HOUR_FAIL',trim(ds),status, &
           precip_mm,temp_c,dew_c,shortwave_w_m2,wind10,et0
      if(allocated(results)) then
        write(*,'(A,1X,I0,1X,A,3(1X,L1),4(1X,I0),3(1X,ES18.10),1X,A,1X,I0)') &
             'KALMTHOUT_RESULT_DEBUG',size(results),trim(results(1)%admission_status), &
             results(1)%admitted,results(1)%completed,results(1)%committed,results(1)%accepted_substeps, &
             results(1)%solver_rejections,results(1)%temporal_rejections,results(1)%mass_rejections, &
             results(1)%mass%residual,results(1)%mass%total_in,results(1)%mass%total_out, &
             trim(results(1)%solver_route),results(1)%solver_status
      end if
      exit
    end if
    max_residual=max(max_residual,abs(results(1)%mass%residual))
    total_precip=total_precip+precip_mm
    total_et0=total_et0+et0*dt_day
    total_in=total_in+results(1)%mass%total_in
    total_out=total_out+results(1)%mass%total_out
    write(UNIT_OUT,'(A,",",F12.6,",",F12.6,",",I0,",",I0,",",I0,",",ES18.10,",",ES18.10,",",ES18.10)') &
         trim(ds),precip_mm,et0,results(1)%accepted_substeps,results(1)%solver_rejections, &
         results(1)%temporal_rejections,results(1)%mass%residual,results(1)%mass%total_in,results(1)%mass%total_out
    deallocate(forcing)
    if(allocated(results)) deallocate(results)
  end do
  close(UNIT_MET); close(UNIT_OUT)
  call app%close(status); call require(status==FMR_APP_BOOT_OK,'clean close')
  call require(failures==0,'no failed days')
  call require(day_index==24120,'complete hourly 2024-01-01 through 2026-10-01')
  call require(max_residual<=HARD_MASS_GATE,'hard mass gate')
  write(*,'(A,I0)') 'KALMTHOUT_HOURS=',day_index
  write(*,'(A,F14.3)') 'KALMTHOUT_TOTAL_PRECIP_MM=',total_precip
  write(*,'(A,F14.3)') 'KALMTHOUT_TOTAL_ET0_MM=',total_et0
  write(*,'(A,ES18.10)') 'KALMTHOUT_MAX_MASS_RESIDUAL_CM=',max_residual
  write(*,'(A,ES18.10)') 'KALMTHOUT_LEDGER_TOTAL_IN_CM=',total_in
  write(*,'(A,ES18.10)') 'KALMTHOUT_LEDGER_TOTAL_OUT_CM=',total_out
  write(*,'(A)') 'KALMTHOUT_SWAP5_DAILY_PILOT=PASS'

contains
  subroutine initialize_config(value)
    type(fmr_production_application_config_t),intent(out)::value
    real(real64)::conductivity0
    value%initial_time=0.0_real64
    value%numerical%transaction%temporal_mode=TX_TEMPORAL_NONE
    value%numerical%transaction%temporal_tolerance=0.0_real64
    value%numerical%transaction%mass_tolerance=HARD_MASS_GATE
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=20
    value%numerical%max_committed_substeps=512
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(1))
    value%tiles(1)%tile_id=5977505689750_int64
    value%tiles(1)%ledger_id=7101001_int64
    value%tiles(1)%template%template_id=6102001_int64
    value%tiles(1)%template%physics_topology_id=6102101_int64
    value%tiles(1)%template%vertical_layout_id=6102201_int64
    value%tiles(1)%template%state_layout_id=6102301_int64
    value%tiles(1)%template%solver_interface_id=6102401_int64
    value%tiles(1)%template%optional_state_layout_id=0_int64
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters,value%tiles(1)%initial_state,value%tiles(1)%base_forcing,conductivity0)
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
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
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
