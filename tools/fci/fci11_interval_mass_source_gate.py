#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PORT=ROOT/'src/legacy/b1_10_fci11_port'
TOOL=ROOT/'tools/fci/fci11_apply_controlled_interval_mass_port.py'
EVID=ROOT/'integration/f-ci/evidence/F-CI11_LOCAL_GENERIC_INTERVAL_GATE.json'

def lf(p:Path)->str: return p.read_text(encoding='utf-8',errors='replace').replace('\r\n','\n').replace('\r','\n')
def sha_lf(p:Path)->str: return hashlib.sha256(lf(p).encode()).hexdigest()
def assembled(name:str,n:int)->str: return ''.join(lf(PORT/f'{name}_part0{i}.inc') for i in range(1,n+1))

def main()->int:
    integral=assembled('integral',6).lower(); tc=assembled('timecontrol',6).lower(); sm=assembled('swap_main',4).lower(); sw=assembled('swap',8).lower(); seam=lf(ROOT/'src/adapter/mod_b1_10_interval_seam.f90').lower(); tool=lf(TOOL); evidence=json.loads(EVID.read_text())
    checks={
      'interval_worker_argument_explicit':'type, public :: b1_10_interval_seam_t' in seam,
      'interval_has_no_io':not re.search(r'\b(open|read|write)\s*\(',seam),
      'timecontrol_optional_interval':'subroutine timecontrol(task, interval)' in tc and 'optional :: interval' in tc,
      'interval_end_clips_dt':'get_dtevent = min(get_dtevent, intervalremaining)' in tc,
      'interval_run_end_independent':'interval%complete = .true.' in tc and 'flrunend = .true.' in tc,
      'legacy_run_end_preserved':'if (.not.intervalactive) then' in tc and 'nint(tend) - nint(t1900)' in tc,
      'day_boundary_preserved':'if (1.d0 - tcum > dtcrit)' in tc and 't1900 = dble(nint(t1900))' in tc,
      'swap_task22_prepares_interval':'if (itask == 22)' in sw and 'interval%prepared = .true.' in sw,
      'task22_does_not_force_daystart':'itask == 22' in sw and "interval t0 does not match committed physical time" in sw,
      'swap_passes_interval_to_timecontrol':'call timecontrol(task, interval)' in sw,
      'trial_mass_wired_timestep':'call integral(3, trial_mass)' in sw,
      'trial_mass_wired_crop_update':'call integral (4, trial_mass)' in sw,
      'integral_records_unrounded_step':'record_b1_10_trial_mass_step' in integral,
      'integral_records_interception_loss':'record_b1_10_trial_interception_loss' in integral,
      'legacy_dll_single_day_guard_retained':'only single day allowed: tend must equal tstart' in sw,
      'standalone_interface_optional':'optional :: trial_mass' in sm and 'optional :: interval' in sm,
      'exact_preimage_pins':all(x in tool for x in ['bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174','6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8','484b0b2d8aabead8efdbcfe01948b5fcc6b2a8be81980eec8b6214cff2c4a7e3','9922e06c085030f36527eefc3be0bbaa43e4c0cd7df1973cdb6e0a5fc214b043']),
      'exact_postimage_pins':all(x in tool for x in ['ba5edbde07a478ca4ea5454d9dcc7243f0f06d3f3de59ddc51acfcc2949ac36e','7f1a34348d758db2c095491bcb55df756ae78ab2b7269e313a2d9b90e600f619','ec5d44d871c8e5a65e76ead8c698fcc27cef643c9c0f806ab0a9bfd7a938a7a0','100aa651a2c1b13094cc56781404601b2c7efdf3934aa6d280b719874095c76a']),
      'materializer_local_pass':evidence['materializer_exact_preimage_postimage_pass'] is True,
      'local_standalone_equivalence':evidence['standalone']['fci10_candidate_vs_fci11_identical'] is True,
      'local_split_daystart_pass':evidence['day_start_split']['pass_count']==8,
      'local_generic_interval_pass':evidence['generic_interval']['pass_count']==8,
      'local_hard_mass':evidence['max_abs_residual_cm'] <= evidence['hard_mass_limit_cm'],
      'local_o0_o2_identity':evidence['o0_o2_identity'] is True,
      'temporal_error_not_claimed':evidence['temporal_error_metric_qualified'] is False,
    }
    failed=[k for k,v in checks.items() if not v]
    print({'work_unit':'F-CI11','checks':checks,'failed':failed})
    return 0 if not failed else 2
if __name__=='__main__': raise SystemExit(main())
