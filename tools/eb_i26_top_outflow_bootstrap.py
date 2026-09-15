from pathlib import Path
import json

ROOT = Path('.')


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one replacement, found {count}')
    p.write_text(text.replace(old, new, 1))

# 1. Extend the already-transactional top carrier with explicit local donor provenance.
replace_once(
    'src/runtime/mod_fmr_top_sensible_boundary_carrier.f90',
    """    real(real64) :: energy_residual_j_cm2 = 0.0_real64\n  end type fmr_top_sensible_boundary_sample_t\n""",
    """    real(real64) :: energy_residual_j_cm2 = 0.0_real64\n    ! EB-I26 local soil-side donor provenance for accepted top-water outflow.\n    ! The external prescribed surface temperature is never a substitute.\n    logical :: local_outflow_donor_available = .false.\n    real(real64) :: local_outflow_start_temperature_c = 0.0_real64\n    real(real64) :: local_outflow_end_temperature_c = 0.0_real64\n  end type fmr_top_sensible_boundary_sample_t\n"""
)
replace_once(
    'src/runtime/mod_fmr_top_sensible_boundary_carrier.f90',
    """  subroutine carrier_append(self, t0, t1, top_exchange_native, thermal_accounting_complete, &\n       boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2, ok)\n    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self\n    real(real64), intent(in) :: t0, t1, top_exchange_native\n    logical, intent(in) :: thermal_accounting_complete\n    real(real64), intent(in) :: boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2\n    logical, intent(out) :: ok\n    type(fmr_top_sensible_boundary_sample_t) :: sample\n\n    sample%t0 = t0\n    sample%t1 = t1\n    sample%top_exchange_native = top_exchange_native\n    sample%thermal_accounting_complete = thermal_accounting_complete\n    sample%boundary_energy_into_soil_j_cm2 = boundary_energy_into_soil_j_cm2\n    sample%storage_change_j_cm2 = storage_change_j_cm2\n    sample%energy_residual_j_cm2 = energy_residual_j_cm2\n\n    ok = .false.\n    if (.not. self%initialized .or. .not. allocated(self%samples)) return\n""",
    """  subroutine carrier_append(self, t0, t1, top_exchange_native, thermal_accounting_complete, &\n       boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2, ok, &\n       local_outflow_donor_available, local_outflow_start_temperature_c, local_outflow_end_temperature_c)\n    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self\n    real(real64), intent(in) :: t0, t1, top_exchange_native\n    logical, intent(in) :: thermal_accounting_complete\n    real(real64), intent(in) :: boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2\n    logical, intent(out) :: ok\n    logical, intent(in), optional :: local_outflow_donor_available\n    real(real64), intent(in), optional :: local_outflow_start_temperature_c, local_outflow_end_temperature_c\n    type(fmr_top_sensible_boundary_sample_t) :: sample\n\n    ok = .false.\n    sample%t0 = t0\n    sample%t1 = t1\n    sample%top_exchange_native = top_exchange_native\n    sample%thermal_accounting_complete = thermal_accounting_complete\n    sample%boundary_energy_into_soil_j_cm2 = boundary_energy_into_soil_j_cm2\n    sample%storage_change_j_cm2 = storage_change_j_cm2\n    sample%energy_residual_j_cm2 = energy_residual_j_cm2\n    if (present(local_outflow_donor_available) .or. present(local_outflow_start_temperature_c) .or. &\n        present(local_outflow_end_temperature_c)) then\n      if (.not. present(local_outflow_donor_available) .or. .not. present(local_outflow_start_temperature_c) .or. &\n          .not. present(local_outflow_end_temperature_c)) return\n      sample%local_outflow_donor_available = local_outflow_donor_available\n      if (sample%local_outflow_donor_available) then\n        sample%local_outflow_start_temperature_c = local_outflow_start_temperature_c\n        sample%local_outflow_end_temperature_c = local_outflow_end_temperature_c\n      end if\n    end if\n\n    if (.not. self%initialized .or. .not. allocated(self%samples)) return\n"""
)
replace_once(
    'src/runtime/mod_fmr_top_sensible_boundary_carrier.f90',
    """    valid = ieee_is_finite(identity) .and. abs(identity) <= 256.0_real64 * epsilon(1.0_real64) * scale\n  end function sample_is_valid\n""",
    """    valid = ieee_is_finite(identity) .and. abs(identity) <= 256.0_real64 * epsilon(1.0_real64) * scale\n    if (.not. valid) return\n    if (sample%local_outflow_donor_available) then\n      valid = sample%top_exchange_native > 0.0_real64 .and. &\n           ieee_is_finite(sample%local_outflow_start_temperature_c) .and. &\n           ieee_is_finite(sample%local_outflow_end_temperature_c)\n    end if\n  end function sample_is_valid\n"""
)

