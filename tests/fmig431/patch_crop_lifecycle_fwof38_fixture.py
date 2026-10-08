from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
def replace_one(a,b):
    global s
    assert s.count(a)==1, (a[:80],s.count(a))
    s=s.replace(a,b,1)
replace_one('  use mod_fmr_wofost_crop_transaction\n',
            '  use mod_fmr_wofost_crop_transaction\n  use mod_crop_lifecycle_continuation\n  use mod_crop_lifecycle_daily_composition\n  use mod_crop_germination_preflight\n')
replace_one('  integer(kind=8) :: crop_revision_before\n',
'''  integer(kind=8) :: crop_revision_before
  type(crop_lifecycle_continuation_t) :: lifecycle_seed, lifecycle_replayed
  type(fmr_wofost_crop_transaction_state_t) :: lifecycle_state, lifecycle_restored
  type(fmr_wofost_crop_transaction_persistence_t) :: lifecycle_view
  logical :: lifecycle_available, lifecycle_exported, lifecycle_reconstructed
  integer :: lifecycle_persistence_status
  type(fmr_wofost_crop_event_identity_persistence_t) :: artificial_receipt
  type(fmr_wofost_crop_event_identity_t) :: artificial_identity
  integer :: artificial_receipt_status
  type(kernel_committed_state_t) :: lifecycle_committed
  type(kernel_checkpoint_t) :: lifecycle_checkpoint
  type(kernel_candidate_state_t) :: lifecycle_candidate
  type(kernel_result_t) :: lifecycle_result
  type(kernel_diagnostics_t) :: lifecycle_diag
  type(fmr_wofost_crop_event_forcing_t) :: lifecycle_forcing
  type(crop_daily_lifecycle_candidate_t) :: lifecycle_plan
  type(crop_germination_candidate_t) :: lifecycle_germination
  class(transaction_state_t), allocatable :: lifecycle_candidate_snapshot
  logical :: lifecycle_checkpoint_ok
''')
anchor="  call require(crop_initial_state%ready(), 'F-WOF38 crop transaction state ready')\n"
replacement="""  call require(crop_initial_state%ready(), 'F-WOF38 crop transaction state ready')
  ! Independent opt-in lifecycle state exercises physical F-KT owner
  ! persistence, without mutating the primary frozen crop fixture.
  lifecycle_seed%valid=.true.
  lifecycle_seed%crop_identity=71
  lifecycle_seed%revision=4
  lifecycle_seed%prepared=.true.
  lifecycle_seed%sown=.true.
  lifecycle_seed%germinated=.true.
  lifecycle_seed%germination_temperature_sum=12.5_real64
  call initialize_fmr_wofost_crop_transaction_state(seed, lifecycle_state, crop_status, &
       lifecycle_initial=lifecycle_seed)
  call require(crop_status == FMR_WOF38_OK .and. lifecycle_state%ready(), &
       'lifecycle owner init')
  call export_fmr_wofost_crop_transaction_persistence(lifecycle_state,lifecycle_view, &
       lifecycle_exported,lifecycle_persistence_status)
  call require(lifecycle_exported .and. lifecycle_persistence_status == FMR_WOFOST_CROP_PERSISTENCE_OK, &
       'lifecycle owner persistence export')
  call require(lifecycle_view%lifecycle_present .and. lifecycle_view%lifecycle%ready(), &
       'lifecycle continuation in persistence view')
  call reconstruct_fmr_wofost_crop_transaction_from_persistence(lifecycle_view,lifecycle_restored, &
       lifecycle_reconstructed,lifecycle_persistence_status)
  call require(lifecycle_reconstructed .and. lifecycle_persistence_status == FMR_WOFOST_CROP_PERSISTENCE_OK, &
       'lifecycle owner persistence reconstruction')
  call lifecycle_restored%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
  call require(lifecycle_available .and. lifecycle_replayed%revision==lifecycle_seed%revision &
       .and. lifecycle_replayed%crop_identity==lifecycle_seed%crop_identity &
       .and. lifecycle_replayed%germination_temperature_sum==lifecycle_seed%germination_temperature_sum, &
       'lifecycle owner persisted restart equivalence')
  ! Restore validation must reject a lifecycle event with no matching receipt.
  artificial_receipt%valid=.true.
  artificial_receipt%lineage_id=91
  artificial_receipt%final_revision=10
  artificial_receipt%t0=0.0_real64
  artificial_receipt%t1=1.0_real64
  call reconstruct_wofost_crop_event_identity_from_persistence(artificial_receipt,artificial_identity, &
       artificial_receipt_status)
  call require(artificial_receipt_status==FMR_WOFOST_LINEAGE_OK, 'artificial valid receipt')
  lifecycle_view%lifecycle%last_event_identity=artificial_identity
  call require(.not.lifecycle_view%ready(), 'orphan lifecycle identity rejects persistence')
  lifecycle_view%receipt_present=.true.
  lifecycle_view%receipt=artificial_receipt
  call require(lifecycle_view%ready(), 'matching physical and lifecycle receipt permits persistence')
  lifecycle_view%receipt%final_revision=lifecycle_view%receipt%final_revision+1
  call require(.not.lifecycle_view%ready(), 'stale physical receipt rejects lifecycle persistence')
  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_RECEIPT_COHERENCE=PASS'


  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_PERSISTENCE_REPLAY=PASS'
"""
replace_one(anchor,replacement)
replace_one("  call require(crop_checkpoint_ok, 'F-WOF38 crop checkpoint')\n","  call require(crop_checkpoint_ok, 'F-WOF38 crop checkpoint')\n  ! One opt-in F-KT trial: candidate and receipt must remain on the\n  ! unpublished trial while accepted owner/persistence remains unchanged.\n  lifecycle_seed%germinated=.false.\n  lifecycle_seed%sown=.false.\n  lifecycle_seed%prepared=.false.\n  call initialize_fmr_wofost_crop_transaction_state(seed,lifecycle_state,crop_status, &\n       lifecycle_initial=lifecycle_seed)\n  call require(crop_status==FMR_WOF38_OK,'optional lifecycle initial owner')\n  lifecycle_plan%valid=.true.\n  lifecycle_plan%prepared=.true.\n  lifecycle_plan%sown=.true.\n  lifecycle_plan%germination_evaluated=.true.\n  lifecycle_germination%valid=.true.\n  lifecycle_germination%complete=.false.\n  lifecycle_germination%next_temperature_sum=2.0_real64\n  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &\n       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &\n       lifecycle_expected_revision=4_8)\n  call require(crop_status==FMR_WOF38_OK.and.lifecycle_forcing%ready(), &\n       'opt-in event forcing ready')\n  call setup_crop_kernel_committed(lifecycle_state,lifecycle_committed,3831_int64,100.0_real64)\n  call lifecycle_committed%capture_checkpoint(lifecycle_checkpoint,lifecycle_checkpoint_ok)\n  call require(lifecycle_checkpoint_ok,'lifecycle checkpoint')\n  call crop_kernel%advance_interval(crop_parameters,lifecycle_committed,lifecycle_forcing,crop_config, &\n       100.0_real64,101.0_real64,lifecycle_result,lifecycle_candidate,lifecycle_diag,lifecycle_checkpoint)\n  call require(lifecycle_result%status==CANONICAL_STATUS_COMPLETED.and.lifecycle_candidate%ready(), &\n       'opt-in physical FKT lifecycle trial')\n  call lifecycle_candidate%snapshot(lifecycle_candidate_snapshot,lifecycle_available)\n  call require(lifecycle_available,'opt-in lifecycle candidate snapshot')\n  select type (tx=>lifecycle_candidate_snapshot)\n  type is (fmr_wofost_crop_transaction_state_t)\n    call tx%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)\n    call require(lifecycle_available.and.lifecycle_replayed%revision==5_8.and. &\n         lifecycle_replayed%prepared.and.lifecycle_replayed%sown.and. &\n         .not.lifecycle_replayed%emerged.and.tx%receipt_ready(), &\n         'lifecycle and physical receipt in one candidate')\n  class default\n    call require(.false.,'opt-in lifecycle candidate type')\n  end select\n  call lifecycle_committed%snapshot(lifecycle_candidate_snapshot,lifecycle_available)\n  call require(lifecycle_available,'committed snapshot remains available')\n  select type (tx=>lifecycle_candidate_snapshot)\n  type is (fmr_wofost_crop_transaction_state_t)\n    call tx%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)\n    call require(lifecycle_available.and.lifecycle_replayed%revision==4_8.and. &\n         .not.tx%receipt_ready(),'reject leaves physical and lifecycle original')\n  class default\n    call require(.false.,'unchanged committed lifecycle type')\n  end select\n  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_ATOMIC_TRIAL=PASS'\n")
p.write_text(s)
