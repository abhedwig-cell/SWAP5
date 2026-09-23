program test_ftab02g_serialized_ksatexm_selection
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
  real(real64), parameter :: h0=-1.0_real64
  integer(int64), parameter :: column_id=9703001_int64

  real(real64) :: analytic_head(numnod), analytic_theta(numnod)
  real(real64) :: generated_head(numnod), generated_theta(numnod)
  integer :: analytic_iterations, generated_iterations, analytic_retries, generated_retries

  call run_route(.false.,.false.,analytic_head,analytic_theta,analytic_iterations,analytic_retries,.true.)
  call run_route(.true., .false.,generated_head,generated_theta,generated_iterations,generated_retries,.true.)

  call require(maxval(abs(generated_head-analytic_head)) <= 5.0e-2_real64,'generated KSATEXM head fidelity')
  call require(maxval(abs(generated_theta-analytic_theta)) <= 2.0e-2_real64,'generated KSATEXM theta fidelity')
  call require(analytic_iterations==generated_iterations,'generated KSATEXM nonlinear count')
  call require(analytic_retries==generated_retries,'generated KSATEXM retry count')

  ! A one-ULP-scale material perturbation is outside the exact bounded Hupsel
  ! envelope and must fail closed rather than selecting another constitutive route.
  call run_route(.true.,.true.,generated_head,generated_theta,generated_iterations,generated_retries,.false.)

  write(*,'(a,es24.16)') 'F_TAB02_G_SERIALIZED_HEAD_MAX_ABS=',maxval(abs(generated_head-analytic_head))
  write(*,'(a,es24.16)') 'F_TAB02_G_SERIALIZED_THETA_MAX_ABS=',maxval(abs(generated_theta-analytic_theta))
  write(*,'(a,i0)') 'F_TAB02_G_SERIALIZED_ANALYTIC_ITERS=',analytic_iterations
  write(*,'(a,i0)') 'F_TAB02_G_SERIALIZED_GENERATED_ITERS=',generated_iterations
  write(*,'(a,i0)') 'F_TAB02_G_SERIALIZED_ANALYTIC_RETRIES=',analytic_retries
  write(*,'(a,i0)') 'F_TAB02_G_SERIALIZED_GENERATED_RETRIES=',generated_retries
  write(*,'(a)') 'F_TAB02_G_SERIALIZED_SUPPORTED_KSATEXM=PASS'
  write(*,'(a)') 'F_TAB02_G_SERIALIZED_NEIGHBOR_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F-TAB02-G SERIALIZED KSA...'
  write(*,'(a)') 'F-TAB02-G SERIALIZED KSATEXM SELECTION GATE PASS'

