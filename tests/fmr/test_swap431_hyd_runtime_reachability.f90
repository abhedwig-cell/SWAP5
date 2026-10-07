program test_swap431_hyd_runtime_reachability
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
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
  use mod_b111_legacy_hydraulic_provider, only: b111_legacy_hydraulic_provider_t, &
       configure_b111_legacy_hydraulic_provider, bind_b111_legacy_hydraulic_provider, B111_LEGACY_HYD_OK
  use mod_b111_extended_hydraulic_provider, only: b111_extended_hydraulic_parameters_t, &
       b111_extended_hydraulic_provider_t, initialize_b111_extended_hydraulic_parameters, &
       bind_b111_extended_hydraulic_provider, B111_EXT_OK
  use mod_b111_conductivity_power_tail, only: b111_conductivity_power_tail_t, &
       configure_b111_conductivity_power_tail, bind_b111_conductivity_power_tail, B111_POWER_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: initial_head=-100.0_real64
  real(real64), parameter :: dt=0.05_real64
  real(real64), parameter :: mass_tol=1.0e-10_real64
  integer, parameter :: models(9)=[2,3,5,6,7,8,9,10,11]
  integer :: i

  do i=1,size(models)
    call run_case(models(i),.false.)
  end do
  call run_case(1,.true.)
  write(*,'(A)') 'SW431_HYD_RUNTIME_REACHABILITY=PASS'

