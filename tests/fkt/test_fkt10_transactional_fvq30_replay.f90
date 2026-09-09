program test_fkt10_transactional_fvq30_replay
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t, fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_TEMPORAL_INDICATOR_AVAILABLE
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: lineage_id = 103001_int64

  real(real64) :: h0, jump, step_dt, expected_binf, actual_binf, binf_diff
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod)
  real(real64), allocatable :: seed_snapshot(:), after_snapshot(:), bad_seed(:)
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_committed_state_t) :: committed, bad_committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_serialized_physical_observation_t) :: observation
  type(canonical_numerical_config_t) :: config
  integer(int64) :: fp_before, fp_after, revision_before
  real(real64) :: time_after
  logical :: ok, available, history_available

  call read_inputs(h0, jump, step_dt, expected_binf)
  call configure_fixture(h0, jump, step_dt, column, template, parameters, forcing, initial_state, &
       hydraulic_parameters, constitutive, heads, water, conductivity, capacity, dkdh)

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity(1)*(h0-(h0+jump))/(0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual/(capacity*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite frozen bootstrap derivative')

  allocate(bad_seed(numnod-1))
  bad_seed = hdot_n(1:numnod-1)
  call fmr_new_b110_temporal_indicator_committed_state(bad_committed, lineage_id+1_int64, initial_state, t0, ok, bad_seed)
  call require(.not. ok, 'wrong-size initial history seed fails closed')

  call fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, initial_state, t0, ok, hdot_n)
  call require(ok, 'qualified initial history seed accepted')
  call get_committed_history(committed, seed_snapshot, history_available)
  call require(history_available, 'seeded history available')
  call require(same_vector_bits(seed_snapshot, hdot_n), 'seeded history bitwise identity')
  revision_before = committed%current_revision()
  fp_before = committed_physical_fingerprint(committed)

  call configure_transaction(config)
  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint from seeded origin')
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t0+step_dt, checkpoint, &
       result, candidate, diagnostics)

  call require(.not. result%completed, 'outer transaction rejected without admitted F-KT09 certificate')
  call require(.not. candidate%ready(), 'certificate rejection publishes no candidate')
  call require(diagnostics%temporal_certificate_unavailable_rejections == 1, &
       'certificate unavailable rejection diagnosed')
  call require(diagnostics%mass_rejections == 0, 'no mass rejection before temporal rejection')
  call require(diagnostics%max_abs_step_mass_residual <= hard_mass_gate, 'hard mass gate before temporal rejection')
  call require(diagnostics%headcalc_calls == 1, 'single principal Richards trajectory in model-certificate mode')

  observation = backend%observation()
  call require(observation%solver_executed, 'real Richards solver executed')
  call require(observation%temporal_indicator_enabled, 'transactional history service enabled')
  call require(observation%temporal_previous_derivative_available, 'seeded previous derivative supplied transactionally')
  call require(observation%temporal_current_derivative_available, 'current derivative candidate materialized')
  call require(observation%temporal_indicator_status == SW_TEMPORAL_INDICATOR_AVAILABLE, 'indicator status available')
  call require(observation%temporal_indicator_available, 'B_inf available diagnostically')
  call require(observation%temporal_additional_full_nonlinear_solves == 0, 'zero extra nonlinear trajectories')
  call require(observation%temporal_additional_tridiagonal_solves == 1, 'exactly one additional defect TRIDAG')
  call require(diagnostics%linear_solves == observation%solver_diagnostics%linear_solves + 1, &
       'transaction cost includes exactly one additional TRIDAG')

  actual_binf = observation%temporal_head_inf_bound
  call require(ieee_is_finite(actual_binf) .and. actual_binf >= 0.0_real64, 'finite nonnegative B_inf')
  binf_diff = abs(actual_binf-expected_binf)
  call require(binf_diff <= 65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(actual_binf),abs(expected_binf)), &
       'transactional B_inf equals frozen owner value')

  call get_committed_history(committed, after_snapshot, history_available)
  call require(history_available .and. same_vector_bits(after_snapshot, seed_snapshot), &
       'rejected transaction preserves committed history bitwise')
  fp_after = committed_physical_fingerprint(committed)
  call require(fp_after == fp_before, 'rejected transaction preserves committed physical state')
  call require(committed%current_revision() == revision_before, 'rejected transaction preserves revision')
  call committed%current_time(time_after, available)
  call require(available .and. same_real_bits(time_after,t0), 'rejected transaction preserves committed time')

  write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0)') &
       'FKT10_G_ROW:H0=',h0,':JUMP=',jump,':DT=',step_dt,':BINF=',actual_binf,':EXPECTED=',expected_binf, &
       ':EXTRA_TRIDAG=',observation%temporal_additional_tridiagonal_solves, &
       ':EXTRA_NONLINEAR=',observation%temporal_additional_full_nonlinear_solves
  write(*,'(A,ES26.17E3,A,ES26.17E3,A,I0)') 'FKT10_G_DIAG:BINF_ABS_DIFF=',binf_diff, &
       ':MAX_STEP_MASS=',diagnostics%max_abs_step_mass_residual,':HEADCALC_CALLS=',diagnostics%headcalc_calls
  write(*,'(A)') 'FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASE PASS'