# 2. Capture node-1 donor temperature on the same transactional trajectory as the carrier.
replace_once(
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    """    real(real64) :: step_duration, bottom_temperature_start_c\n    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok\n    logical :: bottom_temperature_start_available\n    integer :: soil_temperature_status, bottom_temperature_status\n""",
    """    real(real64) :: step_duration, bottom_temperature_start_c, top_temperature_start_c\n    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok, hydraulic_view_ok\n    logical :: bottom_temperature_start_available, top_temperature_start_available\n    integer :: soil_temperature_status, bottom_temperature_status, top_temperature_status\n"""
)
replace_once(
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    """    bottom_temperature_start_c = 0.0_real64\n    bottom_temperature_start_available = .false.\n""",
    """    bottom_temperature_start_c = 0.0_real64\n    bottom_temperature_start_available = .false.\n    top_temperature_start_c = 0.0_real64\n    top_temperature_start_available = .false.\n"""
)
replace_once(
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    """        if (self%bottom_thermal_carrier_active) then\n          call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, bottom_temperature_start_c, &\n               bottom_temperature_status)\n          bottom_temperature_start_available = bottom_temperature_status == SOIL_TEMP_OK\n        end if\n""",
    """        if (self%bottom_thermal_carrier_active) then\n          call soil_temperature_at_node(physical%soil_temperature, physical%active_nodes, bottom_temperature_start_c, &\n               bottom_temperature_status)\n          bottom_temperature_start_available = bottom_temperature_status == SOIL_TEMP_OK\n        end if\n        if (self%top_sensible_boundary_carrier_active) then\n          call soil_temperature_at_node(physical%soil_temperature, 1, top_temperature_start_c, top_temperature_status)\n          top_temperature_start_available = top_temperature_status == SOIL_TEMP_OK\n        end if\n"""
)
replace_once(
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    """    if (self%top_sensible_boundary_carrier_active .and. self%top_sensible_boundary_carrier_valid) then\n      call record_top_sensible_boundary_sample(self, t0, t1, solve_result%top_flux * step_duration)\n    end if\n""",
    """    if (self%top_sensible_boundary_carrier_active .and. self%top_sensible_boundary_carrier_valid) then\n      call record_top_sensible_boundary_sample(self, state, t0, t1, solve_result%top_flux * step_duration, &\n           top_temperature_start_c, top_temperature_start_available)\n    end if\n"""
)
replace_once(
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    """  subroutine record_top_sensible_boundary_sample(self, t0, t1, top_exchange_native)\n    class(fmr_serialized_reference_model_t), intent(inout) :: self\n    real(real64), intent(in) :: t0, t1, top_exchange_native\n    logical :: appended\n\n    if (.not. self%top_sensible_boundary_carrier_active .or. &\n        .not. self%top_sensible_boundary_carrier_valid) return\n    call self%top_sensible_boundary_carrier%append(t0, t1, top_exchange_native, &\n         self%last_observation%soil_temperature_energy_accounting_complete, &\n         self%last_observation%soil_temperature_boundary_energy_j_cm2, &\n         self%last_observation%soil_temperature_storage_change_j_cm2, &\n         self%last_observation%soil_temperature_energy_residual_j_cm2, appended)\n    if (.not. appended) self%top_sensible_boundary_carrier_valid = .false.\n  end subroutine record_top_sensible_boundary_sample\n""",
    """  subroutine record_top_sensible_boundary_sample(self, state, t0, t1, top_exchange_native, &\n                                                        start_temperature_c, start_temperature_available)\n    class(fmr_serialized_reference_model_t), intent(inout) :: self\n    class(transaction_state_t), intent(in) :: state\n    real(real64), intent(in) :: t0, t1, top_exchange_native, start_temperature_c\n    logical, intent(in) :: start_temperature_available\n    real(real64) :: end_temperature_c\n    integer :: temperature_status\n    logical :: appended, donor_available\n\n    if (.not. self%top_sensible_boundary_carrier_active .or. &\n        .not. self%top_sensible_boundary_carrier_valid) return\n    donor_available = .false.\n    end_temperature_c = 0.0_real64\n    if (top_exchange_native > 0.0_real64 .and. start_temperature_available) then\n      select type (physical => state)\n      class is (fmr_b110_physical_state_t)\n        if (allocated(physical%soil_temperature)) then\n          call soil_temperature_at_node(physical%soil_temperature, 1, end_temperature_c, temperature_status)\n          donor_available = temperature_status == SOIL_TEMP_OK\n        end if\n      class default\n        donor_available = .false.\n      end select\n    end if\n    call self%top_sensible_boundary_carrier%append(t0, t1, top_exchange_native, &\n         self%last_observation%soil_temperature_energy_accounting_complete, &\n         self%last_observation%soil_temperature_boundary_energy_j_cm2, &\n         self%last_observation%soil_temperature_storage_change_j_cm2, &\n         self%last_observation%soil_temperature_energy_residual_j_cm2, appended, &\n         local_outflow_donor_available=donor_available, &\n         local_outflow_start_temperature_c=start_temperature_c, &\n         local_outflow_end_temperature_c=end_temperature_c)\n    if (.not. appended) self%top_sensible_boundary_carrier_valid = .false.\n  end subroutine record_top_sensible_boundary_sample\n"""
)

# 3. Let the successor consume I25's accepted carrier without changing I25 semantics.
replace_once(
    'src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90',
    """       external_bottom_temperature_provider, top_temperature, output, diagnostic, runtime, active_physical_calls, &\n       publication)\n""",
    """       external_bottom_temperature_provider, top_temperature, output, diagnostic, runtime, active_physical_calls, &\n       publication, accepted_top_candidate)\n"""
)
replace_once(
    'src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90',
    """    type(eb_i25_sensible_boundary_publication_t), intent(out) :: publication\n\n    type(eb_i24_sensible_boundary_publication_t) :: inherited\n""",
    """    type(eb_i25_sensible_boundary_publication_t), intent(out) :: publication\n    type(fmr_top_sensible_boundary_candidate_t), intent(out), optional :: accepted_top_candidate\n\n    type(eb_i24_sensible_boundary_publication_t) :: inherited\n"""
)
replace_once(
    'src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90',
    """    publication = eb_i25_sensible_boundary_publication_t()\n\n    ! Opt in only for this call.\n""",
    """    publication = eb_i25_sensible_boundary_publication_t()\n    if (present(accepted_top_candidate)) call accepted_top_candidate%clear()\n\n    ! Opt in only for this call.\n"""
)
replace_once(
    'src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90',
    """    top_candidate = backend%top_sensible_boundary_snapshot()\n    call backend%set_top_sensible_boundary_enabled(.false.)\n""",
    """    top_candidate = backend%top_sensible_boundary_snapshot()\n    if (present(accepted_top_candidate)) call top_candidate%copy_to(accepted_top_candidate)\n    call backend%set_top_sensible_boundary_enabled(.false.)\n"""
)

