program test_fpe_miqual06_serialized_manager
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_timestep_numerical_profile, only: timestep_numerical_profile_t, make_moving_interface_manager_profile
  use mod_moving_interface_manager, only: MI_MANAGER_ROUTE_REDUCED, MI_MANAGER_ROUTE_FULL_BYPASS
  implicit none

  integer, parameter :: tail_start=13
  real(real64), parameter :: dt=0.00125_real64
  real(real64), parameter :: top_flux=-0.01_real64
  real(real64), parameter :: tol=1.0e-12_real64
  type(fmr_b110_physical_state_t) :: default_state, manager_state, bypass_state
  type(fmr_serialized_physical_observation_t) :: default_obs, manager_obs, bypass_obs

  call require(numnod==16,'MIQUAL06 gate requires N=16')
  call execute_case(.false.,.true.,default_state,default_obs)
  call execute_case(.true.,.true.,manager_state,manager_obs)
  call execute_case(.true.,.false.,bypass_state,bypass_obs)

  call require(.not.default_obs%moving_interface_manager_requested,'default route manager off')
  call require(manager_obs%moving_interface_manager_requested,'manager requested')
  call require(manager_obs%moving_interface_manager_route==MI_MANAGER_ROUTE_REDUCED,'eligible route reduced')
  call require(manager_obs%moving_interface_full_nodes==16,'manager full nodes')
  call require(manager_obs%moving_interface_active_nodes==tail_start,'manager active nodes')
  call require(.not.manager_obs%moving_interface_fallback_used,'manager no fallback')
  call require(trim(manager_obs%moving_interface_reason)=='none','manager reduced reason none')
  call require(maxval(abs(default_state%pressure_head-manager_state%pressure_head))<=tol,'default/manager head identity')
  call require(maxval(abs(default_state%water_content-manager_state%water_content))<=tol,'default/manager theta identity')
  call require(abs(default_state%ponding_depth-manager_state%ponding_depth)<=tol,'default/manager pond identity')

  call require(bypass_obs%moving_interface_manager_requested,'bypass manager requested')
  call require(bypass_obs%moving_interface_manager_route==MI_MANAGER_ROUTE_FULL_BYPASS,'ineligible route full bypass')
  call require(.not.bypass_obs%moving_interface_fallback_used,'bypass is not fallback')
  call require(trim(bypass_obs%moving_interface_reason)=='reduced-view-ineligible','typed bypass reason')

  write(*,'(*(g0))') 'F_PE_MIQUAL06_MANAGER|ROUTE=',manager_obs%moving_interface_manager_route, &
       '|FULL_N=',manager_obs%moving_interface_full_nodes,'|ACTIVE_N=',manager_obs%moving_interface_active_nodes, &
       '|NL=',manager_obs%solver_diagnostics%nonlinear_iterations, &
       '|JAC=',manager_obs%solver_diagnostics%jacobian_builds, &
       '|LIN=',manager_obs%solver_diagnostics%linear_solves
  write(*,'(*(g0))') 'F_PE_MIQUAL06_BYPASS|ROUTE=',bypass_obs%moving_interface_manager_route, &
       '|REASON=',trim(bypass_obs%moving_interface_reason)
  write(*,'(a)') 'F_PE_MIQUAL06_SERIALIZED_RUNTIME_SEAM=PASS'

