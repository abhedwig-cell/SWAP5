module mod_wofost_two_phase_crop_window
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t, &
       wofost_one_day_rate_packet_t, wofost_one_day_window_context_t, &
       wofost_one_day_diagnostics_t, prepare_wofost_one_day_candidate, &
       finalize_wofost_one_day_candidate, WOFOST_ONE_DAY_OK
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t, &
       assemble_wofost_one_day_rate_state_view, WOFOST_RATE_STATE_VIEW_OK
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_forcing_t, &
       wofost_prepare_assimilation_result_t, prepare_wofost_actual_assimilation, &
       WOFOST_PREPARE_ASSIMILATION_OK
  use mod_wofost_finalize_rates, only: wofost_finalize_rate_forcing_t, &
       finalize_wofost_one_day_rates, WOFOST_FINALIZE_RATES_OK
  implicit none
  private

  integer, parameter, public :: WOFOST_CROP_WINDOW_OK = 0
  integer, parameter, public :: WOFOST_CROP_WINDOW_STRUCTURAL_PREPARE_ERROR = 1
  integer, parameter, public :: WOFOST_CROP_WINDOW_RATE_VIEW_ERROR = 2
  integer, parameter, public :: WOFOST_CROP_WINDOW_PHASE_A_ERROR = 3
  integer, parameter, public :: WOFOST_CROP_WINDOW_CONTEXT_NOT_READY = 4
  integer, parameter, public :: WOFOST_CROP_WINDOW_PHASE_B_ERROR = 5
  integer, parameter, public :: WOFOST_CROP_WINDOW_STRUCTURAL_FINALIZE_ERROR = 6

  type, public :: wofost_two_phase_crop_window_t
    private
    logical :: initialized = .false.
    type(wofost_crop_owner_state_t) :: prepared_candidate
    type(wofost_one_day_window_context_t) :: structural_context
    type(wofost_one_day_rate_state_view_t) :: rate_state_view
    type(wofost_prepare_assimilation_result_t) :: prepared_assimilation
    type(wofost_finalize_rate_forcing_t) :: phase_b_forcing
  contains
    procedure, public :: ready => wofost_crop_window_ready
    procedure, public :: crop_active => wofost_crop_window_crop_active
    procedure, public :: read_prepared_actual_pgass => wofost_crop_window_read_prepared_actual_pgass
    procedure, public :: copy_prepared_candidate => wofost_crop_window_copy_prepared_candidate
  end type wofost_two_phase_crop_window_t

  type, public :: wofost_crop_window_begin_diagnostics_t
    integer :: structural_prepare_status = WOFOST_ONE_DAY_OK
    integer :: rate_state_view_status = WOFOST_RATE_STATE_VIEW_OK
    integer :: phase_a_status = WOFOST_PREPARE_ASSIMILATION_OK
    logical :: prepared_candidate_built = .false.
    logical :: crop_active = .false.
    logical :: rate_state_view_available = .false.
    logical :: phase_a_evaluated = .false.
    real(real64) :: actual_pgass = 0.0_real64
  end type wofost_crop_window_begin_diagnostics_t

  type, public :: wofost_crop_window_complete_diagnostics_t
    integer :: phase_b_status = WOFOST_FINALIZE_RATES_OK
    integer :: structural_finalize_status = WOFOST_ONE_DAY_OK
    logical :: phase_b_evaluated = .false.
    logical :: rate_packet_built = .false.
    logical :: candidate_built = .false.
    type(wofost_one_day_diagnostics_t) :: structural
  end type wofost_crop_window_complete_diagnostics_t

  public :: begin_wofost_one_day_crop_window
  public :: complete_wofost_one_day_crop_window

