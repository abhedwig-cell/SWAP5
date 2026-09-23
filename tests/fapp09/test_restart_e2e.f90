program test_fapp09_restart_e2e
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_execute_serialized_resolved_physical_column
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_ribasim_surface_water_profile, only: ribasim_surface_water_profile_t, &
       accepted_ribasim_surface_water_head_view_t, bind_accepted_ribasim_heads, RSW_PROFILE_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0=12000.125_real64, tm=12000.250_real64, t1=12000.375_real64
  real(real64), parameter :: initial_head=-123.0_real64, initial_gwl=-2.25_real64
  real(real64), parameter :: signed_rate=1.0e-2_real64, mass_gate=1.0e-10_real64
  integer(int64), parameter :: column_id=49001_int64, parameter_set_identity=4905001_int64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
  type(kernel_committed_state_t) :: states_cont(1), states_restart(1)
  type(fmr_committed_restart_bundle_t) :: bundle
  type(ribasim_surface_water_profile_t) :: profile
  type(accepted_ribasim_surface_water_head_view_t) :: head_view
  type(fmr_serialized_column_result_t) :: first_out, cont_out, restart_out
  logical :: exported, restored
  integer :: status

  call initialize_base(states_cont(1), columns(1), templates(1), parameters)
  allocate(head_view%level_head_cm(1))

  call configure_accepted_head(head_view, 101_int64, t0, -12.25_real64)
  call configure_forcing(parameters, profile, head_view, signed_rate, forcing_a, status)
  call require(status == RSW_PROFILE_OK, 'first accepted head binding')
  call execute_window(states_cont(1), columns(1), templates(1), parameters, forcing_a, t0, tm, first_out)
  call require(first_out%committed, 'first window committed')
  call require(abs(first_out%mass%residual) <= mass_gate, 'first window mass closure')
  call require(first_out%final_revision == 1_int64, 'first window revision')

  call fmr_export_committed_restart(columns, templates, states_cont, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'restart export')
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, states_restart, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'restart restore')
  call require(committed_states_identical(states_cont(1), states_restart(1)), 'midpoint restored state identity')
  write(*,'(A)') 'FAPP09_RESTART_MIDPOINT_STATE_IDENTITY=PASS'

  head_view%accepted = .false.
  call configure_forcing(parameters, profile, head_view, -signed_rate, forcing_b, status)
  call require(status /= RSW_PROFILE_OK, 'trial external head rejected')
  call require(all(.not. forcing_b%drainage_response_controls%resolved_surface_water_head_supplied), &
       'trial external head produced no controls')
  call require(committed_states_identical(states_cont(1), states_restart(1)), 'trial head did not mutate SWAP state')
  write(*,'(A)') 'FAPP09_RESTART_TRIAL_HEAD_FAIL_CLOSED=PASS'

  call configure_accepted_head(head_view, 102_int64, tm, 7.75_real64)
  call configure_forcing(parameters, profile, head_view, -signed_rate, forcing_b, status)
  call require(status == RSW_PROFILE_OK, 'second accepted head binding')

  call execute_window(states_cont(1), columns(1), templates(1), parameters, forcing_b, tm, t1, cont_out)
  call execute_window(states_restart(1), columns(1), templates(1), parameters, forcing_b, tm, t1, restart_out)

  call require(cont_out%committed .and. restart_out%committed, 'second windows committed')
  call require(abs(cont_out%mass%residual) <= mass_gate .and. abs(restart_out%mass%residual) <= mass_gate, &
       'second window mass closure')
  call require(committed_states_identical(states_cont(1), states_restart(1)), 'continuous versus restart final state')
  call require(results_identical(cont_out, restart_out), 'continuous versus restart result identity')
  call require(states_cont(1)%current_revision() == 2_int64 .and. states_restart(1)%current_revision() == 2_int64, &
       'restart revision continuation')
  write(*,'(A)') 'FAPP09_RESTART_POST_BIND_RESULT_IDENTITY=PASS'
  write(*,'(A)') 'FAPP09_RESTART_EXACTLY_ONCE_MASS=PASS'
  write(*,'(A)') 'FAPP09_EXTERNAL_HEAD_NOT_PERSISTED_IN_SWAP_RESTART=PASS'
  write(*,'(A)') 'FAPP09_RESTART_E2E=PASS'

