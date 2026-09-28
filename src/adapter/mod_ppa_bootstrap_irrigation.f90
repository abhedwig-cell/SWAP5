! Serialized application composition. Snapshots are read-only inputs, never owners.
module mod_ppa_bootstrap_irrigation
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_bootstrap_t, &
       FMR_APP_BOOT_OK,FMR_APP_BOOT_INVALID_CONFIG
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t
  use mod_fmr_serialized_reference_backend, only: ppa_irrigation_event_state_t,fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_irrigation_process, only: scheduled_irrigation_parameters_t,scheduled_irrigation_request_t, &
       irrigation_state_t,irrigation_flux_result_t,irrigation_diagnostics_t,IRRIGATION_EVENT_SCHEDULED, &
       IRRIGATION_DEPTH_DCS2_FIXED,IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_ppa_irr_tcs1_4_source, only: evaluate_tcs1_4_source,ppa_tcs1_4_observations_t,evaluate_tcs2_4_profile_source
  use mod_ppa_irr_tcs1_4_source, only: evaluate_tcs1_4_dcs1_source
  use mod_ppa_irr_tcs6_source, only: ppa_tcs6_daily_input_t,evaluate_tcs6_source
  use mod_ppa_irr_tcs6_source, only: evaluate_tcs6_profile_source
  use mod_irrigation_process, only: ppa_weekly_identity_t
  use mod_irrigation_process, only: ppa_tcsfix_identity_t
  use mod_ppa_irr_tcsfix_source, only: ppa_tcsfix_daily_input_t,evaluate_tcsfix_daily_source
  use mod_ppa_irrigation_source_binding, only: evaluate_ppa_irrigation_source, &
       evaluate_ppa_profile_irrigation_source,ppa_irrigation_profile_t
  implicit none
  private
  public :: execute_ppa_bootstrap_irrigation
  public :: execute_next_ppa_bootstrap_irrigation
  public :: execute_window_ppa_bootstrap_irrigation
  integer,parameter,public :: PPA_IRR_WINDOW_BUDGET_EXHAUSTED=-1
  type,public :: ppa_irrigation_prefix_result_t
    real(real64) :: interval_end=0.0_real64
    type(fmr_serialized_column_result_t),allocatable :: columns(:)
  end type
  type,public :: ppa_irrigation_preparation_t
    logical :: process_evaluated=.false.
    logical :: source_prepared=.false.
    type(irrigation_diagnostics_t) :: process
  end type
