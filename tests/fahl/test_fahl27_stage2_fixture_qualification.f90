program test_fahl27_stage2_fixture_qualification
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0=-75.0_real64, mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=527027_int64
  character(len=64) :: id,arg
  real(real64) :: hbot,dt

  if(command_argument_count()/=3) error stop 'usage: test ID HBOT DT'
  call get_command_argument(1,id)
  call get_command_argument(2,arg); read(arg,*) hbot
  call get_command_argument(3,arg); read(arg,*) dt
  call execute_analytical(trim(id),hbot,dt)

contains

  subroutine execute_analytical(case_id,bottom_head,duration)
    character(len=*),intent(in)::case_id
    real(real64),intent(in)::bottom_head,duration
    type(fmr_serialized_reference_backend_t)::backend
    type(kernel_executor_t)::transaction_control
    type(kernel_committed_state_t)::committed
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(fmr_b110_physical_parameters_t)::parameters
    type(fmr_b110_physical_forcing_t)::forcing
    type(canonical_numerical_config_t)::config
    type(fmr_column_diagnostics_t)::diagnostic
    type(fmr_serialized_batch_diagnostics_t)::runtime
    type(fmr_serialized_column_result_t)::output
    type(fixed_flux_top_boundary_provider_t),target::top
    integer::active_calls
    logical::ok
    real(real64)::k0,mass_abs

    call initialize_parameters(parameters)
    call determine_initial_conductivity(parameters,duration,k0)
    call initialize_committed(committed,parameters,duration,ok)
    if(.not.ok) then
      write(*,'(A,1X,A,1X,A)') 'FAHL27_FIXTURE',trim(case_id),'INITIALIZATION_FAIL'
      return
    end if
    call initialize_forcing(forcing,-k0,bottom_head)
    call initialize_column(column,template)
    call initialize_config(config)

    output=fmr_serialized_column_result_t()
    output%column_id=column_id
    output%requested_t0=0.0_real64
    output%requested_t1=duration
    diagnostic=fmr_column_diagnostics_t()
    diagnostic%column_id=column_id
    runtime=fmr_serialized_batch_diagnostics_t()
    active_calls=0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,parameters, &
         forcing,committed,config,0.0_real64,duration,output,diagnostic,runtime,active_calls)

    if(output%mass%complete) then
      mass_abs=abs(output%mass%residual)
    else
      mass_abs=-1.0_real64
    end if

    write(*,'(A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,L1,1X,A,L1,1X,A,I0,1X,A,I0,1X,A,L1,1X,A,ES14.6,1X,A,I0,1X,A,I0)') &
         'FAHL27_FIXTURE',trim(case_id),'HBOT=',bottom_head,'DT=',duration, &
         'COMPLETED=',output%completed,'COMMITTED=',output%committed,'KERNEL=',output%kernel_status, &
         'SUBSTEPS=',output%accepted_substeps,'MASS_COMPLETE=',output%mass%complete,'MASS=',mass_abs, &
         'RETRIES=',diagnostic%retries,'REJECTED=',diagnostic%rejected
  end subroutine execute_analytical

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::i
    p%parameter_set_id=527027_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.032_real64; p%cofgen(2,i)=0.423_real64; p%cofgen(3,i)=4.75_real64
      p%cofgen(4,i)=0.0135_real64; p%cofgen(5,i)=0.365_real64; p%cofgen(6,i)=1.455_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i); p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64; p%cofgen(10,i)=p%cofgen(3,i); p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i); p%cofgen(22,i)=-1.0e6_real64; p%cofgen(23,i)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_gate; p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate; p%head_rel_tolerance=mass_gate; p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%adaptive_hydraulics_active=.false.
    p%elasticity_active=.false.; p%frost_active=.false.; p%soil_temperature_active=.false.
    p%drainage_response_active=.false.; p%black_evaporation_active=.false.; p%boesten_evaporation_active=.false.
  end subroutine initialize_parameters

  subroutine determine_initial_conductivity(p,duration,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::duration
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    hh=h0
    call provider%evaluate(hh,ww,kk,cc,dd)
    k0=kk(1)
  end subroutine determine_initial_conductivity

  subroutine initialize_committed(committed,p,duration,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::duration
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::hh(numnod),ww(numnod),kk(numnod),cc(numnod),dd(numnod)
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    hh=h0
    call provider%evaluate(hh,ww,kk,cc,dd)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=hh; state%water_content=ww
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine initialize_forcing(f,qtop,bottom_head)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop,bottom_head
    f%top_flux=qtop; f%top_head=h0; f%bottom_flux=0.0_real64; f%bottom_head=bottom_head
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=527021_int64; t%physics_topology_id=527022_int64; t%vertical_layout_id=527023_int64
    t%state_layout_id=527024_int64; t%solver_interface_id=527025_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=mass_gate
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%model_temporal_indicator_budget=0.0_real64
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

end program test_fahl27_stage2_fixture_qualification
