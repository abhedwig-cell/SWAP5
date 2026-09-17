program test_pub_gc_e1_screening
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: initial_head = -75.0_real64
  real(real64), parameter :: candidate_head_a = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  real(real64), parameter :: qualification_head_budget = 100.0_real64
  integer(int64), parameter :: origin_lineage = 820001_int64
  integer(int64), parameter :: synthetic_lineage = 829901_int64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: origin, synthetic
  type(kernel_checkpoint_t) :: origin_checkpoint, synthetic_checkpoint
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result_a1, result_b, result_a2, result_history
  type(kernel_diagnostics_t) :: diag_a1, diag_b, diag_a2, diag_history, discard_diag
  type(kernel_executor_t) :: discard_executor
  class(transaction_state_t), allocatable :: origin_before, origin_after
  class(transaction_state_t), allocatable :: snap_a1, snap_b, snap_a2, snap_history
  real(real64) :: candidate_head_b, duration, t1, conductivity_reference
  real(real64) :: accepted_predecessor_right_derivative(numnod)
  real(real64) :: delta_head_max, delta_water_max
  logical :: ok, available, trial_ok, b_endpoint_differs
  character(len=64) :: reason
  character(len=128) :: arg

  if (command_argument_count() /= 2) then
    write(*,'(a)') 'SCREEN_INFRA_FAIL=expected B_head_cm and duration_days'
    error stop 2
  end if
  call get_command_argument(1, arg)
  read(arg,*,iostat=ok_int) candidate_head_b
  if (ok_int /= 0 .or. .not. ieee_is_finite(candidate_head_b)) then
    write(*,'(a)') 'SCREEN_INFRA_FAIL=invalid B_head_cm'
    error stop 2
  end if
  call get_command_argument(2, arg)
  read(arg,*,iostat=ok_int) duration
  if (ok_int /= 0 .or. .not. ieee_is_finite(duration) .or. duration <= 0.0_real64) then
    write(*,'(a)') 'SCREEN_INFRA_FAIL=invalid duration_days'
    error stop 2
  end if
  t1 = t0 + duration

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_case(parameters, initial_state, forcing_a, conductivity_reference, duration)
  forcing_b = forcing_a
  forcing_a%bottom_head = candidate_head_a
  forcing_b%bottom_head = candidate_head_b

  call backend%initialize(top_provider)
  accepted_predecessor_right_derivative = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(origin, origin_lineage, initial_state, t0, ok, &
       accepted_predecessor_right_derivative)
  call require(ok .and. origin%ready(), 'accepted origin initialization')
  call origin%snapshot(origin_before, available)
  call require(available, 'accepted origin snapshot')
  call fmr_capture_checkpoint(origin, origin_checkpoint, ok)
  call require(ok .and. origin_checkpoint%ready(), 'accepted origin checkpoint')

  call attempt_trial(origin, origin_checkpoint, forcing_a, result_a1, candidate, diag_a1, snap_a1, trial_ok, reason)
  if (.not. trial_ok) then
    call emit_invalid('A1', reason, diag_a1)
    stop
  end if
  discard_diag = diag_a1
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'A1 discard')

  call attempt_trial(origin, origin_checkpoint, forcing_b, result_b, candidate, diag_b, snap_b, trial_ok, reason)
  if (.not. trial_ok) then
    call emit_invalid('B', reason, diag_b)
    stop
  end if
  b_endpoint_differs = .not. states_identical(snap_b, origin_before)
  discard_diag = diag_b
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'B discard')

  call attempt_trial(origin, origin_checkpoint, forcing_a, result_a2, candidate, diag_a2, snap_a2, trial_ok, reason)
  if (.not. trial_ok) then
    call emit_invalid('A2', reason, diag_a2)
    stop
  end if
  discard_diag = diag_a2
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'A2 discard')

  call require(same_bits(result_a1%bottom_outward_exchange_native, result_a2%bottom_outward_exchange_native), &
       'same-origin A exchange replay')
  call require(same_bits(result_a1%terminal_bottom_outward_flux_native, result_a2%terminal_bottom_outward_flux_native), &
       'same-origin A terminal replay')
  call require(states_identical(snap_a1, snap_a2), 'same-origin A endpoint replay')
  call origin%snapshot(origin_after, available)
  call require(available .and. states_identical(origin_before, origin_after), 'same-origin mutated accepted origin')
  call require(origin%current_revision() == 0_int64, 'same-origin revision mutation')

  call synthetic%initialize(synthetic_lineage, snap_b, ok, initial_time=t0)
  call require(ok .and. synthetic%ready(), 'synthetic initialization')
  call require(synthetic%current_lineage_id() /= origin%current_lineage_id(), 'synthetic lineage distinct')
  call require(synthetic%current_revision() == 0_int64, 'synthetic revision starts zero')
  call fmr_capture_checkpoint(synthetic, synthetic_checkpoint, ok)
  call require(ok .and. synthetic_checkpoint%ready(), 'synthetic checkpoint')

  call attempt_trial(synthetic, synthetic_checkpoint, forcing_a, result_history, candidate, diag_history, &
       snap_history, trial_ok, reason)
  if (.not. trial_ok) then
    call emit_invalid('A_HISTORY', reason, diag_history)
    stop
  end if
  discard_diag = diag_history
  call fmr_discard_candidate(discard_executor, candidate, discard_diag)
  call require(.not. candidate%ready(), 'history discard')
  call synthetic%snapshot(origin_after, available)
  call require(available .and. states_identical(origin_after, snap_b), 'history mutated synthetic committed state')
  call require(synthetic%current_revision() == 0_int64, 'history revision mutation')

  call endpoint_deltas(snap_a1, snap_history, delta_head_max, delta_water_max, ok)
  call require(ok, 'endpoint delta comparison')

  write(*,'(a)') 'SCREEN_ROW_STATUS=PASS'
  call emit_common()
  write(*,'(a,l1)') 'SCREEN_B_ENDPOINT_DIFFERS=', b_endpoint_differs
  write(*,'(a,l1)') 'SCREEN_SAME_ORIGIN_A_REPLAY_IDENTITY=', .true.
  write(*,'(a,l1)') 'SCREEN_ACCEPTED_ORIGIN_UNCHANGED=', .true.
  write(*,'(a,l1)') 'SCREEN_HISTORY_DIAGNOSTIC_NO_COMMIT=', .true.
  write(*,'(a,es26.17e3)') 'SCREEN_A_SAME_Q=', result_a1%bottom_outward_exchange_native
  write(*,'(a,es26.17e3)') 'SCREEN_B_SAME_Q=', result_b%bottom_outward_exchange_native
  write(*,'(a,es26.17e3)') 'SCREEN_A_HISTORY_Q=', result_history%bottom_outward_exchange_native
  write(*,'(a,es26.17e3)') 'SCREEN_A_SAME_TERMINAL=', result_a1%terminal_bottom_outward_flux_native
  write(*,'(a,es26.17e3)') 'SCREEN_A_HISTORY_TERMINAL=', result_history%terminal_bottom_outward_flux_native
  write(*,'(a,es26.17e3)') 'SCREEN_DELTA_Q_ABS=', &
       abs(result_history%bottom_outward_exchange_native-result_a1%bottom_outward_exchange_native)
  write(*,'(a,es26.17e3)') 'SCREEN_DELTA_TERMINAL_ABS=', &
       abs(result_history%terminal_bottom_outward_flux_native-result_a1%terminal_bottom_outward_flux_native)
  write(*,'(a,es26.17e3)') 'SCREEN_DELTA_ENDPOINT_HEAD_MAX=', delta_head_max
  write(*,'(a,es26.17e3)') 'SCREEN_DELTA_ENDPOINT_WATER_MAX=', delta_water_max
  write(*,'(a,es26.17e3)') 'SCREEN_A_SAME_MASS_RESIDUAL=', result_a1%mass%residual
  write(*,'(a,es26.17e3)') 'SCREEN_B_SAME_MASS_RESIDUAL=', result_b%mass%residual
  write(*,'(a,es26.17e3)') 'SCREEN_A_HISTORY_MASS_RESIDUAL=', result_history%mass%residual
  write(*,'(a,i0)') 'SCREEN_A_SAME_RETRIES=', diag_a1%retries
  write(*,'(a,i0)') 'SCREEN_B_SAME_RETRIES=', diag_b%retries
  write(*,'(a,i0)') 'SCREEN_A_HISTORY_RETRIES=', diag_history%retries
  write(*,'(a)') 'SCREEN_HISTORY_DIAGNOSTIC_PRODUCTION_VALID=false'

