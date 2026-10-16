#!/usr/bin/env python3
import copy
from unittest.mock import patch
import verify_b111_nfixation_successor as v
if (v.ROOT/'tests/mc-irr01/check_managed_weather_controls.py').exists():
 import runpy
 runpy.run_path(str(v.ROOT/'tests/mc-irr01/check_managed_weather_controls.py'),run_name='__main__')
 raise SystemExit(0)

def rejects(label,call):
 try:call()
 except(AssertionError,ValueError):print('NFIX_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
original=v.git
def foreign(*a):
 s=original(*a)
 if a[:2]==('diff','--name-status'):s+='\nM\tsrc/crop/mod_wofost81_nitrogen.f90'
 return s
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
def dirty(*a):return ' M '+v.PROVIDER if a[:2]==('status','--porcelain')else original(*a)
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
r=copy.deepcopy(v.record());r['evidence']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_ARCHIVE',v.evidence)
d=v.evidence();d['literal/O2.stdout']+=b'foreign numerical output'
with patch.object(v,'evidence',return_value=d):rejects('OPTIMIZATION_DRIFT',v.verify_qualification)
d=v.evidence();d['component/native.log']=d['component/native.log'].replace(b'B111_NFIX_INVALID_CASES=39',b'ABSENT')
with patch.object(v,'evidence',return_value=d):rejects('INVALID_INPUT_PROOF_MISSING',v.verify_qualification)
d=v.evidence();d['component/native.log']=d['component/native.log'].replace(b'SWAP431_WOF81_07_N_ARBITRATION_PASS',b'ABSENT')
with patch.object(v,'evidence',return_value=d):rejects('INCUMBENT_WOFOST81_PROOF_MISSING',v.verify_qualification)
