program test_fpe_approx02_a2_application_sequence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64),parameter :: exact_tol=1.0e-12_real64,a2_tol=1.0e-4_real64
  real(real64),parameter :: dt=1.0e-4_real64,h0=-10.0_real64
  integer,parameter :: nsteps=20
  type(fmr_production_application_config_t) :: exact_cfg,a2_cfg
  type(fmr_production_application_bootstrap_t) :: exact_app,a2_app
  type(fmr_serialized_column_result_t),allocatable :: result(:)
  real(real64) :: exact_storage(nsteps),exact_net(nsteps)
  real(real64) :: exact_seconds,a2_seconds
  real(real64) :: exact_cum_net,a2_cum_net,exact_cum_storage,a2_cum_storage
  real(real64) :: exact_max_mass,a2_max_mass,max_storage_abs,max_storage_rel,max_net_abs,max_net_rel
  integer :: exact_nonlinear,a2_nonlinear,exact_substeps,a2_substeps,exact_retries,a2_retries
  integer :: exact_backtrack,a2_backtrack,step,status
  character(len=64) :: arg
  integer(int64) :: c0,c1,rate

  dt=1.0e-4_real64; top_factor=-1.0_real64
  if(command_argument_count()>=1)then
    call get_command_argument(1,arg); read(arg,*) dt
  end if
  if(command_argument_count()>=2)then
    call get_command_argument(2,arg); read(arg,*) top_factor
  end if
  if(dt<=0.0_real64) error stop 'invalid dt'

  call build_config(exact_cfg,exact_tol)
  call build_config(a2_cfg,a2_tol)
  call exact_app%initialize(exact_cfg,status)
  if(status/=FMR_APP_BOOT_OK .or. .not.exact_app%ready()) error stop 'exact app bootstrap'
  call a2_app%initialize(a2_cfg,status)
  if(status/=FMR_APP_BOOT_OK .or. .not.a2_app%ready()) error stop 'A2 app bootstrap'

  exact_cum_net=0.0_real64; exact_cum_storage=0.0_real64; exact_max_mass=0.0_real64
  exact_nonlinear=0; exact_substeps=0; exact_retries=0; exact_backtrack=0
  call system_clock(c0,rate)
  do step=1,nsteps
    call exact_app%run_standalone(real(step-1,real64)*dt,real(step,real64)*dt,result,status)
    call verify_result('exact',step,status,result)
    exact_storage(step)=result(1)%mass%storage_end
    exact_net(step)=result(1)%mass%total_in-result(1)%mass%total_out
    exact_cum_net=exact_cum_net+exact_net(step)
    exact_cum_storage=exact_cum_storage+result(1)%mass%storage_change
    exact_max_mass=max(exact_max_mass,abs(result(1)%mass%residual))
    exact_nonlinear=exact_nonlinear+result(1)%solver_nonlinear_iterations
    exact_substeps=exact_substeps+result(1)%accepted_substeps
    exact_retries=exact_retries+result(1)%solver_internal_retries
    exact_backtrack=exact_backtrack+result(1)%solver_backtracking_attempts
  end do
  call system_clock(c1)
  exact_seconds=real(c1-c0,real64)/real(rate,real64)

  a2_cum_net=0.0_real64; a2_cum_storage=0.0_real64; a2_max_mass=0.0_real64
  a2_nonlinear=0; a2_substeps=0; a2_retries=0; a2_backtrack=0
  max_storage_abs=0.0_real64; max_storage_rel=0.0_real64
  max_net_abs=0.0_real64; max_net_rel=0.0_real64
  call system_clock(c0)
  do step=1,nsteps
    call a2_app%run_standalone(real(step-1,real64)*dt,real(step,real64)*dt,result,status)
    call verify_result('A2',step,status,result)
    max_storage_abs=max(max_storage_abs,abs(result(1)%mass%storage_end-exact_storage(step)))
    max_storage_rel=max(max_storage_rel,abs(result(1)%mass%storage_end-exact_storage(step))/ &
         max(abs(exact_storage(step)),1.0e-30_real64))
    max_net_abs=max(max_net_abs,abs((result(1)%mass%total_in-result(1)%mass%total_out)-exact_net(step)))
    max_net_rel=max(max_net_rel,abs((result(1)%mass%total_in-result(1)%mass%total_out)-exact_net(step))/ &
         max(abs(exact_net(step)),1.0e-30_real64))
    a2_cum_net=a2_cum_net+result(1)%mass%total_in-result(1)%mass%total_out
    a2_cum_storage=a2_cum_storage+result(1)%mass%storage_change
    a2_max_mass=max(a2_max_mass,abs(result(1)%mass%residual))
    a2_nonlinear=a2_nonlinear+result(1)%solver_nonlinear_iterations
    a2_substeps=a2_substeps+result(1)%accepted_substeps
    a2_retries=a2_retries+result(1)%solver_internal_retries
    a2_backtrack=a2_backtrack+result(1)%solver_backtracking_attempts
  end do
  call system_clock(c1)
  a2_seconds=real(c1-c0,real64)/real(rate,real64)

  write(*,'(*(g0))') 'APPROX02_A2_APPLICATION|STEPS=',nsteps,'|DT=',dt,'|TOP_FACTOR=',top_factor, &
       '|EXACT_SECONDS=',exact_seconds,'|A2_SECONDS=',a2_seconds, &
       '|RUNTIME_RATIO=',a2_seconds/exact_seconds, &
       '|SPEEDUP_PERCENT=',100.0_real64*(1.0_real64-a2_seconds/exact_seconds), &
       '|EXACT_NONLINEAR=',exact_nonlinear,'|A2_NONLINEAR=',a2_nonlinear, &
       '|EXACT_SUBSTEPS=',exact_substeps,'|A2_SUBSTEPS=',a2_substeps, &
       '|EXACT_RETRIES=',exact_retries,'|A2_RETRIES=',a2_retries, &
       '|EXACT_BACKTRACK=',exact_backtrack,'|A2_BACKTRACK=',a2_backtrack, &
       '|EXACT_MAX_MASS_RESIDUAL=',exact_max_mass,'|A2_MAX_MASS_RESIDUAL=',a2_max_mass, &
       '|EXACT_CUM_NET=',exact_cum_net,'|A2_CUM_NET=',a2_cum_net, &
       '|CUM_NET_ABS=',abs(a2_cum_net-exact_cum_net), &
       '|CUM_NET_REL=',abs(a2_cum_net-exact_cum_net)/max(abs(exact_cum_net),1.0e-30_real64), &
       '|EXACT_CUM_STORAGE=',exact_cum_storage,'|A2_CUM_STORAGE=',a2_cum_storage, &
       '|CUM_STORAGE_ABS=',abs(a2_cum_storage-exact_cum_storage), &
       '|CUM_STORAGE_REL=',abs(a2_cum_storage-exact_cum_storage)/max(abs(exact_cum_storage),1.0e-30_real64), &
       '|MAX_STORAGE_END_ABS=',max_storage_abs,'|MAX_STORAGE_END_REL=',max_storage_rel, &
       '|MAX_STEP_NET_ABS=',max_net_abs,'|MAX_STEP_NET_REL=',max_net_rel
  if(exact_max_mass>exact_tol .or. a2_max_mass>exact_tol) error stop 'canonical mass gate'
  print '(A)','FPE_APPROX02_A2_APPLICATION_SEQUENCE=PASS'

  call exact_app%close(status)
  if(status/=FMR_APP_BOOT_OK) error stop 'exact close'
  call a2_app%close(status)
  if(status/=FMR_APP_BOOT_OK) error stop 'A2 close'

