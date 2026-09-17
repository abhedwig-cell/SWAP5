program test_pub_me_d1b_detection_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t, &
       kernel_reconstruct_committed_state_trusted, KERNEL_TRUSTED_RECONSTRUCTION_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  integer(int64), parameter :: column_id = 920111_int64
  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: contaminated_h = -74.5_real64
  real(real64), parameter :: duration = 0.25_real64
  real(real64), parameter :: reject_mass_gate = 1.0e-12_real64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: reject_config, accept_config

  type(kernel_committed_state_t) :: clean_committed, mutant_committed, contaminated_committed
  type(kernel_executor_t) :: clean_reject_control, mutant_reject_control
  type(kernel_executor_t) :: clean_continue_control, mutant_continue_control
  type(fmr_serialized_reference_backend_t) :: clean_reject_backend, mutant_reject_backend
  type(fmr_serialized_reference_backend_t) :: clean_continue_backend, mutant_continue_backend
  type(fixed_flux_top_boundary_provider_t), target :: top_clean_reject, top_mutant_reject
  type(fixed_flux_top_boundary_provider_t), target :: top_clean_continue, top_mutant_continue

  type(fmr_serialized_column_result_t) :: reject_clean, reject_mutant, continue_clean, continue_mutant
  type(fmr_column_diagnostics_t) :: diag_reject_clean, diag_reject_mutant
  type(fmr_column_diagnostics_t) :: diag_continue_clean, diag_continue_mutant
  type(fmr_serialized_batch_diagnostics_t) :: runtime_reject_clean, runtime_reject_mutant
  type(fmr_serialized_batch_diagnostics_t) :: runtime_continue_clean, runtime_continue_mutant

  class(transaction_state_t), allocatable :: initial_snapshot, clean_boundary, mutant_boundary
  class(transaction_state_t), allocatable :: clean_final, mutant_final
  integer(int64) :: clean_revision, mutant_revision
  real(real64) :: clean_time, mutant_time
  real(real64) :: boundary_head_diff, boundary_theta_diff
  real(real64) :: endpoint_head_diff, endpoint_theta_diff
  logical :: ok, clean_time_ok, mutant_time_ok, clean_boundary_ok, mutant_boundary_ok
  logical :: clean_final_ok, mutant_final_ok, b1_boundary_match, b2_detected
  logical :: b1_detected_later
  integer :: calls_clean_reject, calls_mutant_reject, calls_clean_continue, calls_mutant_continue
  character(len=32) :: classification

  call initialize_parameters(parameters)
  call initialize_forcing(forcing)
  call initialize_column_and_template(column, template)
  call initialize_rejecting_config(reject_config)
  call initialize_accepting_config(accept_config)

  call initialize_committed(clean_committed, parameters, ok)
  call require(ok, 'clean committed state initialized')
  call initialize_committed(mutant_committed, parameters, ok)
  call require(ok, 'mutant committed state initialized')

  call clean_committed%snapshot(initial_snapshot, ok)
  call require(ok, 'initial authoritative snapshot available')

  call execute_column(clean_reject_backend, top_clean_reject, clean_reject_control, clean_committed, &
       reject_config, reject_clean, diag_reject_clean, runtime_reject_clean, calls_clean_reject)
  call execute_column(mutant_reject_backend, top_mutant_reject, mutant_reject_control, mutant_committed, &
       reject_config, reject_mutant, diag_reject_mutant, runtime_reject_mutant, calls_mutant_reject)

  call require_rejected_physical_path(reject_clean, diag_reject_clean, 'clean')
  call require_rejected_physical_path(reject_mutant, diag_reject_mutant, 'mutant-before-fault')

  ! The qualification-only faulty adapter is applied only after the real
  ! rejected physical execution. It preserves provenance and accepted-ledger
  ! metadata while changing one constitutively consistent physical node.
  call inject_rejected_physical_contamination(mutant_committed, contaminated_committed, parameters, ok)
  call require(ok, 'qualification-only rejected-state contamination injected')

  clean_revision = clean_committed%current_revision()
  mutant_revision = contaminated_committed%current_revision()
  call clean_committed%current_time(clean_time, clean_time_ok)
  call contaminated_committed%current_time(mutant_time, mutant_time_ok)
  call require(clean_time_ok .and. mutant_time_ok, 'boundary committed times available')

  b1_boundary_match = reject_clean%status == reject_mutant%status .and. &
       reject_clean%completed .eqv. reject_mutant%completed .and. &
       reject_clean%committed .eqv. reject_mutant%committed .and. &
       reject_clean%mass%accepted_transaction_count == reject_mutant%mass%accepted_transaction_count .and. &
       same_bits(reject_clean%mass%total_in, reject_mutant%mass%total_in) .and. &
       same_bits(reject_clean%mass%total_out, reject_mutant%mass%total_out) .and. &
       clean_revision == mutant_revision .and. same_bits(clean_time, mutant_time)
  call require(b1_boundary_match, 'frozen B1 boundary observations remain matched')

  call clean_committed%snapshot(clean_boundary, clean_boundary_ok)
  call contaminated_committed%snapshot(mutant_boundary, mutant_boundary_ok)
  call require(clean_boundary_ok .and. mutant_boundary_ok, 'boundary physical snapshots available')
  call physical_differences(clean_boundary, mutant_boundary, boundary_head_diff, boundary_theta_diff)
  b2_detected = boundary_head_diff > 0.0_real64 .or. boundary_theta_diff > 0.0_real64
  call require(b2_detected, 'B2 detects physical contamination at rejection boundary')

  call execute_column(clean_continue_backend, top_clean_continue, clean_continue_control, clean_committed, &
       accept_config, continue_clean, diag_continue_clean, runtime_continue_clean, calls_clean_continue)
  call execute_column(mutant_continue_backend, top_mutant_continue, mutant_continue_control, contaminated_committed, &
       accept_config, continue_mutant, diag_continue_mutant, runtime_continue_mutant, calls_mutant_continue)

  if (.not. continue_clean%completed .or. .not. continue_clean%committed) then
    write(*,'(A)') 'PUB_ME_D1B_CLASSIFICATION=BLOCKED_CONTINUATION_CONFIGURATION'
    write(*,'(A,I0)') 'PUB_ME_D1B_CLEAN_CONTINUATION_STATUS=', continue_clean%status
    error stop 2
  end if

  b1_detected_later = .false.
  endpoint_head_diff = 0.0_real64
  endpoint_theta_diff = 0.0_real64

  if (.not. continue_mutant%completed .or. .not. continue_mutant%committed) then
    b1_detected_later = .true.
  else
    call clean_committed%snapshot(clean_final, clean_final_ok)
    call contaminated_committed%snapshot(mutant_final, mutant_final_ok)
    call require(clean_final_ok .and. mutant_final_ok, 'accepted continuation snapshots available')
    call physical_differences(clean_final, mutant_final, endpoint_head_diff, endpoint_theta_diff)
    b1_detected_later = endpoint_head_diff > 0.0_real64 .or. endpoint_theta_diff > 0.0_real64
  end if

  if (b1_detected_later) then
    classification = 'EARLIER_DETECTION'
  else
    classification = 'UNIQUE_DETECTION'
  end if

  write(*,'(A,I0)') 'PUB_ME_D1B_REJECT_HEADCALC_CALLS_CLEAN=', reject_clean%solver_headcalc_calls
  write(*,'(A,I0)') 'PUB_ME_D1B_REJECT_HEADCALC_CALLS_MUTANT=', reject_mutant%solver_headcalc_calls
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1B_BOUNDARY_HEAD_DIFF_CM=', boundary_head_diff
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1B_BOUNDARY_THETA_DIFF=', boundary_theta_diff
  write(*,'(A,L1)') 'PUB_ME_D1B_B1_BOUNDARY_MATCH=', b1_boundary_match
  write(*,'(A,L1)') 'PUB_ME_D1B_B2_BOUNDARY_DETECTED=', b2_detected
  write(*,'(A,L1)') 'PUB_ME_D1B_CLEAN_CONTINUATION_COMPLETED=', continue_clean%completed
  write(*,'(A,L1)') 'PUB_ME_D1B_MUTANT_CONTINUATION_COMPLETED=', continue_mutant%completed
  write(*,'(A,I0)') 'PUB_ME_D1B_CLEAN_CONTINUATION_STATUS=', continue_clean%status
  write(*,'(A,I0)') 'PUB_ME_D1B_MUTANT_CONTINUATION_STATUS=', continue_mutant%status
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1B_ENDPOINT_HEAD_DIFF_CM=', endpoint_head_diff
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1B_ENDPOINT_THETA_DIFF=', endpoint_theta_diff
  write(*,'(A,L1)') 'PUB_ME_D1B_B1_DETECTED_LATER=', b1_detected_later
  write(*,'(A,A)') 'PUB_ME_D1B_CLASSIFICATION=', trim(classification)
  write(*,'(A)') 'PUB_ME_D1B_DETECTION_TIMING_EXPERIMENT=PASS'

