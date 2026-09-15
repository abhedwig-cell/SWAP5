module mod_eb_i24_top_liquid_sensible_inflow_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_physical_observation_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_provider_i
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       evaluate_liquid_water_sensible_transport, LWSE_OK
  use mod_external_liquid_water_temperature, only: external_liquid_water_temperature_t, &
       external_liquid_water_temperature_result_t, resolve_external_liquid_water_temperature, &
       EXT_LIQ_TEMP_NOT_REQUIRED, EXT_LIQ_TEMP_AVAILABLE
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  use mod_eb_i23_sensible_boundary_runtime, only: eb_i23_sensible_boundary_publication_t, &
       fmr_execute_column_with_sensible_boundary
  implicit none
  private

  integer, parameter, public :: EB_I24_NOT_PUBLISHED = 0
  integer, parameter, public :: EB_I24_ACCEPTED_PARTIAL = 1
  integer, parameter, public :: EB_I24_INVALID_ACCEPTED_PROVENANCE = 2

  integer, parameter, public :: EB_I24_TOP_NOT_MATERIALIZED = 0
  integer, parameter, public :: EB_I24_TOP_INFLOW_MATERIALIZED = 1
  integer, parameter, public :: EB_I24_TOP_ZERO_MATERIALIZED = 2
  integer, parameter, public :: EB_I24_TOP_DONOR_UNAVAILABLE = 3
  integer, parameter, public :: EB_I24_TOP_OUTFLOW_UNQUALIFIED = 4
  integer, parameter, public :: EB_I24_TOP_SNOW_UNQUALIFIED = 5
  integer, parameter, public :: EB_I24_TOP_MULTI_SUBSTEP_UNQUALIFIED = 6
  integer, parameter, public :: EB_I24_TOP_INVALID = 7

  type, public :: eb_i24_sensible_boundary_publication_t
    private
    logical :: initialized = .false.
    integer :: status_value = EB_I24_NOT_PUBLISHED
    integer :: top_status_value = EB_I24_TOP_NOT_MATERIALIZED
    integer(int64) :: column_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    logical :: top_liquid_inflow_available_value = .false.
    real(real64) :: top_liquid_inflow_cm_value = 0.0_real64
    type(whole_column_sensible_boundary_t) :: boundary_value
  contains
    procedure, public :: ready => eb_i24_publication_ready
    procedure, public :: status => eb_i24_publication_status
    procedure, public :: top_status => eb_i24_publication_top_status
    procedure, public :: column_id => eb_i24_publication_column_id
    procedure, public :: current_lineage_id => eb_i24_publication_lineage_id
    procedure, public :: origin_revision => eb_i24_publication_origin_revision
    procedure, public :: committed_revision => eb_i24_publication_committed_revision
    procedure, public :: origin_interval => eb_i24_publication_origin_interval
    procedure, public :: top_liquid_inflow => eb_i24_publication_top_liquid_inflow
    procedure, public :: boundary_snapshot => eb_i24_publication_boundary_snapshot
    procedure, public :: runtime_materialization_complete => eb_i24_runtime_materialization_complete
  end type eb_i24_sensible_boundary_publication_t

  public :: fmr_execute_column_with_top_sensible_inflow