# 4. New EB-I26 successor runtime. It never changes the transaction owner.
i26 = r'''module mod_eb_i26_top_liquid_sensible_outflow_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_provider_i
  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_candidate_t, &
       fmr_top_sensible_boundary_sample_t
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       evaluate_liquid_water_sensible_transport, LWSE_OK
  use mod_external_liquid_water_temperature, only: external_liquid_water_temperature_t
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  use mod_eb_i25_multisubstep_sensible_boundary_runtime, only: eb_i25_sensible_boundary_publication_t, &
       fmr_execute_multisubstep_sensible_boundary
  implicit none
  private

  integer, parameter, public :: EB_I26_NOT_PUBLISHED = 0
  integer, parameter, public :: EB_I26_ACCEPTED_PARTIAL = 1
  integer, parameter, public :: EB_I26_INVALID_ACCEPTED_PROVENANCE = 2

  integer, parameter, public :: EB_I26_TOP_NOT_MATERIALIZED = 0
  integer, parameter, public :: EB_I26_TOP_INHERITED_I25 = 1
  integer, parameter, public :: EB_I26_TOP_OUTFLOW_MATERIALIZED = 2
  integer, parameter, public :: EB_I26_TOP_MIXED_UNQUALIFIED = 3
  integer, parameter, public :: EB_I26_TOP_DONOR_UNAVAILABLE = 4
  integer, parameter, public :: EB_I26_TOP_CARRIER_INVALID = 5
  integer, parameter, public :: EB_I26_TOP_SNOW_UNQUALIFIED = 6
  integer, parameter, public :: EB_I26_TOP_INVALID = 7

  type, public :: eb_i26_sensible_boundary_publication_t
    private
    logical :: initialized = .false.
    integer :: status_value = EB_I26_NOT_PUBLISHED
    integer :: top_status_value = EB_I26_TOP_NOT_MATERIALIZED
    integer(int64) :: column_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer :: accepted_substeps_value = 0
    integer :: carrier_sample_count_value = 0
    logical :: top_liquid_outflow_available_value = .false.
    real(real64) :: top_liquid_outflow_cm_value = 0.0_real64
    type(whole_column_sensible_boundary_t) :: boundary_value
    type(fmr_top_sensible_boundary_candidate_t) :: carrier_value
  contains
    procedure, public :: ready => publication_ready
    procedure, public :: status => publication_status
    procedure, public :: top_status => publication_top_status
    procedure, public :: column_id => publication_column_id
    procedure, public :: current_lineage_id => publication_lineage_id
    procedure, public :: origin_revision => publication_origin_revision
    procedure, public :: committed_revision => publication_committed_revision
    procedure, public :: origin_interval => publication_origin_interval
    procedure, public :: accepted_substeps => publication_accepted_substeps
    procedure, public :: carrier_sample_count => publication_carrier_sample_count
    procedure, public :: top_liquid_outflow => publication_top_liquid_outflow
    procedure, public :: boundary_snapshot => publication_boundary_snapshot
    procedure, public :: carrier_snapshot => publication_carrier_snapshot
    procedure, public :: runtime_materialization_complete => publication_runtime_complete
  end type eb_i26_sensible_boundary_publication_t

  public :: fmr_execute_top_sensible_outflow
  public :: materialize_top_outflow_from_candidate

contains

  subroutine fmr_execute_top_sensible_outflow(backend, transaction_control, column, template, parameters, &
       effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
       external_bottom_temperature_provider, top_temperature, output, diagnostic, runtime, active_physical_calls, &
       publication)
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
    procedure(fmr_external_bottom_thermal_provider_i) :: external_bottom_temperature_provider
    type(external_liquid_water_temperature_t), intent(in) :: top_temperature
    type(fmr_serialized_column_result_t), intent(inout) :: output
    type(fmr_column_diagnostics_t), intent(inout) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    type(eb_i26_sensible_boundary_publication_t), intent(out) :: publication

    type(eb_i25_sensible_boundary_publication_t) :: inherited
    type(fmr_top_sensible_boundary_candidate_t) :: candidate
    type(whole_column_sensible_boundary_t) :: boundary
    real(real64) :: inherited_t0, inherited_t1, carrier_t0, carrier_t1, outflow_cm
    logical :: interval_available, boundary_available, carrier_interval_available, outflow_available
    integer :: materialization_status

    publication = eb_i26_sensible_boundary_publication_t()
    call fmr_execute_multisubstep_sensible_boundary(backend, transaction_control, column, template, parameters, &
         effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
         external_bottom_temperature_provider, top_temperature, output, diagnostic, runtime, active_physical_calls, &
         inherited, candidate)

    if (.not. output%completed .or. .not. output%committed) return
    if (.not. inherited%ready()) then
      publication%status_value = EB_I26_INVALID_ACCEPTED_PROVENANCE
      return
    end if
    call inherited%origin_interval(inherited_t0, inherited_t1, interval_available)
    call inherited%boundary_snapshot(boundary, boundary_available)
    if (.not. interval_available .or. .not. boundary_available .or. &
        inherited%column_id() /= column%column_id .or. &
        inherited%origin_revision() /= output%initial_revision .or. &
        inherited%committed_revision() /= output%final_revision .or. &
        committed_state%current_revision() /= output%final_revision .or. &
        .not. same_time(inherited_t0, t0) .or. .not. same_time(inherited_t1, t1)) then
      publication%status_value = EB_I26_INVALID_ACCEPTED_PROVENANCE
      return
    end if

    publication%column_id_value = inherited%column_id()
    publication%lineage_id_value = inherited%current_lineage_id()
    publication%origin_revision_value = inherited%origin_revision()
    publication%committed_revision_value = inherited%committed_revision()
    publication%t0_value = inherited_t0
    publication%t1_value = inherited_t1
    publication%accepted_substeps_value = output%accepted_substeps
    publication%boundary_value = boundary

    publication%carrier_sample_count_value = candidate%sample_count()
    call candidate%interval(carrier_t0, carrier_t1, carrier_interval_available)
    if (.not. candidate%ready() .or. .not. carrier_interval_available .or. &
        publication%carrier_sample_count_value <= 0 .or. &
        .not. same_time(carrier_t0, t0) .or. .not. same_time(carrier_t1, t1)) then
      publication%top_status_value = EB_I26_TOP_CARRIER_INVALID
      call finish_publication(publication)
      return
    end if
    call candidate%copy_to(publication%carrier_value)

    call materialize_top_outflow_from_candidate(candidate, energy_parameters, publication%boundary_value, &
         materialization_status, outflow_cm, outflow_available)
    select case (materialization_status)
    case (EB_I26_TOP_INHERITED_I25)
      publication%top_status_value = EB_I26_TOP_INHERITED_I25
    case (EB_I26_TOP_OUTFLOW_MATERIALIZED)
      if (parameters%snow_active) then
        publication%boundary_value%top_advective_available = .false.
        publication%boundary_value%top_advective_into_j_m2 = 0.0_real64
        publication%top_status_value = EB_I26_TOP_SNOW_UNQUALIFIED
      else
        publication%top_status_value = materialization_status
        publication%top_liquid_outflow_available_value = outflow_available
        if (outflow_available) publication%top_liquid_outflow_cm_value = outflow_cm
      end if
    case default
      publication%top_status_value = materialization_status
    end select
    call finish_publication(publication)
  end subroutine fmr_execute_top_sensible_outflow

  subroutine materialize_top_outflow_from_candidate(candidate, energy_parameters, boundary, top_status, &
                                                     outflow_cm, outflow_available)
    type(fmr_top_sensible_boundary_candidate_t), intent(in) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: energy_parameters
    type(whole_column_sensible_boundary_t), intent(inout) :: boundary
    integer, intent(out) :: top_status
    real(real64), intent(out) :: outflow_cm
    logical, intent(out) :: outflow_available
    type(fmr_top_sensible_boundary_sample_t) :: sample
    real(real64) :: sample_energy, total_energy
    logical :: sample_available, any_outflow, any_inflow
    integer :: i, enthalpy_status

    top_status = EB_I26_TOP_CARRIER_INVALID
    outflow_cm = 0.0_real64
    outflow_available = .false.
    if (.not. candidate%ready()) return

    any_outflow = .false.
    any_inflow = .false.
    do i = 1, candidate%sample_count()
      call candidate%sample_at(i, sample, sample_available)
      if (.not. sample_available .or. .not. ieee_is_finite(sample%top_exchange_native)) return
      if (sample%top_exchange_native > 0.0_real64) any_outflow = .true.
      if (sample%top_exchange_native < 0.0_real64) any_inflow = .true.
    end do

    if (.not. any_outflow) then
      top_status = EB_I26_TOP_INHERITED_I25
      return
    end if
    if (any_inflow) then
      boundary%top_advective_available = .false.
      boundary%top_advective_into_j_m2 = 0.0_real64
      top_status = EB_I26_TOP_MIXED_UNQUALIFIED
      return
    end if
    if (.not. energy_parameters%ready() .or. .not. boundary%mass_carried_reference_available .or. &
        .not. same_value(boundary%mass_carried_reference_temperature_c, energy_parameters%reference_temperature_c)) then
      boundary%top_advective_available = .false.
      boundary%top_advective_into_j_m2 = 0.0_real64
      top_status = EB_I26_TOP_INVALID
      return
    end if

    total_energy = 0.0_real64
    outflow_cm = 0.0_real64
    do i = 1, candidate%sample_count()
      call candidate%sample_at(i, sample, sample_available)
      if (.not. sample_available) then
        top_status = EB_I26_TOP_CARRIER_INVALID
        return
      end if
      if (sample%top_exchange_native == 0.0_real64) cycle
      if (.not. sample%local_outflow_donor_available .or. &
          .not. ieee_is_finite(sample%local_outflow_end_temperature_c)) then
        boundary%top_advective_available = .false.
        boundary%top_advective_into_j_m2 = 0.0_real64
        outflow_cm = 0.0_real64
        top_status = EB_I26_TOP_DONOR_UNAVAILABLE
        return
      end if
      ! whole-column top advection is positive into soil, while the canonical
      ! top-water carrier is positive outward. The local accepted end-state
      ! node-1 temperature is therefore paired with the negative orientation.
      call evaluate_liquid_water_sensible_transport(-sample%top_exchange_native, &
           sample%local_outflow_end_temperature_c, energy_parameters, sample_energy, enthalpy_status)
      if (enthalpy_status /= LWSE_OK .or. .not. ieee_is_finite(sample_energy)) then
        boundary%top_advective_available = .false.
        boundary%top_advective_into_j_m2 = 0.0_real64
        outflow_cm = 0.0_real64
        top_status = EB_I26_TOP_INVALID
        return
      end if
      total_energy = total_energy + sample_energy
      outflow_cm = outflow_cm + sample%top_exchange_native
      if (.not. ieee_is_finite(total_energy) .or. .not. ieee_is_finite(outflow_cm)) then
        boundary%top_advective_available = .false.
        boundary%top_advective_into_j_m2 = 0.0_real64
        outflow_cm = 0.0_real64
        top_status = EB_I26_TOP_INVALID
        return
      end if
    end do

    boundary%top_advective_available = .true.
    boundary%top_advective_into_j_m2 = total_energy
    outflow_available = .true.
    top_status = EB_I26_TOP_OUTFLOW_MATERIALIZED
  end subroutine materialize_top_outflow_from_candidate

  subroutine finish_publication(publication)
    type(eb_i26_sensible_boundary_publication_t), intent(inout) :: publication
    publication%status_value = EB_I26_ACCEPTED_PARTIAL
    publication%initialized = .true.
  end subroutine finish_publication

  logical function publication_ready(self) result(ready)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    ready = self%initialized .and. self%status_value == EB_I26_ACCEPTED_PARTIAL .and. &
         self%column_id_value > 0_int64 .and. self%lineage_id_value > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         self%accepted_substeps_value > 0
  end function publication_ready

  integer function publication_status(self) result(status)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    status = self%status_value
  end function publication_status

  integer function publication_top_status(self) result(status)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    status = self%top_status_value
  end function publication_top_status

  integer(int64) function publication_column_id(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = self%column_id_value
  end function publication_column_id

  integer(int64) function publication_lineage_id(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = self%lineage_id_value
  end function publication_lineage_id

  integer(int64) function publication_origin_revision(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = self%origin_revision_value
  end function publication_origin_revision

  integer(int64) function publication_committed_revision(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = self%committed_revision_value
  end function publication_committed_revision

  subroutine publication_origin_interval(self, t0, t1, available)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine publication_origin_interval

  integer function publication_accepted_substeps(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = self%accepted_substeps_value
  end function publication_accepted_substeps

  integer function publication_carrier_sample_count(self) result(value)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    value = 0
    if (self%ready()) value = self%carrier_sample_count_value
  end function publication_carrier_sample_count

  subroutine publication_top_liquid_outflow(self, outflow_cm, available)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    real(real64), intent(out) :: outflow_cm
    logical, intent(out) :: available
    available = self%ready() .and. self%top_liquid_outflow_available_value
    outflow_cm = 0.0_real64
    if (available) outflow_cm = self%top_liquid_outflow_cm_value
  end subroutine publication_top_liquid_outflow

  subroutine publication_boundary_snapshot(self, boundary, available)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    type(whole_column_sensible_boundary_t), intent(out) :: boundary
    logical, intent(out) :: available
    boundary = whole_column_sensible_boundary_t()
    available = self%ready()
    if (available) boundary = self%boundary_value
  end subroutine publication_boundary_snapshot

  subroutine publication_carrier_snapshot(self, candidate, available)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    type(fmr_top_sensible_boundary_candidate_t), intent(out) :: candidate
    logical, intent(out) :: available
    call candidate%clear()
    available = self%ready() .and. self%carrier_value%ready()
    if (available) call self%carrier_value%copy_to(candidate)
  end subroutine publication_carrier_snapshot

  logical function publication_runtime_complete(self) result(complete)
    class(eb_i26_sensible_boundary_publication_t), intent(in) :: self
    complete = self%ready() .and. self%boundary_value%complete()
  end function publication_runtime_complete

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

  pure logical function same_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_value

end module mod_eb_i26_top_liquid_sensible_outflow_runtime
'''
(ROOT / 'src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90').write_text(i26)