contains

  integer function ok_int()
  end function ok_int

  subroutine attempt_trial(committed, checkpoint, forcing, result, local_candidate, diagnostics, snapshot, &
                           completed, why)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: local_candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    class(transaction_state_t), allocatable, intent(out) :: snapshot
    logical, intent(out) :: completed
    character(len=*), intent(out) :: why
    logical :: snapshot_ok

    completed = .false.
    why = 'UNKNOWN'
    call poison_legacy_bottom_context()
    call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, local_candidate, diagnostics)
    if (.not. result%completed) then
      if (diagnostics%admission_rejections > 0) then
        why = 'ADMISSION_REJECTION'
      else if (diagnostics%solver_rejections > 0) then
        why = 'SOLVER_REJECTION'
      else if (diagnostics%mass_rejections > 0) then
        why = 'MASS_REJECTION'
      else if (diagnostics%temporal_rejections > 0) then
        why = 'TEMPORAL_REJECTION'
      else
        why = 'TRANSACTION_INCOMPLETE'
      end if
      return
    end if
    if (.not. local_candidate%ready()) then
      why = 'CANDIDATE_NOT_READY'
      return
    end if
    if (.not. result%bottom_interface_exchange_available) then
      why = 'WHOLE_WINDOW_EXCHANGE_UNAVAILABLE'
      return
    end if
    if (.not. ieee_is_finite(result%bottom_outward_exchange_native) .or. &
        .not. ieee_is_finite(result%terminal_bottom_outward_flux_native)) then
      why = 'NONFINITE_EXCHANGE'
      return
    end if
    if (.not. result%mass%complete .or. .not. ieee_is_finite(result%mass%residual)) then
      why = 'MASS_ACCOUNTING_INCOMPLETE'
      return
    end if
    call local_candidate%snapshot(snapshot, snapshot_ok)
    if (.not. snapshot_ok .or. .not. allocated(snapshot)) then
      why = 'SNAPSHOT_UNAVAILABLE'
      return
    end if
    completed = .true.
    why = 'PASS'
  end subroutine attempt_trial

  subroutine emit_invalid(label, why, diagnostics)
    character(len=*), intent(in) :: label, why
    type(kernel_diagnostics_t), intent(in) :: diagnostics
    write(*,'(a)') 'SCREEN_ROW_STATUS=INVALID'
    call emit_common()
    write(*,'(a,a)') 'SCREEN_INVALID_STAGE=', trim(label)
    write(*,'(a,a)') 'SCREEN_INVALID_REASON=', trim(why)
    write(*,'(a,i0)') 'SCREEN_INVALID_ADMISSION_REJECTIONS=', diagnostics%admission_rejections
    write(*,'(a,i0)') 'SCREEN_INVALID_SOLVER_REJECTIONS=', diagnostics%solver_rejections
    write(*,'(a,i0)') 'SCREEN_INVALID_TEMPORAL_REJECTIONS=', diagnostics%temporal_rejections
    write(*,'(a,i0)') 'SCREEN_INVALID_CERT_UNAVAILABLE_REJECTIONS=', &
         diagnostics%temporal_certificate_unavailable_rejections
    write(*,'(a,i0)') 'SCREEN_INVALID_MASS_REJECTIONS=', diagnostics%mass_rejections
    write(*,'(a,i0)') 'SCREEN_INVALID_RETRIES=', diagnostics%retries
  end subroutine emit_invalid

  subroutine emit_common()
    write(*,'(a,es26.17e3)') 'SCREEN_B_HEAD_CM=', candidate_head_b
    write(*,'(a,es26.17e3)') 'SCREEN_B_DELTA_CM=', candidate_head_b-candidate_head_a
    write(*,'(a,es26.17e3)') 'SCREEN_DURATION_DAYS=', duration
  end subroutine emit_common

  subroutine endpoint_deltas(a, b, head_delta, water_delta, valid)
    class(transaction_state_t), allocatable, intent(in) :: a, b
    real(real64), intent(out) :: head_delta, water_delta
    logical, intent(out) :: valid
    valid = .false.
    head_delta = huge(0.0_real64)
    water_delta = huge(0.0_real64)
    if (.not. allocated(a) .or. .not. allocated(b)) return
    select type (pa => a)
    class is (fmr_b110_physical_state_t)
      select type (pb => b)
      class is (fmr_b110_physical_state_t)
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head)) return
        if (size(pa%water_content) /= size(pb%water_content)) return
        head_delta = maxval(abs(pa%pressure_head-pb%pressure_head))
        water_delta = maxval(abs(pa%water_content-pb%water_content))
        valid = ieee_is_finite(head_delta) .and. ieee_is_finite(water_delta)
      end select
    end select
  end subroutine endpoint_deltas

  subroutine configure_column(c, tpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: tpl
    tpl%template_id = 8201_int64
    tpl%physics_topology_id = 820101_int64
    tpl%vertical_layout_id = 820102_int64
    tpl%state_layout_id = 820103_int64
    tpl%solver_interface_id = 820104_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = origin_lineage
    c%template_id = tpl%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 4
    cfg%max_committed_substeps = 64
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
    cfg%model_temporal_indicator_budget = qualification_head_budget
  end subroutine configure_transaction

  subroutine configure_case(p, state, forcing, conductivity_reference, dt)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity_reference
    real(real64), intent(in) :: dt
    real(real64) :: heads(numnod), conductivity(numnod)
    integer :: k

    call configure_base_parameters(p)
    heads = initial_head
    call evaluate_state(p, heads, state, conductivity, dt)
    conductivity_reference = conductivity(1)
    do k = 2, numnod
      call require(same_bits(conductivity(k), conductivity_reference), 'uniform initial conductivity')
    end do
    forcing%top_flux = -conductivity_reference
    forcing%top_head = initial_head
    forcing%bottom_flux = 12345.0_real64
    forcing%bottom_head = initial_head
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 820101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
    p%max_iterations = 12
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-7_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = 1.0e-10_real64
    p%head_rel_tolerance = 1.0e-10_real64
    p%ponding_tolerance = 1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p, heads, state, conductivity, dt)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: heads(:), dt
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity(:)
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(inout) :: f
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
             f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine allocate_zero_forcing

  logical function states_identical(a, b) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: a, b
    integer :: k
    equal = .false.
    if (.not. allocated(a) .or. .not. allocated(b)) return
    select type (pa => a)
    class is (fmr_b110_physical_state_t)
      select type (pb => b)
      class is (fmr_b110_physical_state_t)
        if (pa%active_nodes /= pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        if (size(pa%pressure_head) /= size(pb%pressure_head)) return
        if (size(pa%water_content) /= size(pb%water_content)) return
        do k = 1, pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k), pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k), pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth, pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level, pb%groundwater_level)) return
        if (allocated(pa%snow) .neqv. allocated(pb%snow)) return
        if (allocated(pa%soil_temperature) .neqv. allocated(pb%soil_temperature)) return
        equal = .true.
      end select
    end select
  end function states_identical

  subroutine poison_legacy_bottom_context()
    swmacro = 0
    legacy_melt = 0.0_real64
    legacy_qdra = 24680.0_real64
    legacy_qssdi = -13579.0_real64
    legacy_qrot = 0.0_real64
    legacy_swbotb = 3
    legacy_hbot = 99999.0_real64
    legacy_qbot = -99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'SCREEN_INFRA_FAIL='//trim(label)
      error stop 3
    end if
  end subroutine require

end program test_pub_gc_e1_screening
