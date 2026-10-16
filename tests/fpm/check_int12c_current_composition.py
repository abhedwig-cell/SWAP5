#!/usr/bin/env python3
"""Bound the additive owner entrypoint; never infer a numerical PASS."""
from pathlib import Path
import re
import subprocess
ROOT=Path(__file__).resolve().parents[2]
BASE='a86da5b6931b15ef8a5432fd03adc30a72491b65'
BACKEND='src/runtime/mod_fmr_production_application_bootstrap.f90'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
raw=(ROOT/BACKEND).read_bytes()
projected=raw.decode()
projected,count=re.subn(r'  use mod_fmr_interception_source_window_binding, only:.*?FMR_INTWIN_OK\n','',projected,flags=re.S)
assert count==1,'missing/ambiguous new import'
for line in ['  integer, parameter, public :: FMR_APP_BOOT_INTERCEPTION_REJECTED = 16\n',
             '    procedure, public :: run_interception_window_interval => production_application_run_interception_window_interval\n']:
 assert projected.count(line)==1,'missing new declaration'
 projected=projected.replace(line,'')
projected,count=re.subn(r'  ! Explicit source-window application:.*?  end subroutine production_application_run_interception_window_interval\n\n','',projected,flags=re.S)
assert count==1 and projected.encode()==git('show',BASE+':'+BACKEND),'incumbent bootstrap body changed'
assert not git('diff','--name-only',BASE,'--','reference').strip(),'reference changed'
assert not git('ls-files','--others','--exclude-standard','--','src').strip(),'untracked production input'
assert git('hash-object','src/runtime/mod_fmr_interception_source_window_binding.f90').decode().strip()=='36f340ad425191a6149a50a21daccaf81d2bf839','candidate adapter changed'
assert (ROOT/'src/runtime/mod_fmr_interception_source_window_binding.f90').read_bytes()==(ROOT/'tests/fpm/recovered/mod_fmr_interception_source_window_binding.f90').read_bytes(),'recovered/candidate science differs'
assert (ROOT/'tests/fpm/test_f_mig431_int12_c.f90').read_bytes()==git('show','c0cab4f511ace7001e3e13360bc410ae950a9e3c:tests/fpm/test_f_mig431_int12_c.f90'),'original scientific driver changed'
print('INT12C_CURRENT_APPLICATION_DELTA_AND_INCUMBENT_BODY=PASS')
print('INT12C_ADAPTER_RECOVERY_BYTES_AND_ORIGINAL_SCIENCE=PASS')
