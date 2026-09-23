program test_pub_me_g1_d2_reverse_flow_replication
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_TRANSACTION_FAILED, &
       CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: q = -1.0e-6_real64
  real(real64), parameter :: rejected_dt = 1.0e-2_real64
  real(real64), parameter :: accepted_dt = 1.0e-4_real64
  real(real64), parameter :: head_budget = 1.0e-6_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: historical_rejected_binf = 3.70914011132183706e-6_real64
  real(real64), parameter :: historical_accepted_binf = 1.23637633357863245e-7_real64
  integer(int64), parameter :: column_id = 920102_int64

  type :: d2_case_result_t
    integer(int64) :: revision = -1_int64
    real(real64) :: committed_time = -1.0_real64
    real(real64) :: accepted_total_in = 0.0_real64
    real(real64) :: accepted_total_out = 0.0_real64
    real(real64) :: accepted_residual = 0.0_real64
    real(real64) :: rejected_binf = 0.0_real64
    real(real64) :: accepted_binf = 0.0_real64
    real(real64) :: ledger_in_at_retry = 0.0_real64
    real(real64) :: ledger_out_at_retry = 0.0_real64
    real(real64) :: final_ledger_in = 0.0_real64
    real(real64) :: final_ledger_out = 0.0_real64
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
  end type d2_case_result_t

  type(d2_case_result_t) :: clean, mutant

  call run_case(.false., clean)
  call run_case(.true., mutant)

  call require(clean%revision == 1_int64 .and. mutant%revision == 1_int64, &
       'clean and mutant exactly one accepted commit')
  call require(same_bits(clean%committed_time, accepted_dt) .and. &
       same_bits(mutant%committed_time, accepted_dt), 'matched accepted committed time')
  call require(same_bits(clean%accepted_total_in, mutant%accepted_total_in) .and. &
       same_bits(clean%accepted_total_out, mutant%accepted_total_out) .and. &
       same_bits(clean%accepted_residual, mutant%accepted_residual), &
       'canonical accepted accounting identical clean versus mutant')
  call require(all_bits_equal(clean%pressure_head, mutant%pressure_head) .and. &
       all_bits_equal(clean%water_content, mutant%water_content), &
       'accepted physical endpoint identical clean versus mutant')

  ! B2 direct transition-authority oracle: before accepted re-execution begins,
  ! rejected work must have contributed exactly zero to accepted accounting.
  call require(same_bits(clean%ledger_in_at_retry, 0.0_real64) .and. &
       same_bits(clean%ledger_out_at_retry, 0.0_real64), 'clean accepted ledger empty at retry entry')
  call require(mutant%ledger_in_at_retry > 0.0_real64 .and. mutant%ledger_out_at_retry > 0.0_real64, &
       'B2 detects rejected-attempt contribution at retry entry')

  ! B1 remains strong. After the accepted retry, reference/output regression on
  ! accepted transfer totals catches the faulty cumulative publication. Mass
  ! closure alone is deliberately insufficient here because the rejected
  ! prescribed throughflow contributes equal inflow and outflow.
  call require(same_bits(clean%final_ledger_in, clean%accepted_total_in) .and. &
       same_bits(clean%final_ledger_out, clean%accepted_total_out), 'clean final ledger equals canonical accepted totals')
  call require(.not. same_bits(mutant%final_ledger_in, mutant%accepted_total_in) .and. &
       .not. same_bits(mutant%final_ledger_out, mutant%accepted_total_out), &
       'B1 accepted-total regression detects mutant after acceptance')
  call require(abs((mutant%final_ledger_in-mutant%final_ledger_out) - &
       (mutant%accepted_total_in-mutant%accepted_total_out)) <= hard_mass_gate, &
       'fault can remain invisible to net mass closure')

  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_REJECTED_BINF_CM=', mutant%rejected_binf
  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_ACCEPTED_BINF_CM=', mutant%accepted_binf
  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_ACCEPTED_TOTAL_IN_CM=', mutant%accepted_total_in
  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_ACCEPTED_TOTAL_OUT_CM=', mutant%accepted_total_out
  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_LEDGER_IN_AT_RETRY_CM=', mutant%ledger_in_at_retry
  write(*,'(A,ES26.17E3)') 'PUB_ME_G1_D2_FINAL_FAULTY_LEDGER_IN_CM=', mutant%final_ledger_in
  write(*,'(A)') 'PUB_ME_G1_D2_B1_FINAL_ACCEPTED_TOTAL_REGRESSION=DETECTED'
  write(*,'(A)') 'PUB_ME_G1_D2_B2_RETRY_ENTRY_AUTHORITY=DETECTED'
  write(*,'(A)') 'PUB_ME_G1_D2_CLASSIFICATION=REPLICATED_EARLIER_DETECTION'
  write(*,'(A)') 'PUB_ME_G1_D2_REVERSE_FLOW_REPLICATION=PASS'