contains

  subroutine configure_accepted_head(view, revision, time, head)
    type(accepted_ribasim_surface_water_head_view_t), intent(inout) :: view
    integer(int64), intent(in) :: revision
    real(real64), intent(in) :: time, head
    view%accepted = .true.
    view%accepted_revision = revision
    view%accepted_time = time
    view%level_head_cm(1) = head
  end subroutine configure_accepted_head

  subroutine configure_forcing(parameters, profile, view, balancing_qssdi, forcing, bind_status)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(ribasim_surface_water_profile_t), intent(in) :: profile
    type(accepted_ribasim_surface_water_head_view_t), intent(in) :: view
    real(real64), intent(in) :: balancing_qssdi
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    integer, intent(out) :: bind_status
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, tm-t0)
    heads = initial_head
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k0 = conductivity(1)

    forcing%top_flux = -k0
    forcing%top_head = initial_head
    forcing%bottom_flux = -k0
    forcing%bottom_head = -321.0_real64
    allocate(forcing%drainage_response_controls(1), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    call bind_accepted_ribasim_heads(profile, view, forcing%drainage_response_controls, bind_status)
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%subsurface_irrigation_source(numnod) = balancing_qssdi
    forcing%root_extraction_sink = 0.0_real64
  end subroutine configure_forcing

  subroutine initialize_base(committed, column, template, parameters)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    logical :: ok
    integer :: k

    parameters%parameter_set_id = parameter_set_identity
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod); parameters%cofgen=0.0_real64
    do k=1,numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.; parameters%frost_active=.false.; parameters%drainage_response_active=.true.
    allocate(parameters%drainage_response_levels(1))
    parameters%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    parameters%drainage_response_levels(1)%extended%zbotdr_cm=-100.0_real64
    parameters%drainage_response_levels(1)%extended%drain_type=EXT_DRAIN_TUBE
    parameters%drainage_response_levels(1)%extended%spacing_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rdrain_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rinfi_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rentry_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%rexit_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%gwlinf_cm=-200.0_real64
    parameters%drainage_response_levels(1)%extended%pondmx_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%highest_level=.false.
    parameters%drainage_response_levels(1)%extended%highest_surface_mode=EXT_DRAIN_TOP_NONE

    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,tm-t0)
    heads=initial_head
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
    call fmr_new_b110_committed_state(committed,column_id,state,t0,ok)
    call require(ok,'initial committed state')

    template%template_id=4901_int64; template%physics_topology_id=49011_int64; template%vertical_layout_id=49012_int64
    template%state_layout_id=49013_int64; template%solver_interface_id=49014_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_base

  subroutine execute_window(committed, column, template, parameters, forcing, ta, tb, output)
    type(kernel_committed_state_t), intent(inout) :: committed
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: ta, tb
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx_control
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_calls

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e3_real64
    config%transaction%mass_tolerance=mass_gate
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=2
    config%max_committed_substeps=8
    config%progress_tolerance=0.0_real64
    call backend%initialize(top)
    output=fmr_serialized_column_result_t(); output%column_id=column_id; output%requested_t0=ta; output%requested_t1=tb
    diagnostic=fmr_column_diagnostics_t(); diagnostic%column_id=column_id
    runtime=fmr_serialized_batch_diagnostics_t(); active_calls=0
    call fmr_execute_serialized_resolved_physical_column(backend,tx_control,column,template,parameters,forcing, &
         committed,config,ta,tb,output,diagnostic,runtime,active_calls)
    call require(active_calls==0,'active call counter restored')
  end subroutine execute_window

  logical function committed_states_identical(left,right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left,right
    class(transaction_state_t), allocatable :: a,b
    logical :: ga,gb,ta,tb
    real(real64) :: xa,xb
    equal=.false.
    if(left%current_lineage_id()/=right%current_lineage_id() .or. left%current_revision()/=right%current_revision())return
    call left%current_time(xa,ta); call right%current_time(xb,tb)
    if(ta .neqv. tb)return
    if(ta .and. .not.same_bits(xa,xb))return
    call left%snapshot(a,ga); call right%snapshot(b,gb)
    if(.not.ga .or. .not.gb)return
    select type(pa=>a)
    type is(fmr_b110_physical_state_t)
      select type(pb=>b)
      type is(fmr_b110_physical_state_t)
        equal=pa%active_nodes==pb%active_nodes .and. all_bits(pa%pressure_head,pb%pressure_head) .and. &
          all_bits(pa%water_content,pb%water_content) .and. same_bits(pa%ponding_depth,pb%ponding_depth) .and. &
          same_bits(pa%groundwater_level,pb%groundwater_level)
      end select
    end select
  end function committed_states_identical

  logical function results_identical(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal=a%committed .eqv. b%committed
    equal=equal .and. a%final_revision==b%final_revision
    equal=equal .and. a%mass%complete .eqv. b%mass%complete
    equal=equal .and. same_bits(a%mass%storage_start,b%mass%storage_start)
    equal=equal .and. same_bits(a%mass%storage_end,b%mass%storage_end)
    equal=equal .and. same_bits(a%mass%total_in,b%mass%total_in)
    equal=equal .and. same_bits(a%mass%total_out,b%mass%total_out)
    equal=equal .and. same_bits(a%mass%residual,b%mass%residual)
  end function results_identical

  logical function all_bits(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if(.not.equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then
        equal=.false.
        return
      end if
    end do
  end function all_bits

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAPP09_E2E_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fapp09_restart_e2e
