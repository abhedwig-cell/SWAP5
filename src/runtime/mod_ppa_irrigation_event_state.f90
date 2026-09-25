! Candidate carrier only: not registered for production dispatch or restart.
module mod_ppa_irrigation_event_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_temporal_indicator_state_t
  use mod_irrigation_process, only: irrigation_state_t, IRRIGATION_EVENT_SCHEDULED, IRRIGATION_EVENT_NONE
  implicit none
  private
  public :: ppa_irrigation_event_state_t
  public :: build_irrigation_event_candidate
  ! Reserved candidate identity, intentionally absent from production's known-layout registry.
  integer(int64), parameter, public :: PPA_IRRIGATION_EVENT_LAYOUT=404101_int64

  type, extends(fmr_b110_temporal_indicator_state_t) :: ppa_irrigation_event_state_t
    type(irrigation_state_t) :: irrigation
  contains
    procedure :: clone => clone_irrigation_event_state
    procedure :: matches_candidate => irrigation_event_matches_candidate
  end type
contains
  subroutine build_irrigation_event_candidate(physical,event,template,boundary_time,candidate,ok)
    ! Combine trial outputs only. The caller must supply the hydraulic state
    ! and event from the same boundary; this routine neither proves hydraulic
    ! acceptance nor publishes committed state or changes the runtime registry.
    type(fmr_b110_temporal_indicator_state_t), intent(in) :: physical
    type(irrigation_state_t), intent(in) :: event
    type(fmr_template_t), intent(in) :: template
    real(real64), intent(in) :: boundary_time
    type(ppa_irrigation_event_state_t), allocatable, intent(out) :: candidate
    logical, intent(out) :: ok
    type(ppa_irrigation_event_state_t) :: proposed
    proposed%fmr_b110_temporal_indicator_state_t=physical
    proposed%irrigation=event
    ok=proposed%matches_candidate(template,boundary_time)
    if(.not.ok) return
    allocate(candidate,source=proposed)
  end subroutine

  logical function irrigation_event_matches_candidate(self,template,committed_time) result(matches)
    class(ppa_irrigation_event_state_t), intent(in) :: self
    type(fmr_template_t), intent(in) :: template
    real(real64), intent(in) :: committed_time
    real(real64), allocatable :: history(:)
    logical :: available
    matches=.false.
    if(template%optional_state_layout_id/=PPA_IRRIGATION_EVENT_LAYOUT) return
    if(template%compatible_backend_id/=FMR_BACKEND_SERIALIZED_REFERENCE) return
    if(template%numerical_continuation_layout_id/=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) return
    if(.not.ieee_is_finite(committed_time)) return
    if(self%active_nodes<1) return
    if(.not.ieee_is_finite(self%ponding_depth).or..not.ieee_is_finite(self%groundwater_level)) return
    if(allocated(self%snow).or.allocated(self%soil_temperature)) return
    if(.not.allocated(self%pressure_head).or..not.allocated(self%water_content)) return
    if(size(self%pressure_head)/=self%active_nodes.or.size(self%water_content)/=self%active_nodes) return
    if(.not.all(ieee_is_finite(self%pressure_head)).or..not.all(ieee_is_finite(self%water_content))) return
    call self%temporal_history_snapshot(history,available)
    if(.not.available) return
    if(.not.allocated(history)) return
    if(size(history)/=self%active_nodes) return
    if(.not.all(ieee_is_finite(history))) return
    if(self%irrigation%next_fixed_event_index<1) return
    if(self%irrigation%active_event) then
      if(self%irrigation%active_event_origin/=IRRIGATION_EVENT_SCHEDULED) return
      if(self%irrigation%active_event_index/=0) return
      if(.not.ieee_is_finite(self%irrigation%active_event_start)) return
      if(.not.ieee_is_finite(self%irrigation%active_event_end)) return
      if(.not.ieee_is_finite(self%irrigation%active_event_rate)) return
      if(self%irrigation%active_event_rate<=0.0_real64) return
      if(self%irrigation%active_event_end<=self%irrigation%active_event_start) return
      if(self%irrigation%active_event_end>self%irrigation%active_event_start+1.0_real64) return
      if(committed_time<self%irrigation%active_event_start.or.committed_time>=self%irrigation%active_event_end) return
    else
      if(self%irrigation%active_event_origin/=IRRIGATION_EVENT_NONE.or.self%irrigation%active_event_index/=0) return
    end if
    matches=.true.
  end function
  subroutine clone_irrigation_event_state(self,copy)
    class(ppa_irrigation_event_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    ! Intrinsic sourced allocation retains inherited private temporal history,
    ! dynamic type and deep copies of allocatable physical arrays.
    allocate(copy,source=self)
  end subroutine
end module
