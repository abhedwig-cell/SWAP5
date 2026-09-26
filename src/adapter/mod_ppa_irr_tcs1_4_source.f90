module mod_ppa_irr_tcs1_4_source
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_ppa_irr_tcs1_4_composition, only: evaluate_tcs1_4_scheduled
  use mod_ppa_irrigation_source_binding, only: bind_ppa_irrigation_source
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  public :: evaluate_tcs1_4_source
  type,public :: ppa_tcs1_4_observations_t
    integer :: knot_count=0
    real(real64) :: dvs_knots(7)=0.0_real64,threshold_values(7)=0.0_real64
    real(real64) :: iptra_day=0.0_real64,iqreddry_day=0.0_real64,iqredsol_day=0.0_real64
    real(real64) :: awlh=0.0_real64,awmh=0.0_real64,awah=0.0_real64
  end type
contains
  subroutine evaluate_tcs1_4_source(parameters,base,request,observations,previous,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(ppa_tcs1_4_observations_t),intent(in)::observations
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(irrigation_state_t)::proposed
    type(irrigation_flux_result_t)::proposed_flux
    candidate=base; flux=irrigation_flux_result_t(); ok=.false.
    call evaluate_tcs1_4_scheduled(parameters,base,request,observations%dvs_knots, &
         observations%threshold_values,observations%knot_count,observations%iptra_day, &
         observations%iqreddry_day,observations%iqredsol_day,observations%awlh,observations%awmh, &
         observations%awah,proposed,proposed_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,proposed_flux,diagnostics,request%t0,forcing,ok)
    if(.not.ok) return
    candidate=proposed; flux=proposed_flux
  end subroutine
end module
