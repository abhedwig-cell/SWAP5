program test_ftab02c_serialized_generated_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: error_unit, int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF, transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_committed_state_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: duration=0.25_real64
  real(real64), parameter :: mass_tolerance=1.0e-12_real64
  real(real64), parameter :: h0=-75.0_real64
  integer(int64), parameter :: column_id=9202001_int64

  real(real64) :: analytic_head(numnod), analytic_theta(numnod)
  real(real64) :: table_head(numnod), table_theta(numnod)
  real(real64) :: repeat_head(numnod), repeat_theta(numnod)
  integer :: analytic_iterations, table_iterations, repeat_iterations
  integer :: analytic_retries, table_retries, repeat_retries

  call run_route(.false.,.false.,.false.,analytic_head,analytic_theta,analytic_iterations,analytic_retries,.true.)
  call run_route(.true., .false.,.false.,table_head,table_theta,table_iterations,table_retries,.true.)
  call run_route(.true., .false.,.false.,repeat_head,repeat_theta,repeat_iterations,repeat_retries,.true.)

  call require(maxval(abs(table_head-analytic_head)) <= 5.0e-2_real64, 'generated head fidelity')
  call require(maxval(abs(table_theta-analytic_theta)) <= 5.0e-3_real64, 'generated theta fidelity')
  call require(all(table_head == repeat_head) .and. all(table_theta == repeat_theta), 'repeated generated determinism')
  call require(table_iterations == repeat_iterations .and. table_retries == repeat_retries, &
       'repeated generated solver semantics')

  ! Generic/legacy tabulated hydraulics remains a separate, unadmitted route.
  call run_route(.false.,.true.,.false.,repeat_head,repeat_theta,repeat_iterations,repeat_retries,.false.)

  ! Explicit generated selection with unsupported H_ENPR must be rejected at
  ! admission; it must never fall back to the analytical provider.
  call run_route(.true.,.false.,.true.,repeat_head,repeat_theta,repeat_iterations,repeat_retries,.false.)

  write(*,'(a,es24.16)') 'F_TAB02_C_HEAD_MAX_ABS=',maxval(abs(table_head-analytic_head))
  write(*,'(a,es24.16)') 'F_TAB02_C_THETA_MAX_ABS=',maxval(abs(table_theta-analytic_theta))
  write(*,'(a,i0)') 'F_TAB02_C_ANALYTIC_ITERATIONS=',analytic_iterations
  write(*,'(a,i0)') 'F_TAB02_C_GENERATED_ITERATIONS=',table_iterations
  write(*,'(a,i0)') 'F_TAB02_C_ANALYTIC_RETRIES=',analytic_retries
  write(*,'(a,i0)') 'F_TAB02_C_GENERATED_RETRIES=',table_retries
  write(*,'(a)') 'F_TAB02_C_REPEATED_GENERATED_IDENTITY=PASS'
  write(*,'(a)') 'F_TAB02_C_GENERIC_TABULATED_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F_TAB02_C_UNSUPPORTED_HENPR_FAIL_CLOSED_NO_FALLBACK=PASS'
  write(*,'(a)') 'F-TAB02-C SERIALIZED PROVIDER SELECTION GATE PASS'