contains

  subroutine run_case(inject_fault, record)
    logical, intent(in) :: inject_fault
    type(d2_case_result_t), intent(out) :: record
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: commit_control
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: rejected_result, accepted_result
    type(kernel_candidate_state_t) :: rejected_candidate, accepted_candidate
    type(kernel_diagnostics_t) :: rejected_diag, accepted_diag
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fixed_flux_top_boundary_provider_t), target :: top
    class(transaction_state_t), allocatable :: snapshot
    logical :: ok, did_commit, time_available, snapshot_available
    integer :: commit_status
    real(real64) :: committed_time
    real(real64) :: faulty_in, faulty_out, scale

    call initialize_parameters(parameters)
    call initialize_committed(committed, parameters, ok)
    call require(ok, 'temporal committed state initialized')
    call initialize_forcing(forcing)
    call initialize_template(column, template)
    call initialize_config(config)

    call backend%initialize(top)
    call fmr_capture_checkpoint(committed, checkpoint, ok)
    call require(ok, 'initial committed checkpoint captured')

    call backend%run_trial(column, template, parameters, committed, forcing, config, &
         0.0_real64, rejected_dt, checkpoint, rejected_result, rejected_candidate, rejected_diag)
    observation = backend%observation()

    call require(rejected_result%status == CANONICAL_STATUS_TRANSACTION_FAILED .and. &
         .not. rejected_result%completed, 'historically predicted long trial rejected')
    call require(.not. rejected_candidate%ready(), 'rejected long trial produces no candidate')
    call require(observation%solver_executed .and. observation%temporal_certificate_available, &
         'rejected long trial executed real Reference solver and certificate')
    call require(observation%temporal_head_inf_bound > head_budget, 'long-trial certificate exceeds frozen budget')
    scale = max(1.0_real64,abs(observation%temporal_head_inf_bound),abs(historical_rejected_binf))
    call require(abs(observation%temporal_head_inf_bound-historical_rejected_binf) <= &
         65536.0_real64*epsilon(1.0_real64)*scale, 'long-trial Binf matches pre-D2 FSI38 evidence')
    record%rejected_binf = observation%temporal_head_inf_bound

    call require(committed%current_revision() == 0_int64, 'rejected trial leaves revision unchanged')
    call committed%current_time(committed_time, time_available)
    call require(time_available .and. same_bits(committed_time,0.0_real64), &
         'rejected trial leaves committed time unchanged')
    call require(rejected_result%mass%accepted_transaction_count == 0 .and. &
         same_bits(rejected_result%mass%total_in,0.0_real64) .and. &
         same_bits(rejected_result%mass%total_out,0.0_real64), &
         'canonical accepted ledger excludes rejected trial')

    faulty_in = 0.0_real64
    faulty_out = 0.0_real64
    if (inject_fault) then
      ! Qualification-only D2 defect replication: publish the prescribed
      ! rejected-trial throughflow into an accepted ledger before acceptance.
      ! Here q is negative: inward at the top and outward at the prescribed
      ! bottom. Accepted accounting stores positive transfer magnitudes.
      faulty_in = abs(q)*rejected_dt
      faulty_out = abs(q)*rejected_dt
    end if
    record%ledger_in_at_retry = faulty_in
    record%ledger_out_at_retry = faulty_out

    ! Re-execute from the exact still-current committed origin using the
    ! independently qualified short duration. The original checkpoint remains
    ! valid because the rejected trial changed neither revision nor time.
    call backend%run_trial(column, template, parameters, committed, forcing, config, &
         0.0_real64, accepted_dt, checkpoint, accepted_result, accepted_candidate, accepted_diag)
    observation = backend%observation()

    call require(accepted_result%status == CANONICAL_STATUS_COMPLETED .and. accepted_result%completed, &
         'short re-execution accepted')
    call require(accepted_candidate%ready(), 'accepted short re-execution materializes candidate')
    call require(observation%solver_executed .and. observation%temporal_certificate_available, &
         'accepted short trial executed real Reference solver and certificate')
    call require(observation%temporal_head_inf_bound < head_budget, 'short-trial certificate below frozen budget')
    scale = max(1.0_real64,abs(observation%temporal_head_inf_bound),abs(historical_accepted_binf))
    call require(abs(observation%temporal_head_inf_bound-historical_accepted_binf) <= &
         65536.0_real64*epsilon(1.0_real64)*scale, 'short-trial Binf matches pre-D2 FSI38 evidence')
    record%accepted_binf = observation%temporal_head_inf_bound
    call require(accepted_result%mass%complete .and. accepted_result%mass%accepted_transaction_count == 1, &
         'short re-execution has one complete accepted mass transaction')
    call require(accepted_result%mass%total_in > 0.0_real64 .and. accepted_result%mass%total_out > 0.0_real64, &
         'short re-execution has nonzero physical exchange')
    call require(abs(accepted_result%mass%residual) <= hard_mass_gate, 'short re-execution hard mass gate')

    call fmr_commit_candidate(commit_control, committed, accepted_candidate, accepted_diag, did_commit, commit_status)
    call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'accepted candidate committed once')
    call require(committed%current_revision() == 1_int64, 'exactly one accepted revision')
    call committed%current_time(record%committed_time, time_available)
    call require(time_available .and. same_bits(record%committed_time, accepted_dt), 'accepted committed time exact')
    record%revision = committed%current_revision()

    record%accepted_total_in = accepted_result%mass%total_in
    record%accepted_total_out = accepted_result%mass%total_out
    record%accepted_residual = accepted_result%mass%residual
    faulty_in = faulty_in + accepted_result%mass%total_in
    faulty_out = faulty_out + accepted_result%mass%total_out
    record%final_ledger_in = faulty_in
    record%final_ledger_out = faulty_out

    call committed%snapshot(snapshot, snapshot_available)
    call require(snapshot_available, 'accepted committed state snapshot available')
    select type (state => snapshot)
    class is (fmr_b110_physical_state_t)
      allocate(record%pressure_head(state%active_nodes), record%water_content(state%active_nodes))
      record%pressure_head = state%pressure_head
      record%water_content = state%water_content
    class default
      call require(.false., 'accepted committed state has expected physical type')
    end select
  end subroutine run_case

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer :: k
    parameters%parameter_set_id = column_id
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=2; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%max_iterations=16; parameters%max_backtracking=8
    parameters%min_step_duration=1.0e-8_real64
    parameters%compartment_balance_tolerance=hard_mass_gate
    parameters%total_balance_tolerance=hard_mass_gate
    parameters%head_abs_tolerance=hard_mass_gate
    parameters%head_rel_tolerance=hard_mass_gate
    parameters%ponding_tolerance=hard_mass_gate
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.
    parameters%snow_active=.false.; parameters%hysteresis_active=.false.
    parameters%tabulated_hydraulics_active=.false.; parameters%elasticity_active=.false.
    parameters%frost_active=.false.; parameters%soil_temperature_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_committed(committed, parameters, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: predecessor(numnod), gradient
    integer :: i

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, rejected_dt)
    heads(1) = -75.0_real64
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
      gradient = (heads(i-1)-heads(i))/parameters%node_distance(i) + 1.0_real64
      call require(abs(gradient) <= 16.0_real64*epsilon(1.0_real64), 'hydrostatic initial gradient')
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    predecessor=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,column_id,state,0.0_real64,ok,predecessor)
  end subroutine initialize_committed

  subroutine initialize_forcing(forcing)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    forcing%top_flux=q; forcing%top_head=-75.0_real64
    forcing%bottom_flux=q; forcing%bottom_head=777777.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_template(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id=column_id+1_int64; template%physics_topology_id=column_id+2_int64
    template%vertical_layout_id=column_id+3_int64; template%state_layout_id=column_id+4_int64
    template%solver_interface_id=column_id+5_int64; template%optional_state_layout_id=0_int64
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id
    column%parameter_ref=1_int64; column%state_handle=1_int64; column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_template

  subroutine initialize_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config=canonical_numerical_config_t()
    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=hard_mass_gate
    config%transaction%retry_scale=0.01_real64
    config%transaction%max_retries=0
    config%max_committed_substeps=1
    config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=.true.
    config%model_temporal_indicator_budget=head_budget
  end subroutine initialize_config

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  pure logical function all_bits_equal(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    all_bits_equal=size(a)==size(b)
    if (.not.all_bits_equal) return
    do i=1,size(a)
      if (.not.same_bits(a(i),b(i))) then
        all_bits_equal=.false.; return
      end if
    end do
  end function all_bits_equal

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'PUB_ME_G1_D2_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_me_g1_d2_reverse_flow_replication