# 5. Derive the owner test from I25's already-qualified physical fixture.
test = (ROOT / 'tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90').read_text()
test = test.replace('program test_eb_i25_multisubstep_sensible_boundary_runtime',
                    'program test_eb_i26_top_liquid_sensible_outflow_runtime', 1)
test = test.replace('end program test_eb_i25_multisubstep_sensible_boundary_runtime',
                    'end program test_eb_i26_top_liquid_sensible_outflow_runtime', 1)
test = test.replace(
    "use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &\n       initialize_liquid_water_sensible_enthalpy_parameters, LWSE_OK",
    "use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &\n       initialize_liquid_water_sensible_enthalpy_parameters, evaluate_liquid_water_sensible_transport, LWSE_OK")
test = test.replace(
    "use mod_eb_i25_provider_fixture, only: reset_provider, eb_i25_bottom_provider",
    "use mod_eb_i25_provider_fixture, only: reset_provider, eb_i25_bottom_provider\n  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_carrier_t, &\n       fmr_top_sensible_boundary_candidate_t, fmr_top_sensible_boundary_sample_t\n  use mod_eb_i26_top_liquid_sensible_outflow_runtime, only: eb_i26_sensible_boundary_publication_t, &\n       fmr_execute_top_sensible_outflow, materialize_top_outflow_from_candidate, &\n       EB_I26_TOP_INHERITED_I25, EB_I26_TOP_OUTFLOW_MATERIALIZED, EB_I26_TOP_MIXED_UNQUALIFIED, &\n       EB_I26_TOP_DONOR_UNAVAILABLE")
