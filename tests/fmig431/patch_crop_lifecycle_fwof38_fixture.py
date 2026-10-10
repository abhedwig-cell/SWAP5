from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
def replace_one(a,b):
    global s
    assert s.count(a)==1, (a[:80],s.count(a))
    s=s.replace(a,b,1)
# The historical F-WOF34 toy donor reported a flux but lacked the
# complete mass contribution certificate now required by F-KT. Repair only
# the disposable combined test fixture, never its frozen source.
replace_one('    outcome%mass_in = transfer_mass',
            '    outcome%mass_in = transfer_mass\n'
            '    outcome%mass_accounting_complete = .true.\n'
            '    outcome%missing_mass_contribution_mask = 0_8')
# Current transaction core also requires explicit storage provenance.
# Repair the disposable toy's method rather than altering production science.
replace_one('    procedure :: temporal_error => fwof34_temporal_error',
            '    procedure :: temporal_error => fwof34_temporal_error\n'
            '    procedure :: storage_accounting_status => fwof34_storage_accounting_status')
replace_one('  real(real64) function fwof34_storage(self, state) result(value)',
'''  subroutine fwof34_storage_accounting_status(self, state, complete, missing_mask)
    class(fwof34_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(kind=8), intent(out) :: missing_mask
    complete = .false.
    missing_mask = 1_8
    if (.not. same_type_as(self,self)) return
    select type(state)
    type is (fwof34_state_t)
      complete = .true.
      missing_mask = 0_8
    class default
      return
    end select
  end subroutine fwof34_storage_accounting_status

  real(real64) function fwof34_storage(self, state) result(value)''')
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
replace_one("  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'\n", """  call require(crop_checkpoint_ok, 'F-WOF38 crop checkpoint')
  ! One opt-in F-KT trial: candidate and receipt must remain on the
  ! unpublished trial while accepted owner/persistence remains unchanged.
  lifecycle_seed%germinated=.false.
  lifecycle_seed%germination_temperature_sum=0.0_real64
  lifecycle_seed%sown=.false.
  lifecycle_seed%prepared=.false.
  call initialize_fmr_wofost_crop_transaction_state(seed,lifecycle_state,crop_status, &
       lifecycle_initial=lifecycle_seed)
  call require(crop_status==FMR_WOF38_OK,'optional lifecycle initial owner')
  lifecycle_plan%valid=.true.
  lifecycle_plan%prepared=.true.
  lifecycle_plan%sown=.true.
  lifecycle_plan%germination_evaluated=.true.
  lifecycle_germination%valid=.true.
  lifecycle_germination%complete=.false.
  lifecycle_germination%next_temperature_sum=2.0_real64
  ! Constructor guards reject invalid lifecycle plans before a physical trial.
  lifecycle_plan%sown=.false.
  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &
       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &
       lifecycle_expected_revision=4_8)
  call require(crop_status==FMR_WOF38_LIFECYCLE_REJECTED.and..not.lifecycle_forcing%ready(), &
       'reject germination before sowing')
  lifecycle_plan%sown=.true.
  lifecycle_plan%germination_evaluated=.false.
  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &
       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &
       lifecycle_expected_revision=4_8)
  call require(crop_status==FMR_WOF38_LIFECYCLE_REJECTED.and..not.lifecycle_forcing%ready(), &
       'reject untested germination for sown crop')
  lifecycle_plan%germination_evaluated=.true.
  lifecycle_germination%valid=.false.
  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &
       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &
       lifecycle_expected_revision=4_8)
  call require(crop_status==FMR_WOF38_LIFECYCLE_REJECTED.and..not.lifecycle_forcing%ready(), &
       'reject invalid germination input')
  lifecycle_germination%valid=.true.
  lifecycle_germination%next_temperature_sum=-1.0_real64
  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &
       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &
       lifecycle_expected_revision=4_8)
  call require(crop_status==FMR_WOF38_LIFECYCLE_REJECTED.and..not.lifecycle_forcing%ready(), &
       'reject negative germination sum')
  lifecycle_germination%next_temperature_sum=2.0_real64
  print '(a)', 'SW431_CROP_FKT_EVENT_PREFLIGHT_NEGATIVES=PASS'
  call prepare_fmr_wofost_crop_event_forcing(accepted_window,forcing,lifecycle_forcing,crop_status, &
       lifecycle_plan=lifecycle_plan,lifecycle_germination=lifecycle_germination, &
       lifecycle_expected_revision=4_8)
  call require(crop_status==FMR_WOF38_OK.and.lifecycle_forcing%ready(), &
       'opt-in event forcing ready')
  call setup_crop_kernel_committed(lifecycle_state,lifecycle_committed,3831_int64,100.0_real64)
  call lifecycle_committed%capture_checkpoint(lifecycle_checkpoint,lifecycle_checkpoint_ok)
  call require(lifecycle_checkpoint_ok,'lifecycle checkpoint')
  call crop_kernel%advance_interval(crop_parameters,lifecycle_committed,lifecycle_forcing,crop_config, &
       100.0_real64,101.0_real64,lifecycle_result,lifecycle_candidate,lifecycle_diag,lifecycle_checkpoint)
  call require(lifecycle_result%status==CANONICAL_STATUS_COMPLETED.and.lifecycle_candidate%ready(), &
       'opt-in physical FKT lifecycle trial')
  call lifecycle_candidate%snapshot(lifecycle_candidate_snapshot,lifecycle_available)
  call require(lifecycle_available,'opt-in lifecycle candidate snapshot')
  select type (tx=>lifecycle_candidate_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
    call require(lifecycle_available.and.lifecycle_replayed%revision==5_8.and. &
         lifecycle_replayed%prepared.and.lifecycle_replayed%sown.and. &
         .not.lifecycle_replayed%emerged.and.tx%receipt_ready(), &
         'lifecycle and physical receipt in one candidate')
  class default
    call require(.false.,'opt-in lifecycle candidate type')
  end select
  call lifecycle_committed%snapshot(lifecycle_candidate_snapshot,lifecycle_available)
  call require(lifecycle_available,'committed snapshot remains available')
  select type (tx=>lifecycle_candidate_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
    call require(lifecycle_available.and.lifecycle_replayed%revision==4_8.and. &
         .not.tx%receipt_ready(),'reject leaves physical and lifecycle original')
  class default
    call require(.false.,'unchanged committed lifecycle type')
  end select
  ! Commit exactly one accepted F-KT candidate. The physical receipt and
  ! continuation must survive owner persistence and fresh reconstruction.
  crop_revision_before=lifecycle_committed%current_revision()
  call crop_kernel%commit_candidate(lifecycle_committed,lifecycle_candidate,lifecycle_diag, &
       did_commit,crop_commit_status)
  call require(did_commit.and.crop_commit_status==KERNEL_COMMIT_STATUS_COMMITTED, &
       'lifecycle and crop physical FKT commit')
  call require(lifecycle_committed%current_revision()==crop_revision_before+1_8, &
       'one accepted lifecycle physical revision')
  call lifecycle_committed%snapshot(lifecycle_candidate_snapshot,lifecycle_available)
  call require(lifecycle_available,'postcommit physical crop snapshot')
  select type (tx=>lifecycle_candidate_snapshot)
  type is (fmr_wofost_crop_transaction_state_t)
    call tx%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
    call require(lifecycle_available.and.lifecycle_replayed%revision==5_8.and. &
         tx%receipt_ready(),'accepted lifecycle and receipt are co-committed')
    call export_fmr_wofost_crop_transaction_persistence(tx,lifecycle_view, &
         lifecycle_exported,lifecycle_persistence_status)
    call require(lifecycle_exported.and.lifecycle_persistence_status==FMR_WOFOST_CROP_PERSISTENCE_OK, &
         'accepted owner lifecycle restart persistence')
  class default
    call require(.false.,'accepted physical lifecycle owner type')
  end select
  call reconstruct_fmr_wofost_crop_transaction_from_persistence(lifecycle_view,lifecycle_restored, &
       lifecycle_reconstructed,lifecycle_persistence_status)
  call require(lifecycle_reconstructed.and.lifecycle_restored%receipt_ready(), &
       'accepted lifecycle restart reconstruction')
  call lifecycle_restored%snapshot_lifecycle(lifecycle_replayed,lifecycle_available)
  call require(lifecycle_available.and.lifecycle_replayed%revision==5_8.and. &
       lifecycle_replayed%prepared.and.lifecycle_replayed%sown.and. &
       .not.lifecycle_replayed%germinated.and..not.lifecycle_replayed%emerged, &
       'accepted crop lifecycle restart successor')
  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_ACCEPT_RESTART=PASS'
  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_ATOMIC_TRIAL=PASS'

  print '(a)', 'FWOF38_ATOMIC_CROP_TRANSACTION_GATE PASS'
""")
replace_one("    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-WOF38 physical trial completes')", """    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) then
      print *, 'SW431_FKT_PHYSICAL_FAILURE status=', result%status, ' completed=', result%completed
      print *, 'SW431_FKT_PHYSICAL_FAILURE t0=', t0, ' t1=', t1, ' revision=', state%current_revision()
      print *, 'SW431_FKT_DIAG calls=',diagnostics%transaction_calls, &
           ' attempts=',diagnostics%attempts,' solver_reject=',diagnostics%solver_rejections, &
           ' mass_reject=',diagnostics%mass_rejections,' temporal_reject=',diagnostics%temporal_rejections
    end if
    call require(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'F-WOF38 physical trial completes')""")
p.write_text(s)
