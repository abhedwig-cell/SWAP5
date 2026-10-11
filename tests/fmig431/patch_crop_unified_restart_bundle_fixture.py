from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
def replace_one(a,b):
    global s
    count=s.count(a)
    if count != 1:
        raise SystemExit(f"restart bundle fixture anchor {a[:65]!r} count={count}")
    s=s.replace(a,b,1)

replace_one("  integer :: pair_status, calendar_status\n",
"""  integer :: pair_status, calendar_status
  type(fmr_crop_physical_calendar_restart_bundle_t) :: restart_bundle, tampered_bundle
  type(fmr_wofost_crop_transaction_state_t) :: restored_bundle_crop
  type(crop_rotation_checkpoint_t) :: restored_bundle_calendar
""")
anchor="  print '(a)', 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS'\n"
addition="""  print '(a)', 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS'
  call export_committed_crop_calendar_restart_bundle(lifecycle_committed,lifecycle_view, &
       restart_calendar,restart_calendar_checkpoint,restart_bundle,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_OK.and.restart_bundle%ready(), &
       'export post-event physical/calendar restart pair')
  call reconstruct_committed_crop_calendar_restart_bundle(restart_bundle,restart_calendar, &
       lifecycle_committed,restored_bundle_crop,restored_bundle_calendar,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_OK, &
       'paired physical calendar checkpoint reconstructed from persistence')
  call require(restored_bundle_crop%receipt_ready(), &
       'reconstructed crop owner has same committed event receipt')
  call require(restored_bundle_calendar%crop()==restart_calendar_checkpoint%crop().and. &
       restored_bundle_calendar%serial()==restart_calendar_checkpoint%serial().and. &
       transfer(restored_bundle_calendar%time(),0_8)== &
       transfer(restart_calendar_checkpoint%time(),0_8), &
       'reconstructed exact calendar crop time and revision')
  tampered_bundle=restart_bundle
  tampered_bundle%fkt_revision=tampered_bundle%fkt_revision+1_8
  call reconstruct_committed_crop_calendar_restart_bundle(tampered_bundle,restart_calendar, &
       lifecycle_committed,restored_bundle_crop,restored_bundle_calendar,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_INVALID, &
       'stale FKT kernel revision rejected')
  tampered_bundle=restart_bundle
  tampered_bundle%calendar%active_crop=0
  call reconstruct_committed_crop_calendar_restart_bundle(tampered_bundle,restart_calendar, &
       lifecycle_committed,restored_bundle_crop,restored_bundle_calendar,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_CALENDAR, &
       'wrong source crop identity rejected during reconstruction')
  tampered_bundle=restart_bundle
  tampered_bundle%crop%receipt%t1=tampered_bundle%crop%receipt%t1+1.0_real64
  call reconstruct_committed_crop_calendar_restart_bundle(tampered_bundle,restart_calendar, &
       lifecycle_committed,restored_bundle_crop,restored_bundle_calendar,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_INVALID, &
       'wrong receipt end time rejected at bundle validation')
  print '(a)', 'SW431_CROP_UNIFIED_RESTART_BUNDLE_ACCEPT_NEGATIVE=PASS'
"""
replace_one(anchor,addition)
p.write_text(s,encoding="utf-8")