contains

  subroutine run_route(generated,neighbor,head_out,theta_out,iterations,retries,expect_success)
    logical,intent(in)::generated,neighbor,expect_success
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

    call initialize_parameters(parameters,generated,neighbor)
    call route_initial_conductivity(parameters,generated .and. .not. neighbor,qref)
    call initialize_forcing(forcing,qref)
    call initialize_column_template(column,template)
    call initialize_config(config)
    call initialize_committed(committed,parameters,generated .and. .not. neighbor,ok)
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
      call require(result%status==KERNEL_STATUS_NOT_ADMITTED .or. .not. result%completed,'neighbor route not admitted')
      return
    end if

    if (result%status/=CANONICAL_STATUS_COMPLETED .or. .not. result%completed) then
      write(error_unit,'(a,l1,1x,a,l1,1x,a,i0)') 'F_TAB02_G_SERIALIZED_RUNTIME_FAIL generated=',generated, &
           ' neighbor=',neighbor,' status=',result%status
      write(error_unit,'(a,5(1x,i0))') 'F_TAB02_G_SERIALIZED_COUNTS', diagnostics%attempts, diagnostics%retries, &
           diagnostics%solver_rejections, diagnostics%temporal_rejections, diagnostics%admission_rejections
    end if
    call require(result%status==CANONICAL_STATUS_COMPLETED .and. result%completed,'runtime completed')
    call require(candidate%ready(),'candidate ready')
    call require(result%mass%complete .and. abs(result%mass%residual)<=mass_tolerance,'hard mass gate')
    call candidate%snapshot(snapshot,available)
    call require(available,'candidate snapshot')
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      head_out=physical%pressure_head
      theta_out=physical%water_content
    class default
      call require(.false.,'candidate state type')
    end select
  end subroutine run_route

  subroutine initialize_parameters(p,generated,neighbor)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    logical,intent(in)::generated,neighbor
    integer::k

    p%parameter_set_id=9703100_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(42,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      if(k<=numnod/2) then
        call set_upper(p%cofgen(:,k))
      else
        call set_lower(p%cofgen(:,k))
      end if
    end do
    if(neighbor) p%cofgen(4,1)=nearest(p%cofgen(4,1),huge(1.0_real64))
    p%bottom_mode=2
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tolerance; p%total_balance_tolerance=mass_tolerance
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64; p%ponding_tolerance=1.0e-10_real64
    p%generated_mvg_acceleration_active=generated
    p%ksatexm_extension_active=.true.
  end subroutine initialize_parameters

  subroutine set_upper(c)
    real(real64),intent(out)::c(:)
    c=0.0_real64
    c(1)=0.02_real64;c(2)=0.433878_real64;c(3)=83.24164_real64;c(4)=0.021645_real64
    c(5)=7.202077_real64;c(6)=1.34877_real64;c(7)=1.0_real64-1.0_real64/c(6)
    c(8)=0.021645_real64;c(9)=0.0_real64;c(10)=832.4163_real64
    call derive_threshold(c)
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_upper

  subroutine set_lower(c)
    real(real64),intent(out)::c(:)
    c=0.0_real64
    c(1)=0.02_real64;c(2)=0.3870640000000001_real64;c(3)=22.76176_real64;c(4)=0.016083_real64
    c(5)=2.4396619999999993_real64;c(6)=1.524418_real64;c(7)=1.0_real64-1.0_real64/c(6)
    c(8)=0.016083_real64;c(9)=0.0_real64;c(10)=227.61759999999998_real64
    call derive_threshold(c)
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_lower

  subroutine derive_threshold(c)
    real(real64),intent(inout)::c(:)
    real(real64)::m,se,term1
    m=1.0_real64-1.0_real64/c(6)
    se=(1.0_real64+abs(c(4)*(-2.0_real64))**c(6))**(-m)
    term1=(1.0_real64-se**(1.0_real64/m))**m
    c(11)=se;c(12)=c(3)*se**c(5)*(1.0_real64-term1)*(1.0_real64-term1)
  end subroutine derive_threshold

  subroutine route_initial_conductivity(p,generated,qref)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::generated
    real(real64),intent(out)::qref
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::ap
    type(b110_generated_mvg_table_state_t),target::ts
    type(b110_generated_mvg_provider_t)::tp
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer::status
    call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=.true.)
    heads=h0
    if(generated) then
      call initialize_b110_generated_mvg_table_state(ts,hp,status)
      call require(status==F_TAB02_STATE_OK,'equilibrium table state')
      call bind_b110_generated_mvg_provider(tp,ts,duration,status)
      call require(status==F_TAB02_PROVIDER_OK,'equilibrium table provider')
      call tp%evaluate(heads,water,conductivity,capacity,dkdh)
    else
      call bind_b110_default_mvg_provider(ap,hp,duration)
      call ap%evaluate(heads,water,conductivity,capacity,dkdh)
    end if
    qref=conductivity(1)
    call require(qref>0.0_real64 .and. ieee_is_finite(qref),'route-consistent conductivity')
  end subroutine route_initial_conductivity

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
    call initialize_b110_default_mvg_parameters(hp,p%cofgen,enable_ksatexm_extension=.true.)
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
    f%top_flux=-qref; f%top_head=h0; f%bottom_flux=-qref; f%bottom_head=h0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=9703201_int64;t%physics_topology_id=9703202_int64;t%vertical_layout_id=9703203_int64
    t%state_layout_id=9703204_int64;t%solver_interface_id=9703205_int64;t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id;c%template_id=t%template_id;c%parameter_ref=1_int64
    c%state_handle=1_int64;c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
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
      write(error_unit,'(a,1x,a)') 'F_TAB02_G_SERIALIZED_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02g_serialized_ksatexm_selection
