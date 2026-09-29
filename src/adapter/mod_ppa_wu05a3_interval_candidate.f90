! Isolated partial interval proposal; not a production macropore time step.
module mod_ppa_wu05a3_interval_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_macrostate_storage_candidate
  use mod_ppa_wu05a3_macrostate_wetting_candidate
  use mod_ppa_wu05a3_conservative_flux
  use mod_ppa_wu05a3_sorptivity_events
  implicit none
  private
  type,public :: interval_sorptivity_drivers
    integer :: saturated_top=0
    logical,allocatable :: ended(:,:)
    real(real64),allocatable :: proportion(:,:),diameter(:),wall_previous(:)
  end type
  public :: prepare_macropore_interval_candidate
contains
  subroutine prepare_macropore_interval_candidate(checkpoint,dt,volume,qlat,qvrt,exchange,drain,dz, &
      bottom_depth,tolerance,candidate,faces,residual,status,sorptivity,wall_after)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in) :: checkpoint
    real(real64),intent(in) :: dt,volume(:,:),qlat(:),qvrt(:),exchange(:,:),drain(:),dz(:)
    real(real64),intent(in) :: bottom_depth(:),tolerance
    type(ppa_wu05a2_macropore_candidate_t),intent(out) :: candidate
    real(real64),allocatable,intent(out) :: faces(:,:),residual(:)
    integer,intent(out) :: status
    type(interval_sorptivity_drivers),optional,intent(in) :: sorptivity
    real(real64),allocatable,optional,intent(out) :: wall_after(:)
    integer(int32) :: n,nd,stage
    integer(int32),allocatable :: front(:)
    real(real64),allocatable :: storage(:),unsat(:),fraction(:,:),water(:,:),level(:),zeros(:,:),drains(:,:)
    real(real64),allocatable :: event_time(:,:),event_sorp(:,:),event_reference(:,:),wall_event(:),wall_final(:)
    real(real64) :: total
    logical :: ok
    status=FLUX_INVALID
    if(.not.ieee_is_finite(dt) .or. .not.ieee_is_finite(tolerance)) return
    if(dt<=0.0_real64 .or. tolerance<0.0_real64) return
    if(checkpoint%lineage_id<=0 .or. checkpoint%revision<0) return
    if(.not.checkpoint%payload%ready()) return
    n=checkpoint%payload%n_compartments; nd=checkpoint%payload%n_domains
    if(any(shape(volume)/=[nd,n]) .or. any(shape(exchange)/=[nd,n]) .or. &
        size(qlat)/=nd .or. size(qvrt)/=nd .or. size(bottom_depth)/=nd .or. size(drain)/=n .or. size(dz)/=n) return
    allocate(storage(nd),unsat(nd),front(nd),fraction(nd,n),water(nd,n),level(nd),zeros(nd,n),drains(nd,n))
    zeros=0.0_real64; drains=0.0_real64; drains(1,:)=drain
    call ppa_wu05a3_macrostate_storage_candidate(n,nd,1_int32,1_int32,checkpoint%payload%bottom_domain,dt, &
        checkpoint%payload%domain_water_storage,qlat,qvrt,exchange,drain,checkpoint%payload%pore_water, &
        volume,zeros(:,1),storage,unsat,front,total,stage)
    if(stage/=PPA_WU05A3_MACROSTATE_STORAGE_OK) return
    call ppa_wu05a3_macrostate_wetting_candidate(n,nd,1_int32,1_int32,checkpoint%payload%bottom_domain, &
        storage,bottom_depth,volume,dz,zeros,checkpoint%payload%pore_water,fraction,water,front,level,stage)
    if(stage/=PPA_WU05A3_MACROSTATE_WETTING_OK) return
    allocate(faces(nd,n+1),residual(nd))
    call reconstruct_conservative_flux(dt,checkpoint%payload%pore_water,water,exchange,drains,qlat+qvrt, &
        zeros(:,1),tolerance,faces,residual,status)
    if(status/=FLUX_OK) return
    if(present(sorptivity)) then
      status=FLUX_INVALID
      if(.not.allocated(sorptivity%ended) .or. .not.allocated(sorptivity%proportion) .or. &
          .not.allocated(sorptivity%diameter) .or. .not.allocated(sorptivity%wall_previous)) return
      allocate(event_time(nd,n),event_sorp(nd,n),event_reference(nd,n),wall_event(n),wall_final(n))
      call update_sorptivity_events(n,nd,1,sorptivity%saturated_top,1,front,checkpoint%payload%bottom_domain, &
          dt,sorptivity%ended,fraction,sorptivity%proportion,sorptivity%diameter, &
          checkpoint%payload%absorption_time,checkpoint%payload%sorptivity, &
          checkpoint%payload%sorptivity_reference,sorptivity%wall_previous, &
          event_time,event_sorp,event_reference,wall_event,stage)
      if(stage/=0) return
      call refresh_sorptivity_wall(1,volume(1,:),sorptivity%proportion(1,:),dz,wall_event,wall_final,stage)
      if(stage/=0) return
    end if
    call ppa_wu05a2_begin_candidate(checkpoint,candidate,ok)
    if(.not.ok) then
      status=FLUX_INVALID
      return
    end if
    candidate%payload%bottom_domain_previous=checkpoint%payload%bottom_domain
    candidate%payload%pore_volume_previous=checkpoint%payload%pore_volume
    candidate%payload%pore_water_previous=checkpoint%payload%pore_water
    candidate%payload%pore_volume=volume
    candidate%payload%pore_water=water
    candidate%payload%domain_water_storage=storage
    if(present(sorptivity)) then
      candidate%payload%absorption_time=event_time
      candidate%payload%sorptivity=event_sorp
      candidate%payload%sorptivity_reference=event_reference
      candidate%payload%sorptivity_event_ended=sorptivity%ended
    end if
    if(.not.candidate%payload%ready()) then
      call ppa_wu05a2_discard_candidate(candidate)
      status=FLUX_INVALID
      return
    end if
    if(present(sorptivity)) then
      if(.not.all(ieee_is_finite(wall_final))) then
        call ppa_wu05a2_discard_candidate(candidate)
        status=FLUX_INVALID
        return
      end if
      if(present(wall_after)) wall_after=wall_final
    end if
    status=FLUX_OK
  end subroutine
end module