contains

  subroutine begin_wofost_one_day_crop_window(committed, forcing, t0, t1, &
       stem_area_coefficient, storage_area_coefficient, rate_parameters, &
       window, diagnostics, status)
    type(wofost_crop_owner_state_t), intent(in) :: committed
    type(wofost_one_day_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    real(real64), intent(in) :: stem_area_coefficient
    real(real64), intent(in) :: storage_area_coefficient
    type(wofost_rate_parameter_bundle_t), intent(in) :: rate_parameters
    type(wofost_two_phase_crop_window_t), intent(out) :: window
    type(wofost_crop_window_begin_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    type(wofost_crop_owner_state_t) :: prepared_candidate
    type(wofost_one_day_window_context_t) :: structural_context
    type(wofost_one_day_rate_state_view_t) :: rate_state_view
    type(wofost_prepare_assimilation_forcing_t) :: phase_a_forcing
    type(wofost_prepare_assimilation_result_t) :: prepared_assimilation
    type(wofost_finalize_rate_forcing_t) :: phase_b_forcing
    logical :: view_available
    integer :: component_status

    window = wofost_two_phase_crop_window_t()
    diagnostics = wofost_crop_window_begin_diagnostics_t()
    status = WOFOST_CROP_WINDOW_STRUCTURAL_PREPARE_ERROR

    call prepare_wofost_one_day_candidate(committed, forcing, t0, t1, &
         prepared_candidate, structural_context, component_status)
    diagnostics%structural_prepare_status = component_status
    if (component_status /= WOFOST_ONE_DAY_OK) return
    diagnostics%prepared_candidate_built = .true.
    diagnostics%crop_active = prepared_candidate%crop_is_emerged()

    ! The inactive route is deliberately independent of active-only canopy and
    ! rate parameters. Preserve F-WOF26/F-WOF28 optional-state semantics.
    if (.not. diagnostics%crop_active) then
      window%prepared_candidate = prepared_candidate
      window%structural_context = structural_context
      window%initialized = .true.
      status = WOFOST_CROP_WINDOW_OK
      return
    end if

    call assemble_wofost_one_day_rate_state_view(prepared_candidate, &
         stem_area_coefficient, storage_area_coefficient, rate_state_view, &
         view_available, component_status)
    diagnostics%rate_state_view_status = component_status
    diagnostics%rate_state_view_available = view_available
    if (component_status /= WOFOST_RATE_STATE_VIEW_OK .or. .not. view_available) then
      status = WOFOST_CROP_WINDOW_RATE_VIEW_ERROR
      return
    end if

    phase_a_forcing = wofost_prepare_assimilation_forcing_t()
    phase_a_forcing%daytime_mean_temperature = forcing%daytime_average_temperature
    phase_a_forcing%global_radiation = forcing%global_radiation
    phase_a_forcing%daylength_hours = forcing%daylength_hours
    phase_a_forcing%sine_solar_height_offset = forcing%sinld
    phase_a_forcing%sine_solar_height_amplitude = forcing%cosld
    phase_a_forcing%diffuse_irradiation_perpendicular = forcing%diffuse_perpendicular_radiation
    phase_a_forcing%daily_effective_solar_height = forcing%daily_sine_solar_elevation_integral
    phase_a_forcing%co2_efficiency_factor = forcing%co2_efficiency_factor
    phase_a_forcing%co2_amax_factor = forcing%co2_amax_factor
    phase_a_forcing%running_minimum_temperature = structural_context%running_minimum_temperature

    call prepare_wofost_actual_assimilation(rate_state_view, rate_parameters, &
         phase_a_forcing, prepared_assimilation, component_status)
    diagnostics%phase_a_status = component_status
    if (component_status /= WOFOST_PREPARE_ASSIMILATION_OK) then
      status = WOFOST_CROP_WINDOW_PHASE_A_ERROR
      return
    end if
    diagnostics%phase_a_evaluated = .true.
    diagnostics%actual_pgass = prepared_assimilation%actual_pgass

    phase_b_forcing = wofost_finalize_rate_forcing_t()
    phase_b_forcing%average_temperature = forcing%average_temperature
    phase_b_forcing%photoperiodic_daylength_hours = forcing%photoperiodic_daylength_hours

    window%prepared_candidate = prepared_candidate
    window%structural_context = structural_context
    window%rate_state_view = rate_state_view
    window%prepared_assimilation = prepared_assimilation
    window%phase_b_forcing = phase_b_forcing
    window%initialized = .true.
    status = WOFOST_CROP_WINDOW_OK
  end subroutine begin_wofost_one_day_crop_window

  subroutine complete_wofost_one_day_crop_window(window, rate_parameters, &
       update_parameters, accepted_aggregates, candidate, rates, diagnostics, status)
    type(wofost_two_phase_crop_window_t), intent(in) :: window
    type(wofost_rate_parameter_bundle_t), intent(in) :: rate_parameters
    type(wofost_one_day_update_parameters_t), intent(in) :: update_parameters
    type(wofost_accepted_window_aggregates_t), intent(in) :: accepted_aggregates
    type(wofost_crop_owner_state_t), intent(out) :: candidate
    type(wofost_one_day_rate_packet_t), intent(out) :: rates
    type(wofost_crop_window_complete_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    integer :: component_status

    candidate = wofost_crop_owner_state_t()
    rates = wofost_one_day_rate_packet_t()
    diagnostics = wofost_crop_window_complete_diagnostics_t()
    status = WOFOST_CROP_WINDOW_CONTEXT_NOT_READY
    if (.not. window%ready()) return

    ! A failure below can never expose a partially advanced crop candidate.
    candidate = window%prepared_candidate

    if (window%crop_active()) then
      diagnostics%phase_b_evaluated = .true.
      call finalize_wofost_one_day_rates(window%rate_state_view, rate_parameters, &
           window%prepared_assimilation, accepted_aggregates, window%phase_b_forcing, &
           rates, component_status)
      diagnostics%phase_b_status = component_status
      if (component_status /= WOFOST_FINALIZE_RATES_OK) then
        rates = wofost_one_day_rate_packet_t()
        status = WOFOST_CROP_WINDOW_PHASE_B_ERROR
        return
      end if
      diagnostics%rate_packet_built = .true.
    end if

    call finalize_wofost_one_day_candidate(window%prepared_candidate, &
         window%structural_context, update_parameters, accepted_aggregates, rates, &
         candidate, diagnostics%structural, component_status)
    diagnostics%structural_finalize_status = component_status
    if (component_status /= WOFOST_ONE_DAY_OK) then
      candidate = window%prepared_candidate
      status = WOFOST_CROP_WINDOW_STRUCTURAL_FINALIZE_ERROR
      return
    end if

    diagnostics%candidate_built = diagnostics%structural%candidate_built
    status = WOFOST_CROP_WINDOW_OK
  end subroutine complete_wofost_one_day_crop_window

  logical function wofost_crop_window_ready(self) result(ready)
    class(wofost_two_phase_crop_window_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (self%prepared_candidate%validate() /= WOFOST_CROP_OWNER_OK) return
    ready = .true.
  end function wofost_crop_window_ready

  logical function wofost_crop_window_crop_active(self) result(active)
    class(wofost_two_phase_crop_window_t), intent(in) :: self

    active = .false.
    if (.not. self%ready()) return
    active = self%prepared_candidate%crop_is_emerged()
  end function wofost_crop_window_crop_active

  subroutine wofost_crop_window_read_prepared_actual_pgass(self, value, available)
    class(wofost_two_phase_crop_window_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    value = 0.0_real64
    available = .false.
    if (.not. self%ready()) return
    if (.not. self%crop_active()) return
    value = self%prepared_assimilation%actual_pgass
    available = .true.
  end subroutine wofost_crop_window_read_prepared_actual_pgass

  subroutine wofost_crop_window_copy_prepared_candidate(self, candidate, available)
    class(wofost_two_phase_crop_window_t), intent(in) :: self
    type(wofost_crop_owner_state_t), intent(out) :: candidate
    logical, intent(out) :: available

    candidate = wofost_crop_owner_state_t()
    available = .false.
    if (.not. self%ready()) return
    candidate = self%prepared_candidate
    available = .true.
  end subroutine wofost_crop_window_copy_prepared_candidate

end module mod_wofost_two_phase_crop_window