contains

  subroutine run_case(model,power)
    integer,intent(in)::model
    logical,intent(in)::power
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: k0
    integer :: active_calls
    logical :: ok

    call initialize_parameters(parameters,model,power)
    call initialize_committed_state(committed,parameters,k0,ok)
    call require(ok,'committed state init')
    call initialize_forcing(forcing,-k0)
    call initialize_column(column,template)
    call initialize_config(config)

    output=fmr_serialized_column_result_t()
    output%column_id=910000_int64+int(model,int64)+merge(100_int64,0_int64,power)
    output%requested_t0=0.0_real64
    output%requested_t1=dt
    diagnostic=fmr_column_diagnostics_t()
    diagnostic%column_id=output%column_id
    runtime=fmr_serialized_batch_diagnostics_t()
    active_calls=0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,parameters, &
         forcing,committed,config,0.0_real64,dt,output,diagnostic,runtime,active_calls)
    observation=backend%observation()

    call require(output%completed.and.output%committed,'runtime commit')
    call require(output%mass%complete,'mass complete')
    call require(abs(output%mass%residual)<=mass_tol,'hard mass')
    call require(observation%solver_executed,'solver executed')
    call require(output%accepted_substeps>0,'accepted substep')
    if(power)then
      write(*,'(A,1X,ES16.8)')'SW431_HYD_POWER_RUNTIME_PASS',output%mass%residual
    else
      write(*,'(A,I0,1X,ES16.8)')'SW431_HYD_MODEL_RUNTIME_PASS=',model,output%mass%residual
    end if
  end subroutine

  subroutine initialize_parameters(p,model,power)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::model
    logical,intent(in)::power
    integer::j
    real(real64)::m1,m2

    m1=1.0_real64-1.0_real64/1.62_real64
    m2=1.0_real64-1.0_real64/1.35_real64
    p%parameter_set_id=910001_int64+int(model,int64)
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod),p%hydraulic_model(numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64;p%hydraulic_model=model
    do j=1,numnod
      p%cofgen(1,j)=0.06_real64;p%cofgen(2,j)=0.44_real64;p%cofgen(3,j)=12.5_real64
      p%cofgen(4,j)=0.018_real64;p%cofgen(5,j)=0.45_real64;p%cofgen(6,j)=1.62_real64;p%cofgen(7,j)=m1
      p%cofgen(8,j)=p%cofgen(4,j);p%cofgen(9,j)=0.0_real64
      p%cofgen(10,j)=p%cofgen(3,j);p%cofgen(11,j)=0.999_real64;p%cofgen(12,j)=0.99_real64*p%cofgen(3,j)
      p%cofgen(13,j)=0.0035_real64;p%cofgen(14,j)=1.35_real64;p%cofgen(15,j)=m2
      p%cofgen(16,j)=0.63_real64;p%cofgen(17,j)=0.37_real64
      p%cofgen(18,j)=1.0e6_real64;p%cofgen(19,j)=100.0_real64;p%cofgen(20,j)=-1.5_real64;p%cofgen(21,j)=0.04_real64
      p%cofgen(22,j)=-200.0_real64;p%cofgen(23,j)=default_k_at(-200.0_real64,p%cofgen(:,j))
    end do
    p%conductivity_power_tail_active=power
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=20;p%max_backtracking=8;p%min_step_duration=1.0e-9_real64
    p%compartment_balance_tolerance=mass_tol;p%total_balance_tolerance=mass_tol
    p%head_abs_tolerance=1.0e-11_real64;p%head_rel_tolerance=1.0e-11_real64;p%ponding_tolerance=1.0e-11_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%elasticity_active=.false.
    p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine

  subroutine initialize_committed_state(committed,p,k0,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(out)::k0
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    real(real64)::head(numnod),theta(numnod),k(numnod),cap(numnod),dk(numnod)
    type(b110_default_mvg_parameters_t),target::bp
    type(b110_default_mvg_provider_t),target::base
    type(b111_legacy_hydraulic_provider_t),target::legacy
    type(b111_extended_hydraulic_parameters_t),target::ep
    type(b111_extended_hydraulic_provider_t),target::ext
    type(b111_conductivity_power_tail_t)::pw
    integer::status

    call initialize_b110_default_mvg_parameters(bp,p%cofgen)
    call bind_b110_default_mvg_provider(base,bp,dt)
    call configure_b111_legacy_hydraulic_provider(legacy,bp%cofgen,p%hydraulic_model,status)
    call require(status==B111_LEGACY_HYD_OK,'legacy configure')
    call bind_b111_legacy_hydraulic_provider(legacy,base,dt,status)
    call require(status==B111_LEGACY_HYD_OK,'legacy bind')
    call initialize_b111_extended_hydraulic_parameters(ep,p%hydraulic_model,bp%cofgen,status)
    call require(status==B111_EXT_OK,'extended configure')
    call bind_b111_extended_hydraulic_provider(ext,ep,legacy,status)
    call require(status==B111_EXT_OK,'extended bind')

    head=initial_head
    if(p%conductivity_power_tail_active)then
      call configure_b111_conductivity_power_tail(pw,bp%cofgen,p%hydraulic_model,status)
      call require(status==B111_POWER_OK,'power configure')
      call bind_b111_conductivity_power_tail(pw,ext,status)
      call require(status==B111_POWER_OK,'power bind')
      call pw%evaluate(head,theta,k,cap,dk)
    else
      call ext%evaluate(head,theta,k,cap,dk)
    end if
    k0=k(1)
    call require(k0>0.0_real64,'positive initial K')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=head;state%water_content=theta;state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
    call fmr_new_b110_committed_state(committed,910000_int64,state,0.0_real64,ok)
  end subroutine

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q;f%top_head=initial_head;f%bottom_flux=q;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine initialize_column(column,template)
    type(fmr_logical_column_t),intent(out)::column
    type(fmr_template_t),intent(out)::template
    template%template_id=910001_int64;template%physics_topology_id=910002_int64
    template%vertical_layout_id=910003_int64;template%state_layout_id=910004_int64;template%solver_interface_id=910005_int64
    template%optional_state_layout_id=0_int64;template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=910000_int64;column%template_id=template%template_id;column%parameter_ref=1_int64
    column%state_handle=1_int64;column%forcing_handle=1_int64;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c=canonical_numerical_config_t()
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;c%transaction%temporal_tolerance=1.0e-5_real64
    c%transaction%max_retries=6;c%transaction%retry_scale=0.5_real64;c%transaction%mass_tolerance=mass_tol
    c%max_committed_substeps=64;c%progress_tolerance=0.0_real64
  end subroutine

  pure real(real64) function default_k_at(h,c) result(k)
    real(real64),intent(in)::h,c(:)
    real(real64)::m,se,t
    m=1.0_real64-1.0_real64/c(6)
    se=(1.0_real64+abs(c(4)*h)**c(6))**(-m)
    t=(1.0_real64-se**(1.0_real64/m))**m
    k=c(3)*se**c(5)*(1.0_real64-t)**2
  end function

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'SW431_HYD_RUNTIME_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program test_swap431_hyd_runtime_reachability
