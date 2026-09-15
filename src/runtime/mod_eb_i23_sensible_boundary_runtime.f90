module mod_eb_i23_sensible_boundary_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t
  use mod_fmr_serialized_reference_backend, only: fmr_serialized_reference_backend_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_physical_observation_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_serialized_bottom_energy_publication_t, &
       fmr_execute_serialized_column_with_bottom_energy
  use mod_fmr_bottom_external_thermal_provider, only: fmr_external_bottom_thermal_provider_i
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  implicit none
  private

  integer, parameter, public :: EB_I23_NOT_PUBLISHED = 0
  integer, parameter, public :: EB_I23_ACCEPTED_PARTIAL = 1
  integer, parameter, public :: EB_I23_INVALID_ACCEPTED_PROVENANCE = 2
  real(real64), parameter :: J_CM2_TO_J_M2 = 1.0e4_real64

  ! Accepted-only, bounded sensible-boundary publication.
  !
  ! The current canonical authority surface has no qualified top mass-carried
  ! sensible-energy donor-temperature source. A ready publication is therefore
  ! intentionally partial: it can materialize the accepted restricted-thermal
  ! conductive terms and the already receipt-owned bottom advective term, but
  ! it can never claim complete I22 boundary closure in this capability.
  type, public :: eb_i23_sensible_boundary_publication_t
    private
    logical :: initialized = .false.
    integer :: status_value = EB_I23_NOT_PUBLISHED
    integer(int64) :: column_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    logical :: top_conductive_available_value = .false.
    real(real64) :: top_conductive_into_j_m2_value = 0.0_real64
    logical :: bottom_conductive_available_value = .false.
    real(real64) :: bottom_conductive_outward_j_m2_value = 0.0_real64
    logical :: bottom_advective_available_value = .false.
    real(real64) :: bottom_advective_outward_j_m2_value = 0.0_real64
    logical :: mass_reference_available_value = .false.
    real(real64) :: mass_reference_temperature_c_value = 0.0_real64
  contains
    procedure, public :: ready => eb_i23_publication_ready
    procedure, public :: status => eb_i23_publication_status
    procedure, public :: column_id => eb_i23_publication_column_id
    procedure, public :: current_lineage_id => eb_i23_publication_lineage_id
    procedure, public :: origin_revision => eb_i23_publication_origin_revision
    procedure, public :: committed_revision => eb_i23_publication_committed_revision
    procedure, public :: origin_interval => eb_i23_publication_origin_interval
    procedure, public :: boundary_snapshot => eb_i23_publication_boundary_snapshot
    procedure, public :: runtime_materialization_complete => eb_i23_runtime_materialization_complete
  end type eb_i23_sensible_boundary_publication_t

  public :: fmr_execute_column_with_sensible_boundary

