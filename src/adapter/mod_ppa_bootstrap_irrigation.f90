! Serialized application composition. Snapshots are read-only inputs, never owners.
module mod_ppa_bootstrap_irrigation
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_bootstrap_t, &
       FMR_APP_BOOT_OK,FMR_APP_BOOT_INVALID_CONFIG
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t
  use mod_fmr_serialized_reference_backend, only: ppa_irrigation_event_state_t,fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t,scheduled_irrigation_request_t, &
       irrigation_state_t,irrigation_flux_result_t,irrigation_diagnostics_t,IRRIGATION_EVENT_SCHEDULED, &
       IRRIGATION_DEPTH_DCS2_FIXED
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irrigation_source_binding, only: evaluate_ppa_irrigation_source
  implicit none
  private
  public :: execute_ppa_bootstrap_irrigation
contains
  subroutine execute_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,requests, &
       previous,results,status)
    type(fmr_production_application_bootstrap_t),intent(inout)::application
    integer(int64),intent(in)::column_ids(:),parameter_identity
    type(scheduled_irrigation_parameters_t),intent(in)::parameters(:)
    type(scheduled_irrigation_request_t),intent(in)::requests(:)
    type(fmr_b110_physical_forcing_t),intent(in)::previous(:)
    type(fmr_serialized_column_result_t),allocatable,intent(out)::results(:)
    integer,intent(out)::status
    type(fmr_committed_restart_bundle_t)::snapshot
    type(fmr_b110_physical_forcing_t),allocatable::prepared(:),forcing
    type(irrigation_state_t),allocatable::events(:)
    logical,allocatable::selected(:)
    type(irrigation_state_t)::event
    type(irrigation_flux_result_t)::flux
    type(irrigation_diagnostics_t)::diagnostics
    type(process_hydraulic_view_t)::hydraulic
    integer::n,i,export_status
    real(real64)::t0,t1
    logical::ok
    status=FMR_APP_BOOT_INVALID_CONFIG
    n=size(column_ids)
    if(n<1.or.size(parameters)/=n.or.size(requests)/=n.or.size(previous)/=n) return
    t0=requests(1)%t0; t1=requests(1)%t1
    if(.not.all(ieee_is_finite([t0,t1]))) return
    if(t1<=t0) return
    do i=1,n
      if(parameters(i)%depth_criterion/=IRRIGATION_DEPTH_DCS2_FIXED) return
      if(.not.all(ieee_is_finite([requests(i)%t0,requests(i)%t1]))) return
      if(requests(i)%t0/=t0.or.requests(i)%t1/=t1) return
    end do
    call application%export_committed_restart(parameter_identity,snapshot,ok,export_status)
    if(.not.ok.or.export_status/=FMR_APP_BOOT_OK) return
    if(.not.allocated(snapshot%records)) return
    if(size(snapshot%records)/=n) return
    allocate(prepared(n),events(n),selected(n))
    do i=1,n
      if(snapshot%records(i)%column_id/=column_ids(i)) return
      if(.not.snapshot%records(i)%time_bound) return
      if(snapshot%records(i)%committed_time/=t0) return
      if(.not.allocated(snapshot%records(i)%physical_state)) return
      select type(state=>snapshot%records(i)%physical_state)
      type is(ppa_irrigation_event_state_t)
        if(.not.state%matches_candidate(snapshot%records(i)%template_identity,t0)) return
        if(parameters(i)%active_nodes/=state%active_nodes) return
        hydraulic%active_nodes=state%active_nodes
        hydraulic%pressure_head=state%pressure_head
        hydraulic%water_content=state%water_content
        call evaluate_ppa_irrigation_source(parameters(i),state%irrigation,requests(i),hydraulic,previous(i), &
             event,flux,diagnostics,forcing,ok)
      class default
        return
      end select
      if(.not.ok) return
      prepared(i)=forcing
      events(i)=event
      selected(i)=flux%event_started
      if(selected(i)) then
        ! The process output can already be cleared at t1; inject its checked
        ! start metadata into the hydraulic trial, not the committed snapshot.
        events(i)%active_event=.true.
        events(i)%active_event_origin=IRRIGATION_EVENT_SCHEDULED
        events(i)%active_event_index=0
        events(i)%active_event_start=t0
        events(i)%active_event_end=t0+flux%event_duration
        events(i)%active_event_rate=flux%subsurface_source(parameters(i)%single_ssdi_node)
      end if
    end do
    call application%run_prepared_irrigation(t0,t1,prepared,results,status,events,selected)
  end subroutine execute_ppa_bootstrap_irrigation
end module mod_ppa_bootstrap_irrigation