contains

  subroutine verify_result(label,istep,istat,r)
    character(len=*),intent(in)::label
    integer,intent(in)::istep,istat
    type(fmr_serialized_column_result_t),allocatable,intent(in)::r(:)
    if(istat/=FMR_APP_BOOT_OK .or. .not.allocated(r) .or. size(r)/=1)then
      write(*,'(*(g0))') 'APPROX02_A2_APP_FAIL|ARM=',trim(label),'|STEP=',istep,'|STATUS=',istat
      error stop 1
    end if
    if(.not.r(1)%completed .or. .not.r(1)%committed .or. .not.r(1)%mass%complete)then
      write(*,'(*(g0))') 'APPROX02_A2_APP_FAIL|ARM=',trim(label),'|STEP=',istep,'|INCOMPLETE=1'
      error stop 1
    end if
    if(abs(r(1)%mass%residual)>exact_tol)then
      write(*,'(*(g0))') 'APPROX02_A2_APP_FAIL|ARM=',trim(label),'|STEP=',istep, &
           '|MASS_RESIDUAL=',r(1)%mass%residual
      error stop 1
    end if
  end subroutine verify_result

  subroutine build_config(value,solver_tol)
    type(fmr_production_application_config_t),intent(out)::value
    real(real64),intent(in)::solver_tol
    real(real64)::k0
    value%initial_time=0.0_real64
    value%numerical%transaction%mass_tolerance=exact_tol
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=8
    value%numerical%max_committed_substeps=128
    value%numerical%progress_tolerance=0.0_real64
    allocate(value%tiles(1))
    value%tiles(1)%tile_id=630301_int64
    value%tiles(1)%ledger_id=630302_int64
    value%tiles(1)%template%template_id=630303_int64
    value%tiles(1)%template%physics_topology_id=630304_int64
    value%tiles(1)%template%vertical_layout_id=630305_int64
    value%tiles(1)%template%state_layout_id=630306_int64
    value%tiles(1)%template%solver_interface_id=630307_int64
    value%tiles(1)%template%optional_state_layout_id=0_int64
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_parameters(value%tiles(1)%parameters,solver_tol)
    call initialize_state_forcing(value%tiles(1)%parameters,value%tiles(1)%initial_state,value%tiles(1)%base_forcing,k0)
    value%tiles(1)%groundwater_datum%available=.true.
    value%tiles(1)%groundwater_datum%datum_id=630308_int64
    value%tiles(1)%groundwater_datum%bottom_boundary_elevation_m=0.0_real64
  end subroutine build_config

  subroutine initialize_parameters(p,tol)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    real(real64),intent(in)::tol
    integer::k
    real(real64),parameter :: tr=0.01_real64,ts=0.393878_real64,alpha=0.003288_real64
    real(real64),parameter :: nvg=1.616573_real64,ksat=2.495984_real64,lambda=0.514012_real64
    p%parameter_set_id=630309_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr; p%cofgen(2,k)=ts; p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lambda; p%cofgen(6,k)=nvg
      p%cofgen(7,k)=1.0_real64-1.0_real64/nvg; p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=ksat; p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ksat; p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16
    p%min_step_duration=1.0e-12_real64
    p%compartment_balance_tolerance=tol
    p%total_balance_tolerance=tol
    p%head_abs_tolerance=tol
    p%head_rel_tolerance=tol
    p%ponding_tolerance=exact_tol
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state_forcing(p,state,forcing,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    forcing%top_flux=top_factor*k0
    forcing%top_head=h0
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=h0
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_state_forcing
end program test_fpe_approx02_a2_application_sequence
