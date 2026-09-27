module mod_ppa_irr_tcsfix_source
  use mod_irrigation_process
  use mod_ppa_irr_tcsfix_composition, only: evaluate_tcsfix_scheduled
  use mod_ppa_irr_tcs1_4_source, only: ppa_tcs1_4_observations_t
  use mod_ppa_irrigation_source_binding, only: bind_ppa_irrigation_source
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  public :: evaluate_tcsfix_source
contains
  subroutine evaluate_tcsfix_source(p,base,r,observations,daily,dayfix,interval_days,previous, &
       proposed_dayfix,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::p
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::r
    type(ppa_tcs1_4_observations_t),intent(in)::observations
    logical,intent(in)::daily
    integer,intent(in)::dayfix,interval_days
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    integer,intent(out)::proposed_dayfix
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    integer::next_day
    type(irrigation_state_t)::event
    type(irrigation_flux_result_t)::next_flux
    proposed_dayfix=dayfix; candidate=base; flux=irrigation_flux_result_t(); ok=.false.
    call evaluate_tcsfix_scheduled(p,base,r,observations%dvs_knots,observations%threshold_values, &
         observations%knot_count,observations%iptra_day,observations%iqreddry_day,observations%iqredsol_day, &
         observations%awlh,observations%awmh,observations%awah,daily,dayfix,interval_days, &
         next_day,event,next_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,next_flux,diagnostics,r%t0,forcing,ok)
    if(.not.ok) return
    proposed_dayfix=next_day; candidate=event; flux=next_flux
  end subroutine
end module
