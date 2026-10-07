program test_swap431_fixed_crop_transaction
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_transaction_reference, only: transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t,CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_fwof34_test_model
  use mod_fmr_wofost_accepted_window_lineage
  use mod_wofost_rate_table, only: construct_wofost_rate_table,WOFOST_RATE_TABLE_OK
  use mod_fixed_crop_owner
  use mod_crop_calendar_end_event
  use mod_fmr_fixed_crop_transaction
  implicit none

  type(kernel_committed_state_t)::physical_committed,fixed_committed
  type(kernel_checkpoint_t)::physical_checkpoint,fixed_checkpoint
  type(kernel_executor_t)::physical_kernel,fixed_kernel
  type(fwof34_model_t),target::physical_model
  type(fwof34_parameters_t)::physical_parameters
  type(fwof34_forcing_t)::physical_forcing
  type(canonical_numerical_config_t)::physical_config,fixed_config
  type(fmr_wofost_accepted_window_t)::window
  type(fmr_wofost_trial_contribution_t)::trial
  type(fmr_wofost_accepted_interval_certificate_t)::certificate
  type(fixed_crop_parameters_t)::crop_parameters
  type(fixed_crop_owner_state_t)::owner,snapshot_owner
  type(fmr_fixed_crop_transaction_state_t)::initial_state,restored_state
  type(fmr_fixed_crop_transaction_parameters_t)::parameters
  type(fmr_fixed_crop_event_forcing_t)::forcing
  type(fmr_fixed_crop_persistence_t)::persist
  type(fmr_fixed_crop_transaction_model_t),target::model
  type(kernel_candidate_state_t)::cand1,cand2
  type(kernel_result_t)::res1,res2
  type(kernel_diagnostics_t)::diag1,diag2
  class(transaction_state_t),allocatable::snapshot
  logical::ok,available,did_commit
  integer::status,commit_status
  integer(int64)::revision_before
  real(real64),parameter::tol=1e-12_real64

  call setup_physical_committed(physical_committed,92001_int64,100._real64)
  call setup_physical_solver(physical_parameters,physical_forcing,physical_config)
  call physical_kernel%bind_model(physical_model)
  call physical_committed%capture_checkpoint(physical_checkpoint,ok)
  call require(ok,'physical checkpoint')
  call open_wofost_accepted_window(physical_checkpoint,101._real64,window,status)
  call require(status==FMR_WOFOST_LINEAGE_OK,'window open')
  call begin_wofost_trial_contribution(physical_checkpoint,101._real64,trial,status)
  call require(status==FMR_WOFOST_LINEAGE_OK,'trial begin')
  call accumulate_wofost_trial_process_rate(trial,100._real64,101._real64,0._real64,0._real64,status)
  call require(status==FMR_WOFOST_LINEAGE_OK.and.trial%complete(),'trial fill')
  call advance_and_commit_physical(physical_kernel,physical_parameters,physical_forcing,physical_config, &
       physical_committed,physical_checkpoint,100._real64,101._real64)
  call certify_fkt_accepted_interval(physical_checkpoint,physical_committed,certificate,status)
  call require(status==FMR_WOFOST_LINEAGE_OK,'certificate')
  call admit_wofost_accepted_trial(window,certificate,trial,status)
  call require(status==FMR_WOFOST_LINEAGE_OK.and.window%complete(),'window complete')

  crop_parameters%development_mode=FIXED_CROP_IDEV_THERMAL
  crop_parameters%base_temperature_c=5._real64
  crop_parameters%temperature_sum_emergence_to_anthesis=100._real64
  crop_parameters%temperature_sum_anthesis_to_maturity=200._real64
  call construct_wofost_rate_table([0._real64,1._real64,2._real64],[.5_real64,3._real64,0._real64], &
       crop_parameters%leaf_area_by_dvs,status)
  call require(status==WOFOST_RATE_TABLE_OK,'LAI table')
  crop_parameters%root_biomass_enabled=.false.
  call initialize_fixed_crop_owner(crop_parameters,.true.,owner,status)
  call require(status==FIXED_CROP_OK,'fixed owner init')
  owner%development_stage=.95_real64
  owner%temperature_sum=95._real64
  owner%leaf_area_index=2.875_real64

  call initialize_fmr_fixed_crop_transaction_state(owner,initial_state,status)
  call require(status==FMR_FIXED_OK.and.initial_state%ready(),'fixed tx init')
  call construct_fmr_fixed_crop_transaction_parameters(crop_parameters,CROP_END_BY_DVS_OR_CALENDAR,200._real64, &
       1._real64,parameters,status)
  call require(status==FMR_FIXED_OK.and.parameters%ready(),'fixed tx params')
  call prepare_fmr_fixed_crop_event_forcing(window,15._real64,101._real64,forcing,status)
  call require(status==FMR_FIXED_OK.and.forcing%ready(),'fixed event forcing')

  call setup_fixed_committed(initial_state,fixed_committed,92002_int64,100._real64)
  call setup_fixed_config(fixed_config)
  call fixed_kernel%bind_model(model)
  call fixed_committed%capture_checkpoint(fixed_checkpoint,ok)
  call require(ok,'fixed checkpoint')

  call fixed_kernel%advance_interval(parameters,fixed_committed,forcing,fixed_config,100._real64,101._real64, &
       res1,cand1,diag1,fixed_checkpoint)
  call require(res1%status==CANONICAL_STATUS_COMPLETED.and.cand1%ready(),'fixed candidate1')
  call fixed_kernel%advance_interval(parameters,fixed_committed,forcing,fixed_config,100._real64,101._real64, &
       res2,cand2,diag2,fixed_checkpoint)
  call require(res2%status==CANONICAL_STATUS_COMPLETED.and.cand2%ready(),'fixed candidate2')

  call fixed_kernel%rollback_candidate(cand1,diag1)
  call fixed_committed%snapshot(snapshot,available)
  call require(available,'rollback snapshot')
  select type(tx=>snapshot)
  type is(fmr_fixed_crop_transaction_state_t)
    call tx%snapshot_owner(snapshot_owner,available)
    call require(available.and.abs(snapshot_owner%development_stage-.95_real64)<tol,'rollback owner unchanged')
    call require(.not.tx%receipt_ready(),'rollback receipt unchanged')
  class default
    call require(.false.,'rollback type')
  end select

  revision_before=fixed_committed%current_revision()
  call fixed_kernel%commit_candidate(fixed_committed,cand2,diag2,did_commit,commit_status)
  call require(did_commit.and.fixed_committed%current_revision()==revision_before+1,'single fixed commit')
  call fixed_committed%snapshot(snapshot,available)
  call require(available,'commit snapshot')
  select type(tx=>snapshot)
  type is(fmr_fixed_crop_transaction_state_t)
    call tx%snapshot_owner(snapshot_owner,available)
    call require(available,'committed owner')
    call require(abs(snapshot_owner%development_stage-1.05_real64)<tol,'daily DVS update')
    call require(abs(snapshot_owner%temperature_sum-105._real64)<tol,'daily TSUM update')
    call require(.not.snapshot_owner%crop_emerged,'DVS crop-end after update')
    call require(tx%receipt_ready(),'fixed receipt committed')
    call export_fmr_fixed_crop_persistence(tx,persist,ok,status)
    call require(ok.and.status==FMR_FIXED_PERSISTENCE_OK,'fixed persistence export')
    call reconstruct_fmr_fixed_crop_from_persistence(persist,restored_state,ok,status)
    call require(ok.and.status==FMR_FIXED_PERSISTENCE_OK.and.restored_state%receipt_ready(),'fixed restart')
    call restored_state%snapshot_owner(owner,available)
    call require(available.and.abs(owner%development_stage-snapshot_owner%development_stage)<tol,'fixed restart owner')
  class default
    call require(.false.,'commit type')
  end select

  print '(a)','SW431_CROP_FIXED_ATOMIC_TRANSACTION=PASS'
  print '(a)','SW431_CROP_FIXED_END_EVENT=PASS'
  print '(a)','SW431_CROP_FIXED_RESTART=PASS'

