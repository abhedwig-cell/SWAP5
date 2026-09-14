module mod_fmr_serialized_multiswap_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_canonical_contracts, only: canonical_mass_accounting_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED
  use mod_soil_water_solver_contract, only: top_boundary_provider_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_COMMIT_REJECTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_build_execution_order, fmr_count_templates, &
       FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_candidate_t, fmr_bottom_thermal_sample_t, &
       FMR_BOTTOM_THERMAL_DONOR_EXTERNAL
  use mod_fmr_bottom_external_thermal_binding, only: fmr_bottom_external_thermal_binding_bundle_t, &
       FMR_EXT_THERMAL_BINDING_OK
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_request_t, &
       fmr_external_bottom_thermal_response_t, fmr_external_bottom_thermal_provider_i, &
       initialize_fmr_external_bottom_thermal_request, FMR_EXT_THERMAL_RESPONSE_COMPLETE, &
       FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, FMR_EXT_THERMAL_RESPONSE_STALE
  use mod_fmr_bottom_sensible_energy, only: fmr_bottom_sensible_energy_result_t, &
       evaluate_fmr_bottom_sensible_energy, evaluate_fmr_bottom_sensible_energy_with_external, &
       FMR_BOTTOM_ENERGY_NOT_EVALUATED, FMR_BOTTOM_ENERGY_INVALID_CANDIDATE
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t
  implicit none
  private

  integer, parameter, public :: FMR_SERIAL_DISPATCH_OK = 0
  integer, parameter, public :: FMR_SERIAL_DISPATCH_INVALID_REQUEST = 1
  integer, parameter, public :: FMR_SERIAL_DISPATCH_REGISTRY_REJECTED = 2
  integer, parameter, public :: FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED = 3

  type, public :: fmr_serialized_column_result_t
    integer(int64) :: column_id = 0_int64
    integer :: dispatch_ordinal = 0
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    logical :: admission_assessed = .false.
    logical :: admitted = .false.
    character(len=40) :: admission_status = 'NOT_ASSESSED'
    integer :: kernel_status = 0
    integer :: commit_status = -1
    logical :: completed = .false.
    logical :: committed = .false.
    logical :: solver_executed = .false.
    character(len=32) :: solver_route = 'not-run'
    integer :: solver_iterations = 0
    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
    integer(int64) :: initial_revision = -1_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: final_committed_time = 0.0_real64
    logical :: final_committed_time_bound = .false.
    logical :: actual_transpiration_available = .false.
    real(real64) :: actual_transpiration_amount = 0.0_real64
    type(canonical_mass_accounting_t) :: mass
  end type fmr_serialized_column_result_t

  ! Sparse ephemeral receipt output. The explicit column id makes the
  ! request/output association self-describing without adding any persistent
  ! optional state to logical columns or committed physical state.
  type, public :: fmr_serialized_commit_receipt_record_t
    integer(int64) :: column_id = 0_int64
    type(fmr_accepted_commit_receipt_t) :: receipt
  end type fmr_serialized_commit_receipt_record_t

  ! Worker-local precommit carrier. It is deliberately private so no caller can
  ! retain energy from candidate B and later combine it with candidate A's
  ! receipt. The carrier may represent complete or explicitly unavailable
  ! diagnostic energy; neither case is committed physical SWAP state.
  type :: fmr_prepared_bottom_energy_publication_t
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer :: energy_status_value = FMR_BOTTOM_ENERGY_NOT_EVALUATED
    logical :: total_available_value = .false.
    real(real64) :: total_energy_j_m2_value = 0.0_real64
    logical :: local_subtotal_available_value = .false.
    real(real64) :: local_subtotal_j_m2_value = 0.0_real64
    integer :: provider_request_count_value = 0
    integer :: provider_complete_count_value = 0
    integer :: provider_unavailable_count_value = 0
    integer :: provider_stale_count_value = 0
    integer :: provider_invalid_count_value = 0
  contains
    procedure :: ready => prepared_bottom_energy_ready
  end type fmr_prepared_bottom_energy_publication_t

  ! Accepted-only bottom sensible-energy accounting. This result is ephemeral
  ! runtime output, not continuation state and not a second water/mass ledger.
  ! A ready publication can still have total_available=.false.; that is the
  ! required fail-closed representation for diagnostic energy when an external
  ! donor temperature was unavailable or invalid after hydrology was accepted.
  type, public :: fmr_serialized_bottom_energy_publication_t
    private
    logical :: initialized = .false.
    integer(int64) :: column_id_value = 0_int64
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer :: energy_status_value = FMR_BOTTOM_ENERGY_NOT_EVALUATED
    logical :: total_available_value = .false.
    real(real64) :: total_energy_j_m2_value = 0.0_real64
    logical :: local_subtotal_available_value = .false.
    real(real64) :: local_subtotal_j_m2_value = 0.0_real64
    integer :: provider_request_count_value = 0
    integer :: provider_complete_count_value = 0
    integer :: provider_unavailable_count_value = 0
    integer :: provider_stale_count_value = 0
    integer :: provider_invalid_count_value = 0
  contains
    procedure, public :: ready => bottom_energy_publication_ready
    procedure, public :: column_id => bottom_energy_publication_column_id
    procedure, public :: current_lineage_id => bottom_energy_publication_lineage_id
    procedure, public :: origin_revision => bottom_energy_publication_origin_revision
    procedure, public :: committed_revision => bottom_energy_publication_committed_revision
    procedure, public :: origin_interval => bottom_energy_publication_origin_interval
    procedure, public :: energy_status => bottom_energy_publication_energy_status
    procedure, public :: complete => bottom_energy_publication_complete
    procedure, public :: total_energy => bottom_energy_publication_total_energy
    procedure, public :: local_outward_subtotal => bottom_energy_publication_local_subtotal
    procedure, public :: provider_counts => bottom_energy_publication_provider_counts
  end type fmr_serialized_bottom_energy_publication_t

  ! F-MR05-specific composition diagnostics.  This is deliberately separate
  ! from the generic F-MR01 aggregate type so the strict serialized physical
  ! admission constraint does not leak into the logical runtime core.
  type, public :: fmr_serialized_batch_diagnostics_t
    integer :: number_requested = 0
    integer :: number_admitted = 0
    integer :: number_executed = 0
    integer :: number_committed = 0
    integer :: number_rejected = 0
    integer :: physical_solve_count = 0
    integer :: max_simultaneous_real_physical_solves = 0
    logical :: deterministic_collection = .false.
    real(real64) :: effective_t0 = 0.0_real64
    real(real64) :: effective_t1 = 0.0_real64
    real(real64) :: max_abs_column_mass_residual = 0.0_real64
    type(canonical_mass_accounting_t) :: authoritative_aggregate_mass
  end type fmr_serialized_batch_diagnostics_t

  public :: fmr_run_serialized_physical_multiswap
  public :: fmr_execute_serialized_physical_column
  public :: fmr_execute_serialized_resolved_physical_column
  public :: fmr_execute_serialized_column_with_bottom_energy

