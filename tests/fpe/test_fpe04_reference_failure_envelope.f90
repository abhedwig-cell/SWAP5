program test_fpe04_reference_failure_envelope
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ncases = 51
  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: head_deltas(13) = [1.0e-14_real64,1.0e-13_real64,1.0e-12_real64,1.0e-11_real64, &
       1.0e-10_real64,1.0e-9_real64,1.0e-8_real64,1.0e-7_real64,1.0e-6_real64,1.0e-5_real64, &
       1.0e-4_real64,1.0e-3_real64,1.0e-2_real64]
  real(real64), parameter :: forcing_deltas(11) = [1.0e-14_real64,1.0e-13_real64,1.0e-12_real64,1.0e-11_real64, &
       1.0e-10_real64,1.0e-9_real64,1.0e-8_real64,1.0e-7_real64,1.0e-6_real64,1.0e-5_real64,1.0e-4_real64]

  type :: envelope_case_t
    character(len=48) :: name = ''
    character(len=24) :: family = ''
    real(real64) :: heads(4) = -75.0_real64
    real(real64) :: head_delta = 0.0_real64
    real(real64) :: top_delta_fraction = 0.0_real64
    real(real64) :: source_delta_fraction = 0.0_real64
    real(real64) :: bottom_delta_fraction = 0.0_real64
    logical :: invalid_forcing_handle = .false.
  end type envelope_case_t

  type :: case_metrics_t
    logical :: accepted = .false.
    logical :: completed = .false.
    logical :: committed = .false.
    logical :: solver_executed = .false.
    logical :: mass_complete = .false.
    logical :: runtime_mass_complete = .false.
    logical :: state_payload_unchanged = .false.
    logical :: replay_deterministic = .false.
    integer :: kernel_status = 0
    integer :: accepted_substeps = 0
    integer :: transaction_retries = 0
    integer :: internal_retries = 0
    integer :: nonlinear_iterations = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    integer :: runtime_number_committed = 0
    integer :: runtime_mass_transactions = 0
    integer(int64) :: mass_missing_mask = 0_int64
    integer(int64) :: initial_revision = 0_int64
    integer(int64) :: final_revision = 0_int64
    real(real64) :: mass_residual = 0.0_real64
    real(real64) :: storage_start = 0.0_real64
    real(real64) :: storage_end = 0.0_real64
    real(real64) :: total_in = 0.0_real64
    real(real64) :: total_out = 0.0_real64
    real(real64) :: final_heads(4) = 0.0_real64
    real(real64) :: final_water(4) = 0.0_real64
    real(real64) :: final_ponding = 0.0_real64
    real(real64) :: final_gwl = 0.0_real64
    character(len=40) :: admission_status = 'NOT_ASSESSED'
    character(len=32) :: solver_route = 'not-run'
    character(len=32) :: classification = 'UNCLASSIFIED'
  end type case_metrics_t

  type(envelope_case_t) :: cases(ncases)
  type(case_metrics_t) :: metrics(ncases)
  integer :: i, accepted_normal, accepted_higher, rejected_retry, pre_solver

  call require(numnod == 4, 'F-PE04 fixture requires exact four-node admitted grid')
  call initialize_cases(cases)

  do i = 1, ncases
    call run_case_pair(i, cases(i), metrics(i))
    call classify_case(metrics(i), metrics(1), cases(i)%invalid_forcing_handle)
    call verify_case_contract(cases(i), metrics(i))
    call print_case(i, cases(i), metrics(i))
  end do

  call require(metrics(1)%accepted, 'baseline must remain accepted')
  call require(trim(metrics(1)%classification) == 'ACCEPTED_NORMAL', 'baseline classification')
  accepted_normal = count([(trim(metrics(i)%classification) == 'ACCEPTED_NORMAL', i=1,ncases)])
  accepted_higher = count([(trim(metrics(i)%classification) == 'ACCEPTED_HIGHER_COST', i=1,ncases)])
  rejected_retry = count([(trim(metrics(i)%classification) == 'REJECTED_AFTER_RETRY', i=1,ncases)])
  pre_solver = count([(trim(metrics(i)%classification) == 'FAIL_CLOSED_PRE_SOLVER', i=1,ncases)])

  call require(pre_solver == 1, 'exactly one negative pre-solver validation control')
  call require(accepted_normal + accepted_higher + rejected_retry + pre_solver == ncases, 'all cases classified')
  call require(all(metrics%replay_deterministic), 'all case replays deterministic')

  write(*,'(A,I0)') 'FPE04_TOTAL_CASES=', ncases
  write(*,'(A,I0)') 'FPE04_ACCEPTED_NORMAL=', accepted_normal
  write(*,'(A,I0)') 'FPE04_ACCEPTED_HIGHER_COST=', accepted_higher
  write(*,'(A,I0)') 'FPE04_REJECTED_AFTER_RETRY=', rejected_retry
  write(*,'(A,I0)') 'FPE04_FAIL_CLOSED_PRE_SOLVER=', pre_solver
  write(*,'(A)') 'FPE04_REPLAY_DETERMINISM=PASS'
  write(*,'(A)') 'FPE04_TRANSACTION_MASS_SAFETY=PASS'
  if (accepted_higher > 0) then
    write(*,'(A)') 'FPE04_FPE03_B01_CANDIDATE=OBSERVED_REQUIRES_DOWNSTREAM_REVIEW'
  else
    write(*,'(A)') 'FPE04_FPE03_B01_CANDIDATE=NOT_OBSERVED'
  end if
  write(*,'(A)') 'FPE04_BALANCED=DEFINED_NOT_ADMITTED'
  write(*,'(A)') 'FPE04_THROUGHPUT=DEFINED_NOT_ADMITTED'
  write(*,'(A)') 'FPE04_FALLBACK=DEFINED_NOT_ADMITTED'
  write(*,'(A)') 'FPE04_REFERENCE_FAILURE_ENVELOPE CHARACTERIZATION_PASS'