old_calls = """  call verify_two_half_inflow_materializes_complete_boundary()\n  call verify_two_half_missing_donor_fails_closed()\n  call verify_two_half_outflow_fixture_rejects_without_publication()\n  call verify_single_substep_matches_i24()\n  call verify_rejected_transaction_has_no_i25_publication()\n  write(*,'(A)') 'EB_I25_MULTISUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS'\n\ncontains\n"""
new_calls = """  call verify_single_substep_outflow_materializes_local_donor()\n  call verify_outflow_is_independent_of_external_donor_temperature()\n  call verify_inflow_route_is_inherited()\n  call verify_candidate_missing_local_donor_fails_closed()\n  call verify_candidate_mixed_direction_fails_closed()\n  call verify_rejected_transaction_has_no_i26_publication()\n  write(*,'(A)') 'EB_I26_TOP_LIQUID_SENSIBLE_OUTFLOW_GATE=PASS'\n\ncontains\n"""
if old_calls not in test:
    raise SystemExit('I25 test call block changed')
test = test.replace(old_calls, new_calls, 1)
insert_marker = '  subroutine verify_two_half_inflow_materializes_complete_boundary()\n'
new_tests = r'''  subroutine verify_single_substep_outflow_materializes_local_donor()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i26_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fmr_top_sensible_boundary_candidate_t) :: candidate
    type(fmr_top_sensible_boundary_sample_t) :: sample
    type(fixed_flux_top_boundary_provider_t), target :: top
    real(real64) :: outflow_cm, expected_energy
    integer :: active_calls, enthalpy_status
    logical :: available, sample_available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, 1.0e-10_real64, .false.)
    top_temperature%available = .true.
    top_temperature%temperature_c = 99.0_real64
    call reset_provider(column_id)
    call fmr_execute_top_sensible_outflow(backend, tx, column, template, parameters, forcing, committed, config, &
         t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, active_calls, &
         publication)

    call require(output%completed .and. output%committed, 'I26 accepted outflow committed')
    call require(publication%ready(), 'I26 accepted publication ready')
    call require(publication%top_status() == EB_I26_TOP_OUTFLOW_MATERIALIZED, 'I26 outflow materialized')
    call require(publication%carrier_sample_count() == 1, 'I26 single accepted carrier sample')
    call publication%top_liquid_outflow(outflow_cm, available)
    call require(available .and. outflow_cm > 0.0_real64, 'I26 accepted top outflow available')
    call publication%boundary_snapshot(boundary, available)
    call require(available .and. boundary%top_advective_available, 'I26 top advective available')
    call require(boundary%top_advective_into_j_m2 < 0.0_real64, 'I26 outflow energy oriented out of soil')
    call require(boundary%complete(), 'I26 closes bounded I22 boundary')
    call publication%carrier_snapshot(candidate, available)
    call require(available .and. candidate%sample_count() == 1, 'I26 carrier provenance available')
    call candidate%sample_at(1, sample, sample_available)
    call require(sample_available .and. sample%local_outflow_donor_available, 'I26 local donor captured')
    call require(close_value(sample%local_outflow_start_temperature_c, 9.0_real64, 1.0e-13_real64), &
         'I26 local donor begins at committed node-1 temperature')
    call require(sample%local_outflow_end_temperature_c > 8.0_real64 .and. &
         sample%local_outflow_end_temperature_c < 20.0_real64, 'I26 local end donor physically bounded')
    call require(abs(sample%local_outflow_end_temperature_c-top_temperature%temperature_c) > 1.0_real64, &
         'I26 external donor is not reused for outflow')
    call evaluate_liquid_water_sensible_transport(-sample%top_exchange_native, &
         sample%local_outflow_end_temperature_c, energy_parameters, expected_energy, enthalpy_status)
    call require(enthalpy_status == LWSE_OK, 'I26 independent primitive evaluation')
    call require(close_value(boundary%top_advective_into_j_m2, expected_energy, 1.0e-12_real64), &
         'I26 exact local-donor sensible transport law')
    write(*,'(A)') 'EB_I26_ACCEPTED_LOCAL_OUTFLOW_MATERIALIZED=PASS'
  end subroutine verify_single_substep_outflow_materializes_local_donor

  subroutine verify_outflow_is_independent_of_external_donor_temperature()
    type(fmr_serialized_reference_backend_t) :: backend_a, backend_b
    type(kernel_executor_t) :: tx_a, tx_b
    type(kernel_committed_state_t) :: committed_a, committed_b
    type(fmr_logical_column_t) :: column_a, column_b
    type(fmr_template_t) :: template_a, template_b
    type(fmr_b110_physical_parameters_t) :: parameters_a, parameters_b
    type(fmr_b110_physical_forcing_t) :: forcing_a, forcing_b
    type(canonical_numerical_config_t) :: config_a, config_b
    type(fmr_serialized_column_result_t) :: output_a, output_b
    type(fmr_column_diagnostics_t) :: diagnostic_a, diagnostic_b
    type(fmr_serialized_batch_diagnostics_t) :: runtime_a, runtime_b
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_a, energy_b
    type(external_liquid_water_temperature_t) :: temp_a, temp_b
    type(eb_i26_sensible_boundary_publication_t) :: pub_a, pub_b
    type(whole_column_sensible_boundary_t) :: boundary_a, boundary_b
    type(fixed_flux_top_boundary_provider_t), target :: top_a, top_b
    integer :: calls_a, calls_b
    logical :: available_a, available_b

    call initialize_case(backend_a, top_a, committed_a, column_a, template_a, parameters_a, forcing_a, config_a, output_a, &
         diagnostic_a, runtime_a, calls_a, energy_a, 1.0e-10_real64, .false.)
    call initialize_case(backend_b, top_b, committed_b, column_b, template_b, parameters_b, forcing_b, config_b, output_b, &
         diagnostic_b, runtime_b, calls_b, energy_b, 1.0e-10_real64, .false.)
    temp_a%available = .true.; temp_a%temperature_c = -20.0_real64
    temp_b%available = .true.; temp_b%temperature_c = 120.0_real64
    call reset_provider(column_id)
    call fmr_execute_top_sensible_outflow(backend_a, tx_a, column_a, template_a, parameters_a, forcing_a, committed_a, &
         config_a, t0, t1, energy_a, eb_i25_bottom_provider, temp_a, output_a, diagnostic_a, runtime_a, calls_a, pub_a)
    call reset_provider(column_id)
    call fmr_execute_top_sensible_outflow(backend_b, tx_b, column_b, template_b, parameters_b, forcing_b, committed_b, &
         config_b, t0, t1, energy_b, eb_i25_bottom_provider, temp_b, output_b, diagnostic_b, runtime_b, calls_b, pub_b)
    call pub_a%boundary_snapshot(boundary_a, available_a)
    call pub_b%boundary_snapshot(boundary_b, available_b)
    call require(available_a .and. available_b, 'I26 donor independence boundaries')
    call require(pub_a%top_status() == EB_I26_TOP_OUTFLOW_MATERIALIZED .and. &
         pub_b%top_status() == EB_I26_TOP_OUTFLOW_MATERIALIZED, 'I26 donor independence statuses')
    call require(close_value(boundary_a%top_advective_into_j_m2, boundary_b%top_advective_into_j_m2, 1.0e-13_real64), &
         'I26 outflow does not depend on external donor temperature')
    write(*,'(A)') 'EB_I26_EXTERNAL_DONOR_NEGATIVE_CONTROL=PASS'
  end subroutine verify_outflow_is_independent_of_external_donor_temperature

  subroutine verify_inflow_route_is_inherited()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i26_sensible_boundary_publication_t) :: publication
    type(whole_column_sensible_boundary_t) :: boundary
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    logical :: available

    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, -1.0e-10_real64, .false.)
    top_temperature%available = .true.; top_temperature%temperature_c = top_donor_temperature_c
    call reset_provider(column_id)
    call fmr_execute_top_sensible_outflow(backend, tx, column, template, parameters, forcing, committed, config, &
         t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, active_calls, &
         publication)
    call require(publication%ready() .and. publication%top_status() == EB_I26_TOP_INHERITED_I25, &
         'I26 inflow inherits I25')
    call publication%boundary_snapshot(boundary, available)
    call require(available .and. boundary%top_advective_available .and. boundary%top_advective_into_j_m2 > 0.0_real64, &
         'I26 inherited inflow energy preserved')
    write(*,'(A)') 'EB_I26_I25_INFLOW_PRESERVATION=PASS'
  end subroutine verify_inflow_route_is_inherited

  subroutine verify_candidate_missing_local_donor_fails_closed()
    type(fmr_top_sensible_boundary_carrier_t) :: carrier
    type(fmr_top_sensible_boundary_candidate_t) :: candidate
    type(whole_column_sensible_boundary_t) :: boundary
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    real(real64) :: outflow_cm
    integer :: status, enthalpy_status
    logical :: ok, available
    call initialize_liquid_water_sensible_enthalpy_parameters(rho, cp, reference_temperature_c, energy_parameters, &
         enthalpy_status)
    call carrier%initialize(1, ok); call require(ok, 'I26 missing donor carrier init')
    call carrier%append(1.0_real64, 2.0_real64, 0.1_real64, .true., 0.0_real64, 0.0_real64, 0.0_real64, ok)
    call require(ok, 'I26 missing donor sample accepted as incomplete provenance')
    call carrier%materialize_candidate(1.0_real64, 2.0_real64, candidate, ok)
    call require(ok, 'I26 missing donor candidate ready')
    boundary%mass_carried_reference_available = .true.
    boundary%mass_carried_reference_temperature_c = reference_temperature_c
    call materialize_top_outflow_from_candidate(candidate, energy_parameters, boundary, status, outflow_cm, available)
    call require(status == EB_I26_TOP_DONOR_UNAVAILABLE .and. .not. available, 'I26 missing local donor status')
    call require(.not. boundary%top_advective_available, 'I26 missing donor remains unavailable not zero')
    write(*,'(A)') 'EB_I26_MISSING_LOCAL_DONOR_FAIL_CLOSED=PASS'
  end subroutine verify_candidate_missing_local_donor_fails_closed

  subroutine verify_candidate_mixed_direction_fails_closed()
    type(fmr_top_sensible_boundary_carrier_t) :: carrier
    type(fmr_top_sensible_boundary_candidate_t) :: candidate
    type(whole_column_sensible_boundary_t) :: boundary
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    real(real64) :: outflow_cm
    integer :: status, enthalpy_status
    logical :: ok, available
    call initialize_liquid_water_sensible_enthalpy_parameters(rho, cp, reference_temperature_c, energy_parameters, &
         enthalpy_status)
    call carrier%initialize(2, ok); call require(ok, 'I26 mixed carrier init')
    call carrier%append(1.0_real64, 1.5_real64, 0.1_real64, .true., 0.0_real64, 0.0_real64, 0.0_real64, ok, &
         local_outflow_donor_available=.true., local_outflow_start_temperature_c=9.0_real64, &
         local_outflow_end_temperature_c=10.0_real64)
    call require(ok, 'I26 mixed outward sample')
    call carrier%append(1.5_real64, 2.0_real64, -0.05_real64, .true., 0.0_real64, 0.0_real64, 0.0_real64, ok)
    call require(ok, 'I26 mixed inward sample')
    call carrier%materialize_candidate(1.0_real64, 2.0_real64, candidate, ok)
    call require(ok, 'I26 mixed candidate ready')
    boundary%mass_carried_reference_available = .true.
    boundary%mass_carried_reference_temperature_c = reference_temperature_c
    call materialize_top_outflow_from_candidate(candidate, energy_parameters, boundary, status, outflow_cm, available)
    call require(status == EB_I26_TOP_MIXED_UNQUALIFIED .and. .not. available, 'I26 mixed direction explicit status')
    call require(.not. boundary%top_advective_available, 'I26 mixed direction not netted')
    write(*,'(A)') 'EB_I26_MIXED_DIRECTION_NO_NETTING=PASS'
  end subroutine verify_candidate_mixed_direction_fails_closed

  subroutine verify_rejected_transaction_has_no_i26_publication()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: tx
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_column_result_t) :: output
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters
    type(external_liquid_water_temperature_t) :: top_temperature
    type(eb_i26_sensible_boundary_publication_t) :: publication
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_calls
    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &
         runtime, active_calls, energy_parameters, 1.0e-10_real64, .false.)
    parameters%bottom_mode = 6
    top_temperature%available = .true.; top_temperature%temperature_c = 99.0_real64
    call reset_provider(column_id)
    call fmr_execute_top_sensible_outflow(backend, tx, column, template, parameters, forcing, committed, config, &
         t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, active_calls, &
         publication)
    call require(.not. output%committed .and. committed%current_revision() == 0_int64, 'I26 rejected path precommit')
    call require(.not. publication%ready(), 'I26 rejected path no publication')
    write(*,'(A)') 'EB_I26_REJECTED_TRIAL_NO_PUBLICATION=PASS'
  end subroutine verify_rejected_transaction_has_no_i26_publication

'''
if insert_marker not in test:
    raise SystemExit('I25 test insertion marker changed')