contains

  subroutine execute_column(backend, top, control, committed, config, output, diagnostic, runtime, active_calls)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(fixed_flux_top_boundary_provider_t), target, intent(inout) :: top
    type(kernel_executor_t), intent(inout) :: control
    type(kernel_committed_state_t), intent(inout) :: committed
    type(canonical_numerical_config_t), intent(in) :: config
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_column_diagnostics_t), intent(out) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime
    integer, intent(out) :: active_calls

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = 0.0_real64
    output%requested_t1 = duration
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_calls = 0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_calls)
  end subroutine execute_column

  subroutine require_rejected_physical_path(output, diagnostic, label)
    type(fmr_serialized_column_result_t), intent(in) :: output
    type(fmr_column_diagnostics_t), intent(in) :: diagnostic
    character(len=*), intent(in) :: label

    call require(output%admission_assessed .and. output%admitted, trim(label)//' admitted before rejection')
    call require(.not. output%completed .and. .not. output%committed, trim(label)//' not committed')
    call require(diagnostic%rejected == 1 .and. trim(diagnostic%failure_classification) == 'KERNEL_REJECTED', &
         trim(label)//' reports kernel rejection')
    call require(output%solver_headcalc_calls >= 3, trim(label)//' executes real full/two-half solver routes')
    call require(output%mass%accepted_transaction_count == 0, trim(label)//' zero accepted transactions')
    call require(same_bits(output%mass%total_in, 0.0_real64) .and. &
         same_bits(output%mass%total_out, 0.0_real64), trim(label)//' zero accepted transfer')
  end subroutine require_rejected_physical_path

  subroutine inject_rejected_physical_contamination(source, contaminated, p, injected)
    type(kernel_committed_state_t), intent(in) :: source
    type(kernel_committed_state_t), intent(out) :: contaminated
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    logical, intent(out) :: injected

    class(transaction_state_t), allocatable :: physical
    integer(int64) :: lineage, revision
    real(real64) :: committed_time
    logical :: available, reconstructed, time_bound
    integer :: status

    injected = .false.
    call source%snapshot(physical, available)
    if (.not. available) return

    select type (typed => physical)
    type is (fmr_b110_physical_state_t)
      if (typed%active_nodes < 1 .or. .not. allocated(typed%pressure_head) .or. &
          .not. allocated(typed%water_content)) return
      typed%pressure_head(1) = contaminated_h
      typed%water_content(1) = theta_from_h(contaminated_h, p%cofgen(:,1))
    class default
      return
    end select

    lineage = source%current_lineage_id()
    revision = source%current_revision()
    time_bound = source%time_is_bound()
    call source%current_time(committed_time, available)
    if (time_bound .and. .not. available) return

    call kernel_reconstruct_committed_state_trusted(contaminated, lineage, revision, physical, &
         committed_time, time_bound, reconstructed, status)
    injected = reconstructed .and. status == KERNEL_TRUSTED_RECONSTRUCTION_OK
  end subroutine inject_rejected_physical_contamination

  real(real64) function theta_from_h(h, cof) result(theta)
    real(real64), intent(in) :: h
    real(real64), intent(in) :: cof(:)
    real(real64) :: m, se

    m = cof(7)
    se = (1.0_real64 + abs(cof(4)*h)**cof(6))**(-m)
    theta = cof(1) + (cof(2)-cof(1))*se
  end function theta_from_h

  subroutine physical_differences(left_state, right_state, head_diff, theta_diff)
    class(transaction_state_t), allocatable, intent(in) :: left_state, right_state
    real(real64), intent(out) :: head_diff, theta_diff

    head_diff = huge(0.0_real64)
    theta_diff = huge(0.0_real64)
    select type (left => left_state)
    type is (fmr_b110_physical_state_t)
      select type (right => right_state)
      type is (fmr_b110_physical_state_t)
        call require(left%active_nodes == right%active_nodes, 'physical difference active-node identity')
        call require(allocated(left%pressure_head) .and. allocated(right%pressure_head), &
             'physical difference head arrays allocated')
        call require(allocated(left%water_content) .and. allocated(right%water_content), &
             'physical difference theta arrays allocated')
        head_diff = maxval(abs(left%pressure_head - right%pressure_head))
        theta_diff = maxval(abs(left%water_content - right%water_content))
      class default
        call require(.false., 'right physical state type')
      end select
    class default
      call require(.false., 'left physical state type')
    end select
  end subroutine physical_differences

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 920111_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z; p%dz = dz; p%node_distance = disnod(1:numnod); p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%max_iterations=16; p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64; p%compartment_balance_tolerance=reject_mass_gate
    p%total_balance_tolerance=reject_mass_gate; p%head_abs_tolerance=reject_mass_gate
    p%head_rel_tolerance=reject_mass_gate; p%ponding_tolerance=reject_mass_gate
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_committed(state_carrier, p, initialized)
    type(kernel_committed_state_t), intent(out) :: state_carrier
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: theta

    theta = theta_from_h(h0, p%cofgen(:,1))
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = h0
    physical%water_content = theta
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(state_carrier, column_id, physical, 0.0_real64, initialized)
  end subroutine initialize_committed

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    f%top_flux=0.0_real64; f%top_head=h0; f%bottom_flux=0.0_real64; f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_and_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t
    t%template_id=920111_int64; t%physics_topology_id=920112_int64; t%vertical_layout_id=920113_int64
    t%state_layout_id=920114_int64; t%solver_interface_id=920115_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=column_id; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template

  subroutine initialize_rejecting_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg=canonical_numerical_config_t()
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=reject_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=0
    cfg%max_committed_substeps=1
    cfg%progress_tolerance=0.0_real64
  end subroutine initialize_rejecting_config

  subroutine initialize_accepting_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg=canonical_numerical_config_t()
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance=1.0e6_real64
    cfg%transaction%mass_tolerance=1.0e-10_real64
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=4
    cfg%max_committed_substeps=1
    cfg%progress_tolerance=0.0_real64
  end subroutine initialize_accepting_config

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D1B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_me_d1b_detection_timing
