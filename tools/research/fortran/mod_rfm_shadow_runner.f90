module mod_rfm_shadow_runner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_rfm_research_adapter, only: rfm_research_parameters_t, rfm_surface_hydraulic_input_t, &
       rfm_surface_activation_result_t, rfm_build_surface_hydraulic_input_from_state, &
       rfm_evaluate_unponded_activation, RFM_RESEARCH_AVAILABLE
  implicit none
  private

  integer, parameter, public :: RFM_SHADOW_NOT_RUN = 0
  integer, parameter, public :: RFM_SHADOW_AVAILABLE = 1
  integer, parameter, public :: RFM_SHADOW_UNAVAILABLE = 2

  type, public :: rfm_shadow_reference_receipt_t
     logical :: available = .false.
     real(real64) :: preferential_rate = 0.0_real64
     real(real64) :: deep_receipt_rate = 0.0_real64
     real(real64) :: mean_deposition_depth = 0.0_real64
     character(len=32) :: route = 'not-available'
  end type rfm_shadow_reference_receipt_t

  type, public :: rfm_shadow_result_t
     integer :: status = RFM_SHADOW_NOT_RUN
     type(rfm_surface_activation_result_t) :: rfm
     type(rfm_shadow_reference_receipt_t) :: reference
     real(real64) :: delta_preferential_rate = 0.0_real64
     logical :: delta_available = .false.
     character(len=40) :: route = 'not-run'
  end type rfm_shadow_result_t

  public :: rfm_run_shadow_surface_activation

contains

  subroutine rfm_run_shadow_surface_activation(view, constitutive, parameters, panels, source_rate, event_age, &
                                               reference, result)
    type(process_hydraulic_view_t), intent(in) :: view
    class(constitutive_hydraulics_provider_t), intent(in) :: constitutive
    type(rfm_research_parameters_t), intent(in) :: parameters
    integer, intent(in) :: panels
    real(real64), intent(in) :: source_rate, event_age
    type(rfm_shadow_reference_receipt_t), intent(in), optional :: reference
    type(rfm_shadow_result_t), intent(out) :: result
    type(rfm_surface_hydraulic_input_t) :: input
    logical :: ok

    result = rfm_shadow_result_t()
    if (present(reference)) result%reference = reference

    call rfm_build_surface_hydraulic_input_from_state(view, constitutive, panels, source_rate, event_age, input, ok)
    if (.not. ok) then
       result%status = RFM_SHADOW_UNAVAILABLE
       result%route = 'hydraulic-input-unavailable'
       return
    end if

    call rfm_evaluate_unponded_activation(parameters, input, result%rfm)
    if (result%rfm%status /= RFM_RESEARCH_AVAILABLE) then
       result%status = RFM_SHADOW_UNAVAILABLE
       result%route = trim(result%rfm%route)
       return
    end if

    if (result%reference%available) then
       result%delta_preferential_rate = result%rfm%preferential_rate - result%reference%preferential_rate
       result%delta_available = .true.
    end if

    result%status = RFM_SHADOW_AVAILABLE
    result%route = 'rfm-shadow-sidecar'
  end subroutine rfm_run_shadow_surface_activation

end module mod_rfm_shadow_runner