contains

  subroutine execute_case(enable_manager,saturated,final_state,obs)
    logical,intent(in)::enable_manager,saturated
    type(fmr_b110_physical_state_t),intent(out)::final_state
    type(fmr_serialized_physical_observation_t),intent(out)::obs
    type(fmr_serialized_reference_backend_t)::backend
    type(fmr_b110_physical_parameters_t),target::parameters
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_b110_physical_state_t)::initial
    type(kernel_committed_state_t)::committed
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::result
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diagnostics
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::config
    type(fixed_flux_top_boundary_provider_t),target::top
    type(timestep_numerical_profile_t)::profile
    class(transaction_state_t),allocatable::snapshot
    logical::ok,available

    call initialize_parameters(parameters)
    call initialize_state(parameters,saturated,initial)
    call initialize_forcing(forcing)
    call fmr_new_b110_committed_state(committed,660006_int64,initial,0.0_real64,ok)
    call require(ok,'committed initialize')
    call committed%capture_checkpoint(checkpoint,available)
    call require(available,'checkpoint available')

    template%template_id=660001_int64
    template%physics_topology_id=660002_int64
    template%vertical_layout_id=660003_int64
    template%state_layout_id=660004_int64
    template%solver_interface_id=660005_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id=660006_int64
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0_real64
    config%transaction%mass_tolerance=1.0e-10_real64
    config%transaction%max_retries=2
    config%transaction%retry_scale=0.5_real64
    config%max_committed_substeps=4
    config%progress_tolerance=0.0_real64

    call backend%initialize(top)
    if(enable_manager)then
      profile=make_moving_interface_manager_profile('MOVING_INTERFACE_MANAGER',.true.)
      call backend%configure_moving_interface_profile(profile,ok)
      call require(ok,'manager profile accepted')
    end if

    call backend%run_trial(column,template,parameters,committed,forcing,config,0.0_real64,dt,checkpoint, &
         result,candidate,diagnostics)
    obs=backend%observation()
    write(*,'(*(g0))') 'F_PE_MIQUAL06_TRIAL|MANAGER=',merge(1,0,enable_manager),'|SAT=',merge(1,0,saturated), &
         '|STATUS=',result%status,'|COMPLETED=',merge(1,0,result%completed),'|CANDIDATE=',merge(1,0,candidate%ready()), &
         '|ADMISSION_REJ=',diagnostics%admission_rejections,'|SOLVER_REJ=',diagnostics%solver_rejections, &
         '|MASS_REJ=',diagnostics%mass_rejections,'|TEMP_REJ=',diagnostics%temporal_rejections, &
         '|ATTEMPTS=',diagnostics%attempts,'|SOLVER_EXEC=',merge(1,0,obs%solver_executed), &
         '|SOLVER_STATUS=',obs%solver_status
    call require(candidate%ready(),'candidate ready')
    call require(obs%solver_executed,'solver executed')
    call candidate%snapshot(snapshot,available)
    call require(available,'candidate snapshot available')
    select type(s=>snapshot)
    type is(fmr_b110_physical_state_t)
      final_state=s
    class default
      call require(.false.,'candidate physical type')
    end select
  end subroutine execute_case

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::i
    real(real64),parameter::tr=0.01_real64,ts=0.336701_real64,alpha=0.030304_real64
    real(real64),parameter::nvg=2.887502_real64,ksat=17.418504_real64,lambda=0.0736_real64
    real(real64)::mm
    mm=1.0_real64-1.0_real64/nvg
    p%parameter_set_id=660006_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=tr;p%cofgen(2,i)=ts;p%cofgen(3,i)=ksat;p%cofgen(4,i)=alpha
      p%cofgen(5,i)=lambda;p%cofgen(6,i)=nvg;p%cofgen(7,i)=mm;p%cofgen(8,i)=alpha
      p%cofgen(9,i)=0.0_real64;p%cofgen(10,i)=ksat;p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*ksat;p%cofgen(22,i)=-1.0e6_real64;p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-6_real64
    p%compartment_balance_tolerance=1.0e-12_real64;p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-9_real64;p%head_rel_tolerance=1.0e-9_real64;p%ponding_tolerance=1.0e-10_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%direct_retention_active=.false.
    p%ksatexm_extension_active=.false.;p%elasticity_active=.false.;p%frost_active=.false.
    p%soil_temperature_active=.false.;p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,saturated,s)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    logical,intent(in)::saturated
    type(fmr_b110_physical_state_t),intent(out)::s
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),kk(numnod),cap(numnod),dk(numnod)
    integer::i
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    if(saturated)then
      do i=1,numnod
        heads(i)=10.0_real64*real(i-tail_start,real64)
      end do
    else
      heads=-75.0_real64
    end if
    call provider%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads;s%water_content=water
    s%ponding_depth=0.0_real64;s%groundwater_level=-120.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=top_flux;f%top_head=0.0_real64;f%bottom_flux=0.0_real64;f%bottom_head=0.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(a,1x,a)')'F_PE_MIQUAL06_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fpe_miqual06_serialized_manager
