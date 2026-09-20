program tabhyd_typed_reference_runtime_benchmark
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider_from_mvg
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NREPEAT=160
  real(real64), parameter :: duration=0.25_real64
  real(real64), parameter :: mass_tolerance=1.0e-12_real64
  integer(int64), parameter :: column_id=990044_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: snapshot
  real(real64) :: k0, kref, h0, t0, t1, forcing_delta, water0(numnod), water_ref(numnod)
  logical :: ok, available
  integer :: rep, i
  character(len=32) :: material, initial_route, forcing_mode

  material='loam'
  initial_route='analytic'
  forcing_mode='equilibrium'
  forcing_delta=0.5_real64
  if (command_argument_count()>=1) call get_command_argument(1,material)
  if (command_argument_count()>=2) call get_command_argument(2,initial_route)
  if (command_argument_count()>=3) call get_command_argument(3,forcing_mode)
  if (command_argument_count()>=4) call read_real_argument(4,forcing_delta)
  if (forcing_delta <= 0.0_real64 .or. forcing_delta >= 1.0_real64) error stop 'forcing delta must be in (0,1)'

  call initialize_parameters(parameters,trim(material),h0)
  call evaluate_initial_constitutive(parameters,h0,trim(initial_route),water0,k0)
  call evaluate_initial_constitutive(parameters,h0,'analytic',water_ref,kref)
  call initialize_forcing(forcing,k0,kref,h0,trim(forcing_mode),forcing_delta)
  call initialize_column_and_template(column,template)
  call initialize_config(config)
  call initialize_committed(committed,parameters,h0,water0,ok)
  call require(ok,'committed state initialized')
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint captured')
  call backend%initialize(top)

  ! Warm-up includes any research-only one-time table preprocessing.
  call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
       checkpoint,result,candidate,diagnostics)
  call validate_trial(result,candidate)

  call cpu_time(t0)
  do rep=1,NREPEAT
    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
         checkpoint,result,candidate,diagnostics)
    call validate_trial(result,candidate)
  end do
  call cpu_time(t1)

  call candidate%snapshot(snapshot,available)
  call require(available,'candidate snapshot available')

  write(*,'(a,a)') 'MATERIAL=',trim(material)
  write(*,'(a,a)') 'INITIAL_ROUTE=',trim(initial_route)
  write(*,'(a,a)') 'FORCING_MODE=',trim(forcing_mode)
  write(*,'(a,es24.16)') 'FORCING_DELTA=',forcing_delta
  write(*,'(a,i0)') 'ACTIVE_NODES=',numnod
  write(*,'(a,i0)') 'REPEATS=',NREPEAT
  write(*,'(a,es24.16)') 'CPU_SECONDS=',t1-t0
  write(*,'(a,es24.16)') 'US_PER_TRIAL=',(t1-t0)*1.0e6_real64/real(NREPEAT,real64)
  write(*,'(a,i0)') 'NONLINEAR_ITERATIONS=',diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'INTERNAL_RETRIES=',diagnostics%internal_retries
  write(*,'(a,i0)') 'HEADCALC_CALLS=',diagnostics%headcalc_calls
  write(*,'(a,i0)') 'JACOBIAN_BUILDS=',diagnostics%jacobian_builds
  write(*,'(a,i0)') 'LINEAR_SOLVES=',diagnostics%linear_solves
  write(*,'(a,i0)') 'BACKTRACKING_ATTEMPTS=',diagnostics%backtracking_attempts
  write(*,'(a,es24.16)') 'MASS_STORAGE_START=',result%mass%storage_start
  write(*,'(a,es24.16)') 'MASS_STORAGE_END=',result%mass%storage_end
  write(*,'(a,es24.16)') 'MASS_TOTAL_IN=',result%mass%total_in
  write(*,'(a,es24.16)') 'MASS_TOTAL_OUT=',result%mass%total_out
  write(*,'(a,es24.16)') 'MASS_RESIDUAL=',result%mass%residual

  select type (physical=>snapshot)
  type is (fmr_b110_physical_state_t)
    do i=1,physical%active_nodes
      write(*,'(a,i0,a,es24.16,a,es24.16)') 'STATE node=',i,' head=',physical%pressure_head(i), &
           ' theta=',physical%water_content(i)
    end do
    write(*,'(a,es24.16)') 'STATE_PONDING=',physical%ponding_depth
    write(*,'(a,es24.16)') 'STATE_GWL=',physical%groundwater_level
  class default
    error stop 'unexpected candidate state type'
  end select
  write(*,'(a)') 'TABHYD_TYPED_REFERENCE_RUNTIME_COMPLETED'