contains
  ! Caller guarantees non-irrigation forcing and supplied configuration remain
  ! constant over this window. Each prefix publishes independently.
  subroutine execute_window_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,requests, &
       previous,max_prefixes,prefixes,prefix_count,status,profiles,observations,weekly_inputs,target_selector, &
       weekly_profile_mode)
    type(fmr_production_application_bootstrap_t),intent(inout)::application
    integer(int64),intent(in)::column_ids(:),parameter_identity
    type(scheduled_irrigation_parameters_t),intent(in)::parameters(:)
    type(scheduled_irrigation_request_t),intent(in)::requests(:)
    type(fmr_b110_physical_forcing_t),intent(in)::previous(:)
    integer,intent(in)::max_prefixes
    logical,intent(in),optional::weekly_profile_mode(:)
    type(ppa_irrigation_prefix_result_t),allocatable,intent(out)::prefixes(:)
    integer,intent(out)::prefix_count,status
    type(ppa_irrigation_profile_t),intent(in),optional::profiles(:)
    type(ppa_tcs1_4_observations_t),intent(in),optional::observations(:)
    type(scheduled_irrigation_request_t),allocatable::remaining(:)
    type(ppa_tcs6_daily_input_t),intent(in),optional::weekly_inputs(:)
    procedure(canonical_subinterval_target_selector),optional::target_selector
    type(fmr_b110_physical_forcing_t),allocatable::last_forcing(:),effective(:)
    real(real64)::endpoint,target
    integer::k
    status=FMR_APP_BOOT_INVALID_CONFIG; prefix_count=0
    if(max_prefixes<1.or.size(requests)<1) return
    remaining=requests; last_forcing=previous; target=requests(1)%t1
    allocate(prefixes(max_prefixes))
    do k=1,max_prefixes
      call execute_next_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,remaining, &
           last_forcing,prefixes(k)%columns,status,endpoint,profiles,effective,observations,weekly_inputs,target_selector, &
           weekly_profile_mode)
      prefixes(k)%interval_end=endpoint
      prefix_count=k
      if(status/=FMR_APP_BOOT_OK) return
      if(endpoint==target) return
      ! A successful prefix is durable even if a later prefix fails or budget
      ! runs out. Do not repeat the original selection opportunity.
      last_forcing=effective
      remaining%t0=endpoint
      remaining%selection_opportunity=.false.
    end do
    status=PPA_IRR_WINDOW_BUDGET_EXHAUSTED
  end subroutine

  ! Execute at most one accepted-for-preparation prefix, never a whole-window
  ! loop. A returned endpoint is an attempt boundary, not proof of commitment.
  subroutine execute_next_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,requests, &
       previous,results,status,interval_end,profiles,effective_forcing,observations,weekly_inputs,target_selector, &
       weekly_profile_mode)
    type(fmr_production_application_bootstrap_t),intent(inout)::application
    integer(int64),intent(in)::column_ids(:),parameter_identity
    type(scheduled_irrigation_parameters_t),intent(in)::parameters(:)
    type(scheduled_irrigation_request_t),intent(in)::requests(:)
    type(fmr_b110_physical_forcing_t),intent(in)::previous(:)
    type(fmr_serialized_column_result_t),allocatable,intent(out)::results(:)
    integer,intent(out)::status
    real(real64),intent(out)::interval_end
    logical,intent(in),optional::weekly_profile_mode(:)
    type(ppa_irrigation_profile_t),intent(in),optional::profiles(:)
    type(ppa_tcs1_4_observations_t),intent(in),optional::observations(:)
    type(fmr_b110_physical_forcing_t),allocatable,intent(out),optional::effective_forcing(:)
    type(scheduled_irrigation_request_t),allocatable::trial_requests(:)
    type(ppa_tcs6_daily_input_t),intent(in),optional::weekly_inputs(:)
    procedure(canonical_subinterval_target_selector),optional::target_selector
    type(ppa_irrigation_preparation_t),allocatable::report(:)
    integer::attempt,i
    real(real64)::split
    logical::found
    status=FMR_APP_BOOT_INVALID_CONFIG
    interval_end=0.0_real64
    if(size(requests)<1) return
    interval_end=requests(1)%t1
    trial_requests=requests
    do attempt=1,size(column_ids)+1
      call execute_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,trial_requests, &
           previous,results,status,profiles,report,effective_forcing,observations,weekly_inputs,target_selector, &
           weekly_profile_mode)
      ! Any hydraulic execution is terminal, including mixed publication.
      if(allocated(results).or.status/=FMR_APP_BOOT_INVALID_CONFIG) return
      if(.not.allocated(report)) return
      found=.false.
      do i=1,size(report)
        if(.not.report(i)%process_evaluated.or.report(i)%source_prepared) cycle
        if(.not.report(i)%process%split_required) return
        split=report(i)%process%split_time
        if(.not.ieee_is_finite(split)) return
        if(split<=requests(1)%t0.or.split>=interval_end) return
        found=.true.
        exit
      end do
      if(.not.found.or.attempt==size(column_ids)+1) return
      interval_end=split
      trial_requests%t1=split
    end do
  end subroutine execute_next_ppa_bootstrap_irrigation

  subroutine execute_ppa_bootstrap_irrigation(application,column_ids,parameter_identity,parameters,requests, &
       previous,results,status,profiles,preparation,effective_forcing,observations,weekly_inputs,target_selector, &
       weekly_profile_mode,tcsfix_inputs)
    type(fmr_production_application_bootstrap_t),intent(inout)::application
    integer(int64),intent(in)::column_ids(:),parameter_identity
    type(scheduled_irrigation_parameters_t),intent(in)::parameters(:)
    type(scheduled_irrigation_request_t),intent(in)::requests(:)
    type(fmr_b110_physical_forcing_t),intent(in)::previous(:)
    type(fmr_serialized_column_result_t),allocatable,intent(out)::results(:)
    integer,intent(out)::status
    type(ppa_irrigation_profile_t),intent(in),optional::profiles(:)
    type(ppa_irrigation_preparation_t),allocatable,intent(out),optional::preparation(:)
    logical,intent(in),optional::weekly_profile_mode(:)
    type(ppa_tcs1_4_observations_t),intent(in),optional::observations(:)
    type(fmr_b110_physical_forcing_t),allocatable,intent(out),optional::effective_forcing(:)
    type(fmr_committed_restart_bundle_t)::snapshot
    type(ppa_tcs6_daily_input_t),intent(in),optional::weekly_inputs(:)
    procedure(canonical_subinterval_target_selector),optional::target_selector
    type(ppa_weekly_identity_t),allocatable::weekly_proposals(:)
    type(ppa_tcsfix_daily_input_t),intent(in),optional::tcsfix_inputs(:)
    type(ppa_tcsfix_identity_t),allocatable::tcsfix_proposals(:)
    type(fmr_b110_physical_forcing_t),allocatable::prepared(:),forcing
    type(irrigation_state_t),allocatable::events(:)
    logical,allocatable::selected(:)
    type(irrigation_state_t)::event
    type(irrigation_flux_result_t)::flux
    type(irrigation_diagnostics_t)::diagnostics
    type(process_hydraulic_view_t)::hydraulic
    integer::n,i,export_status
    real(real64)::t0,t1
    logical::ok,derive_weekly,use_tcsfix
    status=FMR_APP_BOOT_INVALID_CONFIG
    n=size(column_ids)
    if(n<1.or.size(parameters)/=n.or.size(requests)/=n.or.size(previous)/=n) return
    if(present(tcsfix_inputs)) then
      if(size(tcsfix_inputs)/=n) return
      do i=1,n
        if(.not.tcsfix_inputs(i)%enabled) cycle
        if(parameters(i)%timing_criterion<1.or.parameters(i)%timing_criterion>4) return
        if(parameters(i)%depth_criterion/=IRRIGATION_DEPTH_DCS2_FIXED) return
        if(.not.present(observations).or.present(profiles)) return
      end do
    end if
    if(present(weekly_profile_mode)) then
      if(size(weekly_profile_mode)/=n) return
      do i=1,n
        if(.not.weekly_profile_mode(i)) cycle
        if(parameters(i)%timing_criterion/=6.or..not.present(profiles)) return
      end do
    end if
    if(present(weekly_inputs)) then
      if(size(weekly_inputs)/=n) return
    end if
    if(present(observations)) then
      if(size(observations)/=n) return
    end if
    if(present(profiles)) then
      if(size(profiles)/=n) return
    end if
    t0=requests(1)%t0; t1=requests(1)%t1
    if(.not.all(ieee_is_finite([t0,t1]))) return
    if(t1<=t0) return
    do i=1,n
      if(parameters(i)%timing_criterion==6) then
        if(.not.present(weekly_inputs)) return
      end if
      if(parameters(i)%timing_criterion>=1.and.parameters(i)%timing_criterion<=4) then
        if(.not.present(observations)) return
      end if
      select case(parameters(i)%depth_criterion)
      case(IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY)
        ! Weekly input explicitly supplies the shared timing/depth deficit.
        ! Other DCS1 routes still require their committed-profile derivation.
        if(parameters(i)%timing_criterion/=6) then
        if(.not.present(profiles)) return
        if(parameters(i)%timing_criterion<1.or.parameters(i)%timing_criterion>4) then
        if(.not.allocated(profiles(i)%layer).or..not.allocated(profiles(i)%dz).or. &
             .not.allocated(profiles(i)%ztopcp).or..not.allocated(profiles(i)%wclos).or. &
             .not.allocated(profiles(i)%wcmes).or..not.allocated(profiles(i)%wchis)) return
        end if
        end if
      case(IRRIGATION_DEPTH_DCS2_FIXED)
        continue
      case default
        return
      end select
      if(.not.all(ieee_is_finite([requests(i)%t0,requests(i)%t1]))) return
      if(requests(i)%t0/=t0.or.requests(i)%t1/=t1) return
    end do
    call application%export_committed_restart(parameter_identity,snapshot,ok,export_status)
    if(.not.ok.or.export_status/=FMR_APP_BOOT_OK) return
    if(.not.allocated(snapshot%records)) return
    if(size(snapshot%records)/=n) return
    allocate(prepared(n),events(n),selected(n),weekly_proposals(n),tcsfix_proposals(n))
    if(present(preparation)) allocate(preparation(n))
    do i=1,n
      if(snapshot%records(i)%column_id/=column_ids(i)) return
      if(.not.snapshot%records(i)%time_bound) return
      if(snapshot%records(i)%committed_time/=t0) return
      if(.not.allocated(snapshot%records(i)%physical_state)) return
      select type(state=>snapshot%records(i)%physical_state)
      type is(ppa_irrigation_event_state_t)
        if(.not.state%matches_candidate(snapshot%records(i)%template_identity,t0)) return
        if(parameters(i)%active_nodes/=state%active_nodes) return
        use_tcsfix=.false.
        if(present(tcsfix_inputs)) use_tcsfix=tcsfix_inputs(i)%enabled
        if(use_tcsfix.neqv.state%tcsfix%enabled) return
        hydraulic%active_nodes=state%active_nodes
        hydraulic%pressure_head=state%pressure_head
        hydraulic%water_content=state%water_content
        if(use_tcsfix) then
          if(state%weekly%enabled) return
          call evaluate_tcsfix_daily_source(parameters(i),state%irrigation,requests(i),observations(i), &
               state%tcsfix,tcsfix_inputs(i)%daily,tcsfix_inputs(i)%ordinal,previous(i), &
               tcsfix_proposals(i),event,flux,diagnostics,forcing,ok)
        else if(parameters(i)%timing_criterion==6) then
          derive_weekly=.false.
          if(present(weekly_profile_mode)) derive_weekly=weekly_profile_mode(i)
          if(derive_weekly) then
            call evaluate_tcs6_profile_source(parameters(i),state%irrigation,requests(i),state%weekly,weekly_inputs(i), &
                 hydraulic,profiles(i),previous(i),weekly_proposals(i),event,flux,diagnostics,forcing,ok)
          else
          call evaluate_tcs6_source(parameters(i),state%irrigation,requests(i),state%weekly,weekly_inputs(i), &
               previous(i),weekly_proposals(i),event,flux,diagnostics,forcing,ok)
          end if
        else if(parameters(i)%timing_criterion>=1.and.parameters(i)%timing_criterion<=4) then
          if(parameters(i)%depth_criterion==IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY) then
            call evaluate_tcs1_4_dcs1_source(parameters(i),state%irrigation,requests(i),observations(i), &
                 hydraulic,profiles(i),previous(i),event,flux,diagnostics,forcing,ok)
          else if(present(profiles).and.parameters(i)%timing_criterion>=2) then
            call evaluate_tcs2_4_profile_source(parameters(i),state%irrigation,requests(i),observations(i), &
                 hydraulic,profiles(i),previous(i),event,flux,diagnostics,forcing,ok)
          else
            call evaluate_tcs1_4_source(parameters(i),state%irrigation,requests(i),observations(i),previous(i), &
                 event,flux,diagnostics,forcing,ok)
          end if
        else if(parameters(i)%depth_criterion==IRRIGATION_DEPTH_DCS1_FIELD_CAPACITY) then
          call evaluate_ppa_profile_irrigation_source(parameters(i),state%irrigation,requests(i),hydraulic, &
               profiles(i)%noddrz,profiles(i)%layer,profiles(i)%dz,profiles(i)%ztopcp,profiles(i)%rd, &
               profiles(i)%wclos,profiles(i)%wcmes,profiles(i)%wchis,previous(i),event,flux,diagnostics,forcing,ok)
        else
          call evaluate_ppa_irrigation_source(parameters(i),state%irrigation,requests(i),hydraulic,previous(i), &
               event,flux,diagnostics,forcing,ok)
        end if
      class default
        return
      end select
      if(present(preparation)) then
        preparation(i)%process_evaluated=.true.
        preparation(i)%source_prepared=ok
        preparation(i)%process=diagnostics
      end if
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
    if(present(effective_forcing)) effective_forcing=prepared
    call application%run_prepared_irrigation(t0,t1,prepared,results,status,events,selected,weekly_proposals, &
         target_selector,tcsfix_proposals)
  end subroutine execute_ppa_bootstrap_irrigation
end module mod_ppa_bootstrap_irrigation