contains

  subroutine run_route(generated,generic_table,unsupported_henpr,head_out,theta_out,iterations,retries,expect_success)
    logical,intent(in)::generated,generic_table,unsupported_henpr,expect_success
    real(real64),intent(out)::head_out(numnod),theta_out(numnod)
    integer,intent(out)::iterations,retries
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
    type(fixed_flux_top_boundary_provider_t),target :: top
    class(transaction_state_t),allocatable :: snapshot
    real(real64) :: qref
    logical :: ok,available

    call initialize_parameters(parameters,generated,generic_table)
    if (unsupported_henpr) parameters%cofgen(9,1)=-5.0_real64
    call analytical_initial_conductivity(parameters,qref)
    call initialize_forcing(forcing,qref)
    call initialize_column_template(column,template)
    call initialize_config(config)
    call initialize_committed(committed,parameters,generated .and. .not. unsupported_henpr,ok)
    call require(ok,'committed initialization')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint capture')
    call backend%initialize(top)

    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,duration, &
         checkpoint,result,candidate,diagnostics)

    head_out=0.0_real64
    theta_out=0.0_real64
    iterations=diagnostics%nonlinear_iterations
    retries=diagnostics%internal_retries

    if (.not. expect_success) then
      call require(result%status == KERNEL_STATUS_NOT_ADMITTED .or. .not. result%completed, &
           'unsupported route not admitted')
      return
    end if

    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) then
      write(error_unit,'(a,l1,1x,a,l1,1x,a,i0)') 'F_TAB02_C_RUNTIME_FAIL generated=',generated, &
           'generic=',generic_table,'status=',result%status
      write(error_unit,'(a,l1,1x,a,l1,1x,a,es24.16)') 'F_TAB02_C_RUNTIME_DIAG completed=',result%completed, &
           'mass_complete=',result%mass%complete,'mass_residual=',result%mass%residual
      write(error_unit,'(a,5(1x,i0))') 'F_TAB02_C_RUNTIME_COUNTS', diagnostics%attempts, diagnostics%retries, &
           diagnostics%solver_rejections, diagnostics%temporal_rejections, diagnostics%admission_rejections
    end if
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed,'runtime completed')
    call require(candidate%ready(),'candidate ready')
    call require(result%mass%complete .and. abs(result%mass%residual) <= mass_tolerance,'hard mass gate')
    call candidate%snapshot(snapshot,available)
    call require(available,'candidate snapshot')
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      call require(physical%active_nodes==numnod,'candidate node count')
      head_out=physical%pressure_head
      theta_out=physical%water_content
    class default
      call require(.false.,'candidate state type')
    end select
  end subroutine run_route

  subroutine initialize_parameters(p,generated,generic_table)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::generated,generic_table
    integer::k
    real(real64),parameter::ores=0.0_real64,osat=0.43_real64,alpha=0.0065_real64
    real(real64),parameter::npar=1.325_real64,ksat=1.54_real64,lexp=-2.161_real64

    p%parameter_set_id=9202100_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=ores; p%cofgen(2,k)=osat; p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lexp; p%cofgen(6,k)=npar
      p%cofgen(7,k)=1.0_real64-1.0_real64/npar; p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=ksat
      p%cofgen(11,k)=0.999_real64; p%cofgen(12,k)=0.99_real64*ksat
      p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tolerance
    p%total_balance_tolerance=mass_tolerance
    p%head_abs_tolerance=1.0e-10_real64
    p%head_rel_tolerance=1.0e-10_real64
    p%ponding_tolerance=1.0e-10_real64
    p%generated_mvg_acceleration_active=generated
    p%tabulated_hydraulics_active=generic_table
  end subroutine initialize_parameters

  subroutine analytical_initial_conductivity(p,qref)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::qref
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    heads=h0
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    qref=conductivity(1)
    call require(qref>0.0_real64 .and. ieee_is_finite(qref),'reference conductivity')
  end subroutine analytical_initial_conductivity

  subroutine initialize_committed(c,p,generated,ok)
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::generated
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::ap
    type(b110_generated_mvg_table_state_t),target::ts
    type(b110_generated_mvg_provider_t)::tp
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::status
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    if(generated) then
      call initialize_b110_generated_mvg_table_state(ts,hp,status)
      call require(status==F_TAB02_STATE_OK,'initial table state')
      call bind_b110_generated_mvg_provider(tp,ts,duration,status)
      call require(status==F_TAB02_PROVIDER_OK,'initial table provider')
      call tp%evaluate(heads,water,conductivity,capacity,dkdh)
    else
      call bind_b110_default_mvg_provider(ap,hp,duration)
      call ap%evaluate(heads,water,conductivity,capacity,dkdh)
    end if
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(c,column_id,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine initialize_forcing(f,qref)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qref
    f%top_flux=-qref
    f%top_head=h0
    f%bottom_flux=-qref
    f%bottom_head=h0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=9202201_int64; t%physics_topology_id=9202202_int64
    t%vertical_layout_id=9202203_int64; t%state_layout_id=9202204_int64
    t%solver_interface_id=9202205_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=1_int64; c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    ! Slice C qualifies provider selection/lifetime, not the strict temporal
    ! error-control contract owned by F-TAB02-D. Keep full/half mechanics live
    ! but make temporal rejection non-limiting for this bounded C oracle.
    c%transaction%temporal_tolerance=1.0_real64
    c%transaction%mass_tolerance=mass_tolerance
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB02_C_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02c_serialized_generated_provider