contains
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(a,1x,a)')'FAIL',trim(label);error stop 1
    end if
  end subroutine

  subroutine setup_physical_committed(state,lineage_id,initial_time)
    type(kernel_committed_state_t),intent(out)::state
    integer(int64),intent(in)::lineage_id
    real(real64),intent(in)::initial_time
    class(transaction_state_t),allocatable::physical
    logical::initialized
    allocate(fwof34_state_t::physical)
    select type(p=>physical);type is(fwof34_state_t);p%water=1._real64;end select
    call state%initialize(lineage_id,physical,initialized,initial_time)
    call require(initialized,'physical committed init')
  end subroutine

  subroutine setup_physical_solver(p,f,c)
    type(fwof34_parameters_t),intent(out)::p
    type(fwof34_forcing_t),intent(out)::f
    type(canonical_numerical_config_t),intent(out)::c
    p%flux_rate=.1_real64;f%scale=1._real64
    c%transaction%temporal_tolerance=1._real64;c%transaction%mass_tolerance=1e-12_real64
    c%transaction%retry_scale=.5_real64;c%transaction%max_retries=2
    c%max_committed_substeps=8;c%progress_tolerance=0._real64
  end subroutine

  subroutine advance_and_commit_physical(k,p,f,c,state,checkpoint,t0,t1)
    type(kernel_executor_t),intent(inout)::k
    type(fwof34_parameters_t),intent(in)::p
    type(fwof34_forcing_t),intent(in)::f
    type(canonical_numerical_config_t),intent(in)::c
    type(kernel_committed_state_t),intent(inout)::state
    type(kernel_checkpoint_t),intent(in)::checkpoint
    real(real64),intent(in)::t0,t1
    type(kernel_result_t)::result
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diagnostics
    logical::committed
    integer::cs
    call k%advance_interval(p,state,f,c,t0,t1,result,candidate,diagnostics,checkpoint)
    call require(result%completed.and.candidate%ready(),'physical advance')
    call k%commit_candidate(state,candidate,diagnostics,committed,cs)
    call require(committed,'physical commit')
  end subroutine

  subroutine setup_fixed_committed(initial,state,lineage_id,initial_time)
    type(fmr_fixed_crop_transaction_state_t),intent(in)::initial
    type(kernel_committed_state_t),intent(out)::state
    integer(int64),intent(in)::lineage_id
    real(real64),intent(in)::initial_time
    class(transaction_state_t),allocatable::payload
    logical::initialized
    allocate(fmr_fixed_crop_transaction_state_t::payload)
    select type(p=>payload);type is(fmr_fixed_crop_transaction_state_t);p=initial;end select
    call state%initialize(lineage_id,payload,initialized,initial_time)
    call require(initialized,'fixed committed init')
  end subroutine

  subroutine setup_fixed_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0._real64;c%transaction%mass_tolerance=0._real64
    c%transaction%retry_scale=.5_real64;c%transaction%max_retries=0
    c%max_committed_substeps=1;c%progress_tolerance=0._real64
  end subroutine
end program
