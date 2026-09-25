program test_fahl49_application_scale
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_direct_retention_core, only: b110_direct_retention_pool_stats
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: T0=0.0_real64, T1=0.25_real64, H0=-75.0_real64, TOL=1.0e-12_real64
  type(fmr_production_application_config_t) :: config
  type(fmr_production_application_bootstrap_t) :: app
  type(fmr_serialized_column_result_t), allocatable :: results(:)
  integer(int64) :: c0,c1,rate
  real(real64) :: init_s,run_s,max_residual
  integer :: n,status,rep,entries,builds,hits
  integer(int64) :: payload
  logical :: frozen,direct_active
  integer :: solver_calls,accepted_substeps,nonlinear_iterations,jacobian_builds,linear_solves
  integer :: headcalc_calls,internal_retries,backtracking_attempts,completed_count,committed_count
  character(len=32) :: arg,mode

  call get_command_argument(1,mode)
  call get_command_argument(2,arg); read(arg,*) n
  call get_command_argument(3,arg); read(arg,*) rep
  select case(trim(mode))
  case('analytical'); direct_active=.false.
  case('direct'); direct_active=.true.
  case default; error stop 'F-AHL49 mode must be analytical or direct'
  end select
  if(n<=0 .or. rep<=0) error stop 'F-AHL49 requires N>0 and rep>0'

  call build_config(config,n,direct_active)
  call system_clock(c0,rate)
  call app%initialize(config,status)
  call system_clock(c1)
  if(status/=FMR_APP_BOOT_OK .or. .not.app%ready()) error stop 'F-AHL49 bootstrap failed'
  if(direct_active) then
    call b110_direct_retention_pool_stats(entries,builds,hits,payload,frozen)
    if(entries/=1 .or. builds/=1 .or. hits/=n-1 .or. payload/=6240_int64 .or. .not.frozen) &
         error stop 'F-AHL49 pool ownership gate'
  else
    entries=0;builds=0;hits=0;payload=0_int64;frozen=.false.
  end if
  init_s=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  call app%run_standalone(T0,T1,results,status)
  call system_clock(c1)
  if(status/=FMR_APP_BOOT_OK) error stop 'F-AHL49 standalone run failed'
  run_s=real(c1-c0,real64)/real(rate,real64)
  if(.not.allocated(results) .or. size(results)/=n) error stop 'F-AHL49 result shape'
  if(.not.all(results%completed) .or. .not.all(results%committed)) error stop 'F-AHL49 incomplete result'

  completed_count=count(results%completed)
  committed_count=count(results%committed)
  solver_calls=count(results%solver_executed)
  accepted_substeps=sum(results%accepted_substeps)
  nonlinear_iterations=sum(results%solver_nonlinear_iterations)
  jacobian_builds=sum(results%solver_jacobian_builds)
  linear_solves=sum(results%solver_linear_solves)
  headcalc_calls=sum(results%solver_headcalc_calls)
  internal_retries=sum(results%solver_internal_retries)
  backtracking_attempts=sum(results%solver_backtracking_attempts)
  max_residual=maxval(abs(results%mass%residual))
  if(max_residual>TOL) error stop 'F-AHL49 hard mass gate'

  write(*,'(*(g0))') 'FAHL49_APP|MODE=',trim(mode),'|N=',n,'|REP=',rep,'|INIT=',init_s,'|RUN=',run_s, &
       '|NS_PER_COLUMN=',1.0e9_real64*run_s/real(n,real64),'|ENTRIES=',entries,'|BUILDS=',builds, &
       '|HITS=',hits,'|PAYLOAD=',payload,'|FROZEN=',frozen,'|COMPLETED=',completed_count,'|COMMITTED=',committed_count, &
       '|SOLVER_CALLS=',solver_calls,'|ACCEPTED=',accepted_substeps,'|ITER=',nonlinear_iterations,'|JAC=',jacobian_builds, &
       '|LIN=',linear_solves,'|HEADCALC=',headcalc_calls,'|RETRIES=',internal_retries,'|BACKTRACK=',backtracking_attempts, &
       '|MASS=',max_residual
  write(*,'(A)') 'FAHL49_APP=PASS'
  call app%close(status)
  if(status/=FMR_APP_BOOT_OK) error stop 'F-AHL49 close failed'

contains

  subroutine build_config(value,count,use_direct)
    type(fmr_production_application_config_t),intent(out) :: value
    integer,intent(in) :: count
    logical,intent(in) :: use_direct
    integer :: k
    real(real64) :: conductivity0
    value%initial_time=T0
    value%numerical%transaction%mass_tolerance=TOL
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=2
    value%numerical%max_committed_substeps=8
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(count))
    do k=1,count
      value%tiles(k)%tile_id=1000000_int64+int(k,int64)
      value%tiles(k)%ledger_id=2000000_int64+int(k,int64)
      value%tiles(k)%template%template_id=3000000_int64+int(k,int64)
      value%tiles(k)%template%physics_topology_id=3000010_int64
      value%tiles(k)%template%vertical_layout_id=3000020_int64
      value%tiles(k)%template%state_layout_id=3000030_int64
      value%tiles(k)%template%solver_interface_id=3000040_int64
      value%tiles(k)%template%optional_state_layout_id=0_int64
      value%tiles(k)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
      value%tiles(k)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_parameters(value%tiles(k)%parameters,4000000_int64+int(k,int64),use_direct)
      call initialize_state_forcing(value%tiles(k)%parameters,value%tiles(k)%initial_state, &
           value%tiles(k)%base_forcing,conductivity0)
      value%tiles(k)%groundwater_datum%available=.true.
      value%tiles(k)%groundwater_datum%datum_id=5000000_int64+int(k,int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m=0.0_real64
    end do
  end subroutine build_config

  subroutine initialize_parameters(p,id,use_direct)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    integer(int64),intent(in) :: id
    logical,intent(in) :: use_direct
    integer :: k
    p%parameter_set_id=id
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.02_real64
      p%cofgen(2,k)=0.427494_real64
      p%cofgen(3,k)=31.225016_real64
      p%cofgen(4,k)=0.021659_real64
      p%cofgen(5,k)=0.98087_real64
      p%cofgen(6,k)=1.734737_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5
    p%direct_retention_active=use_direct
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=16
    p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=TOL
    p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL
    p%head_rel_tolerance=TOL
    p%ponding_tolerance=TOL
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    p%soil_temperature_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state_forcing(p,state,forcing,k0)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(fmr_b110_physical_forcing_t),intent(out) :: forcing
    real(real64),intent(out) :: k0
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,T1-T0)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    forcing%top_flux=-k0
    forcing%top_head=H0
    forcing%bottom_flux=-k0
    forcing%bottom_head=-50.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_state_forcing
end program test_fahl49_application_scale
