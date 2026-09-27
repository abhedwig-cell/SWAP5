module mod_ppa_irr_tcs1_4_source
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process
  use mod_ppa_irr_tcs1_4_composition, only: evaluate_tcs1_4_scheduled
  use mod_ppa_irr_tcs1_4_dcs1, only: evaluate_tcs1_4_dcs1_profile
  use mod_ppa_irrigation_source_binding, only: bind_ppa_irrigation_source,ppa_irrigation_profile_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_water_deficit, only: evaluate_root_zone_water_deficit_checked,IRR_DEFICIT_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  public :: evaluate_tcs1_4_source
  public :: evaluate_tcs2_4_profile_source
  public :: evaluate_tcs1_4_dcs1_source
  type,public :: ppa_tcs1_4_observations_t
    integer :: knot_count=0
    real(real64) :: dvs_knots(7)=0.0_real64,threshold_values(7)=0.0_real64
    real(real64) :: iptra_day=0.0_real64,iqreddry_day=0.0_real64,iqredsol_day=0.0_real64
    real(real64) :: awlh=0.0_real64,awmh=0.0_real64,awah=0.0_real64
  end type
contains
  subroutine evaluate_tcs1_4_dcs1_source(parameters,base,request,observations,hydraulic,profile, &
       previous,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(ppa_tcs1_4_observations_t),intent(in)::observations
    type(process_hydraulic_view_t),intent(in)::hydraulic
    type(ppa_irrigation_profile_t),intent(in)::profile
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(ppa_irrigation_profile_t)::supplied
    type(irrigation_state_t)::proposed
    type(irrigation_flux_result_t)::proposed_flux
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t(); ok=.false.
    ! Empty arrays safely reach the checked process on selection and are unused
    ! for pending/nonselection. Never dereference an unallocated profile field.
    supplied=profile
    if(.not.allocated(supplied%layer)) allocate(supplied%layer(0))
    if(.not.allocated(supplied%dz)) allocate(supplied%dz(0))
    if(.not.allocated(supplied%ztopcp)) allocate(supplied%ztopcp(0))
    if(.not.allocated(supplied%wclos)) allocate(supplied%wclos(0))
    if(.not.allocated(supplied%wcmes)) allocate(supplied%wcmes(0))
    if(.not.allocated(supplied%wchis)) allocate(supplied%wchis(0))
    call evaluate_tcs1_4_dcs1_profile(parameters,base,request,hydraulic,supplied%noddrz,supplied%layer, &
         supplied%dz,supplied%ztopcp,supplied%rd,supplied%wclos,supplied%wcmes,supplied%wchis, &
         observations%dvs_knots,observations%threshold_values,observations%knot_count,observations%iptra_day, &
         observations%iqreddry_day,observations%iqredsol_day,proposed,proposed_flux,diagnostics)
    if(diagnostics%status/=IRRIGATION_OK) return
    call bind_ppa_irrigation_source(previous,proposed_flux,diagnostics,request%t0,forcing,ok)
    if(.not.ok) return
    candidate=proposed; flux=proposed_flux
  end subroutine

  subroutine evaluate_tcs2_4_profile_source(parameters,base,request,observations,hydraulic,profile, &
       previous,candidate,flux,diagnostics,forcing,ok)
    type(scheduled_irrigation_parameters_t),intent(in)::parameters
    type(irrigation_state_t),intent(in)::base
    type(scheduled_irrigation_request_t),intent(in)::request
    type(ppa_tcs1_4_observations_t),intent(in)::observations
    type(process_hydraulic_view_t),intent(in)::hydraulic
    type(ppa_irrigation_profile_t),intent(in)::profile
    type(fmr_b110_physical_forcing_t),intent(in)::previous
    type(irrigation_state_t),intent(out)::candidate
    type(irrigation_flux_result_t),intent(out)::flux
    type(irrigation_diagnostics_t),intent(out)::diagnostics
    type(fmr_b110_physical_forcing_t),allocatable,intent(out)::forcing
    logical,intent(out)::ok
    type(ppa_tcs1_4_observations_t)::derived
    real(real64)::deficit
    integer::code
    candidate=base; flux=irrigation_flux_result_t(); diagnostics=irrigation_diagnostics_t(); ok=.false.
    diagnostics%status=IRRIGATION_INVALID_PARAMETERS
    if(parameters%timing_criterion<2.or.parameters%timing_criterion>4) return
    derived=observations
    if(.not.base%active_event.and.parameters%scheduled_irrigation_enabled.and.request%selection_opportunity.and. &
         request%irrigation_enabled.and.request%schedule_enabled.and.request%crop_emerged.and. &
         request%irrigation_window_open.and..not.request%fixed_event_already_selected) then
      if(.not.allocated(profile%layer).or..not.allocated(profile%dz).or..not.allocated(profile%ztopcp).or. &
           .not.allocated(profile%wclos).or..not.allocated(profile%wcmes).or..not.allocated(profile%wchis)) return
      diagnostics%status=IRRIGATION_INVALID_HYDRAULIC_VIEW
      if(hydraulic%active_nodes/=parameters%active_nodes.or.hydraulic%active_nodes<1) return
      if(.not.allocated(hydraulic%water_content)) return
      if(size(hydraulic%water_content)/=hydraulic%active_nodes) return
      diagnostics%status=IRRIGATION_INVALID_PARAMETERS
      if(profile%noddrz>hydraulic%active_nodes) return
      call evaluate_root_zone_water_deficit_checked(profile%noddrz,profile%layer,profile%dz,profile%ztopcp, &
           profile%rd,profile%wclos,profile%wcmes,profile%wchis,hydraulic%water_content, &
           derived%awlh,derived%awmh,derived%awah,deficit,code)
      if(code/=IRR_DEFICIT_OK) return
    end if
    call evaluate_tcs1_4_source(parameters,base,request,derived,previous,candidate,flux,diagnostics,forcing,ok)
  end subroutine

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
