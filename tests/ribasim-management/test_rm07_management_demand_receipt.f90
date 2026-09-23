program test_rm07_management_demand_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  use mod_rutter_interception_process
  use mod_fmr_hupsel_management_transaction
  implicit none

  integer(int64), parameter :: lineage = 7007_int64
  integer(int64), parameter :: crop_revision = 91_int64
  real(real64), parameter :: t0 = 237.0_real64
  real(real64), parameter :: tol = 1.0e-13_real64

  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation0, irrigation_before, irrigation_after
  type(rutter_state_t) :: rutter0, rutter_before, rutter_after
  type(rutter_interval_input_t) :: rutter_template
  type(tcs1_dcs2_sprinkling_request_t) :: request, no_event_request
  type(fmr_hupsel_management_state_t) :: state0, active_state
  type(fmr_hupsel_management_parameters_t) :: parameters
  type(fmr_hupsel_management_demand_receipt_t) :: a, b, no_event, active_receipt
  type(fmr_hupsel_management_forcing_t) :: forcing
  type(fmr_hupsel_management_model_t), target :: model
  type(fmr_hupsel_management_observation_t) :: observation
  type(kernel_committed_state_t) :: committed, active_committed
  type(kernel_checkpoint_t) :: checkpoint, active_checkpoint
  type(kernel_executor_t) :: executor
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: initial, snapshot
  logical :: ok, available
  integer :: status
  real(real64) :: rt0, rt1

  call setup_parameters(p)
  call construct_fmr_hupsel_management_parameters(p,parameters,status)
  call require(status==FMR_RM_OK,'parameters status')
  available=parameters%ready()
  call require(available,'parameters ready')

  irrigation0=tcs1_dcs2_sprinkling_state_t()
  irrigation0%dayfix=12
  rutter0=rutter_state_t()
  rutter0%canopy_storage_cm=0.02_real64
  call initialize_fmr_hupsel_management_state(irrigation0,rutter0,state0,status)
  call require(status==FMR_RM_OK,'state construction')
  call state0%clone(initial)
  call committed%initialize(lineage,initial,ok,initial_time=t0)
  call require(ok,'committed initialize')
  call committed%capture_checkpoint(checkpoint,ok)
  call require(ok,'checkpoint capture')

  call setup_trigger_request(request)
  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,crop_revision,a,status)
  call require(status==FMR_RM_OK,'receipt A status')
  available=a%ready()
  call require(available,'receipt A ready')
  call require(a%origin_lineage_id()==lineage,'receipt lineage')
  call require(a%origin_revision()==0_int64,'receipt revision')
  call require(a%crop_origin_revision()==crop_revision,'receipt crop revision')
  call require(abs(a%requested_depth_cm()-2.0_real64)<=tol,'receipt requested depth')
  call a%interval(rt0,rt1,available)
  call require(available,'receipt interval available')
  call require(same_real(rt0,request%t0) .and. same_real(rt1,request%t1),'receipt interval identity')
  call require(a%application_t1()>request%t0 .and. a%application_t1()<request%t1,'receipt event split')

  call committed%snapshot(snapshot,available)
  call require(available,'origin snapshot before replay')
  call extract(snapshot,irrigation_before,rutter_before)
  if(allocated(snapshot)) deallocate(snapshot)

  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,crop_revision,b,status)
  call require(status==FMR_RM_OK,'receipt B status')
  available=b%ready()
  call require(available,'receipt B ready')
  call require(same_receipt(a,b),'same-origin receipt identity')

  call committed%snapshot(snapshot,available)
  call require(available,'origin snapshot after replay')
  call extract(snapshot,irrigation_after,rutter_after)
  call require(same_irrigation(irrigation_before,irrigation_after),'receipt derivation irrigation nonmutating')
  call require(same_rutter(rutter_before,rutter_after),'receipt derivation Rutter nonmutating')
  call require(committed%current_revision()==0_int64,'receipt derivation revision nonmutating')
  if(allocated(snapshot)) deallocate(snapshot)

  ! Compare the read-only request with the later RM06 transaction's recomputed request.
  call setup_rutter(rutter_template)
  call prepare_fmr_hupsel_management_forcing(request,rutter_template,crop_revision,2.0_real64,2.0_real64,forcing,status)
  call require(status==FMR_RM_OK,'forcing status')
  call setup_config(config)
  call executor%bind_model(model)
  call executor%advance_interval(parameters,committed,forcing,config,request%t0,request%t1,result,candidate,diagnostics,checkpoint)
  call require(result%completed,'RM06 comparison candidate')
  call model%observation(observation)
  call require(same_real(observation%requested_depth_cm,a%requested_depth_cm()),'receipt equals RM06 request')
  call executor%rollback_candidate(candidate,diagnostics)
  call require(committed%current_revision()==0_int64,'comparison rollback nonmutating')

  ! No-event request is a valid zero demand receipt.
  call setup_no_event_request(no_event_request)
  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,no_event_request,crop_revision,no_event,status)
  call require(status==FMR_RM_OK,'no-event receipt status')
  available=no_event%ready()
  call require(available,'no-event receipt ready')
  call require(same_real(no_event%requested_depth_cm(),0.0_real64),'no-event zero demand')

  ! Active event at accepted origin remains outside the first profile.
  irrigation0=tcs1_dcs2_sprinkling_state_t()
  irrigation0%dayfix=1
  irrigation0%active_event=.true.
  irrigation0%active_event_start=t0
  irrigation0%active_event_end=t0+0.01_real64
  call initialize_fmr_hupsel_management_state(irrigation0,rutter0,active_state,status)
  call require(status==FMR_RM_OK,'active seed construction')
  call active_state%clone(initial)
  call active_committed%initialize(lineage+1_int64,initial,ok,initial_time=t0)
  call require(ok,'active committed initialize')
  call active_committed%capture_checkpoint(active_checkpoint,ok)
  call require(ok,'active checkpoint')
  call derive_fmr_hupsel_management_demand_receipt(active_checkpoint,parameters,request,crop_revision,active_receipt,status)
  call require(status==FMR_RM_ACTIVE_EVENT_ORIGIN_NOT_ADMITTED,'active event fail closed')
  available=active_receipt%ready()
  call require(.not. available,'active event no receipt')

  print '(a)','RM07_READ_ONLY_DEMAND_RECEIPT=PASS'
  print '(a)','RM07_ORIGIN_PROVENANCE_BOUND=PASS'
  print '(a)','RM07_SAME_ORIGIN_BIT_IDENTITY=PASS'
  print '(a)','RM07_ACCEPTED_STATE_NONMUTATING=PASS'
  print '(a)','RM07_RECEIPT_EQUALS_RM06_REQUEST=PASS'
  print '(a)','RM07_NO_EVENT_ZERO_REQUEST=PASS'
  print '(a)','RM07_ACTIVE_EVENT_FAIL_CLOSED=PASS'
  print '(a)','RM07 MANAGEMENT DEMAND RECEIPT GATE PASS'

