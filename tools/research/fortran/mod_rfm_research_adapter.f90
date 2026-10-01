module mod_rfm_research_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_rfm_surface_sorptivity, only: rfm_evaluate_surface_sorptivity
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  integer, parameter, public :: RFM_RESEARCH_NOT_RUN = 0
  integer, parameter, public :: RFM_RESEARCH_AVAILABLE = 1
  integer, parameter, public :: RFM_RESEARCH_SURFACE_BOUNDARY_REQUIRED = 2
  integer, parameter, public :: RFM_RESEARCH_UNAVAILABLE = 3

  type, public :: rfm_research_parameters_t
     real(real64) :: sigma_b = 0.65_real64
     real(real64) :: f_mb = 0.25_real64
     real(real64) :: connectivity_p = 1.0_real64
     real(real64) :: chi_wall = 1.0_real64
  end type rfm_research_parameters_t

  type, public :: rfm_surface_hydraulic_input_t
     real(real64) :: pressure_head = 0.0_real64
     real(real64) :: water_content = 0.0_real64
     real(real64) :: conductivity = 0.0_real64
     real(real64) :: surface_sorptivity = 0.0_real64
     real(real64) :: source_rate = 0.0_real64
     real(real64) :: event_age = 0.0_real64
     real(real64) :: ponding_depth = 0.0_real64
  end type rfm_surface_hydraulic_input_t

  type, public :: rfm_surface_activation_result_t
     integer :: status = RFM_RESEARCH_NOT_RUN
     real(real64) :: b50 = 0.0_real64
     real(real64) :: matrix_rate = 0.0_real64
     real(real64) :: preferential_rate = 0.0_real64
     real(real64) :: preferential_fraction = 0.0_real64
     character(len=40) :: route = 'not-run'
  end type rfm_surface_activation_result_t

  public :: rfm_build_surface_hydraulic_input
  public :: rfm_build_surface_hydraulic_input_from_state
  public :: rfm_evaluate_unponded_activation
  public :: rfm_connectivity_survival
  public :: rfm_validate_parameters

