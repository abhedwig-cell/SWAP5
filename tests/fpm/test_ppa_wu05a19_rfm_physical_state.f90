program test_ppa_wu05a19_rfm_physical_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rfm_preferential_router, only: rfm_preferential_routing_result_t, RFM_PREF_ROUTER_AVAILABLE
  use mod_rfm_surface_event_age, only: rfm_surface_event_age_result_t, RFM_SURFACE_EVENT_AGE_AVAILABLE
  use mod_rfm_physical_state
  implicit none

  real(real64), parameter :: TOL=1.0e-12_real64
  type(rfm_physical_state_t) :: accepted,snapshot,candidate,replay,copied
  type(rfm_preferential_routing_result_t) :: routing,bad_routing
  type(rfm_surface_event_age_result_t) :: event_age
  type(rfm_candidate_receipt_t) :: receipt,replay_receipt
  logical :: ok

  call accepted%initialize(5,ok)
  call require(ok .and. accepted%ready(),'A19 initialize')
  accepted%mb_water_cm=0.3_real64
  accepted%endpoint_water_cm=[0.1_real64,0.2_real64,0.3_real64,0.4_real64,0.5_real64]
  accepted%tau_surface_day=0.2_real64
  call require(accepted%ready(),'A19 accepted ready')

  call copy_rfm_physical_state(accepted,snapshot,ok)
  call require(ok .and. accepted%same_values(snapshot),'A19 snapshot copy')
  call copy_rfm_physical_state(accepted,copied,ok)
  call require(ok .and. accepted%same_values(copied),'A19 copy identity')
  call require(accepted%payload_bytes()>0,'A19 payload bytes')

  routing%status=RFM_PREF_ROUTER_AVAILABLE
  routing%mb_amount=0.4_real64
  routing%ic_amount=1.6_real64
  allocate(routing%endpoint_amount(5),routing%endpoint_weight(5))
  routing%endpoint_amount=[0.0_real64,1.6_real64,0.0_real64,0.0_real64,0.0_real64]
  routing%endpoint_weight=[0.0_real64,1.0_real64,0.0_real64,0.0_real64,0.0_real64]

  event_age%status=RFM_SURFACE_EVENT_AGE_AVAILABLE
  event_age%evaluation_age_day=0.25_real64
  event_age%candidate_age_day=0.3_real64

  call build_rfm_candidate_from_routing(accepted,routing,event_age,0.1_real64,TOL,candidate,receipt,ok)
  call require(ok .and. receipt%valid,'A19 candidate available')
  call require(accepted%same_values(snapshot),'A19 accepted mutated')
  call require(abs(receipt%mb_input_cm-0.04_real64)<=TOL,'A19 MB integration')
  call require(abs(receipt%ic_input_cm-0.16_real64)<=TOL,'A19 IC integration')
  call require(abs(receipt%preferential_input_cm-0.20_real64)<=TOL,'A19 pref integration')
  call require(abs(receipt%storage_change_cm-0.20_real64)<=TOL,'A19 storage change')
  call require(abs(receipt%mass_residual_cm)<=TOL,'A19 mass residual')
  call require(abs(candidate%mb_water_cm-0.34_real64)<=TOL,'A19 MB state')
  call require(abs(candidate%endpoint_water_cm(2)-0.36_real64)<=TOL,'A19 endpoint state')
  call require(abs(candidate%tau_surface_day-0.3_real64)<=TOL,'A19 tau state')

  call build_rfm_candidate_from_routing(accepted,routing,event_age,0.1_real64,TOL,replay,replay_receipt,ok)
  call require(ok .and. candidate%same_values(replay),'A19 replay state identity')
  call require(abs(receipt%mass_residual_cm-replay_receipt%mass_residual_cm)<=TOL,'A19 replay receipt')

  bad_routing=routing
  deallocate(bad_routing%endpoint_amount)
  allocate(bad_routing%endpoint_amount(4))
  bad_routing%endpoint_amount=0.0_real64
  call build_rfm_candidate_from_routing(accepted,bad_routing,event_age,0.1_real64,TOL,replay,replay_receipt,ok)
  call require(.not.ok,'A19 endpoint mismatch accepted')
  call require(accepted%same_values(snapshot),'A19 mismatch mutated accepted')

  bad_routing=routing
  bad_routing%status=0
  call build_rfm_candidate_from_routing(accepted,bad_routing,event_age,0.1_real64,TOL,replay,replay_receipt,ok)
  call require(.not.ok,'A19 bad routing status')

  event_age%status=0
  call build_rfm_candidate_from_routing(accepted,routing,event_age,0.1_real64,TOL,replay,replay_receipt,ok)
  call require(.not.ok,'A19 bad event age status')

  event_age%status=RFM_SURFACE_EVENT_AGE_AVAILABLE
  call build_rfm_candidate_from_routing(accepted,routing,event_age,0.0_real64,TOL,replay,replay_receipt,ok)
  call require(.not.ok,'A19 zero dt accepted')

  print '(a)', 'PPA_WU05A19_RFM_PHYSICAL_STATE=PASS'

contains

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A19_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a19_rfm_physical_state