contains

  subroutine setup_parameters(x)
    type(tcs1_dcs2_sprinkling_parameters_t),intent(out)::x
    x=tcs1_dcs2_sprinkling_parameters_t()
    x%enabled=.true.; x%rate_cm_per_day=36.0_real64
    x%threshold_knot_count=2; x%threshold_dvs(1:2)=[0.0_real64,2.0_real64]
    x%threshold_trel(1:2)=[0.85_real64,0.85_real64]
    x%depth_knot_count=2; x%depth_dvs(1:2)=[0.0_real64,2.0_real64]
    x%depth_cm(1:2)=[2.0_real64,2.0_real64]
    x%minimum_interval_days=7
  end subroutine setup_parameters

  subroutine setup_trigger_request(r)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::r
    r=tcs1_dcs2_sprinkling_request_t()
    r%t0=t0; r%t1=t0+1.0_real64
    r%dvs=1.5060476190476193_real64
    r%potential_transpiration_day_cm=0.31534971046284993_real64
    r%dry_reduction_day_cm=0.11551480616973946_real64
    r%salinity_reduction_day_cm=0.0_real64
    r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
    r%crop_emerged=.true.; r%irrigation_window_open=.true.
  end subroutine setup_trigger_request

  subroutine setup_no_event_request(r)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::r
    call setup_trigger_request(r)
    r%dry_reduction_day_cm=0.0_real64
    r%salinity_reduction_day_cm=0.0_real64
  end subroutine setup_no_event_request

  subroutine setup_rutter(r)
    type(rutter_interval_input_t),intent(out)::r
    r=rutter_interval_input_t()
    r%gross_rain_cm_per_day=0.0_real64
    r%vegetation_cover_fraction=0.5_real64
    r%canopy_storage_capacity_cm=0.12_real64
    r%interception_evaporation_capacity_cm_per_day=0.01_real64
    r%potential_transpiration_dry_cm_per_day=0.011621209174202582_real64
    r%potential_transpiration_wet_cm_per_day=0.0047014973566050335_real64
  end subroutine setup_rutter

  subroutine setup_config(x)
    type(canonical_numerical_config_t),intent(out)::x
    x=canonical_numerical_config_t()
    x%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    x%transaction%temporal_tolerance=0.0_real64
    x%transaction%mass_tolerance=0.0_real64
    x%transaction%retry_scale=0.5_real64
    x%transaction%max_retries=0
    x%max_committed_substeps=1
    x%progress_tolerance=0.0_real64
  end subroutine setup_config

  subroutine extract(box,irrigation,rutter)
    class(transaction_state_t),allocatable,intent(in)::box
    type(tcs1_dcs2_sprinkling_state_t),intent(out)::irrigation
    type(rutter_state_t),intent(out)::rutter
    logical::got
    call require(allocated(box),'snapshot allocated')
    select type(typed=>box)
    type is(fmr_hupsel_management_state_t)
      call typed%snapshot(irrigation,rutter,got)
      call require(got,'snapshot typed')
    class default
      call require(.false.,'snapshot type')
    end select
  end subroutine extract

  logical function same_receipt(x,y)
    type(fmr_hupsel_management_demand_receipt_t),intent(in)::x,y
    real(real64)::x0,x1,y0,y1
    logical::xa,ya
    call x%interval(x0,x1,xa); call y%interval(y0,y1,ya)
    same_receipt=xa .and. ya
    same_receipt=same_receipt .and. x%origin_lineage_id()==y%origin_lineage_id()
    same_receipt=same_receipt .and. x%origin_revision()==y%origin_revision()
    same_receipt=same_receipt .and. x%crop_origin_revision()==y%crop_origin_revision()
    same_receipt=same_receipt .and. same_real(x0,y0) .and. same_real(x1,y1)
    same_receipt=same_receipt .and. same_real(x%application_t1(),y%application_t1())
    same_receipt=same_receipt .and. same_real(x%requested_depth_cm(),y%requested_depth_cm())
  end function same_receipt

  logical function same_irrigation(x,y)
    type(tcs1_dcs2_sprinkling_state_t),intent(in)::x,y
    same_irrigation=x%dayfix==y%dayfix .and. (x%active_event .eqv. y%active_event) .and. &
         same_real(x%active_event_start,y%active_event_start) .and. same_real(x%active_event_end,y%active_event_end)
  end function same_irrigation

  logical function same_rutter(x,y)
    type(rutter_state_t),intent(in)::x,y
    same_rutter=same_real(x%canopy_storage_cm,y%canopy_storage_cm)
  end function same_rutter

  logical function same_real(x,y)
    real(real64),intent(in)::x,y
    same_real=transfer(x,0_int64)==transfer(y,0_int64)
  end function same_real

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)')'RM07_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_rm07_management_demand_receipt