contains

  subroutine rfm_validate_parameters(parameters, ok)
    type(rfm_research_parameters_t), intent(in) :: parameters
    logical, intent(out) :: ok

    ok = .false.
    if (.not. ieee_is_finite(parameters%sigma_b) .or. parameters%sigma_b <= 0.0_real64) return
    if (.not. ieee_is_finite(parameters%f_mb) .or. parameters%f_mb < 0.0_real64 .or. &
        parameters%f_mb > 1.0_real64) return
    if (.not. ieee_is_finite(parameters%connectivity_p) .or. parameters%connectivity_p <= 0.0_real64) return
    if (.not. ieee_is_finite(parameters%chi_wall) .or. parameters%chi_wall <= 0.0_real64) return
    ok = .true.
  end subroutine rfm_validate_parameters

  subroutine rfm_build_surface_hydraulic_input_from_state(view, constitutive, panels, source_rate, event_age, input, ok)
    type(process_hydraulic_view_t), intent(in) :: view
    class(constitutive_hydraulics_provider_t), intent(in) :: constitutive
    integer, intent(in) :: panels
    real(real64), intent(in) :: source_rate, event_age
    type(rfm_surface_hydraulic_input_t), intent(out) :: input
    logical, intent(out) :: ok
    real(real64) :: surface_sorptivity
    logical :: sorptivity_ok

    input = rfm_surface_hydraulic_input_t()
    ok = .false.
    call rfm_evaluate_surface_sorptivity(view, constitutive, panels, surface_sorptivity, sorptivity_ok)
    if (.not. sorptivity_ok) return
    call rfm_build_surface_hydraulic_input(view, constitutive, surface_sorptivity, source_rate, event_age, input, ok)
  end subroutine rfm_build_surface_hydraulic_input_from_state
  subroutine rfm_build_surface_hydraulic_input(view, constitutive, surface_sorptivity, source_rate, event_age, input, ok)
    type(process_hydraulic_view_t), intent(in) :: view
    class(constitutive_hydraulics_provider_t), intent(in) :: constitutive
    real(real64), intent(in) :: surface_sorptivity, source_rate, event_age
    type(rfm_surface_hydraulic_input_t), intent(out) :: input
    logical, intent(out) :: ok
    logical :: available

    input = rfm_surface_hydraulic_input_t()
    ok = .false.
    if (view%active_nodes <= 0) return
    if (.not. allocated(view%pressure_head) .or. .not. allocated(view%water_content)) return
    if (size(view%pressure_head) < 1 .or. size(view%water_content) < 1) return
    if (.not. ieee_is_finite(surface_sorptivity) .or. surface_sorptivity < 0.0_real64) return
    if (.not. ieee_is_finite(source_rate) .or. source_rate < 0.0_real64) return
    if (.not. ieee_is_finite(event_age) .or. event_age < 0.0_real64) return

    input%pressure_head = view%pressure_head(1)
    input%water_content = view%water_content(1)
    input%surface_sorptivity = surface_sorptivity
    input%source_rate = source_rate
    input%event_age = event_age
    input%ponding_depth = view%ponding_depth

    call constitutive%evaluate_point_conductivity(1, input%pressure_head, input%water_content, &
         input%conductivity, available)
    if (.not. available) return
    if (.not. ieee_is_finite(input%conductivity) .or. input%conductivity < 0.0_real64) return
    ok = .true.
  end subroutine rfm_build_surface_hydraulic_input

  subroutine rfm_evaluate_unponded_activation(parameters, input, result)
    type(rfm_research_parameters_t), intent(in) :: parameters
    type(rfm_surface_hydraulic_input_t), intent(in) :: input
    type(rfm_surface_activation_result_t), intent(out) :: result
    logical :: ok
    real(real64) :: age, mu, log_r, z_trunc, z_tail, truncated_mean

    result = rfm_surface_activation_result_t()
    call rfm_validate_parameters(parameters, ok)
    if (.not. ok) then
       result%status = RFM_RESEARCH_UNAVAILABLE
       result%route = 'invalid-parameters'
       return
    end if

    if (input%ponding_depth > 0.0_real64) then
       result%status = RFM_RESEARCH_SURFACE_BOUNDARY_REQUIRED
       result%route = 'surface-boundary-required'
       return
    end if

    if (input%source_rate <= 0.0_real64) then
       result%status = RFM_RESEARCH_AVAILABLE
       result%route = 'no-positive-source'
       return
    end if

    age = max(input%event_age, 1.0e-12_real64)
    result%b50 = input%conductivity + input%surface_sorptivity / (2.0_real64*sqrt(age))
    if (.not. ieee_is_finite(result%b50) .or. result%b50 <= 0.0_real64) then
       result%status = RFM_RESEARCH_UNAVAILABLE
       result%route = 'invalid-b50'
       return
    end if

    mu = log(result%b50)
    log_r = log(input%source_rate)
    z_trunc = (log_r - mu - parameters%sigma_b**2) / parameters%sigma_b
    z_tail = (log_r - mu) / parameters%sigma_b
    truncated_mean = exp(mu + 0.5_real64*parameters%sigma_b**2) * normal_cdf(z_trunc)
    result%matrix_rate = truncated_mean + input%source_rate*(1.0_real64-normal_cdf(z_tail))
    result%matrix_rate = min(input%source_rate, max(0.0_real64, result%matrix_rate))
    result%preferential_rate = input%source_rate - result%matrix_rate
    result%preferential_fraction = result%preferential_rate / input%source_rate
    result%status = RFM_RESEARCH_AVAILABLE
    result%route = 'rfm-unponded-research'
  end subroutine rfm_evaluate_unponded_activation

  pure real(real64) function rfm_connectivity_survival(depth, z_ah, z_ic, p) result(value)
    real(real64), intent(in) :: depth, z_ah, z_ic, p
    real(real64) :: x

    if (depth <= z_ah) then
       value = 1.0_real64
       return
    end if
    if (depth >= z_ic .or. z_ic <= z_ah .or. p <= 0.0_real64) then
       value = 0.0_real64
       return
    end if
    x = (depth-z_ah)/(z_ic-z_ah)
    value = 1.0_real64 - x**p
  end function rfm_connectivity_survival

  pure real(real64) function normal_cdf(x) result(value)
    real(real64), intent(in) :: x
    value = 0.5_real64*(1.0_real64 + erf(x/sqrt(2.0_real64)))
  end function normal_cdf

end module mod_rfm_research_adapter
