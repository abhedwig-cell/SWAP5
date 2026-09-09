program test_fkt11_richards_head_budget_policy
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t, fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: t0 = 2200.125_real64
  real(real64), parameter :: step_dt = 0.3_real64
  real(real64), parameter :: head0 = -125.0_real64
  real(real64), parameter :: bottom_jump = 0.03_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: lineage_id = 111001_int64

  character(len=64) :: case_id
  character(len=128) :: arg
  real(real64) :: expected_binf, actual_binf, expected_c, budget
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: static_residual(numnod), hdot_n(numnod)
  real(real64), allocatable :: history_before(:), history_after(:)
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t) :: constitutive
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(fmr_serialized_reference_backend_t) :: backend
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_physical_observation_t) :: observation
  type(canonical_numerical_config_t) :: config
  integer(int64) :: fp_before, fp_after, revision_before
  real(real64) :: time_before, time_after
  logical :: ok, available, history_available_before, history_available_after, did_commit
  integer :: commit_status, stat

  if (command_argument_count() /= 2) error stop 'F-KT11 requires CASE expected_Binf'
  call get_command_argument(1,case_id)
  call get_command_argument(2,arg)
  read(arg,*,iostat=stat) expected_binf
  call require(stat == 0 .and. ieee_is_finite(expected_binf) .and. expected_binf > 0.0_real64, &
       'positive finite source-locked direct B_inf')

  call configure_fixture(column, template, parameters, forcing, initial_state, hydraulic_parameters, constitutive, &
       heads, water, conductivity, capacity, dkdh)

  static_residual = 0.0_real64
  static_residual(numnod) = conductivity(1)*(head0-(head0+bottom_jump))/(0.5_real64*parameters%dz(numnod))
  hdot_n = -static_residual/(capacity*parameters%dz)
  call require(all(ieee_is_finite(hdot_n)), 'finite restricted right-sided derivative seed')

  if (trim(case_id) == 'NO_HISTORY_WITH_VALID_BUDGET') then
    call fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, initial_state, t0, ok)
  else
    call fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, initial_state, t0, ok, hdot_n)
  end if
  call require(ok, 'committed state initialization')

  call get_committed_history(committed, history_before, history_available_before)
  if (trim(case_id) == 'NO_HISTORY_WITH_VALID_BUDGET') then
    call require(.not. history_available_before, 'no-history case starts without accepted history')
  else
    call require(history_available_before .and. same_vector_bits(history_before, hdot_n), &
         'qualified seed is present bitwise')
  end if

  revision_before = committed%current_revision()
  fp_before = committed_physical_fingerprint(committed)
  call committed%current_time(time_before, available)
  call require(available .and. same_real_bits(time_before,t0), 'initial committed time')

  call configure_transaction(config)
  select case (trim(case_id))
  case ('VALID_ACCEPT')
    budget = 2.0_real64*expected_binf
    expected_c = 0.5_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
  case ('VALID_REJECT')
    budget = 0.5_real64*expected_binf
    expected_c = 2.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
  case ('MISSING_BUDGET')
    budget = 0.0_real64
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .false.
  case ('INVALID_ZERO_BUDGET')
    budget = 0.0_real64
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = 0.0_real64
  case ('NO_HISTORY_WITH_VALID_BUDGET')
    budget = 2.0_real64*expected_binf
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
  case ('BOUNDED_RETRY_NO_MONOTONICITY_CLAIM')
    budget = 1.0e-12_real64
    expected_c = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget
    config%transaction%max_retries = 2
  case default
    error stop 'unknown F-KT11 owner case'
  end select

  call backend%initialize(top_provider)
  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint from exact committed origin')
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t0+step_dt, checkpoint, &
       result, candidate, diagnostics)
  observation = backend%observation()

  call require(diagnostics%mass_rejections == 0, 'hard mass gate passes before temporal decision')
  call require(diagnostics%max_abs_step_mass_residual <= hard_mass_gate, 'hard 1e-12 mass residual gate')
  call require(observation%temporal_indicator_enabled, 'Richards temporal history service enabled')
  call require(observation%temporal_head_budget_supplied .eqv. config%model_temporal_indicator_budget_available, &
       'budget supplied diagnostic')
  call require(observation%temporal_additional_full_nonlinear_solves == 0, &
       'indicator adds zero full nonlinear trajectories')
  call require(observation%temporal_additional_tridiagonal_solves == 1, &
       'indicator adds one defect TRIDAG on evaluated attempt')
  call require(diagnostics%headcalc_calls == diagnostics%attempts, &
       'one principal Richards trajectory per transaction attempt')

  select case (trim(case_id))
  case ('VALID_ACCEPT')
    call require(result%completed .and. candidate%ready(), 'valid certificate accepted and candidate materialized')
    call require(diagnostics%attempts == 1 .and. diagnostics%retries == 0 .and. diagnostics%trial_rollbacks == 0, &
         'valid accept single attempt no rollback')
    call require(diagnostics%temporal_rejections == 0 .and. diagnostics%temporal_certificate_unavailable_rejections == 0, &
         'valid accept has no temporal rejection')
    call require(observation%temporal_previous_derivative_available .and. observation%temporal_indicator_available, &
         'valid accept has accepted history and raw B_inf')
    call require(observation%temporal_head_budget_valid, 'valid accept budget valid')
    call require(same_real_bits(observation%temporal_head_budget,budget), 'valid accept native budget diagnostic')
    call require(observation%temporal_certificate_available, 'valid accept certificate available')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'available', 'valid accept reason')
    actual_binf = observation%temporal_head_inf_bound
    call require(close_to(actual_binf,expected_binf), 'valid accept B_inf equals direct oracle')
    call require(close_to(observation%temporal_normalized_indicator,expected_c), 'VALID_ACCEPT C_h=0.5')
    call require(result%mass%complete .and. abs(result%mass%residual) <= hard_mass_gate, 'accepted mass remains complete')
    fp_after = committed_physical_fingerprint(committed)
    call require(fp_after == fp_before .and. committed%current_revision() == revision_before, &
         'accepted trial does not mutate committed state before explicit commit')
    call fmr_commit_candidate(transaction_control, committed, candidate, diagnostics, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'accepted candidate explicit commit')
    call require(committed%current_revision() == revision_before+1_int64, 'accepted commit increments revision once')
    call committed%current_time(time_after,available)
    call require(available .and. same_real_bits(time_after,t0+step_dt), 'accepted commit advances exact committed time')
    call get_committed_history(committed,history_after,history_available_after)
    call require(history_available_after, 'accepted commit publishes current derivative history')

  case ('VALID_REJECT')
    call require(.not. result%completed .and. .not. candidate%ready(), 'C_h=2 rejected')
    call require(diagnostics%attempts == 1 .and. diagnostics%retries == 0 .and. diagnostics%trial_rollbacks == 1, &
         'threshold reject exact rollback')
    call require(diagnostics%temporal_rejections == 1 .and. diagnostics%temporal_certificate_unavailable_rejections == 0, &
         'threshold reject is available-certificate rejection')
    call require(observation%temporal_head_budget_valid .and. observation%temporal_certificate_available, &
         'threshold reject certificate diagnostic remains available')
    actual_binf = observation%temporal_head_inf_bound
    call require(close_to(actual_binf,expected_binf), 'valid reject B_inf equals direct oracle')
    call require(close_to(observation%temporal_normalized_indicator,expected_c), 'VALID_REJECT C_h=2')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)

  case ('MISSING_BUDGET')
    call require(.not. result%completed .and. .not. candidate%ready(), 'missing budget rejects')
    call require(.not. observation%temporal_head_budget_supplied .and. .not. observation%temporal_head_budget_valid, &
         'missing budget diagnostics')
    call require(.not. observation%temporal_certificate_available, 'missing budget certificate unavailable')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'budget-not-supplied', 'missing budget reason')
    call require(diagnostics%temporal_certificate_unavailable_rejections == 1 .and. diagnostics%temporal_rejections == 1, &
         'missing budget unavailable rejection counted')
    actual_binf = observation%temporal_head_inf_bound
    call require(close_to(actual_binf,expected_binf), 'missing budget still exposes raw B_inf')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)

  case ('INVALID_ZERO_BUDGET')
    call require(.not. result%completed .and. .not. candidate%ready(), 'zero budget rejects')
    call require(observation%temporal_head_budget_supplied .and. .not. observation%temporal_head_budget_valid, &
         'zero budget supplied but invalid')
    call require(.not. observation%temporal_certificate_available, 'zero budget certificate unavailable')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'budget-invalid', 'zero budget reason')
    call require(diagnostics%temporal_certificate_unavailable_rejections == 1 .and. diagnostics%temporal_rejections == 1, &
         'zero budget unavailable rejection counted')
    actual_binf = observation%temporal_head_inf_bound
    call require(close_to(actual_binf,expected_binf), 'zero budget still exposes raw B_inf')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)

  case ('NO_HISTORY_WITH_VALID_BUDGET')
    call require(.not. result%completed .and. .not. candidate%ready(), 'no-history origin rejects')
    call require(observation%temporal_head_budget_valid, 'no-history case budget itself valid')
    call require(.not. observation%temporal_previous_derivative_available, 'no-history previous derivative absent')
    call require(observation%temporal_current_derivative_available, 'no-history trial may materialize current derivative privately')
    call require(.not. observation%temporal_certificate_available, 'no-history certificate unavailable')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'history-unavailable', 'no-history reason')
    call require(diagnostics%temporal_certificate_unavailable_rejections == 1, 'no-history unavailable rejection counted')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)
    call get_committed_history(committed,history_after,history_available_after)
    call require(.not. history_available_after, 'rejected no-history trial cannot bootstrap committed history')

  case ('BOUNDED_RETRY_NO_MONOTONICITY_CLAIM')
    call require(.not. result%completed .and. .not. candidate%ready(), 'small fixed budget exhausts bounded retries')
    call require(diagnostics%attempts == 3 .and. diagnostics%retries == 2 .and. diagnostics%trial_rollbacks == 3, &
         'max_retries=2 gives exactly three attempts and exact rollbacks')
    call require(diagnostics%temporal_rejections == 3, 'each bounded retry rejected temporally')
    call require(diagnostics%temporal_certificate_unavailable_rejections == 0, &
         'bounded retry uses available certificate, not unavailable fallback')
    call require(observation%temporal_head_budget_valid .and. same_real_bits(observation%temporal_head_budget,budget), &
         'fixed retry budget retained unchanged')
    call assert_rejected_state_unchanged(committed,fp_before,revision_before,time_before,history_before,history_available_before)
  end select

  write(*,'(A,A)') 'FKT11_CASE=',trim(case_id)
  write(*,'(A,ES26.17E3)') 'FKT11_DIRECT_BINF=',expected_binf
  write(*,'(A,ES26.17E3)') 'FKT11_BUDGET=',budget
  write(*,'(A,L1)') 'FKT11_BUDGET_SUPPLIED=',observation%temporal_head_budget_supplied
  write(*,'(A,L1)') 'FKT11_BUDGET_VALID=',observation%temporal_head_budget_valid
  write(*,'(A,ES26.17E3)') 'FKT11_RAW_BINF=',observation%temporal_head_inf_bound
  write(*,'(A,ES26.17E3)') 'FKT11_CH=',observation%temporal_normalized_indicator
  write(*,'(A,L1)') 'FKT11_CERTIFICATE_AVAILABLE=',observation%temporal_certificate_available
  write(*,'(A,A)') 'FKT11_UNAVAILABLE_REASON=',trim(observation%temporal_certificate_unavailable_reason)
  write(*,'(A,I0)') 'FKT11_ATTEMPTS=',diagnostics%attempts
  write(*,'(A,I0)') 'FKT11_RETRIES=',diagnostics%retries
  write(*,'(A,I0)') 'FKT11_ROLLBACKS=',diagnostics%trial_rollbacks
  write(*,'(A,I0)') 'FKT11_MASS_REJECTIONS=',diagnostics%mass_rejections
  write(*,'(A,ES26.17E3)') 'FKT11_MAX_ABS_STEP_MASS=',diagnostics%max_abs_step_mass_residual
  write(*,'(A,I0)') 'FKT11_EXTRA_TRIDAG_LAST=',observation%temporal_additional_tridiagonal_solves
  write(*,'(A,I0)') 'FKT11_EXTRA_NONLINEAR_LAST=',observation%temporal_additional_full_nonlinear_solves
  write(*,'(A,A,A)') 'FKT11_OWNER_CASE_',trim(case_id),'=PASS'

