! Compatibility facade: the carrier is owned beside its temporal parent.
! It remains unregistered for production dispatch and restart.
module mod_ppa_irrigation_event_state
  use mod_fmr_serialized_reference_backend, only: ppa_irrigation_event_state_t, &
       PPA_IRRIGATION_EVENT_LAYOUT, build_irrigation_event_candidate
  implicit none
  private
  public :: ppa_irrigation_event_state_t, PPA_IRRIGATION_EVENT_LAYOUT, build_irrigation_event_candidate
end module