test = test.replace(insert_marker, new_tests + insert_marker, 1)
(ROOT / 'tests/eb/test_eb_i26_top_liquid_sensible_outflow_runtime.f90').write_text(test)

# 6. Owner gate compiles the new route and replays the old I25 oracle on the same modified sources.
gate = r'''#!/usr/bin/env bash
set -euo pipefail

BASE=6acba7e7371347a17cc277ab8cec063d94646006

git merge-base --is-ancestor "$BASE" HEAD

git diff --name-only "$BASE" HEAD | sort > changed.txt
cat > allowed.txt <<'EOF'
.github/workflows/eb-i26-top-liquid-sensible-outflow.yml
src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90
src/runtime/mod_fmr_serialized_reference_backend.f90
src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
tests/eb/EB-I26_CHECKPOINT.json
tests/eb/EB-I26_CONTRACT.md
tests/eb/run_eb_i26_top_liquid_sensible_outflow_gate.sh
tests/eb/test_eb_i26_top_liquid_sensible_outflow_runtime.f90
EOF
sort -o allowed.txt allowed.txt
diff -u allowed.txt changed.txt

test ! -e tools/eb_i26_top_outflow_bootstrap.py
test ! -e .github/workflows/eb-i26-top-outflow-bootstrap.yml
grep -Fq 'local_outflow_donor_available' src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
grep -Fq 'soil_temperature_at_node(physical%soil_temperature, 1' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'accepted_top_candidate' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'sample%local_outflow_end_temperature_c' src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90
grep -Fq 'evaluate_liquid_water_sensible_transport(-sample%top_exchange_native' src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90
grep -Fq 'EB_I26_TOP_MIXED_UNQUALIFIED' src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90
! grep -R -E 'RossFast|ROSSFAST|mod_ross' src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90 tests/eb/EB-I26_CONTRACT.md tests/eb/test_eb_i26_top_liquid_sensible_outflow_runtime.f90
echo 'EB_I26_BOUNDED_DELTA=PASS'
echo 'EB_I26_STATIC_CONTRACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_linear_mixture_sensible_storage.f90
  src/kernel/mod_energy_conservation_types.f90
  src/process/mod_whole_column_sensible_energy_accounting.f90
  src/runtime/mod_eb_i23_sensible_boundary_runtime.f90
  src/process/mod_external_liquid_water_temperature.f90
  src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90
  src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
  src/runtime/mod_eb_i26_top_liquid_sensible_outflow_runtime.f90
)

for opt in 0 2; do
  OUT="${RUNNER_TEMP:-/tmp}/eb-i26-o${opt}"
  rm -rf "$OUT"; mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90 -o "$OUT/test_i25.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_i25.o" -o "$OUT/test_i25"
  "$OUT/test_i25" > "$OUT/i25.txt" 2>&1
  grep -Fx 'EB_I25_MULTISUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS' "$OUT/i25.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i26_top_liquid_sensible_outflow_runtime.f90 -o "$OUT/test_i26.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_i26.o" -o "$OUT/test_i26"
  "$OUT/test_i26" > "$OUT/i26.txt" 2>&1
  grep -Fx 'EB_I26_ACCEPTED_LOCAL_OUTFLOW_MATERIALIZED=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_EXTERNAL_DONOR_NEGATIVE_CONTROL=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_I25_INFLOW_PRESERVATION=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_MISSING_LOCAL_DONOR_FAIL_CLOSED=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_MIXED_DIRECTION_NO_NETTING=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_REJECTED_TRIAL_NO_PUBLICATION=PASS' "$OUT/i26.txt"
  grep -Fx 'EB_I26_TOP_LIQUID_SENSIBLE_OUTFLOW_GATE=PASS' "$OUT/i26.txt"
  cat "$OUT/i25.txt"
  cat "$OUT/i26.txt"
done
cmp -s "${RUNNER_TEMP:-/tmp}/eb-i26-o0/i25.txt" "${RUNNER_TEMP:-/tmp}/eb-i26-o2/i25.txt"
cmp -s "${RUNNER_TEMP:-/tmp}/eb-i26-o0/i26.txt" "${RUNNER_TEMP:-/tmp}/eb-i26-o2/i26.txt"
echo 'EB_I26_I25_PRESERVATION_O0_O2=PASS'
echo 'EB_I26_O0_O2_IDENTITY=PASS'
echo 'EB_I26_OWNER_QUALIFICATION=PASS'
'''
(ROOT / 'tests/eb/run_eb_i26_top_liquid_sensible_outflow_gate.sh').write_text(gate)

