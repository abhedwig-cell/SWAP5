module mod_fmr_rfm_activation_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, validate_process_hydraulic_view
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_rfm_surface_sorptivity, only: evaluate_rfm_surface_sorptivity
  use mod_rfm_unponded_activation, only: rfm_unponded_activation_request_t, &
       rfm_unponded_activation_result_t, evaluate_rfm_unponded_activation
  implicit none
  private

  type, public :: fmr_rfm_hydraulic_activation_result_t
    logical :: hydraulic_available = .false.
    real(real64) :: surface_conductivity_cm_per_day = 0.0_real64
    real(real64) :: surface_sorptivity_cm_sqrt_day = 0.0_real64
    type(rfm_unponded_activation_result_t) :: activation
  end type fmr_rfm_hydraulic_activation_result_t

  public :: evaluate_fmr_rfm_activation_from_view

contains

  subroutine evaluate_fmr_rfm_activation_from_view(view,constitutive,panels,sigma_b,source_rate,event_age,result,ok, &
       precomputed_conductivity,precomputed_sorptivity)
    type(process_hydraulic_view_t), intent(in) :: view
    class(constitutive_hydraulics_provider_t), intent(in) :: constitutive
    integer, intent(in) :: panels
    real(real64), intent(in) :: sigma_b,source_rate,event_age
    type(fmr_rfm_hydraulic_activation_result_t), intent(out) :: result
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: precomputed_conductivity,precomputed_sorptivity

    type(rfm_unponded_activation_request_t) :: request
    real(real64) :: conductivity,sorptivity
    logical :: view_ok, conductivity_available, sorptivity_ok

    result = fmr_rfm_hydraulic_activation_result_t()
    ok = .false.

    call validate_process_hydraulic_view(view,view_ok)
    if (.not. view_ok) return
    if (panels <= 0) return
    if (.not. ieee_is_finite(sigma_b) .or. sigma_b <= 0.0_real64) return
    if (.not. ieee_is_finite(source_rate) .or. source_rate < 0.0_real64) return
    if (.not. ieee_is_finite(event_age) .or. event_age < 0.0_real64) return

    if (present(precomputed_conductivity) .neqv. present(precomputed_sorptivity)) return
    if (present(precomputed_conductivity)) then
      conductivity=precomputed_conductivity
      sorptivity=precomputed_sorptivity
      if (.not. ieee_is_finite(conductivity) .or. conductivity < 0.0_real64) return
      if (.not. ieee_is_finite(sorptivity) .or. sorptivity < 0.0_real64) return
    else
      call constitutive%evaluate_point_conductivity(1,view%pressure_head(1),view%water_content(1), &
           conductivity,conductivity_available)
      if (.not. conductivity_available) return
      if (.not. ieee_is_finite(conductivity) .or. conductivity < 0.0_real64) return
      call evaluate_rfm_surface_sorptivity(view,constitutive,panels,sorptivity,sorptivity_ok)
      if (.not. sorptivity_ok) return
    end if

    request%sigma_b = sigma_b
    request%matrix_conductivity_cm_per_day = conductivity
    request%surface_sorptivity_cm_sqrt_day = sorptivity
    request%source_rate_cm_per_day = source_rate
    request%event_age_day = event_age
    request%ponding_depth_cm = view%ponding_depth

    result%surface_conductivity_cm_per_day = conductivity
    result%surface_sorptivity_cm_sqrt_day = sorptivity
    result%hydraulic_available = .true.
    call evaluate_rfm_unponded_activation(request,result%activation)
    ok = .true.
  end subroutine evaluate_fmr_rfm_activation_from_view

end module mod_fmr_rfm_activation_binding