contains

  subroutine configure_fixture(col,tpl,p,f,state,hp,cp,h,theta,kval,cap,dk)
    type(fmr_logical_column_t), intent(out) :: col
    type(fmr_template_t), intent(out) :: tpl
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), intent(out) :: cp
    real(real64), intent(out) :: h(numnod), theta(numnod), kval(numnod), cap(numnod), dk(numnod)
    integer :: i

    col%column_id=111001_int64; col%template_id=11101_int64; col%parameter_ref=1_int64
    col%state_handle=1_int64; col%forcing_handle=1_int64; col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    tpl%template_id=col%template_id; tpl%physics_topology_id=11101_int64; tpl%vertical_layout_id=11102_int64
    tpl%state_layout_id=11103_int64; tpl%solver_interface_id=11104_int64; tpl%optional_state_layout_id=0_int64
    tpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    p%parameter_set_id=111001_int64; p%active_nodes=numnod
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
    call bind_b110_default_mvg_provider(cp,hp,step_dt)
    h=head0
    call cp%evaluate(h,theta,kval,cap,dk)
    call require(all(ieee_is_finite(cap)) .and. all(cap>0.0_real64), 'positive finite bootstrap capacity')
    call require(all(ieee_is_finite(kval)) .and. all(kval>0.0_real64), 'positive finite bootstrap conductivity')
    do i=2,numnod
      call require(same_real_bits(kval(i),kval(1)), 'uniform initial conductivity')
    end do

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h; state%water_content=theta; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64

    f%top_flux=-kval(1); f%top_head=head0; f%bottom_flux=12345.678_real64; f%bottom_head=head0+bottom_jump
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine configure_fixture

  subroutine configure_transaction(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=hard_mass_gate
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=0
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%max_committed_substeps=1
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%model_temporal_indicator_budget=0.0_real64
  end subroutine configure_transaction

  subroutine get_committed_history(c,derivative,available_out)
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

  subroutine assert_rejected_state_unchanged(c,fp0,revision0,time0,hist0,hist_available0)
    type(kernel_committed_state_t), intent(in) :: c
    integer(int64), intent(in) :: fp0, revision0
    real(real64), intent(in) :: time0
    real(real64), allocatable, intent(in) :: hist0(:)
    logical, intent(in) :: hist_available0
    real(real64), allocatable :: hist1(:)
    logical :: hist_available1, time_available
    real(real64) :: t
    call require(committed_physical_fingerprint(c)==fp0,'rejected trial physical state immutable')
    call require(c%current_revision()==revision0,'rejected trial revision immutable')
    call c%current_time(t,time_available)
    call require(time_available .and. same_real_bits(t,time0),'rejected trial committed time immutable')
    call get_committed_history(c,hist1,hist_available1)
    call require(hist_available1 .eqv. hist_available0,'rejected trial history availability immutable')
    if (hist_available0) call require(same_vector_bits(hist1,hist0),'rejected trial accepted history bitwise immutable')
  end subroutine assert_rejected_state_unchanged

  integer(int64) function committed_physical_fingerprint(c) result(fp)
    type(kernel_committed_state_t), intent(in) :: c
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call c%snapshot(snapshot,got)
    call require(got,'committed physical fingerprint snapshot')
    fp=1469598103934665603_int64
    select type (s=>snapshot)
    class is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(s%active_nodes,int64))
      fp=ieor(fp,transfer(s%ponding_depth,fp)); fp=ieor(fp,transfer(s%groundwater_level,fp))
      do stat=1,s%active_nodes
        fp=ieor(fp,transfer(s%pressure_head(stat),fp)); fp=ieor(fp,transfer(s%water_content(stat),fp))
      end do
    class default
      call require(.false.,'physical fingerprint dynamic type')
    end select
  end function committed_physical_fingerprint

  logical function close_to(a,b) result(ok_close)
    real(real64), intent(in) :: a,b
    ok_close = ieee_is_finite(a) .and. ieee_is_finite(b) .and. &
         abs(a-b) <= 65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function close_to

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
      write(*,'(A,1X,A,1X,A)') 'FKT11_OWNER_FAIL',trim(case_id),trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt11_richards_head_budget_policy
