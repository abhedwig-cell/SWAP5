program test_rm10_origin_bound_realization_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  use mod_rutter_interception_process
  use mod_fmr_hupsel_management_transaction
  use mod_fmr_ribasim_management_binding
  implicit none

  integer(int64), parameter :: lineage = 1010_int64
  integer(int64), parameter :: crop_revision = 110_int64
  integer(int64), parameter :: ribasim_origin = 90001_int64
  real(real64), parameter :: t0 = 237.0_real64
  real(real64), parameter :: t1 = 238.0_real64
  real(real64), parameter :: supplied_rm09 = 1.9999999999999998_real64
  real(real64), parameter :: tol = 1.0e-12_real64

  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation0
  type(rutter_state_t) :: rutter0
  type(rutter_interval_input_t) :: rutter_template
  type(tcs1_dcs2_sprinkling_request_t) :: request, request_copy, wider_request
  type(fmr_hupsel_management_state_t) :: management0
  type(fmr_hupsel_management_parameters_t) :: parameters
  type(fmr_hupsel_management_demand_receipt_t) :: demand, demand_other_lineage, demand_other_crop, demand_other_interval
  type(fmr_ribasim_realization_receipt_t) :: realization, realization_replay, rejected
  type(fmr_hupsel_management_forcing_t) :: typed_forcing, scalar_forcing
  type(fmr_hupsel_management_model_t), target :: typed_model, scalar_model
  type(fmr_hupsel_management_observation_t) :: typed_a, typed_b, scalar_observation
  type(kernel_committed_state_t) :: committed, scalar_committed, other_committed
  type(kernel_checkpoint_t) :: checkpoint, scalar_checkpoint, other_checkpoint
  type(kernel_executor_t) :: executor, scalar_executor
  type(kernel_candidate_state_t) :: ca, cb, scalar_candidate
  type(kernel_result_t) :: result_a, result_b, scalar_result
  type(kernel_diagnostics_t) :: da, db, scalar_diagnostics
  type(canonical_numerical_config_t) :: config
  logical :: ok, available, did_commit
  integer :: status, commit_status
  real(real64) :: rt0,rt1

  call setup_parameters(p)
  call construct_fmr_hupsel_management_parameters(p,parameters,status)
  call require(status==FMR_RM_OK,'parameters')

  irrigation0=tcs1_dcs2_sprinkling_state_t()
  irrigation0%dayfix=12
  rutter0=rutter_state_t()
  rutter0%canopy_storage_cm=0.02_real64
  call initialize_fmr_hupsel_management_state(irrigation0,rutter0,management0,status)
  call require(status==FMR_RM_OK,'management state')
  call initialize_committed(management0,committed,lineage,t0)
  call committed%capture_checkpoint(checkpoint,ok)
  call require(ok,'checkpoint')

  call setup_request(request,t0,t1)
  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,crop_revision,demand,status)
  call require(status==FMR_RM_OK,'demand receipt')
  available=demand%ready()
  call require(available,'demand ready')
  call demand%request_copy(request_copy,available)
  call require(available,'request copy available')
  call require(same_request(request,request_copy),'complete immutable request copy')

  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,2.0_real64,supplied_rm09, &
       0.10_real64,0.02_real64,1.0_real64,realization,status)
  call require(status==FMR_RB_OK,'valid realization status')
  available=realization%ready()
  call require(available,'valid realization ready')
  call require(realization%matches_demand(demand),'realization matches demand')
  call require(realization%management_lineage_id()==lineage,'management lineage bound')
  call require(realization%management_origin_revision()==0_int64,'management revision bound')
  call require(realization%crop_origin_revision()==crop_revision,'crop revision bound')
  call require(realization%ribasim_origin_id()==ribasim_origin,'Ribasim origin id bound')
  call require(realization%ribasim_origin_revision()==0_int64,'Ribasim origin revision bound')
  call realization%interval(rt0,rt1,available)
  call require(available .and. same_real(rt0,t0) .and. same_real(rt1,t1),'interval bound')
  call require(abs(realization%requested_depth_cm()-2.0_real64)<=tol,'request quantity bound')
  call require(abs(realization%allocated_depth_cm()-2.0_real64)<=tol,'allocation quantity distinct')
  call require(abs(realization%supplied_depth_cm()-supplied_rm09)<=tol,'supply quantity distinct')

  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,2.0_real64,supplied_rm09, &
       0.10_real64,0.02_real64,1.0_real64,realization_replay,status)
  call require(status==FMR_RB_OK,'realization replay construction')
  call require(same_realization(realization,realization_replay),'same-origin realization identity')

  ! RM08-like physical shortfall remains outside the bounded profile.
  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,2.0_real64, &
       1.6488994020651218_real64,0.10_real64,0.02_real64,1.0_real64,rejected,status)
  call require(status==FMR_RB_FULL_REALIZATION_NOT_ADMITTED,'partial physical supply fails closed')
  available=rejected%ready()
  call require(.not.available,'partial physical supply no receipt')

  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,2.0_real64,supplied_rm09, &
       0.05_real64,0.02_real64,1.0_real64,rejected,status)
  call require(status==FMR_RB_FULL_REALIZATION_NOT_ADMITTED,'insufficient level margin fails closed')

  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,2.0_real64,supplied_rm09, &
       0.10_real64,0.02_real64,0.99_real64,rejected,status)
  call require(status==FMR_RB_FULL_REALIZATION_NOT_ADMITTED,'low storage factor fails closed')

  call construct_fmr_ribasim_full_realization_receipt(demand,ribasim_origin,0_int64,1.5_real64,1.5_real64, &
       0.10_real64,0.02_real64,1.0_real64,rejected,status)
  call require(status==FMR_RB_FULL_REALIZATION_NOT_ADMITTED,'partial allocation fails closed')

  call setup_rutter(rutter_template)
  call prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand,rutter_template,realization,typed_forcing,status)
  call require(status==FMR_RB_OK,'typed forcing construction')
  call prepare_fmr_hupsel_management_forcing(request,rutter_template,crop_revision,2.0_real64,supplied_rm09, &
       scalar_forcing,status)
  call require(status==FMR_RM_OK,'scalar reference forcing')

  call setup_config(config)
  call executor%bind_model(typed_model)
  call executor%advance_interval(parameters,committed,typed_forcing,config,t0,t1,result_a,ca,da,checkpoint)
  call require(result_a%completed,'typed candidate A')
  call typed_model%observation(typed_a)
  call executor%rollback_candidate(ca,da)
  call require(committed%current_revision()==0_int64,'typed rejection nonmutating')

  call executor%advance_interval(parameters,committed,typed_forcing,config,t0,t1,result_b,cb,db,checkpoint)
  call require(result_b%completed,'typed candidate B')
  call typed_model%observation(typed_b)
  call require(same_observation(typed_a,typed_b),'typed same-origin replay')

  call initialize_committed(management0,scalar_committed,lineage+1_int64,t0)
  call scalar_committed%capture_checkpoint(scalar_checkpoint,ok)
  call require(ok,'scalar checkpoint')
  call scalar_executor%bind_model(scalar_model)
  call scalar_executor%advance_interval(parameters,scalar_committed,scalar_forcing,config,t0,t1, &
       scalar_result,scalar_candidate,scalar_diagnostics,scalar_checkpoint)
  call require(scalar_result%completed,'scalar comparison candidate')
  call scalar_model%observation(scalar_observation)
  call require(same_observation(typed_b,scalar_observation),'typed/scalar numerical identity')

  call executor%commit_candidate(committed,cb,db,did_commit,commit_status)
  call require(did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'typed exactly once commit')
  call require(committed%current_revision()==1_int64,'typed one accepted revision')

  ! A receipt from another SWAP management lineage cannot be consumed with this realization.
  call initialize_committed(management0,other_committed,lineage+2_int64,t0)
  call other_committed%capture_checkpoint(other_checkpoint,ok)
  call require(ok,'other-lineage checkpoint')
  call derive_fmr_hupsel_management_demand_receipt(other_checkpoint,parameters,request,crop_revision, &
       demand_other_lineage,status)
  call require(status==FMR_RM_OK,'other-lineage demand')
  call prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand_other_lineage,rutter_template, &
       realization,typed_forcing,status)
  call require(status==FMR_RB_PROVENANCE_MISMATCH,'lineage mismatch rejected')

  ! Crop-origin mismatch is independently rejected.
  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,crop_revision+1_int64, &
       demand_other_crop,status)
  call require(status==FMR_RM_OK,'other-crop demand')
  call prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand_other_crop,rutter_template, &
       realization,typed_forcing,status)
  call require(status==FMR_RB_PROVENANCE_MISMATCH,'crop mismatch rejected')

  ! Same origin with a different management interval is independently rejected.
  wider_request=request
  wider_request%t1=t1+1.0_real64
  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,wider_request,crop_revision, &
       demand_other_interval,status)
  call require(status==FMR_RM_OK,'other-interval demand')
  call prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand_other_interval,rutter_template, &
       realization,typed_forcing,status)
  call require(status==FMR_RB_PROVENANCE_MISMATCH,'interval mismatch rejected')

  print '(a)','RM10_FULL_REQUEST_COPY=PASS'
  print '(a)','RM10_TYPED_REALIZATION_PROVENANCE=PASS'
  print '(a)','RM10_SAME_ORIGIN_RECEIPT_IDENTITY=PASS'
  print '(a)','RM10_RM08_PARTIAL_SUPPLY_FAIL_CLOSED=PASS'
  print '(a)','RM10_FULL_REALIZATION_PRECONDITIONS_FAIL_CLOSED=PASS'
  print '(a)','RM10_TYPED_SCALAR_NUMERICAL_IDENTITY=PASS'
  print '(a)','RM10_TYPED_REJECT_REPLAY_COMMIT=PASS'
  print '(a)','RM10_CROSS_ORIGIN_MISMATCH_REJECTED=PASS'
  print '(a)','RM10 ORIGIN BOUND REALIZATION RECEIPT GATE PASS'

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

  subroutine setup_request(r,a,b)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::r
    real(real64),intent(in)::a,b
    r=tcs1_dcs2_sprinkling_request_t()
    r%t0=a; r%t1=b; r%dvs=1.5060476190476193_real64
    r%potential_transpiration_day_cm=0.31534971046284993_real64
    r%dry_reduction_day_cm=0.11551480616973946_real64
    r%salinity_reduction_day_cm=0.0_real64
    r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
    r%crop_emerged=.true.; r%irrigation_window_open=.true.; r%fixed_event_already_selected=.false.
  end subroutine setup_request

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

  subroutine initialize_committed(initial,state,lineage_id,time0)
    type(fmr_hupsel_management_state_t),intent(in)::initial
    type(kernel_committed_state_t),intent(out)::state
    integer(int64),intent(in)::lineage_id
    real(real64),intent(in)::time0
    class(transaction_state_t),allocatable::physical
    logical::initialized
    call initial%clone(physical)
    call state%initialize(lineage_id,physical,initialized,time0)
    call require(initialized,'committed initialization')
  end subroutine initialize_committed

  logical function same_request(a,b)
    type(tcs1_dcs2_sprinkling_request_t),intent(in)::a,b
    same_request=same_real(a%t0,b%t0) .and. same_real(a%t1,b%t1) .and. same_real(a%dvs,b%dvs) .and. &
      same_real(a%potential_transpiration_day_cm,b%potential_transpiration_day_cm) .and. &
      same_real(a%dry_reduction_day_cm,b%dry_reduction_day_cm) .and. &
      same_real(a%salinity_reduction_day_cm,b%salinity_reduction_day_cm) .and. &
      (a%selection_opportunity .eqv. b%selection_opportunity) .and. &
      (a%irrigation_enabled .eqv. b%irrigation_enabled) .and. &
      (a%schedule_enabled .eqv. b%schedule_enabled) .and. &
      (a%crop_emerged .eqv. b%crop_emerged) .and. &
      (a%irrigation_window_open .eqv. b%irrigation_window_open) .and. &
      (a%fixed_event_already_selected .eqv. b%fixed_event_already_selected)
  end function same_request

  logical function same_realization(a,b)
    type(fmr_ribasim_realization_receipt_t),intent(in)::a,b
    real(real64)::a0,a1,b0,b1
    logical::aa,bb
    call a%interval(a0,a1,aa); call b%interval(b0,b1,bb)
    same_realization=aa .and. bb .and. a%management_lineage_id()==b%management_lineage_id() .and. &
      a%management_origin_revision()==b%management_origin_revision() .and. &
      a%crop_origin_revision()==b%crop_origin_revision() .and. a%ribasim_origin_id()==b%ribasim_origin_id() .and. &
      a%ribasim_origin_revision()==b%ribasim_origin_revision() .and. same_real(a0,b0) .and. same_real(a1,b1) .and. &
      same_real(a%requested_depth_cm(),b%requested_depth_cm()) .and. &
      same_real(a%allocated_depth_cm(),b%allocated_depth_cm()) .and. &
      same_real(a%supplied_depth_cm(),b%supplied_depth_cm())
  end function same_realization

  logical function same_observation(a,b)
    type(fmr_hupsel_management_observation_t),intent(in)::a,b
    same_observation=(a%decision_evaluated .eqv. b%decision_evaluated) .and. &
      (a%irrigation_requested .eqv. b%irrigation_requested) .and. a%crop_origin_revision==b%crop_origin_revision .and. &
      same_real(a%requested_depth_cm,b%requested_depth_cm) .and. same_real(a%allocated_depth_cm,b%allocated_depth_cm) .and. &
      same_real(a%supplied_depth_cm,b%supplied_depth_cm) .and. same_real(a%allocation_shortage_cm,b%allocation_shortage_cm) .and. &
      same_real(a%realization_shortage_cm,b%realization_shortage_cm) .and. &
      same_real(a%gross_surface_rate_cm_per_day,b%gross_surface_rate_cm_per_day) .and. &
      same_real(a%net_surface_irrigation_amount_cm,b%net_surface_irrigation_amount_cm)
  end function same_observation

  logical function same_real(a,b)
    real(real64),intent(in)::a,b
    same_real=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_real

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)')'RM10_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_rm10_origin_bound_realization_receipt