contains

  subroutine fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
                                                    state_registry, numerical_config, top_boundary, t0, t1, &
                                                    batch_size, results, diagnostics, aggregate, dispatch_status, &
                                                    runtime_diagnostics, receipt_column_ids, commit_receipts)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    real(real64), intent(in) :: t0, t1
    integer, intent(in) :: batch_size
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer, intent(out) :: dispatch_status
    type(fmr_serialized_batch_diagnostics_t), intent(out), optional :: runtime_diagnostics
    integer(int64), intent(in), optional :: receipt_column_ids(:)
    type(fmr_serialized_commit_receipt_record_t), allocatable, intent(out), optional :: commit_receipts(:)

    type(fmr_serialized_reference_backend_t), target :: backend
    type(kernel_executor_t) :: transaction_control
    type(fmr_serialized_batch_diagnostics_t) :: local_runtime
    integer, allocatable :: order(:)
    integer :: batch_start, batch_end, pos, idx, batches, active_physical_calls, receipt_slot

    call initialize_outputs(columns, t0, t1, results, diagnostics, aggregate)
    call initialize_runtime_diagnostics(size(columns), t0, t1, local_runtime)
    active_physical_calls = 0
    dispatch_status = FMR_SERIAL_DISPATCH_OK
    if (present(commit_receipts)) allocate(commit_receipts(0))

    ! Receipt requests are optional feature-scoped runtime metadata. Validate
    ! the complete sparse request before backend initialization or any physical
    ! trial so every expected request error is transactionally precommit.
    if (present(receipt_column_ids) .neqv. present(commit_receipts)) then
      dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
      call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if
    if (present(receipt_column_ids)) then
      if (.not. receipt_request_valid(columns, receipt_column_ids)) then
        dispatch_status = FMR_SERIAL_DISPATCH_RECEIPT_REQUEST_REJECTED
        call mark_all_rejected(diagnostics, 'RECEIPT_REQUEST_REJECTED')
        call build_aggregate(columns, diagnostics, 0, aggregate)
        call finalize_runtime_diagnostics(results, local_runtime)
        if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
        return
      end if
      deallocate(commit_receipts)
      allocate(commit_receipts(size(receipt_column_ids)))
      do receipt_slot = 1, size(receipt_column_ids)
        commit_receipts(receipt_slot)%column_id = receipt_column_ids(receipt_slot)
      end do
    end if

    if (batch_size <= 0 .or. t1 <= t0) then
      dispatch_status = FMR_SERIAL_DISPATCH_INVALID_REQUEST
      call mark_all_rejected(diagnostics, 'INVALID_DISPATCH_REQUEST')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    if (.not. registry_structure_valid(columns, templates, state_registry)) then
      dispatch_status = FMR_SERIAL_DISPATCH_REGISTRY_REJECTED
      call mark_all_rejected(diagnostics, 'REGISTRY_STRUCTURE_REJECTED')
      call build_aggregate(columns, diagnostics, 0, aggregate)
      call finalize_runtime_diagnostics(results, local_runtime)
      if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
      return
    end if

    call backend%initialize(top_boundary)
    call fmr_build_execution_order(columns, order)
    batches = 0
    do batch_start = 1, size(columns), batch_size
      batches = batches + 1
      batch_end = min(size(columns), batch_start + batch_size - 1)
      do pos = batch_start, batch_end
        idx = order(pos)
        results(idx)%dispatch_ordinal = pos
        receipt_slot = 0
        if (present(receipt_column_ids)) receipt_slot = find_receipt_slot(columns(idx)%column_id, receipt_column_ids)
        if (receipt_slot > 0) then
          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &
               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &
               local_runtime, active_physical_calls, commit_receipts(receipt_slot)%receipt)
        else
          call execute_column(backend, transaction_control, columns(idx), templates, parameter_registry, &
               forcing_registry, state_registry, numerical_config, t0, t1, results(idx), diagnostics(idx), &
               local_runtime, active_physical_calls)
        end if
      end do
    end do

    local_runtime%deterministic_collection = .true.
    call build_aggregate(columns, diagnostics, batches, aggregate, order)
    call finalize_runtime_diagnostics(results, local_runtime, order)
    if (present(runtime_diagnostics)) runtime_diagnostics = local_runtime
  end subroutine fmr_run_serialized_physical_multiswap

  ! Registry-facing worker seam retained for current parallel callers.  Handle
  ! validation and resolution remain here; the transaction path below consumes
  ! only the one selected forcing object.
  subroutine fmr_execute_serialized_physical_column(backend, transaction_control, column, templates, parameter_registry, &
                                                     forcing_registry, state_registry, numerical_config, t0, t1, &
                                                     output, diagnostic, runtime, active_physical_calls)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls

    call execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &
         state_registry, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
  end subroutine fmr_execute_serialized_physical_column

  ! Resolved worker seam for ephemeral effective forcing.  The caller owns and
  ! pre-resolves template, parameter, forcing and committed-state objects.  The
  ! forcing object is read-only scratch/input and is never persisted here.
  subroutine fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
                                                              effective_forcing, committed_state, numerical_config, t0, t1, &
                                                              output, diagnostic, runtime, active_physical_calls)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls

    if (.not. resolved_column_is_routable(column, template)) then
      output%admission_status = 'ROUTING_REJECTED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'ROUTING_REJECTED'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    call execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
         committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
  end subroutine fmr_execute_serialized_resolved_physical_column

  ! Opt-in worker-level energy publication seam. The exact thermal candidate,
  ! provider resolution, energy preparation and physical candidate all remain
  ! inside the existing private transaction owner. No caller-created binding
  ! bundle or prepared result crosses this boundary.
  subroutine fmr_execute_serialized_column_with_bottom_energy(backend, transaction_control, column, &
       template, parameters, effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
       external_temperature_provider, output, diagnostic, runtime, active_physical_calls, energy_publication)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: energy_parameters
    procedure(fmr_external_bottom_thermal_provider_i) :: external_temperature_provider
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    type(fmr_serialized_bottom_energy_publication_t), intent(out) :: energy_publication

    energy_publication = fmr_serialized_bottom_energy_publication_t()
    if (.not. resolved_column_is_routable(column, template)) then
      output%admission_status = 'ROUTING_REJECTED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'ROUTING_REJECTED'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    call execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
         committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, &
         bottom_energy_parameters=energy_parameters, bottom_thermal_provider=external_temperature_provider, &
         bottom_energy_publication=energy_publication)
  end subroutine fmr_execute_serialized_column_with_bottom_energy

  subroutine initialize_outputs(columns, t0, t1, results, diagnostics, aggregate)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    type(fmr_column_diagnostics_t), allocatable, intent(out) :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t), intent(out) :: aggregate
    integer :: i

    allocate(results(size(columns)), diagnostics(size(columns)))
    aggregate = fmr_aggregate_diagnostics_t()
    do i = 1, size(columns)
      results(i)%column_id = columns(i)%column_id
      results(i)%requested_t0 = t0
      results(i)%requested_t1 = t1
      diagnostics(i)%column_id = columns(i)%column_id
      diagnostics(i)%template_id = columns(i)%template_id
      diagnostics(i)%backend = columns(i)%backend_id
      diagnostics(i)%execution_class = columns(i)%execution_class
      allocate(diagnostics(i)%worker_assignments(1))
      diagnostics(i)%worker_assignments(1) = 1
    end do
  end subroutine initialize_outputs

  subroutine initialize_runtime_diagnostics(number_requested, t0, t1, runtime)
    integer, intent(in) :: number_requested
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_batch_diagnostics_t), intent(out) :: runtime

    runtime = fmr_serialized_batch_diagnostics_t()
    runtime%number_requested = number_requested
    runtime%effective_t0 = t0
    runtime%effective_t1 = t1
    runtime%authoritative_aggregate_mass = canonical_mass_accounting_t()
    runtime%authoritative_aggregate_mass%interval_t0 = t0
    runtime%authoritative_aggregate_mass%interval_t1 = t1
    runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
  end subroutine initialize_runtime_diagnostics

  logical function receipt_request_valid(columns, receipt_column_ids) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    integer(int64), intent(in) :: receipt_column_ids(:)
    integer :: i, j

    valid = .true.
    do i = 1, size(receipt_column_ids)
      if (receipt_column_ids(i) <= 0_int64) then
        valid = .false.
        return
      end if
      if (.not. any(columns%column_id == receipt_column_ids(i))) then
        valid = .false.
        return
      end if
      do j = i + 1, size(receipt_column_ids)
        if (receipt_column_ids(j) == receipt_column_ids(i)) then
          valid = .false.
          return
        end if
      end do
    end do
  end function receipt_request_valid

  integer function find_receipt_slot(column_id, receipt_column_ids) result(slot)
    integer(int64), intent(in) :: column_id
    integer(int64), intent(in) :: receipt_column_ids(:)
    integer :: i

    slot = 0
    do i = 1, size(receipt_column_ids)
      if (receipt_column_ids(i) == column_id) then
        slot = i
        return
      end if
    end do
  end function find_receipt_slot

  logical function registry_structure_valid(columns, templates, states) result(valid)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_template_t), intent(in) :: templates(:)
    type(kernel_committed_state_t), intent(in) :: states(:)
    logical, allocatable :: state_claimed(:)
    integer :: i, j, state_index

    valid = .false.

    do i = 1, size(templates)
      if (templates(i)%template_id <= 0_int64) return
      do j = i + 1, size(templates)
        if (templates(j)%template_id == templates(i)%template_id) return
      end do
    end do

    allocate(state_claimed(size(states)))
    state_claimed = .false.
    do i = 1, size(columns)
      if (columns(i)%column_id <= 0_int64) return
      do j = i + 1, size(columns)
        if (columns(j)%column_id == columns(i)%column_id) return
      end do
      if (columns(i)%state_handle < 1_int64 .or. &
          columns(i)%state_handle > int(size(states), int64)) return
      state_index = int(columns(i)%state_handle)
      if (state_claimed(state_index)) return
      state_claimed(state_index) = .true.
    end do

    valid = .true.
  end function registry_structure_valid

  ! Registry-facing resolver.  Existing callers retain the same routing
  ! contract and provenance behavior; only the resolved objects cross the
  ! shared transaction boundary.
  subroutine execute_column(backend, transaction_control, column, templates, parameter_registry, forcing_registry, &
                            state_registry, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, &
                            commit_receipt)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    type(kernel_committed_state_t), intent(inout) :: state_registry(:)
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    type(fmr_accepted_commit_receipt_t), intent(inout), optional :: commit_receipt

    integer :: state_index, parameter_index, forcing_index, template_index

    if (.not. column_is_routable(column, templates, parameter_registry, forcing_registry)) then
      output%admission_status = 'ROUTING_REJECTED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'ROUTING_REJECTED'
      call update_committed_provenance_by_handle(column, state_registry, output, diagnostic)
      return
    end if

    state_index = int(column%state_handle)
    parameter_index = int(column%parameter_ref)
    forcing_index = int(column%forcing_handle)
    template_index = find_template_index(column%template_id, templates)

    if (present(commit_receipt)) then
      call execute_resolved_column(backend, transaction_control, column, templates(template_index), &
           parameter_registry(parameter_index), forcing_registry(forcing_index), state_registry(state_index), &
           numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, commit_receipt)
    else
      call execute_resolved_column(backend, transaction_control, column, templates(template_index), &
           parameter_registry(parameter_index), forcing_registry(forcing_index), state_registry(state_index), &
           numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
    end if
  end subroutine execute_column

  ! Single authoritative physical transaction body.  It receives already
  ! resolved objects and therefore does not know forcing registries or handles.
  subroutine execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
                                     committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
                                     active_physical_calls, commit_receipt, bottom_energy_parameters, &
                                     bottom_thermal_provider, bottom_energy_publication)
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(kernel_executor_t), intent(inout) :: transaction_control
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    type(fmr_accepted_commit_receipt_t), intent(inout), optional :: commit_receipt
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in), optional :: bottom_energy_parameters
    procedure(fmr_external_bottom_thermal_provider_i), optional :: bottom_thermal_provider
    type(fmr_serialized_bottom_energy_publication_t), intent(out), optional :: bottom_energy_publication

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: kernel_result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: kernel_diag
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr_bottom_thermal_candidate_t) :: thermal_candidate
    type(fmr_prepared_bottom_energy_publication_t) :: prepared_bottom_energy
    type(fmr_accepted_commit_receipt_t) :: local_energy_receipt
    integer :: commit_status, receipt_status, simultaneous_physical_calls
    logical :: checkpoint_ok, candidate_ready, did_commit, energy_requested, receipt_path

    output%initial_revision = committed_state%current_revision()
    energy_requested = present(bottom_energy_parameters) .and. present(bottom_thermal_provider) .and. &
         present(bottom_energy_publication)
    if (present(bottom_energy_parameters) .or. present(bottom_thermal_provider) .or. present(bottom_energy_publication)) then
      if (.not. energy_requested) error stop 'EB-I18: partial bottom-energy transaction request'
    end if
    receipt_path = present(commit_receipt) .or. energy_requested
    if (present(bottom_energy_publication)) bottom_energy_publication = fmr_serialized_bottom_energy_publication_t()
    call thermal_candidate%clear()
    prepared_bottom_energy = fmr_prepared_bottom_energy_publication_t()

    call fmr_capture_checkpoint(committed_state, checkpoint, checkpoint_ok)
    if (.not. checkpoint_ok) then
      output%admission_status = 'CHECKPOINT_CAPTURE_FAILED'
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CHECKPOINT_CAPTURE_FAILED'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    diagnostic%checkpoint_captures = 1
    diagnostic%checkpoint_replays = 1
    diagnostic%runtime_attempts = 1

    !$omp atomic capture
    active_physical_calls = active_physical_calls + 1
    simultaneous_physical_calls = active_physical_calls
    !$omp end atomic
    if (energy_requested) call backend%set_bottom_thermal_carrier_enabled(.true.)
    call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
         numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)
    if (energy_requested) then
      thermal_candidate = backend%bottom_thermal_snapshot()
      ! The snapshot is now local to this transaction call. Clear backend
      ! scratch immediately so a later trial cannot observe or reuse it.
      call backend%set_bottom_thermal_carrier_enabled(.false.)
    end if

    output%kernel_status = kernel_result%status
    output%mass = kernel_result%mass
    diagnostic%attempts = kernel_diag%attempts
    diagnostic%retries = kernel_diag%retries
    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
    candidate_ready = candidate%ready()

    if (kernel_diag%admission_rejections > 0 .or. kernel_result%status == KERNEL_STATUS_NOT_ADMITTED) then
      output%admission_assessed = .true.
      output%admitted = .false.
      output%admission_status = 'PHYSICAL_PROFILE_REJECTED'
    else if (kernel_diag%transaction_calls > 0 .or. kernel_result%completed) then
      output%admission_assessed = .true.
      output%admitted = .true.
      output%admission_status = 'ADMITTED'
    else
      output%admission_status = 'PRE_ADMISSION_REJECTED'
    end if

    if (kernel_diag%transaction_calls > 0) then
      observation = backend%observation()
      output%solver_executed = observation%solver_executed
      output%solver_route = observation%solver_diagnostics%route
      output%solver_iterations = observation%solver_diagnostics%nonlinear_iterations
      if (output%solver_executed) then
        runtime%max_simultaneous_real_physical_solves = max( &
             runtime%max_simultaneous_real_physical_solves, simultaneous_physical_calls)
      end if
    end if
    !$omp atomic update
    active_physical_calls = active_physical_calls - 1
    !$omp end atomic

    if (.not. kernel_result%completed) then
      if (candidate_ready) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'KERNEL_REJECTED'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    if (.not. kernel_result%mass%complete .or. &
        kernel_result%mass%missing_contribution_mask /= TX_MASS_MISSING_NONE) then
      if (candidate_ready) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'MASS_INCOMPLETE'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    if (.not. candidate_ready) then
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CANDIDATE_INVALID'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    if (energy_requested) then
      call prepare_candidate_bound_bottom_energy(column%column_id, candidate, thermal_candidate, &
           bottom_energy_parameters, bottom_thermal_provider, prepared_bottom_energy)
    end if

    if (energy_requested) then
      if (present(commit_receipt)) then
        call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
             kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
      else
        call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
             kernel_diag, did_commit, local_energy_receipt, receipt_status, commit_status)
      end if
    else if (present(commit_receipt)) then
      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
    else
      receipt_status = FMR_COMMIT_RECEIPT_OK
      call fmr_commit_candidate(transaction_control, committed_state, candidate, kernel_diag, &
           did_commit, commit_status)
    end if
    output%commit_status = commit_status
    if (.not. did_commit) then
      diagnostic%rejected = 1
      if (receipt_path .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then
        if (candidate%ready()) call fmr_discard_candidate(transaction_control, candidate, kernel_diag)
        diagnostic%failure_classification = 'RECEIPT_PREVALIDATION_REJECTED'
      else
        diagnostic%failure_classification = 'COMMIT_REJECTED'
      end if
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if
    if (present(commit_receipt)) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. commit_receipt%ready()) &
           error stop 'F-MR18: successful physical commit without ready accepted receipt'
    else if (energy_requested) then
      if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. local_energy_receipt%ready()) &
           error stop 'EB-I18: successful energy-path commit without ready accepted receipt'
    end if

    if (energy_requested) then
      if (present(commit_receipt)) then
        call finalize_bottom_energy_publication(column%column_id, prepared_bottom_energy, commit_receipt, &
             bottom_energy_publication)
      else
        call finalize_bottom_energy_publication(column%column_id, prepared_bottom_energy, local_energy_receipt, &
             bottom_energy_publication)
      end if
    end if

    call bind_committed_actual_transpiration(parameters, effective_forcing, t0, t1, output)
    output%completed = .true.
    output%committed = .true.
    diagnostic%accepted = 1
    diagnostic%failure_classification = 'NONE'
    diagnostic%unrounded_mass_residual = output%mass%residual
    call update_committed_provenance(committed_state, output, diagnostic)
  end subroutine execute_resolved_column

  subroutine prepare_candidate_bound_bottom_energy(column_id, candidate, thermal_candidate, energy_parameters, &
       external_temperature_provider, prepared)
    integer(int64), intent(in) :: column_id
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(fmr_bottom_thermal_candidate_t), intent(in) :: thermal_candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: energy_parameters
    procedure(fmr_external_bottom_thermal_provider_i) :: external_temperature_provider
    type(fmr_prepared_bottom_energy_publication_t), intent(out) :: prepared

    type(fmr_bottom_external_thermal_binding_bundle_t) :: bindings
    type(fmr_bottom_thermal_sample_t) :: sample
    type(fmr_external_bottom_thermal_request_t) :: request
    type(fmr_external_bottom_thermal_response_t) :: response
    type(fmr_bottom_sensible_energy_result_t) :: energy_result
    real(real64) :: candidate_t0, candidate_t1, thermal_t0, thermal_t1, donor_temperature_c
    integer(int64) :: provenance_token
    integer :: i, external_count, binding_status
    logical :: candidate_interval_available, thermal_interval_available, sample_available, ok, temperature_available

    prepared = fmr_prepared_bottom_energy_publication_t()
    if (.not. candidate%ready()) return
    call candidate%origin_interval(candidate_t0, candidate_t1, candidate_interval_available)
    if (.not. candidate_interval_available) return
    if (candidate%current_lineage_id() <= 0_int64 .or. candidate%origin_revision() < 0_int64) return
    if (.not. ieee_is_finite(candidate_t0) .or. .not. ieee_is_finite(candidate_t1) .or. candidate_t1 <= candidate_t0) return

    prepared%lineage_id = candidate%current_lineage_id()
    prepared%origin_revision_value = candidate%origin_revision()
    prepared%t0_value = candidate_t0
    prepared%t1_value = candidate_t1
    prepared%initialized = .true.

    if (.not. thermal_candidate%ready()) then
      call evaluate_fmr_bottom_sensible_energy(thermal_candidate, energy_parameters, energy_result)
      call capture_bottom_energy_result(energy_result, prepared)
      return
    end if
    call thermal_candidate%interval(thermal_t0, thermal_t1, thermal_interval_available)
    if (.not. thermal_interval_available .or. .not. same_time_value(thermal_t0, candidate_t0) .or. &
        .not. same_time_value(thermal_t1, candidate_t1)) then
      prepared%energy_status_value = FMR_BOTTOM_ENERGY_INVALID_CANDIDATE
      return
    end if

    external_count = 0
    do i = 1, thermal_candidate%sample_count()
      call thermal_candidate%sample_at(i, sample, sample_available)
      if (.not. sample_available) cycle
      if (sample%donor_class == FMR_BOTTOM_THERMAL_DONOR_EXTERNAL) external_count = external_count + 1
    end do

    call bindings%initialize(candidate%current_lineage_id(), external_count, ok)
    if (.not. ok) then
      prepared%energy_status_value = FMR_BOTTOM_ENERGY_INVALID_CANDIDATE
      return
    end if

    do i = 1, thermal_candidate%sample_count()
      call thermal_candidate%sample_at(i, sample, sample_available)
      if (.not. sample_available) cycle
      if (sample%donor_class /= FMR_BOTTOM_THERMAL_DONOR_EXTERNAL) cycle

      prepared%provider_request_count_value = prepared%provider_request_count_value + 1
      call initialize_fmr_external_bottom_thermal_request(column_id, i, sample%t0, sample%t1, &
           sample%bottom_outward_exchange_native, request, ok)
      if (.not. ok) then
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
        cycle
      end if

      call external_temperature_provider(request, response)
      if (.not. response%ready() .or. .not. response%identity_matches(request)) then
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
        cycle
      end if

      select case (response%disposition())
      case (FMR_EXT_THERMAL_RESPONSE_COMPLETE)
        call response%donor_temperature(donor_temperature_c, temperature_available)
        if (.not. temperature_available) then
          prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
          cycle
        end if
        provenance_token = response%source_provenance_token()
        call bindings%append(i, donor_temperature_c, provenance_token, binding_status)
        if (binding_status /= FMR_EXT_THERMAL_BINDING_OK) then
          prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
          cycle
        end if
        prepared%provider_complete_count_value = prepared%provider_complete_count_value + 1
      case (FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE)
        prepared%provider_unavailable_count_value = prepared%provider_unavailable_count_value + 1
      case (FMR_EXT_THERMAL_RESPONSE_STALE)
        prepared%provider_stale_count_value = prepared%provider_stale_count_value + 1
      case default
        prepared%provider_invalid_count_value = prepared%provider_invalid_count_value + 1
      end select
    end do

    call evaluate_fmr_bottom_sensible_energy_with_external(thermal_candidate, candidate%current_lineage_id(), &
         bindings, energy_parameters, energy_result)
    call capture_bottom_energy_result(energy_result, prepared)
  end subroutine prepare_candidate_bound_bottom_energy

  subroutine capture_bottom_energy_result(energy_result, prepared)
    type(fmr_bottom_sensible_energy_result_t), intent(in) :: energy_result
    type(fmr_prepared_bottom_energy_publication_t), intent(inout) :: prepared
    real(real64) :: value
    logical :: available

    prepared%energy_status_value = energy_result%status()
    call energy_result%total_energy(value, available)
    prepared%total_available_value = available
    if (available) prepared%total_energy_j_m2_value = value
    call energy_result%local_outward_subtotal(value, available)
    prepared%local_subtotal_available_value = available
    if (available) prepared%local_subtotal_j_m2_value = value
  end subroutine capture_bottom_energy_result

  subroutine finalize_bottom_energy_publication(column_id, prepared, receipt, publication)
    integer(int64), intent(in) :: column_id
    type(fmr_prepared_bottom_energy_publication_t), intent(in) :: prepared
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    type(fmr_serialized_bottom_energy_publication_t), intent(out) :: publication
    real(real64) :: receipt_t0, receipt_t1
    logical :: interval_available

    publication = fmr_serialized_bottom_energy_publication_t()
    if (.not. prepared%ready()) error stop 'EB-I18: accepted candidate has invalid local prepared energy provenance'
    if (.not. receipt%ready()) error stop 'EB-I18: accepted candidate has no ready receipt for energy publication'
    call receipt%origin_interval(receipt_t0, receipt_t1, interval_available)
    if (.not. interval_available) error stop 'EB-I18: accepted receipt interval unavailable'
    if (receipt%current_lineage_id() /= prepared%lineage_id .or. &
        receipt%origin_revision() /= prepared%origin_revision_value .or. &
        receipt%committed_revision() /= prepared%origin_revision_value + 1_int64 .or. &
        .not. same_time_value(receipt_t0, prepared%t0_value) .or. &
        .not. same_time_value(receipt_t1, prepared%t1_value)) &
         error stop 'EB-I18: local prepared energy and accepted receipt provenance mismatch'

    publication%column_id_value = column_id
    publication%lineage_id = prepared%lineage_id
    publication%origin_revision_value = prepared%origin_revision_value
    publication%committed_revision_value = receipt%committed_revision()
    publication%t0_value = prepared%t0_value
    publication%t1_value = prepared%t1_value
    publication%energy_status_value = prepared%energy_status_value
    publication%total_available_value = prepared%total_available_value
    publication%total_energy_j_m2_value = prepared%total_energy_j_m2_value
    publication%local_subtotal_available_value = prepared%local_subtotal_available_value
    publication%local_subtotal_j_m2_value = prepared%local_subtotal_j_m2_value
    publication%provider_request_count_value = prepared%provider_request_count_value
    publication%provider_complete_count_value = prepared%provider_complete_count_value
    publication%provider_unavailable_count_value = prepared%provider_unavailable_count_value
    publication%provider_stale_count_value = prepared%provider_stale_count_value
    publication%provider_invalid_count_value = prepared%provider_invalid_count_value
    publication%initialized = .true.
    if (.not. publication%ready()) error stop 'EB-I18: accepted energy publication postcondition failed'
  end subroutine finalize_bottom_energy_publication

  logical function prepared_bottom_energy_ready(self) result(ready)
    class(fmr_prepared_bottom_energy_publication_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         self%provider_request_count_value >= 0 .and. self%provider_complete_count_value >= 0 .and. &
         self%provider_unavailable_count_value >= 0 .and. self%provider_stale_count_value >= 0 .and. &
         self%provider_invalid_count_value >= 0 .and. &
         self%provider_complete_count_value + self%provider_unavailable_count_value + self%provider_stale_count_value + &
         self%provider_invalid_count_value == self%provider_request_count_value
    if (.not. ready) return
    if (self%total_available_value) ready = ieee_is_finite(self%total_energy_j_m2_value)
    if (ready .and. self%local_subtotal_available_value) ready = ieee_is_finite(self%local_subtotal_j_m2_value)
  end function prepared_bottom_energy_ready

  logical function bottom_energy_publication_ready(self) result(ready)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    ready = self%initialized .and. self%column_id_value > 0_int64 .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         self%provider_complete_count_value + self%provider_unavailable_count_value + self%provider_stale_count_value + &
         self%provider_invalid_count_value == self%provider_request_count_value
    if (.not. ready) return
    if (self%total_available_value) ready = ieee_is_finite(self%total_energy_j_m2_value)
    if (ready .and. self%local_subtotal_available_value) ready = ieee_is_finite(self%local_subtotal_j_m2_value)
  end function bottom_energy_publication_ready

  integer(int64) function bottom_energy_publication_column_id(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%column_id_value
  end function bottom_energy_publication_column_id

  integer(int64) function bottom_energy_publication_lineage_id(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%lineage_id
  end function bottom_energy_publication_lineage_id

  integer(int64) function bottom_energy_publication_origin_revision(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%origin_revision_value
  end function bottom_energy_publication_origin_revision

  integer(int64) function bottom_energy_publication_committed_revision(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%committed_revision_value
  end function bottom_energy_publication_committed_revision

  subroutine bottom_energy_publication_origin_interval(self, t0, t1, available)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    available = self%ready()
    t0 = 0.0_real64
    t1 = 0.0_real64
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    end if
  end subroutine bottom_energy_publication_origin_interval

  integer function bottom_energy_publication_energy_status(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = FMR_BOTTOM_ENERGY_NOT_EVALUATED
    if (self%ready()) value = self%energy_status_value
  end function bottom_energy_publication_energy_status

  logical function bottom_energy_publication_complete(self) result(value)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    value = self%ready() .and. self%total_available_value
  end function bottom_energy_publication_complete

  subroutine bottom_energy_publication_total_energy(self, value, available)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available
    available = self%ready() .and. self%total_available_value
    value = 0.0_real64
    if (available) value = self%total_energy_j_m2_value
  end subroutine bottom_energy_publication_total_energy

  subroutine bottom_energy_publication_local_subtotal(self, value, available)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available
    available = self%ready() .and. self%local_subtotal_available_value
    value = 0.0_real64
    if (available) value = self%local_subtotal_j_m2_value
  end subroutine bottom_energy_publication_local_subtotal

  subroutine bottom_energy_publication_provider_counts(self, requested, complete, unavailable, stale, invalid)
    class(fmr_serialized_bottom_energy_publication_t), intent(in) :: self
    integer, intent(out) :: requested, complete, unavailable, stale, invalid
    requested = 0
    complete = 0
    unavailable = 0
    stale = 0
    invalid = 0
    if (.not. self%ready()) return
    requested = self%provider_request_count_value
    complete = self%provider_complete_count_value
    unavailable = self%provider_unavailable_count_value
    stale = self%provider_stale_count_value
    invalid = self%provider_invalid_count_value
  end subroutine bottom_energy_publication_provider_counts

  pure logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    matches = ia == ib
  end function same_time_value

  subroutine bind_committed_actual_transpiration(parameters, forcing, t0, t1, output)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), intent(inout) :: output
    real(real64) :: amount

    output%actual_transpiration_available = .false.
    output%actual_transpiration_amount = 0.0_real64

    if (.not. parameters%root_extraction_active) return
    if (parameters%active_nodes <= 0) return
    if (.not. allocated(forcing%root_extraction_sink)) return
    if (size(forcing%root_extraction_sink) /= parameters%active_nodes) return
    if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
    if (any(forcing%root_extraction_sink < 0.0_real64)) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    amount = sum(forcing%root_extraction_sink) * (t1 - t0)
    if (.not. ieee_is_finite(amount) .or. amount < 0.0_real64) return

    output%actual_transpiration_amount = amount
    output%actual_transpiration_available = .true.
  end subroutine bind_committed_actual_transpiration

  logical function column_is_routable(column, templates, parameter_registry, forcing_registry) result(routable)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: templates(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameter_registry(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_registry(:)
    integer :: template_index

    template_index = find_template_index(column%template_id, templates)
    routable = template_index > 0 .and. column%backend_id == FMR_BACKEND_SERIALIZED_REFERENCE .and. &
         column%parameter_ref >= 1_int64 .and. &
         column%parameter_ref <= int(size(parameter_registry), int64) .and. &
         column%forcing_handle >= 1_int64 .and. &
         column%forcing_handle <= int(size(forcing_registry), int64)
    if (routable) routable = templates(template_index)%compatible_backend_id == FMR_BACKEND_SERIALIZED_REFERENCE
  end function column_is_routable

  logical function resolved_column_is_routable(column, template) result(routable)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template

    routable = column%backend_id == FMR_BACKEND_SERIALIZED_REFERENCE .and. &
         template%template_id == column%template_id .and. &
         template%compatible_backend_id == FMR_BACKEND_SERIALIZED_REFERENCE
  end function resolved_column_is_routable

  integer function find_template_index(template_id, templates) result(index)
    integer(int64), intent(in) :: template_id
    type(fmr_template_t), intent(in) :: templates(:)
    integer :: i

    index = 0
    do i = 1, size(templates)
      if (templates(i)%template_id == template_id) then
        index = i
        return
      end if
    end do
  end function find_template_index

  subroutine update_committed_provenance_by_handle(column, states, output, diagnostic)
    type(fmr_logical_column_t), intent(in) :: column
    type(kernel_committed_state_t), intent(in) :: states(:)
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    integer :: state_index

    if (column%state_handle < 1_int64 .or. column%state_handle > int(size(states), int64)) return
    state_index = int(column%state_handle)
    call update_committed_provenance(states(state_index), output, diagnostic)
  end subroutine update_committed_provenance_by_handle

  subroutine update_committed_provenance(committed, output, diagnostic)
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    logical :: available

    output%final_revision = committed%current_revision()
    call committed%current_time(output%final_committed_time, available)
    output%final_committed_time_bound = available
    diagnostic%committed_revision = output%final_revision
    diagnostic%committed_time = output%final_committed_time
    diagnostic%committed_time_bound = available
  end subroutine update_committed_provenance

  subroutine mark_all_rejected(diagnostics, classification)
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostics(:)
    character(len=*), intent(in) :: classification
    integer :: i

    do i = 1, size(diagnostics)
      diagnostics(i)%rejected = 1
      diagnostics(i)%failure_classification = classification
    end do
  end subroutine mark_all_rejected

  subroutine build_aggregate(columns, diagnostics, batches, aggregate, execution_order)
    type(fmr_logical_column_t), intent(in) :: columns(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    integer, intent(in) :: batches
    type(fmr_aggregate_diagnostics_t), intent(inout) :: aggregate
    integer, intent(in), optional :: execution_order(:)
    integer, allocatable :: local_order(:)
    integer :: pos, i

    aggregate = fmr_aggregate_diagnostics_t()
    aggregate%columns = size(columns)
    aggregate%templates = fmr_count_templates(columns)
    aggregate%batches = batches
    aggregate%workers = 1
    allocate(aggregate%work_distribution(1))
    aggregate%work_distribution = 0_int64

    allocate(local_order(size(columns)))
    if (present(execution_order)) then
      local_order = execution_order
    else
      do i = 1, size(columns)
        local_order(i) = i
      end do
    end if

    do pos = 1, size(local_order)
      i = local_order(pos)
      aggregate%attempts = aggregate%attempts + diagnostics(i)%attempts
      aggregate%retries = aggregate%retries + diagnostics(i)%retries
      if (diagnostics(i)%accepted == 0) aggregate%failures = aggregate%failures + 1
      if (diagnostics(i)%accepted == 1) then
        aggregate%aggregate_unrounded_mass_residual = aggregate%aggregate_unrounded_mass_residual + &
             diagnostics(i)%unrounded_mass_residual
      end if
    end do
    aggregate%work_distribution(1) = int(aggregate%attempts, int64)
  end subroutine build_aggregate

  subroutine finalize_runtime_diagnostics(results, runtime, execution_order)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(in), optional :: execution_order(:)
    integer, allocatable :: local_order(:)
    integer :: pos, i
    logical :: aggregate_complete

    runtime%number_admitted = 0
    runtime%number_executed = 0
    runtime%number_committed = 0
    runtime%number_rejected = 0
    runtime%physical_solve_count = 0
    runtime%max_abs_column_mass_residual = 0.0_real64
    runtime%authoritative_aggregate_mass%complete = .false.
    runtime%authoritative_aggregate_mass%origin_lineage_id = 0_int64
    runtime%authoritative_aggregate_mass%origin_revision = -1_int64
    runtime%authoritative_aggregate_mass%accepted_transaction_count = 0
    runtime%authoritative_aggregate_mass%storage_start = 0.0_real64
    runtime%authoritative_aggregate_mass%storage_end = 0.0_real64
    runtime%authoritative_aggregate_mass%storage_change = 0.0_real64
    runtime%authoritative_aggregate_mass%total_in = 0.0_real64
    runtime%authoritative_aggregate_mass%total_out = 0.0_real64
    runtime%authoritative_aggregate_mass%residual = 0.0_real64
    aggregate_complete = .true.

    allocate(local_order(size(results)))
    if (present(execution_order)) then
      local_order = execution_order
    else
      do i = 1, size(results)
        local_order(i) = i
      end do
    end if

    do pos = 1, size(local_order)
      i = local_order(pos)
      if (results(i)%admitted) runtime%number_admitted = runtime%number_admitted + 1
      if (results(i)%solver_executed) then
        runtime%number_executed = runtime%number_executed + 1
        runtime%physical_solve_count = runtime%physical_solve_count + 1
      end if
      if (results(i)%committed) then
        runtime%number_committed = runtime%number_committed + 1
        aggregate_complete = aggregate_complete .and. results(i)%mass%complete .and. &
             results(i)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE
        runtime%authoritative_aggregate_mass%accepted_transaction_count = &
             runtime%authoritative_aggregate_mass%accepted_transaction_count + &
             results(i)%mass%accepted_transaction_count
        runtime%authoritative_aggregate_mass%storage_start = runtime%authoritative_aggregate_mass%storage_start + &
             results(i)%mass%storage_start
        runtime%authoritative_aggregate_mass%storage_end = runtime%authoritative_aggregate_mass%storage_end + &
             results(i)%mass%storage_end
        runtime%authoritative_aggregate_mass%storage_change = runtime%authoritative_aggregate_mass%storage_change + &
             results(i)%mass%storage_change
        runtime%authoritative_aggregate_mass%total_in = runtime%authoritative_aggregate_mass%total_in + &
             results(i)%mass%total_in
        runtime%authoritative_aggregate_mass%total_out = runtime%authoritative_aggregate_mass%total_out + &
             results(i)%mass%total_out
        runtime%authoritative_aggregate_mass%residual = runtime%authoritative_aggregate_mass%residual + &
             results(i)%mass%residual
        runtime%max_abs_column_mass_residual = max(runtime%max_abs_column_mass_residual, abs(results(i)%mass%residual))
      else
        runtime%number_rejected = runtime%number_rejected + 1
      end if
    end do

    if (runtime%number_committed > 0 .and. aggregate_complete) then
      runtime%authoritative_aggregate_mass%complete = .true.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_NONE
    else
      runtime%authoritative_aggregate_mass%complete = .false.
      runtime%authoritative_aggregate_mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    end if
  end subroutine finalize_runtime_diagnostics

end module mod_fmr_serialized_multiswap_runtime