contract = r'''# EB-I26 Accepted Top-Liquid Sensible Outflow Transport

## Scope

EB-I26 qualifies one missing top-boundary sensible-energy term on an already accepted serialized SWAP trajectory: liquid water leaving the soil through the top boundary.

The canonical top-water carrier uses positive exchange for water leaving the soil and negative exchange for water entering the soil. Whole-column sensible-energy accounting uses top advective energy positive into the soil. EB-I26 therefore evaluates each accepted local outflow sample with the negative of its canonical top-water exchange.

## Donor authority

For top-water outflow, the donor is local SWAP soil water. EB-I26 uses the accepted end-state temperature of soil-temperature node 1 for that sample. The corresponding start-state node-1 temperature is retained as provenance. This mirrors the already admitted bottom local-outflow contract, where accepted end-state donor-node temperature is used for sensible transport.

The prescribed surface temperature of the restricted soil-temperature boundary is an external Dirichlet forcing. It is not soil-side donor authority and must never be substituted for the node-1 local donor. Likewise, the external liquid-water temperature used by EB-I24 for inflow is not reused for outflow.

## Transactional provenance

Donor temperatures are appended to `fmr_top_sensible_boundary_carrier_t`, which is already part of the serialized attempt context. Rejected and retried trial work is therefore restored with the carrier and cannot leak into the accepted candidate. EB-I25 exposes an optional copy of that accepted candidate to EB-I26 without changing I25 publication semantics.

## Materialization

For every positive accepted top-water sample, EB-I26 requires finite local donor provenance and evaluates the existing qualified liquid-water sensible-enthalpy primitive using:

`oriented_transport_cm = -top_exchange_native`

`advected_temperature_c = accepted local node-1 end temperature`

The per-sample energies are summed. Exact-zero samples require no donor. If no positive sample exists, EB-I26 preserves the I25 result unchanged.

## Fail-closed boundaries

Mixed accepted top-water directions remain unqualified: positive and negative samples are not netted before temperature assignment. Missing local donor provenance remains unavailable, never encoded as zero. Snow/melt thermal provenance remains outside EB-I26.

## Nonclaims

EB-I26 does not qualify snow or melt thermal transport, latent heat, vapor enthalpy, freezing/thawing enthalpy, a whole-column energy residual, arbitrary full-energy-balance closure, or any new Richards/soil-temperature physics. It does not change transaction ownership, timestep policy, I23/I24/I25 semantics, groundwater coupling, or alternative solver semantics.
'''
(ROOT / 'tests/eb/EB-I26_CONTRACT.md').write_text(contract)