contains

  subroutine initialize_parameters(p,soil,hstart)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    character(len=*), intent(in) :: soil
    real(real64), intent(out) :: hstart
    real(real64) :: ores,osat,alpha,npar,ksat,lexp
    integer :: k

    select case(trim(soil))
    case('coarse')
      ores=0.01_real64; osat=0.42_real64; alpha=0.0163_real64; npar=1.559_real64
      ksat=54.80_real64; lexp=0.177_real64; hstart=-180.0_real64
      p%parameter_set_id=990041_int64
    case('loam')
      ores=0.00_real64; osat=0.43_real64; alpha=0.0065_real64; npar=1.325_real64
      ksat=1.54_real64; lexp=-2.161_real64; hstart=-75.0_real64
      p%parameter_set_id=990042_int64
    case('clay')
      ores=0.00_real64; osat=0.55_real64; alpha=0.0532_real64; npar=1.081_real64
      ksat=15.46_real64; lexp=-8.823_real64; hstart=-40.0_real64
      p%parameter_set_id=990043_int64
    case default
      error stop 'material must be coarse, loam or clay'
    end select

    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=ores
      p%cofgen(2,k)=osat
      p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lexp
      p%cofgen(6,k)=npar
      p%cofgen(7,k)=1.0_real64-1.0_real64/npar
      p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=ksat
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ksat
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%max_iterations=16
    p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tolerance
    p%total_balance_tolerance=mass_tolerance
    p%head_abs_tolerance=1.0e-10_real64
    p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
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

  subroutine evaluate_initial_constitutive(p,hstart,route,water0,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: hstart
    character(len=*), intent(in) :: route
    real(real64), intent(out) :: water0(numnod)
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: aprovider
    type(tabhyd_raw_provider_t) :: tprovider
    real(real64) :: heads(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)

    heads=hstart
    select case(trim(route))
    case('analytic')
      call initialize_b110_default_mvg_parameters(hp,p%cofgen)
      call bind_b110_default_mvg_provider(aprovider,hp,duration)
      call aprovider%evaluate(heads,water0,conductivity,capacity,dkdh)
    case('table')
      call initialize_tabhyd_raw_provider_from_mvg(tprovider,p%cofgen,duration)
      call tprovider%evaluate(heads,water0,conductivity,capacity,dkdh)
    case default
      error stop 'initial route must be analytic or table'
    end select
    conductivity0=conductivity(1)
    call require(conductivity0>0.0_real64 .and. ieee_is_finite(conductivity0),'initial conductivity positive')
  end subroutine evaluate_initial_constitutive

  subroutine initialize_forcing(f,qactive,qref,hstart,mode,delta)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: qactive,qref,hstart,delta
    character(len=*), intent(in) :: mode
    select case(trim(mode))
    case('equilibrium')
      f%top_flux=-qactive
      f%bottom_flux=-qactive
    case('drying')
      ! Same forcing on analytical and table runs. With uniform h, qref is
      ! the analytical gravity-flow magnitude; reduced top inflow dries storage.
      f%top_flux=-(1.0_real64-delta)*qref
      f%bottom_flux=-qref
    case('wetting')
      ! Increased top inflow relative to the common lower flux wets storage.
      f%top_flux=-(1.0_real64+delta)*qref
      f%bottom_flux=-qref
    case default
      error stop 'forcing mode must be equilibrium, drying or wetting'
    end select
    f%top_head=hstart
    f%bottom_head=hstart
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_and_template(c,t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=990001_int64
    t%physics_topology_id=990002_int64
    t%vertical_layout_id=990003_int64
    t%state_layout_id=990004_int64
    t%solver_interface_id=990005_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id
    c%template_id=t%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=mass_tolerance
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%model_temporal_indicator_budget=0.0_real64
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_committed(c,p,hstart,water0,initialized)
    type(kernel_committed_state_t), intent(out) :: c
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: hstart
    real(real64), intent(in) :: water0(numnod)
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(numnod)
    heads=hstart
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water0
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(c,column_id,state,0.0_real64,initialized)
  end subroutine initialize_committed

  subroutine validate_trial(r,c)
    type(kernel_result_t), intent(in) :: r
    type(kernel_candidate_state_t), intent(in) :: c
    if (.not. (r%status==CANONICAL_STATUS_COMPLETED .and. r%completed .and. c%ready() .and. &
        r%mass%complete .and. abs(r%mass%residual)<=mass_tolerance)) then
      write(*,'(a,i0)') 'DIAG_STATUS=',r%status
      write(*,'(a,l1)') 'DIAG_COMPLETED=',r%completed
      write(*,'(a,l1)') 'DIAG_CANDIDATE_READY=',c%ready()
      write(*,'(a,l1)') 'DIAG_MASS_COMPLETE=',r%mass%complete
      write(*,'(a,es24.16)') 'DIAG_MASS_RESIDUAL=',r%mass%residual
      write(*,'(a,i0)') 'DIAG_ATTEMPTS=',diagnostics%attempts
      write(*,'(a,i0)') 'DIAG_RETRIES=',diagnostics%retries
      write(*,'(a,i0)') 'DIAG_SOLVER_REJECTIONS=',diagnostics%solver_rejections
      write(*,'(a,i0)') 'DIAG_TEMPORAL_REJECTIONS=',diagnostics%temporal_rejections
      write(*,'(a,i0)') 'DIAG_MASS_REJECTIONS=',diagnostics%mass_rejections
      write(*,'(a,i0)') 'DIAG_ADMISSION_REJECTIONS=',diagnostics%admission_rejections
      write(*,'(a,es24.16)') 'DIAG_MAX_STEP_MASS_RESIDUAL=',diagnostics%max_abs_step_mass_residual
    end if
    call require(r%status==CANONICAL_STATUS_COMPLETED .and. r%completed,'runtime completed')
    call require(c%ready(),'candidate ready')
    call require(r%mass%complete,'mass complete')
    call require(abs(r%mass%residual)<=mass_tolerance,'hard mass gate')
  end subroutine validate_trial

  subroutine read_real_argument(index,value)
    integer, intent(in) :: index
    real(real64), intent(out) :: value
    character(len=64) :: text
    integer :: ios
    call get_command_argument(index,text)
    read(text,*,iostat=ios) value
    if (ios /= 0 .or. .not. ieee_is_finite(value)) error stop 'invalid real command argument'
  end subroutine read_real_argument

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(a,1x,a)') 'TABHYD_TYPED_RUNTIME_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program tabhyd_typed_reference_runtime_benchmark
