program test_f_rom0r_gravity_steady_seed
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: dt_day=0.0016_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer, parameter :: requested_intervals=8
  integer(int64), parameter :: column_id=920001_int64

  character(len=16) :: material_id
  real(real64) :: tr,ts,alpha,nn,ks,lam,h0,k0,qeq
  real(real64) :: storage0,storage_now,max_storage_drift,scale,roundoff_envelope
  real(real64) :: t0,t1
  logical :: ok,snapshot_ok
  integer :: i,active_physical_calls

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(kernel_executor_t) :: transaction_control
  type(kernel_committed_state_t) :: committed
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(fmr_serialized_column_result_t) :: output
  type(fmr_column_diagnostics_t) :: diagnostic
  type(fmr_serialized_batch_diagnostics_t) :: runtime
  type(fmr_serialized_physical_observation_t) :: observation
  class(transaction_state_t), allocatable :: snapshot

  call require(numnod==16,'R1 geometry is frozen at 16 nodes')
  call get_command_argument(1,material_id)
  material_id=adjustl(material_id)
  call material_parameters(trim(material_id),tr,ts,alpha,nn,ks,lam,ok)
  call require(ok,'known R1 material')

  call initialize_parameters(parameters,tr,ts,alpha,nn,ks,lam)
  call initialize_state(parameters,h0,k0,initial_state)
  qeq=-k0
  call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
  call require(ok,'committed seed initialized')
  storage0=sum(parameters%dz*initial_state%water_content)+initial_state%ponding_depth

  call initialize_forcing(forcing,qeq)
  call initialize_identity(column,template)
  call initialize_numerics(config)
  call backend%initialize(top_boundary)

  max_storage_drift=0.0_real64
  t0=0.0_real64
  write(*,'(*(g0))') 'F_ROM0R_R1_CASE|MATERIAL=',trim(material_id),'|SE=',se0, &
       '|H0_CM=',h0,'|K0_CM_PER_DAY=',k0,'|QEQ_CM_PER_DAY=',qeq, &
       '|DT_DAY=',dt_day,'|INTERVALS=',requested_intervals,'|S0_CM=',storage0

  do i=1,requested_intervals
    t1=real(i,real64)*dt_day
    output=fmr_serialized_column_result_t()
    output%column_id=column_id
    output%requested_t0=t0
    output%requested_t1=t1
    diagnostic=fmr_column_diagnostics_t()
    diagnostic%column_id=column_id
    runtime=fmr_serialized_batch_diagnostics_t()
    active_physical_calls=0

    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,parameters, &
         forcing,committed,config,t0,t1,output,diagnostic,runtime,active_physical_calls)
    observation=backend%observation()

    if (.not.output%completed .or. .not.output%committed) then
      write(*,'(*(g0))') 'F_ROM0R_R1_REJECT|MATERIAL=',trim(material_id),'|STEP=',i, &
           '|KERNEL_STATUS=',output%kernel_status,'|ADMISSION=',trim(output%admission_status), &
           '|COMPLETED=',output%completed,'|COMMITTED=',output%committed, &
           '|SOLVER_EXECUTED=',output%solver_executed,'|SOLVER_ROUTE=',trim(output%solver_route), &
           '|SOLVER_ITERS=',output%solver_nonlinear_iterations,'|INTERNAL_RETRIES=',output%solver_internal_retries, &
           '|HEADCALC=',output%solver_headcalc_calls,'|LINEAR=',output%solver_linear_solves, &
           '|BACKTRACK=',output%solver_backtracking_attempts,'|OBS_SOLVER_STATUS=',observation%solver_status, &
           '|OBS_SOLVER_ROUTE=',trim(observation%solver_diagnostics%route)
      error stop 1
    end if

    call require(output%mass%complete,'complete accepted mass accounting')
    call require(abs(output%mass%residual)<=hard_mass_gate,'hard mass gate')
    call require(output%final_revision==int(i,int64),'one external revision per interval')
    call require(output%final_committed_time_bound,'committed time bound')
    call require(abs(output%final_committed_time-t1)<=1.0e-14_real64,'committed time identity')
    call require(observation%solver_executed,'solver executed')
    call require(abs(observation%top_flux-qeq)<=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(qeq)), &
         'top steady flux identity')
    call require(abs(observation%bottom_flux-qeq)<=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(qeq)), &
         'bottom steady flux identity')

    call committed%snapshot(snapshot,snapshot_ok)
    call require(snapshot_ok,'committed snapshot')
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      call require(physical%active_nodes==numnod,'snapshot node count')
      call require(all(ieee_is_finite(physical%pressure_head)),'finite pressure head')
      call require(all(ieee_is_finite(physical%water_content)),'finite water content')
      storage_now=sum(parameters%dz*physical%water_content)+physical%ponding_depth
      max_storage_drift=max(max_storage_drift,abs(storage_now-storage0))
      write(*,'(*(g0))') 'F_ROM0R_R1_ACCEPTED|MATERIAL=',trim(material_id),'|STEP=',i,'|T=',t1, &
           '|REV=',output%final_revision,'|ACCEPTED_SUBSTEPS=',output%accepted_substeps, &
           '|MASS_RES=',output%mass%residual,'|S_CM=',storage_now,'|DS_CM=',storage_now-storage0, &
           '|QTOP=',observation%top_flux,'|QBOT=',observation%bottom_flux, &
           '|SOLVER_ROUTE=',trim(output%solver_route),'|NONLINEAR_ITERS=',output%solver_nonlinear_iterations, &
           '|INTERNAL_RETRIES=',output%solver_internal_retries,'|BACKTRACK=',output%solver_backtracking_attempts
    class default
      error stop 'F_ROM0R_R1_FAIL unexpected committed snapshot type'
    end select
    if(allocated(snapshot)) deallocate(snapshot)
    t0=t1
  end do

  scale=max(1.0_real64,abs(storage0))
  roundoff_envelope=65536.0_real64*epsilon(1.0_real64)*scale
  call require(max_storage_drift<=roundoff_envelope,'steady storage within roundoff envelope')

  write(*,'(*(g0))') 'F_ROM0R_R1_STORAGE|MATERIAL=',trim(material_id), &
       '|MAX_ABS_DRIFT_CM=',max_storage_drift,'|ROUND_OFF_ENVELOPE_CM=',roundoff_envelope
  write(*,'(*(g0))') 'F_ROM0R_R1_PASS|MATERIAL=',trim(material_id),'|FINAL_REV=',requested_intervals, &
       '|FINAL_T=',real(requested_intervals,real64)*dt_day

