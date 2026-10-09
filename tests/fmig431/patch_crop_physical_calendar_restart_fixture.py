from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
def replace_one(a,b):
    global s
    if s.count(a)!=1:
        raise SystemExit(f"crop restart fixture anchor mismatch {a[:60]} count={s.count(a)}")
    s=s.replace(a,b,1)

replace_one("  use mod_fmr_wofost_crop_transaction\n",
"""  use mod_fmr_wofost_crop_transaction
  use mod_fmr_crop_physical_calendar_restart_coherence
  use mod_crop_rotation_calendar
  use mod_crop_rotation_transition
""")

# Append declarations alongside the previously materialized F-WOF38 test.
replace_one("  integer :: lifecycle_persistence_status\n",
"""  integer :: lifecycle_persistence_status
  type(crop_calendar_t) :: restart_calendar, wrong_calendar
  type(crop_rotation_checkpoint_t) :: restart_calendar_checkpoint, wrong_checkpoint
  integer :: pair_status, calendar_status
""")
anchor="  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_ACCEPT_RESTART=PASS'\n"
insert="""  print '(a)', 'SW431_CROP_FKT_LIFECYCLE_ACCEPT_RESTART=PASS'
  ! A post-accept restart is coherent only when the derived calendar and
  ! the physical F-KT receipt refer to the exact same accepted instant.
  call initialize_crop_calendar([90.0_real64],[110.0_real64],restart_calendar,calendar_status)
  call require(calendar_status==CROP_CAL_OK,'restart source calendar setup')
  call initialize_crop_rotation_checkpoint(restart_calendar,101.0_real64, &
       restart_calendar_checkpoint,calendar_status)
  call require(calendar_status==ROT_TRANS_OK,'restart calendar checkpoint setup')
  call validate_committed_crop_calendar_restart_pair(lifecycle_committed,lifecycle_view, &
       restart_calendar,restart_calendar_checkpoint,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_OK,'physical calendar receipt restart coherence')
  call initialize_crop_rotation_checkpoint(restart_calendar,100.0_real64,wrong_checkpoint,calendar_status)
  call require(calendar_status==ROT_TRANS_OK,'stale calendar checkpoint setup')
  call validate_committed_crop_calendar_restart_pair(lifecycle_committed,lifecycle_view, &
       restart_calendar,wrong_checkpoint,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_TIME,'stale calendar checkpoint rejected')
  call initialize_crop_calendar([200.0_real64],[210.0_real64],wrong_calendar,calendar_status)
  call require(calendar_status==CROP_CAL_OK,'fallow calendar setup')
  call initialize_crop_rotation_checkpoint(wrong_calendar,101.0_real64,wrong_checkpoint,calendar_status)
  call require(calendar_status==ROT_TRANS_OK,'fallow calendar checkpoint setup')
  call validate_committed_crop_calendar_restart_pair(lifecycle_committed,lifecycle_view, &
       wrong_calendar,wrong_checkpoint,pair_status)
  call require(pair_status==CROP_RESTART_PAIR_CALENDAR,'unadmitted fallow restart rejected')
  print '(a)', 'SW431_CROP_PHYSICAL_CALENDAR_RESTART_PAIR=PASS'
"""
replace_one(anchor,insert)
p.write_text(s,encoding="utf-8")
