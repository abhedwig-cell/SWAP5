from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
expected_blob = 'f06a2eef7b47880e449cf9b201342d7bd1e197e1'
actual_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual_blob != expected_blob:
    raise SystemExit(f'EB-I18 runtime blob precondition failed: {actual_blob} != {expected_blob}')

text = path.read_text()

def once(old: str, new: str, label: str) -> None:
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'EB-I18 patch anchor {label!r} matched {n} times')
    text = text.replace(old, new, 1)

once(
"""  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_serialized_physical_observation_t
""",
"""  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
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
""",
'use imports')

once(
"""  type, public :: fmr_serialized_commit_receipt_record_t
    integer(int64) :: column_id = 0_int64
    type(fmr_accepted_commit_receipt_t) :: receipt
  end type fmr_serialized_commit_receipt_record_t

""",
"""  type, public :: fmr_serialized_commit_receipt_record_t
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

""",
'type declarations')

once(
"""  public :: fmr_run_serialized_physical_multiswap
  public :: fmr_execute_serialized_physical_column
  public :: fmr_execute_serialized_resolved_physical_column
""",
"""  public :: fmr_run_serialized_physical_multiswap
  public :: fmr_execute_serialized_physical_column
  public :: fmr_execute_serialized_resolved_physical_column
  public :: fmr_execute_serialized_resolved_physical_column_with_bottom_energy
""",
'public entrypoint')

marker = "  subroutine initialize_outputs(columns, t0, t1, results, diagnostics, aggregate)\n"
new_entry = r'''  ! Opt-in worker-level energy publication seam. The exact thermal candidate,
  ! provider resolution, energy preparation and physical candidate all remain
  ! inside the existing private transaction owner. No caller-created binding
  ! bundle or prepared result crosses this boundary.
  subroutine fmr_execute_serialized_resolved_physical_column_with_bottom_energy(backend, transaction_control, column, &
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
  end subroutine fmr_execute_serialized_resolved_physical_column_with_bottom_energy

'''
if text.count(marker) != 1:
    raise SystemExit('EB-I18 initialize_outputs marker mismatch')
text = text.replace(marker, new_entry + marker, 1)

once(
"""  subroutine execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
                                     committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
                                     active_physical_calls, commit_receipt)
""",
"""  subroutine execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
                                     committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
                                     active_physical_calls, commit_receipt, bottom_energy_parameters, &
                                     bottom_thermal_provider, bottom_energy_publication)
""",
'execute signature')

once(
"""    integer, intent(inout) :: active_physical_calls
    type(fmr_accepted_commit_receipt_t), intent(inout), optional :: commit_receipt

    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: kernel_result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: kernel_diag
    type(fmr_serialized_physical_observation_t) :: observation
    integer :: commit_status, receipt_status, simultaneous_physical_calls
    logical :: checkpoint_ok, candidate_ready, did_commit
""",
"""    integer, intent(inout) :: active_physical_calls
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
""",
'execute declarations')

once(
"""    output%initial_revision = committed_state%current_revision()

    call fmr_capture_checkpoint(committed_state, checkpoint, checkpoint_ok)
""",
"""    output%initial_revision = committed_state%current_revision()
    energy_requested = present(bottom_energy_parameters) .and. present(bottom_thermal_provider) .and. &
         present(bottom_energy_publication)
    if (present(bottom_energy_parameters) .or. present(bottom_thermal_provider) .or. present(bottom_energy_publication)) then
      if (.not. energy_requested) error stop 'EB-I18: partial bottom-energy transaction request'
    end if
    receipt_path = present(commit_receipt) .or. energy_requested
    if (present(bottom_energy_publication)) bottom_energy_publication = fmr_serialized_bottom_energy_publication_t()
    thermal_candidate = fmr_bottom_thermal_candidate_t()
    prepared_bottom_energy = fmr_prepared_bottom_energy_publication_t()

    call fmr_capture_checkpoint(committed_state, checkpoint, checkpoint_ok)
""",
'execute initialization')

once(
"""    !$omp end atomic
    call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
         numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)

    output%kernel_status = kernel_result%status
""",
"""    !$omp end atomic
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
""",
'run trial thermal capture')

once(
"""    if (.not. candidate_ready) then
      diagnostic%rejected = 1
      diagnostic%failure_classification = 'CANDIDATE_INVALID'
      call update_committed_provenance(committed_state, output, diagnostic)
      return
    end if

    if (present(commit_receipt)) then
      call fmr_commit_candidate_with_receipt(transaction_control, checkpoint, committed_state, candidate, &
           kernel_diag, did_commit, commit_receipt, receipt_status, commit_status)
    else
      receipt_status = FMR_COMMIT_RECEIPT_OK
      call fmr_commit_candidate(transaction_control, committed_state, candidate, kernel_diag, &
           did_commit, commit_status)
    end if
""",
"""    if (.not. candidate_ready) then
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
""",
'prepare and commit')

once(
"""    if (.not. did_commit) then
      diagnostic%rejected = 1
      if (present(commit_receipt) .and. receipt_status /= FMR_COMMIT_RECEIPT_COMMIT_REJECTED) then
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
    end if

    call bind_committed_actual_transpiration(parameters, effective_forcing, t0, t1, output)
""",
"""    if (.not. did_commit) then
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
""",
'commit result and publication')

helpers_marker = "  subroutine bind_committed_actual_transpiration(parameters, forcing, t0, t1, output)\n"
helpers = r'''  subroutine prepare_candidate_bound_bottom_energy(column_id, candidate, thermal_candidate, energy_parameters, &
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

'''
if text.count(helpers_marker) != 1:
    raise SystemExit('EB-I18 helper insertion marker mismatch')
text = text.replace(helpers_marker, helpers + helpers_marker, 1)

path.write_text(text)
new_blob = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
print(f'EB_I18_RUNTIME_PATCH_OK old={expected_blob} new={new_blob}')