contains

  subroutine material_parameters(id,tr,ts,alpha,nn,ks,lam,found)
    character(len=*),intent(in) :: id
    real(real64),intent(out) :: tr,ts,alpha,nn,ks,lam
    logical,intent(out) :: found
    found=.true.
    select case(trim(id))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64
      nn=1.734737_real64; ks=31.225016_real64; lam=0.98087_real64
    case('B14')
      tr=0.01_real64; ts=0.416774_real64; alpha=0.00541_real64
      nn=1.301528_real64; ks=0.895023_real64; lam=-0.334926_real64
    case default
      tr=0.0_real64; ts=0.0_real64; alpha=0.0_real64
      nn=0.0_real64; ks=0.0_real64; lam=0.0_real64; found=.false.
    end select
  end subroutine material_parameters

  subroutine initialize_parameters(p,tr,ts,alpha,nn,ks,lam)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64),intent(in) :: tr,ts,alpha,nn,ks,lam
    real(real64) :: mm
    integer :: k
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=920001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr; p%cofgen(2,k)=ts; p%cofgen(3,k)=ks
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lam; p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm; p%cofgen(8,k)=alpha; p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=ks; p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*ks
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=1.0e-12_real64
    p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-12_real64
    p%head_rel_tolerance=1.0e-12_real64
    p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
    p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt_day)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)).and.all(ieee_is_finite(conductivity)),'finite constitutive seed')
    k0=conductivity(1)
    call require(k0>0.0_real64,'positive seed conductivity')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: q
    f%top_flux=q; f%top_head=0.0_real64; f%bottom_flux=q; f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=920001_int64; tmpl%physics_topology_id=920002_int64
    tmpl%vertical_layout_id=920003_int64; tmpl%state_layout_id=920004_int64
    tmpl%solver_interface_id=920005_int64; tmpl%optional_state_layout_id=0_int64
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id; col%template_id=tmpl%template_id
    col%parameter_ref=1_int64; col%state_handle=1_int64; col%forcing_handle=1_int64
    col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine initialize_numerics(cfg)
    type(canonical_numerical_config_t),intent(out) :: cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance=1.0e-6_real64
    cfg%transaction%max_retries=8
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%max_committed_substeps=128
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.false.
    cfg%model_temporal_indicator_budget=0.0_real64
  end subroutine initialize_numerics

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0R_R1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_rom0r_gravity_steady_seed