contains

  subroutine initialize_cases(c)
    type(envelope_case_t), intent(out) :: c(ncases)
    integer :: idx, j

    idx = 0
    call push_uniform(c, idx, 'C00_uniform_m75', 'BASELINE', -75.0_real64)
    call push_uniform(c, idx, 'C01_uniform_m5', 'UNIFORM_STATE', -5.0_real64)
    call push_uniform(c, idx, 'C02_uniform_m5000', 'UNIFORM_STATE', -5000.0_real64)

    do j = 1, size(head_deltas)
      idx = idx + 1
      call reset_case(c(idx), 'INITIAL_HEAD')
      write(c(idx)%name,'(A,I2.2)') 'H_node2_plus_', j
      c(idx)%head_delta = head_deltas(j)
      c(idx)%heads(2) = c(idx)%heads(2) + head_deltas(j)
    end do

    do j = 1, size(forcing_deltas)
      idx = idx + 1
      call reset_case(c(idx), 'TOP_FLUX_PLUS')
      write(c(idx)%name,'(A,I2.2)') 'T_plus_', j
      c(idx)%top_delta_fraction = forcing_deltas(j)
    end do
    do j = 1, size(forcing_deltas)
      idx = idx + 1
      call reset_case(c(idx), 'TOP_FLUX_MINUS')
      write(c(idx)%name,'(A,I2.2)') 'T_minus_', j
      c(idx)%top_delta_fraction = -forcing_deltas(j)
    end do

    do j = 1, size(forcing_deltas)
      idx = idx + 1
      call reset_case(c(idx), 'SOURCE_SINK')
      write(c(idx)%name,'(A,I2.2)') 'Q_source_plus_', j
      c(idx)%source_delta_fraction = forcing_deltas(j)
    end do

    idx = idx + 1
    call reset_case(c(idx), 'BOTTOM_MODE7_CONTROL')
    c(idx)%name = 'B_mode7_bottom_flux_plus_1pct'
    c(idx)%bottom_delta_fraction = 1.0e-2_real64

    idx = idx + 1
    call reset_case(c(idx), 'PRE_SOLVER_VALIDATION')
    c(idx)%name = 'V_invalid_forcing_handle'
    c(idx)%invalid_forcing_handle = .true.

    call require(idx == ncases, 'matrix case count')
  end subroutine initialize_cases

  subroutine reset_case(c, family)
    type(envelope_case_t), intent(out) :: c
    character(len=*), intent(in) :: family
    c = envelope_case_t()
    c%family = family
  end subroutine reset_case

  subroutine push_uniform(c, idx, name, family, head)
    type(envelope_case_t), intent(inout) :: c(ncases)
    integer, intent(inout) :: idx
    character(len=*), intent(in) :: name, family
    real(real64), intent(in) :: head
    idx = idx + 1
    call reset_case(c(idx), family)
    c(idx)%name = name
    c(idx)%heads = head
  end subroutine push_uniform

  subroutine run_case_pair(case_id, spec, metric)
    integer, intent(in) :: case_id
    type(envelope_case_t), intent(in) :: spec
    type(case_metrics_t), intent(out) :: metric
    type(case_metrics_t) :: a, b

    call run_once(case_id, spec, a)
    call run_once(case_id, spec, b)
    call require(metrics_equivalent(a, b), 'deterministic replay mismatch: '//trim(spec%name))
    metric = a
    metric%replay_deterministic = .true.
  end subroutine run_case_pair

  subroutine run_once(case_id, spec, metric)
    integer, intent(in) :: case_id
    type(envelope_case_t), intent(in) :: spec
    type(case_metrics_t), intent(out) :: metric
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t) :: forcings(1)
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: states(1)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    class(transaction_state_t), allocatable :: final_snapshot
    real(real64) :: k_top, k_bottom
    integer :: dispatch_status
    logical :: ok, snapshot_ok

    metric = case_metrics_t()
    call configure_template(templates(1))
    call configure_parameters(parameters(1), initial_state, spec%heads, k_top, k_bottom)
    call configure_forcing(forcings(1), spec, k_top, k_bottom)
    call configure_transaction(config)

    columns(1)%column_id = 504000_int64 + int(case_id, int64)
    columns(1)%template_id = templates(1)%template_id
    columns(1)%parameter_ref = 1_int64
    columns(1)%state_handle = 1_int64
    columns(1)%forcing_handle = merge(2_int64, 1_int64, spec%invalid_forcing_handle)
    columns(1)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(states(1), columns(1)%column_id, initial_state, t0, ok)
    call require(ok, 'committed-state initialization')

    metric%initial_revision = states(1)%current_revision()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64

    call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, states, config, &
         top_provider, t0, t1, 1, results, diagnostics, aggregate, dispatch_status, runtime)
    call require(dispatch_status == FMR_SERIAL_DISPATCH_OK, 'serialized dispatch status')
    call require(size(results) == 1, 'single result')

    metric%kernel_status = results(1)%kernel_status
    metric%completed = results(1)%completed
    metric%committed = results(1)%committed
    metric%solver_executed = results(1)%solver_executed
    metric%accepted_substeps = results(1)%accepted_substeps
    metric%transaction_retries = diagnostics(1)%retries
    metric%internal_retries = results(1)%solver_internal_retries
    metric%nonlinear_iterations = results(1)%solver_nonlinear_iterations
    metric%headcalc_calls = results(1)%solver_headcalc_calls
    metric%jacobian_builds = results(1)%solver_jacobian_builds
    metric%linear_solves = results(1)%solver_linear_solves
    metric%backtracking_attempts = results(1)%solver_backtracking_attempts
    metric%alternative_solver_calls = results(1)%solver_alternative_solver_calls
    metric%mass_complete = results(1)%mass%complete
    metric%mass_missing_mask = results(1)%mass%missing_contribution_mask
    metric%mass_residual = results(1)%mass%residual
    metric%storage_start = results(1)%mass%storage_start
    metric%storage_end = results(1)%mass%storage_end
    metric%total_in = results(1)%mass%total_in
    metric%total_out = results(1)%mass%total_out
    metric%admission_status = results(1)%admission_status
    metric%solver_route = results(1)%solver_route
    metric%runtime_number_committed = runtime%number_committed
    metric%runtime_mass_complete = runtime%authoritative_aggregate_mass%complete
    metric%runtime_mass_transactions = runtime%authoritative_aggregate_mass%accepted_transaction_count
    metric%final_revision = states(1)%current_revision()
    metric%accepted = results(1)%completed .and. results(1)%committed .and. results(1)%mass%complete .and. &
         results(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE

    call states(1)%snapshot(final_snapshot, snapshot_ok)
    call require(snapshot_ok, 'final committed snapshot available')
    select type (physical => final_snapshot)
    type is (fmr_b110_physical_state_t)
      call require(physical%active_nodes == 4, 'final physical active nodes')
      metric%final_heads = physical%pressure_head
      metric%final_water = physical%water_content
      metric%final_ponding = physical%ponding_depth
      metric%final_gwl = physical%groundwater_level
      metric%state_payload_unchanged = all(physical%pressure_head == initial_state%pressure_head) .and. &
           all(physical%water_content == initial_state%water_content) .and. &
           physical%ponding_depth == initial_state%ponding_depth .and. &
           physical%groundwater_level == initial_state%groundwater_level
    class default
      call require(.false., 'unexpected final snapshot type')
    end select
  end subroutine run_once

  subroutine classify_case(metric, baseline, pre_solver_expected)
    type(case_metrics_t), intent(inout) :: metric
    type(case_metrics_t), intent(in) :: baseline
    logical, intent(in) :: pre_solver_expected

    if (pre_solver_expected) then
      metric%classification = 'FAIL_CLOSED_PRE_SOLVER'
    else if (metric%accepted) then
      if (cost_exceeds(metric, baseline)) then
        metric%classification = 'ACCEPTED_HIGHER_COST'
      else
        metric%classification = 'ACCEPTED_NORMAL'
      end if
    else
      metric%classification = 'REJECTED_AFTER_RETRY'
    end if
  end subroutine classify_case

  subroutine verify_case_contract(spec, metric)
    type(envelope_case_t), intent(in) :: spec
    type(case_metrics_t), intent(in) :: metric

    call require(metric%replay_deterministic, 'replay flag')
    if (spec%invalid_forcing_handle) then
      call require(.not. metric%accepted, 'pre-solver negative control not accepted')
      call require(.not. metric%solver_executed, 'pre-solver negative control solver not executed')
      call require(.not. metric%completed .and. .not. metric%committed, 'pre-solver result not published')
      call require(metric%final_revision == metric%initial_revision, 'pre-solver revision unchanged')
      call require(metric%state_payload_unchanged, 'pre-solver state payload unchanged')
      call require(metric%runtime_number_committed == 0, 'pre-solver no runtime commit')
      call require(.not. metric%runtime_mass_complete .and. metric%runtime_mass_transactions == 0, &
           'pre-solver no authoritative mass publication')
      call require(metric%nonlinear_iterations == 0 .and. metric%headcalc_calls == 0 .and. &
           metric%jacobian_builds == 0 .and. metric%linear_solves == 0 .and. &
           metric%backtracking_attempts == 0, 'pre-solver zero solver work')
    else if (metric%accepted) then
      call require(metric%mass_complete .and. metric%mass_missing_mask == TX_MASS_MISSING_NONE, &
           'accepted authoritative mass complete')
      call require(abs(metric%mass_residual) <= hard_mass_gate, 'accepted hard mass gate')
      call require(metric%final_revision == metric%initial_revision + 1_int64, 'accepted exactly one commit')
      call require(metric%runtime_number_committed == 1, 'accepted runtime committed once')
      call require(metric%runtime_mass_complete, 'accepted runtime aggregate mass complete')
      call require(metric%runtime_mass_transactions == 1, 'accepted no duplicate mass accounting')
    else
      call require(metric%solver_executed, 'rejected admitted perturbation reached solver')
      call require(metric%transaction_retries > 0 .or. metric%internal_retries > 0, 'rejected case used retry path')
      call require(.not. metric%completed .and. .not. metric%committed, 'rejected result not published')
      call require(metric%final_revision == metric%initial_revision, 'rejected checkpoint revision unchanged')
      call require(metric%state_payload_unchanged, 'rejected committed payload unchanged')
      call require(metric%runtime_number_committed == 0, 'rejected no runtime commit')
      call require(.not. metric%runtime_mass_complete .and. metric%runtime_mass_transactions == 0, &
           'rejected no authoritative committed mass leakage')
    end if
  end subroutine verify_case_contract

  logical function metrics_equivalent(a, b) result(equal)
    type(case_metrics_t), intent(in) :: a, b
    equal = a%accepted .eqv. b%accepted
    equal = equal .and. (a%completed .eqv. b%completed) .and. (a%committed .eqv. b%committed) .and. &
         (a%solver_executed .eqv. b%solver_executed) .and. (a%mass_complete .eqv. b%mass_complete) .and. &
         (a%runtime_mass_complete .eqv. b%runtime_mass_complete) .and. &
         (a%state_payload_unchanged .eqv. b%state_payload_unchanged)
    equal = equal .and. a%kernel_status == b%kernel_status .and. a%accepted_substeps == b%accepted_substeps .and. &
         a%transaction_retries == b%transaction_retries .and. a%internal_retries == b%internal_retries .and. &
         a%nonlinear_iterations == b%nonlinear_iterations .and. a%headcalc_calls == b%headcalc_calls .and. &
         a%jacobian_builds == b%jacobian_builds .and. a%linear_solves == b%linear_solves .and. &
         a%backtracking_attempts == b%backtracking_attempts .and. &
         a%alternative_solver_calls == b%alternative_solver_calls .and. &
         a%runtime_number_committed == b%runtime_number_committed .and. &
         a%runtime_mass_transactions == b%runtime_mass_transactions .and. a%mass_missing_mask == b%mass_missing_mask .and. &
         a%initial_revision == b%initial_revision .and. a%final_revision == b%final_revision
    equal = equal .and. a%mass_residual == b%mass_residual .and. a%storage_start == b%storage_start .and. &
         a%storage_end == b%storage_end .and. a%total_in == b%total_in .and. a%total_out == b%total_out .and. &
         all(a%final_heads == b%final_heads) .and. all(a%final_water == b%final_water) .and. &
         a%final_ponding == b%final_ponding .and. a%final_gwl == b%final_gwl .and. &
         trim(a%admission_status) == trim(b%admission_status) .and. trim(a%solver_route) == trim(b%solver_route)
  end function metrics_equivalent

  logical function cost_exceeds(candidate, baseline) result(exceeds)
    type(case_metrics_t), intent(in) :: candidate, baseline
    exceeds = candidate%headcalc_calls > baseline%headcalc_calls .or. &
         candidate%nonlinear_iterations > baseline%nonlinear_iterations .or. &
         candidate%backtracking_attempts > baseline%backtracking_attempts .or. &
         candidate%internal_retries > baseline%internal_retries .or. &
         candidate%transaction_retries > baseline%transaction_retries .or. &
         candidate%jacobian_builds > baseline%jacobian_builds .or. candidate%linear_solves > baseline%linear_solves
  end function cost_exceeds

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 504_int64
    template%physics_topology_id = 50501_int64
    template%vertical_layout_id = 50502_int64
    template%state_layout_id = 50503_int64
    template%solver_interface_id = 50504_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameters, state, heads, k_top, k_bottom)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: heads(4)
    real(real64), intent(out) :: k_top, k_bottom
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    parameters%parameter_set_id = 50401_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    allocate(parameters%cofgen(24,numnod))
    parameters%cofgen = 0.0_real64
    do i = 1, numnod
      parameters%cofgen(1,i) = 0.032_real64
      parameters%cofgen(2,i) = 0.423_real64
      parameters%cofgen(3,i) = 4.75_real64
      parameters%cofgen(4,i) = 0.0135_real64
      parameters%cofgen(5,i) = 0.365_real64
      parameters%cofgen(6,i) = 1.455_real64
      parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i) = parameters%cofgen(4,i)
      parameters%cofgen(9,i) = 0.0_real64
      parameters%cofgen(10,i) = parameters%cofgen(3,i)
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
    end do
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 8
    parameters%max_backtracking = 4
    parameters%min_step_duration = 1.0e-6_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    k_top = conductivity(1)
    k_bottom = conductivity(numnod)
    call require(k_top > 0.0_real64 .and. k_bottom > 0.0_real64, 'positive endpoint conductivity')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing, spec, k_top, k_bottom)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(envelope_case_t), intent(in) :: spec
    real(real64), intent(in) :: k_top, k_bottom
    integer :: i

    forcing%top_flux = -(1.0_real64 + spec%top_delta_fraction) * k_top
    forcing%top_head = spec%heads(1)
    forcing%bottom_flux = -(1.0_real64 + spec%bottom_delta_fraction) * k_bottom
    forcing%bottom_head = spec%heads(numnod)
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = (forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)) * (1.0_real64 + spec%source_delta_fraction)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine print_case(i, spec, metric)
    integer, intent(in) :: i
    type(envelope_case_t), intent(in) :: spec
    type(case_metrics_t), intent(in) :: metric
    character(len=20) :: prefix

    write(prefix,'(A,I2.2)') 'FPE04_CASE_', i
    write(*,'(A,A)') trim(prefix)//'_NAME=', trim(spec%name)
    write(*,'(A,A)') trim(prefix)//'_FAMILY=', trim(spec%family)
    write(*,'(A,ES26.17E3)') trim(prefix)//'_HEAD_DELTA=', spec%head_delta
    write(*,'(A,ES26.17E3)') trim(prefix)//'_TOP_DELTA_FRACTION=', spec%top_delta_fraction
    write(*,'(A,ES26.17E3)') trim(prefix)//'_SOURCE_DELTA_FRACTION=', spec%source_delta_fraction
    write(*,'(A,ES26.17E3)') trim(prefix)//'_BOTTOM_DELTA_FRACTION=', spec%bottom_delta_fraction
    write(*,'(A,A)') trim(prefix)//'_CLASS=', trim(metric%classification)
    write(*,'(A,L1)') trim(prefix)//'_ACCEPTED=', metric%accepted
    write(*,'(A,A)') trim(prefix)//'_ADMISSION_STATUS=', trim(metric%admission_status)
    write(*,'(A,L1)') trim(prefix)//'_SOLVER_EXECUTED=', metric%solver_executed
    write(*,'(A,A)') trim(prefix)//'_SOLVER_ROUTE=', trim(metric%solver_route)
    write(*,'(A,I0)') trim(prefix)//'_ACCEPTED_SUBSTEPS=', metric%accepted_substeps
    write(*,'(A,I0)') trim(prefix)//'_TRANSACTION_RETRIES=', metric%transaction_retries
    write(*,'(A,I0)') trim(prefix)//'_INTERNAL_RETRIES=', metric%internal_retries
    write(*,'(A,I0)') trim(prefix)//'_NONLINEAR_ITERATIONS=', metric%nonlinear_iterations
    write(*,'(A,I0)') trim(prefix)//'_HEADCALC_CALLS=', metric%headcalc_calls
    write(*,'(A,I0)') trim(prefix)//'_JACOBIAN_BUILDS=', metric%jacobian_builds
    write(*,'(A,I0)') trim(prefix)//'_LINEAR_SOLVES=', metric%linear_solves
    write(*,'(A,I0)') trim(prefix)//'_BACKTRACKING_ATTEMPTS=', metric%backtracking_attempts
    write(*,'(A,L1)') trim(prefix)//'_MASS_COMPLETE=', metric%mass_complete
    write(*,'(A,I0)') trim(prefix)//'_MASS_MISSING_MASK=', metric%mass_missing_mask
    write(*,'(A,ES26.17E3)') trim(prefix)//'_MASS_RESIDUAL=', metric%mass_residual
    write(*,'(A,I0)') trim(prefix)//'_INITIAL_REVISION=', metric%initial_revision
    write(*,'(A,I0)') trim(prefix)//'_FINAL_REVISION=', metric%final_revision
    write(*,'(A,L1)') trim(prefix)//'_STATE_PAYLOAD_UNCHANGED=', metric%state_payload_unchanged
    write(*,'(A,I0)') trim(prefix)//'_RUNTIME_COMMITTED=', metric%runtime_number_committed
    write(*,'(A,L1)') trim(prefix)//'_RUNTIME_MASS_COMPLETE=', metric%runtime_mass_complete
    write(*,'(A,I0)') trim(prefix)//'_RUNTIME_MASS_TRANSACTIONS=', metric%runtime_mass_transactions
    write(*,'(A,L1)') trim(prefix)//'_REPLAY_DETERMINISTIC=', metric%replay_deterministic
  end subroutine print_case

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FPE04_FAIL '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fpe04_reference_failure_envelope