contains

  subroutine read_inputs(initial_head, jump_head, dt_in, expected)
    real(real64), intent(out) :: initial_head, jump_head, dt_in, expected
    character(len=128) :: arg
    integer :: stat
    if (command_argument_count() /= 4) error stop 'F-KT10 Gate G requires h0 jump dt expected_Binf'
    call get_command_argument(1,arg); read(arg,*,iostat=stat) initial_head; if (stat/=0) error stop 'bad h0'
    call get_command_argument(2,arg); read(arg,*,iostat=stat) jump_head; if (stat/=0) error stop 'bad jump'
    call get_command_argument(3,arg); read(arg,*,iostat=stat) dt_in; if (stat/=0) error stop 'bad dt'
    call get_command_argument(4,arg); read(arg,*,iostat=stat) expected; if (stat/=0) error stop 'bad expected Binf'
    call require(dt_in > 0.0_real64 .and. ieee_is_finite(dt_in), 'positive finite dt')
    call require(expected >= 0.0_real64 .and. ieee_is_finite(expected), 'finite expected Binf')
  end subroutine read_inputs

  subroutine configure_fixture(initial_head, jump_head, dt_in, col, tpl, p, f, state, hp, cp, &
                               h, theta, kval, cap, dk)
    real(real64), intent(in) :: initial_head, jump_head, dt_in
    type(fmr_logical_column_t), intent(out) :: col
    type(fmr_template_t), intent(out) :: tpl
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), intent(out) :: cp
    real(real64), intent(out) :: h(numnod), theta(numnod), kval(numnod), cap(numnod), dk(numnod)
    integer :: i

    col%column_id = 103001_int64
    col%template_id = 10301_int64
    col%parameter_ref = 1_int64
    col%state_handle = 1_int64
    col%forcing_handle = 1_int64
    col%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    tpl%template_id = col%template_id
    tpl%physics_topology_id = 10301_int64
    tpl%vertical_layout_id = 10302_int64
    tpl%state_layout_id = 10303_int64
    tpl%solver_interface_id = 10304_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    p%parameter_set_id = 103001_int64
    p%active_nodes = numnod
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
    p%max_iterations=8; p%max_backtracking=4; p%min_step_duration=1.0e-6_real64
    p%compartment_balance_tolerance=hard_mass_gate; p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=1.0e-12_real64; p%head_rel_tolerance=1.0e-12_real64; p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(cp,hp,dt_in)
    h=initial_head
    call cp%evaluate(h,theta,kval,cap,dk)
    call require(all(ieee_is_finite(cap)) .and. all(cap>0.0_real64), 'positive finite bootstrap capacity')
    call require(all(ieee_is_finite(kval)) .and. all(kval>0.0_real64), 'positive finite bootstrap conductivity')
    do i=2,numnod
      call require(same_real_bits(kval(i),kval(1)), 'uniform initial conductivity')
    end do

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64

    f%top_flux=-kval(1); f%top_head=initial_head; f%bottom_flux=12345.678_real64
    f%bottom_head=initial_head+jump_head
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine configure_fixture

  subroutine configure_transaction(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance = 0.0_real64
    c%transaction%mass_tolerance = hard_mass_gate
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    c%max_committed_substeps = 1
    c%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine get_committed_history(c, derivative, available_out)
    type(kernel_committed_state_t), intent(in) :: c
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available_out
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call c%snapshot(snapshot,got)
    call require(got,'committed history snapshot')
    select type (s=>snapshot)
    type is (fmr_b110_temporal_indicator_state_t)
      call s%temporal_history_snapshot(derivative,available_out)
    class default
      call require(.false.,'committed history dynamic type')
    end select
  end subroutine get_committed_history

  integer(int64) function committed_physical_fingerprint(c) result(fp)
    type(kernel_committed_state_t), intent(in) :: c
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: i
    call c%snapshot(snapshot,got)
    call require(got,'committed physical snapshot')
    fp=1469598103934665603_int64
    select type (s=>snapshot)
    class is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(s%active_nodes,int64))
      do i=1,s%active_nodes
        fp=ieor(fp,transfer(s%pressure_head(i),fp))
        fp=ieor(fp,transfer(s%water_content(i),fp))
      end do
      fp=ieor(fp,transfer(s%ponding_depth,fp))
      fp=ieor(fp,transfer(s%groundwater_level,fp))
    class default
      call require(.false.,'committed physical dynamic type')
    end select
  end function committed_physical_fingerprint

  logical function same_vector_bits(a,b) result(same)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    same=size(a)==size(b)
    if (.not. same) return
    do i=1,size(a)
      if (.not. same_real_bits(a(i),b(i))) then
        same=.false.; return
      end if
    end do
  end function same_vector_bits

  logical function same_real_bits(a,b) result(same)
    real(real64), intent(in) :: a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_real_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FKT10_GATE_G_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt10_transactional_fvq30_replay