contains

  subroutine fmr_execute_column_with_top_sensible_inflow(backend, transaction_control, column, template, parameters, &
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
    type(eb_i24_sensible_boundary_publication_t), intent(out) :: publication

    type(eb_i23_sensible_boundary_publication_t) :: inherited
    type(fmr_serialized_physical_observation_t) :: observation
    type(external_liquid_water_temperature_result_t) :: temperature_result
    type(whole_column_sensible_boundary_t) :: boundary
    real(real64) :: inherited_t0, inherited_t1, inflow_cm, energy_j_m2
    logical :: boundary_available, interval_available
    integer :: enthalpy_status

    publication = eb_i24_sensible_boundary_publication_t()

    ! Observation and accepted I23 receipt stay inside one call boundary.  A
    ! caller cannot pair a top flux from one trial with another transaction's
    ! accepted sensible-boundary publication.
    call fmr_execute_column_with_sensible_boundary(backend, transaction_control, column, template, parameters, &
         effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
         external_bottom_temperature_provider, output, diagnostic, runtime, active_physical_calls, inherited)

    if (.not. output%completed .or. .not. output%committed) return
    if (.not. inherited%ready()) then
      publication%status_value = EB_I24_INVALID_ACCEPTED_PROVENANCE
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
      publication%status_value = EB_I24_INVALID_ACCEPTED_PROVENANCE
      return
    end if

    publication%column_id_value = inherited%column_id()
    publication%lineage_id_value = inherited%current_lineage_id()
    publication%origin_revision_value = inherited%origin_revision()
    publication%committed_revision_value = inherited%committed_revision()
    publication%t0_value = inherited_t0
    publication%t1_value = inherited_t1
    publication%boundary_value = boundary

    observation = backend%observation()

    ! I23 already proved that last_observation is safe only for one accepted
    ! substep.  I24 applies the same accepted-state restriction to the top
    ! liquid-water flux rather than pretending the last solve is an aggregate.
    if (output%accepted_substeps /= 1) then
      publication%top_status_value = EB_I24_TOP_MULTI_SUBSTEP_UNQUALIFIED
      call finish_publication(publication)
      return
    end if
    if (parameters%snow_active) then
      ! With snow active the solver top flux contains base_top_flux - melt_rate.
      ! That mixes external liquid input and snow-to-soil transfer and therefore
      ! has no single qualified donor temperature in this capability.
      publication%top_status_value = EB_I24_TOP_SNOW_UNQUALIFIED
      call finish_publication(publication)
      return
    end if
    if (.not. observation%solver_executed .or. observation%solver_status /= SW_SOLVE_CONVERGED .or. &
        .not. ieee_is_finite(observation%top_flux) .or. .not. ieee_is_finite(t1-t0) .or. t1 <= t0) then
      publication%top_status_value = EB_I24_TOP_INVALID
      call finish_publication(publication)
      return
    end if

    if (observation%top_flux > 0.0_real64) then
      ! Positive canonical top flux is water leaving the soil.  Its donor is on
      ! the soil side and no accepted local-liquid donor-temperature authority
      ! is qualified here.  Never reuse the external inflow temperature.
      publication%top_status_value = EB_I24_TOP_OUTFLOW_UNQUALIFIED
      call finish_publication(publication)
      return
    end if

    inflow_cm = -observation%top_flux * (t1-t0)
    if (.not. ieee_is_finite(inflow_cm) .or. inflow_cm < 0.0_real64) then
      publication%top_status_value = EB_I24_TOP_INVALID
      call finish_publication(publication)
      return
    end if
    publication%top_liquid_inflow_available_value = .true.
    publication%top_liquid_inflow_cm_value = inflow_cm

    call resolve_external_liquid_water_temperature(inflow_cm, top_temperature, temperature_result)
    select case (temperature_result%status)
    case (EXT_LIQ_TEMP_AVAILABLE)
      if (.not. energy_parameters%ready() .or. .not. boundary%mass_carried_reference_available .or. &
          .not. same_value(boundary%mass_carried_reference_temperature_c, &
                          energy_parameters%reference_temperature_c)) then
        publication%top_status_value = EB_I24_TOP_INVALID
        call finish_publication(publication)
        return
      end if
      call evaluate_liquid_water_sensible_transport(inflow_cm, temperature_result%temperature_c, energy_parameters, &
           energy_j_m2, enthalpy_status)
      if (enthalpy_status /= LWSE_OK .or. .not. ieee_is_finite(energy_j_m2)) then
        publication%top_status_value = EB_I24_TOP_INVALID
        call finish_publication(publication)
        return
      end if
      publication%boundary_value%top_advective_available = .true.
      publication%boundary_value%top_advective_into_j_m2 = energy_j_m2
      publication%top_status_value = EB_I24_TOP_INFLOW_MATERIALIZED
    case (EXT_LIQ_TEMP_NOT_REQUIRED)
      ! Exact zero accepted transport is a known zero, not a missing value
      ! repaired to zero.  No donor temperature is required by the I08 law.
      if (inflow_cm /= 0.0_real64) then
        publication%top_status_value = EB_I24_TOP_INVALID
        call finish_publication(publication)
        return
      end if
      publication%boundary_value%top_advective_available = .true.
      publication%boundary_value%top_advective_into_j_m2 = 0.0_real64
      publication%top_status_value = EB_I24_TOP_ZERO_MATERIALIZED
    case default
      publication%top_status_value = EB_I24_TOP_DONOR_UNAVAILABLE
    end select

    call finish_publication(publication)
  end subroutine fmr_execute_column_with_top_sensible_inflow

  subroutine finish_publication(publication)
    type(eb_i24_sensible_boundary_publication_t), intent(inout) :: publication
    publication%status_value = EB_I24_ACCEPTED_PARTIAL
    publication%initialized = .true.
  end subroutine finish_publication

  logical function eb_i24_publication_ready(self) result(ready)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    ready = self%initialized .and. self%status_value == EB_I24_ACCEPTED_PARTIAL .and. &
         self%column_id_value > 0_int64 .and. self%lineage_id_value > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value
    if (.not. ready) return
    if (self%top_liquid_inflow_available_value) then
      ready = ieee_is_finite(self%top_liquid_inflow_cm_value) .and. self%top_liquid_inflow_cm_value >= 0.0_real64
    end if
    if (ready .and. self%boundary_value%top_advective_available) &
         ready = ieee_is_finite(self%boundary_value%top_advective_into_j_m2)
  end function eb_i24_publication_ready

  integer function eb_i24_publication_status(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = self%status_value
  end function eb_i24_publication_status

  integer function eb_i24_publication_top_status(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = self%top_status_value
  end function eb_i24_publication_top_status

  integer(int64) function eb_i24_publication_column_id(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%column_id_value
  end function eb_i24_publication_column_id

  integer(int64) function eb_i24_publication_lineage_id(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%lineage_id_value
  end function eb_i24_publication_lineage_id

  integer(int64) function eb_i24_publication_origin_revision(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%origin_revision_value
  end function eb_i24_publication_origin_revision

  integer(int64) function eb_i24_publication_committed_revision(self) result(value)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%committed_revision_value
  end function eb_i24_publication_committed_revision

  subroutine eb_i24_publication_origin_interval(self, t0, t1, available)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
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
  end subroutine eb_i24_publication_origin_interval

  subroutine eb_i24_publication_top_liquid_inflow(self, inflow_cm, available)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    real(real64), intent(out) :: inflow_cm
    logical, intent(out) :: available
    available = self%ready() .and. self%top_liquid_inflow_available_value
    inflow_cm = 0.0_real64
    if (available) inflow_cm = self%top_liquid_inflow_cm_value
  end subroutine eb_i24_publication_top_liquid_inflow

  subroutine eb_i24_publication_boundary_snapshot(self, boundary, available)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    type(whole_column_sensible_boundary_t), intent(out) :: boundary
    logical, intent(out) :: available
    boundary = whole_column_sensible_boundary_t()
    available = self%ready()
    if (available) boundary = self%boundary_value
  end subroutine eb_i24_publication_boundary_snapshot

  logical function eb_i24_runtime_materialization_complete(self) result(complete)
    class(eb_i24_sensible_boundary_publication_t), intent(in) :: self
    complete = self%ready() .and. self%boundary_value%complete()
  end function eb_i24_runtime_materialization_complete

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

end module mod_eb_i24_top_liquid_sensible_inflow_runtime