contains

  subroutine fmr_execute_column_with_sensible_boundary(backend, transaction_control, column, template, parameters, &
       effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
       external_temperature_provider, output, diagnostic, runtime, active_physical_calls, publication)
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
    type(eb_i23_sensible_boundary_publication_t), intent(out) :: publication

    type(fmr_serialized_bottom_energy_publication_t) :: bottom_publication
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: bottom_t0, bottom_t1, bottom_energy, converted_top, accounting_identity
    logical :: interval_available, bottom_available, thermal_safe

    publication = eb_i23_sensible_boundary_publication_t()

    ! Keep the accepted receipt and the thermal observation inside one runtime
    ! call boundary. This prevents a caller from pairing an observation from
    ! one transaction with the accepted bottom-energy receipt from another.
    call fmr_execute_serialized_column_with_bottom_energy(backend, transaction_control, column, template, parameters, &
         effective_forcing, committed_state, numerical_config, t0, t1, energy_parameters, &
         external_temperature_provider, output, diagnostic, runtime, active_physical_calls, bottom_publication)

    if (.not. output%completed .or. .not. output%committed) return
    if (.not. bottom_publication%ready()) then
      publication%status_value = EB_I23_INVALID_ACCEPTED_PROVENANCE
      return
    end if

    call bottom_publication%origin_interval(bottom_t0, bottom_t1, interval_available)
    if (.not. interval_available .or. bottom_publication%column_id() /= column%column_id .or. &
        bottom_publication%origin_revision() /= output%initial_revision .or. &
        bottom_publication%committed_revision() /= output%final_revision .or. &
        committed_state%current_revision() /= output%final_revision .or. &
        .not. same_time(bottom_t0, t0) .or. .not. same_time(bottom_t1, t1) .or. &
        .not. same_time(output%requested_t0, t0) .or. .not. same_time(output%requested_t1, t1)) then
      publication%status_value = EB_I23_INVALID_ACCEPTED_PROVENANCE
      return
    end if

    publication%column_id_value = column%column_id
    publication%lineage_id_value = bottom_publication%current_lineage_id()
    publication%origin_revision_value = bottom_publication%origin_revision()
    publication%committed_revision_value = bottom_publication%committed_revision()
    publication%t0_value = bottom_t0
    publication%t1_value = bottom_t1

    if (energy_parameters%ready()) then
      publication%mass_reference_available_value = .true.
      publication%mass_reference_temperature_c_value = energy_parameters%reference_temperature_c
    end if

    call bottom_publication%total_energy(bottom_energy, bottom_available)
    if (bottom_available .and. ieee_is_finite(bottom_energy)) then
      publication%bottom_advective_available_value = .true.
      publication%bottom_advective_outward_j_m2_value = bottom_energy
    end if

    ! last_observation is the complete accepted thermal interval only when the
    ! accepted transaction used exactly one committed substep. For an accepted
    ! two-half trajectory it represents only the final half and MUST NOT be
    ! promoted as whole-interval conductive energy. I23 therefore fails closed
    ! on that route until a rollback-safe thermal boundary carrier exists.
    observation = backend%observation()
    thermal_safe = output%accepted_substeps == 1 .and. observation%soil_temperature_active .and. &
         observation%soil_temperature_executed .and. observation%soil_temperature_status == SOIL_TEMP_OK .and. &
         observation%soil_temperature_energy_accounting_complete .and. &
         ieee_is_finite(observation%soil_temperature_boundary_energy_j_cm2) .and. &
         ieee_is_finite(observation%soil_temperature_storage_change_j_cm2) .and. &
         ieee_is_finite(observation%soil_temperature_energy_residual_j_cm2)

    if (thermal_safe) then
      ! Qualified F-PM07B/FMR39 definition:
      ! energy_residual = sensible_storage_change - boundary_energy_into_soil.
      accounting_identity = observation%soil_temperature_storage_change_j_cm2 - &
           observation%soil_temperature_boundary_energy_j_cm2 - observation%soil_temperature_energy_residual_j_cm2
      thermal_safe = close_roundoff(accounting_identity, observation%soil_temperature_boundary_energy_j_cm2, &
           observation%soil_temperature_storage_change_j_cm2, observation%soil_temperature_energy_residual_j_cm2)
    end if

    if (thermal_safe) then
      converted_top = J_CM2_TO_J_M2 * observation%soil_temperature_boundary_energy_j_cm2
      if (ieee_is_finite(converted_top)) then
        publication%top_conductive_available_value = .true.
        publication%top_conductive_into_j_m2_value = converted_top

        ! The qualified restricted-soil-temperature authority explicitly uses
        ! zero bottom conductive heat flux. This is a known modeled zero, not
        ! a missing term repaired to zero.
        publication%bottom_conductive_available_value = .true.
        publication%bottom_conductive_outward_j_m2_value = 0.0_real64
      end if
    end if

    ! No qualified canonical top-water donor-temperature authority exists in
    ! EB-I23. top_advective_available therefore remains false by construction.
    publication%status_value = EB_I23_ACCEPTED_PARTIAL
    publication%initialized = .true.
  end subroutine fmr_execute_column_with_sensible_boundary

  logical function eb_i23_publication_ready(self) result(ready)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    ready = self%initialized .and. self%status_value == EB_I23_ACCEPTED_PARTIAL .and. &
         self%column_id_value > 0_int64 .and. self%lineage_id_value > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value
    if (.not. ready) return
    if (self%top_conductive_available_value) ready = ieee_is_finite(self%top_conductive_into_j_m2_value)
    if (ready .and. self%bottom_conductive_available_value) &
         ready = ieee_is_finite(self%bottom_conductive_outward_j_m2_value)
    if (ready .and. self%bottom_advective_available_value) &
         ready = ieee_is_finite(self%bottom_advective_outward_j_m2_value)
    if (ready .and. self%mass_reference_available_value) &
         ready = ieee_is_finite(self%mass_reference_temperature_c_value)
  end function eb_i23_publication_ready

  integer function eb_i23_publication_status(self) result(value)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    value = self%status_value
  end function eb_i23_publication_status

  integer(int64) function eb_i23_publication_column_id(self) result(value)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%column_id_value
  end function eb_i23_publication_column_id

  integer(int64) function eb_i23_publication_lineage_id(self) result(value)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%lineage_id_value
  end function eb_i23_publication_lineage_id

  integer(int64) function eb_i23_publication_origin_revision(self) result(value)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%origin_revision_value
  end function eb_i23_publication_origin_revision

  integer(int64) function eb_i23_publication_committed_revision(self) result(value)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%committed_revision_value
  end function eb_i23_publication_committed_revision

  subroutine eb_i23_publication_origin_interval(self, t0, t1, available)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
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
  end subroutine eb_i23_publication_origin_interval

  subroutine eb_i23_publication_boundary_snapshot(self, boundary, available)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    type(whole_column_sensible_boundary_t), intent(out) :: boundary
    logical, intent(out) :: available

    boundary = whole_column_sensible_boundary_t()
    available = self%ready()
    if (.not. available) return

    boundary%top_conductive_available = self%top_conductive_available_value
    boundary%top_conductive_into_j_m2 = self%top_conductive_into_j_m2_value
    boundary%top_advective_available = .false.
    boundary%top_advective_into_j_m2 = 0.0_real64
    boundary%bottom_conductive_available = self%bottom_conductive_available_value
    boundary%bottom_conductive_outward_j_m2 = self%bottom_conductive_outward_j_m2_value
    boundary%bottom_advective_available = self%bottom_advective_available_value
    boundary%bottom_advective_outward_j_m2 = self%bottom_advective_outward_j_m2_value
    boundary%mass_carried_reference_available = self%mass_reference_available_value
    boundary%mass_carried_reference_temperature_c = self%mass_reference_temperature_c_value
  end subroutine eb_i23_publication_boundary_snapshot

  logical function eb_i23_runtime_materialization_complete(self) result(complete)
    class(eb_i23_sensible_boundary_publication_t), intent(in) :: self
    type(whole_column_sensible_boundary_t) :: boundary
    logical :: available
    call self%boundary_snapshot(boundary, available)
    complete = available .and. boundary%complete()
  end function eb_i23_runtime_materialization_complete

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

  pure logical function close_roundoff(residual, a, b, c) result(close)
    real(real64), intent(in) :: residual, a, b, c
    real(real64) :: scale
    if (.not. ieee_is_finite(residual) .or. .not. ieee_is_finite(a) .or. &
        .not. ieee_is_finite(b) .or. .not. ieee_is_finite(c)) then
      close = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b), abs(c))
    close = abs(residual) <= 256.0_real64 * epsilon(1.0_real64) * scale
  end function close_roundoff

end module mod_eb_i23_sensible_boundary_runtime