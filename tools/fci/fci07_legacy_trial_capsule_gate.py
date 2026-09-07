#!/usr/bin/env python3
from pathlib import Path
import re, sys

root=Path(__file__).resolve().parents[2]
src=root/'src/adapter/mod_b1_10_legacy_trial_capsule.f90'
s=src.read_text()
low=s.lower()
code='\n'.join(x.split('!')[0] for x in s.splitlines())
checks={
 'capsule_type_present':'type, public :: b1_10_legacy_trial_capsule_t' in low,
 'not_canonical_state':'extends(canonical_state_t)' not in low,
 'not_transaction_state':'extends(transaction_state_t)' not in low,
 'no_file_io':not re.search(r'(?im)^\s*(open|read|write)\s*\(', code),
 'capture_present':'capture_b1_10_legacy_trial_capsule' in low,
 'restore_present':'restore_b1_10_legacy_trial_capsule' in low,
 'forcing_cursors':all(x in low for x in ['meteo_rec','rain_rec','i_metdetail','fl_update_meteo']),
 'time_numerical':all(x in low for x in ['t1900','tcum','dtold','fldecdt','fldtmin','fldtreduce']),
 'irrigation_workspace':all(x in low for x in ['dayfix','nirri','irrigevent','dt_irr_event','qssdi','qssdisum']),
 'intermediate_accounting':all(x in low for x in ['inqrot','inqdra','iqrot','igrai']),
 'cumulative_accounting':all(x in low for x in ['cgrai','cqbotdo','crunoff','cevap','cqdra','cqdrain']),
 'allocatable_large_arrays':all(re.search(rf'allocatable\s*::[^\n]*\b{x}\b',low) for x in ['qssdi','inqrot','inqdra','cqdrain']),
 'no_physical_state_payload':not re.search(r'\b(h|theta|tsoil|cml|cmsy)\s*=', low),
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI07','status':'PASS' if not failed else 'FAIL','checks':checks,'failed':failed})
sys.exit(0 if not failed else 2)