checkpoint = {
  'capability': 'EB-I26 accepted top-liquid sensible outflow transport',
  'phase': 'QUALIFY_PENDING_OWNER_CI',
  'base_branch': 'integration/f-ci-canonical',
  'base_head': '6acba7e7371347a17cc277ab8cec063d94646006',
  'work_branch': 'work/eb-i26-top-liquid-outflow-sensible-transport',
  'reconcile': {
    'existing_equivalent_found': False,
    'accepted_outflow_surface': 'EB-I24 model-certificate route already accepts positive top flux but leaves top advection unavailable',
    'donor_authority': 'accepted end-state restricted-soil-temperature node 1; start node 1 retained as provenance',
    'external_surface_temperature_is_not_donor': True,
    'bottom_precedent_reused': 'FMR bottom local-outflow sensible transport uses accepted end donor-node temperature'
  },
  'production_delta': [
    'extend top sensible carrier with optional local outflow donor provenance',
    'capture node-1 start/end donor temperatures inside existing transactional carrier path',
    'expose optional accepted carrier snapshot from EB-I25 without altering I25 result semantics',
    'add EB-I26 successor composition for accepted top-water outflow'
  ],
  'owner_tests_planned': [
    'accepted single-step outflow materializes negative top advective energy',
    'external donor temperature negative control',
    'I25 inflow preservation',
    'missing local donor fails closed',
    'mixed inflow/outflow is not netted',
    'rejected transaction publishes no I26 evidence',
    'legacy I25 owner oracle replay on modified sources',
    'O0/O2 output identity'
  ],
  'verdict': 'PENDING_OWNER_CI',
  'next_permitted_action': 'run owner CI; repair only implementation/test defects; if green, persist qualified checkpoint and start independent qualification',
  'exclusions': ['snow/melt thermal provenance', 'latent heat', 'vapor enthalpy', 'freeze/thaw enthalpy', 'whole-column residual', 'full energy balance', 'groundwater semantics', 'Ross/RossFast']
}
(ROOT / 'tests/eb/EB-I26_CHECKPOINT.json').write_text(json.dumps(checkpoint, indent=2) + '\n')

owner_workflow = r'''name: EB-I26 accepted top liquid sensible outflow

on:
  push:
    branches:
      - work/eb-i26-top-liquid-outflow-sensible-transport
  workflow_dispatch:

permissions:
  contents: read

jobs:
  qualify-owner:
    runs-on: ubuntu-24.04
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install GNU Fortran
        run: sudo apt-get update && sudo apt-get install -y gfortran
      - name: Run EB-I26 owner qualification
        shell: bash
        run: bash tests/eb/run_eb_i26_top_liquid_sensible_outflow_gate.sh
'''
(ROOT / '.github/workflows/eb-i26-top-liquid-sensible-outflow.yml').write_text(owner_workflow)

print('EB_I26_BOOTSTRAP_PATCH=READY')
