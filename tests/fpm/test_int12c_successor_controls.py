#!/usr/bin/env python3
"""Reject missing/stale source and numerical proof without changing production."""
import copy
from unittest.mock import patch
import verify_int12c_successor as v

def rejects(label,call):
 try:call()
 except (ValueError,AssertionError):print('INT12C_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)

original=v.git
def foreign(*args):
 value=original(*args)
 if args[:2]==('diff','--name-status'):value+='\nA\tsrc/runtime/unknown_source.f90'
 return value
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
def dirty(*args):return ' M '+v.BOOT if args[:2]==('status','--porcelain') else original(*args)
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
r=copy.deepcopy(v.record());r['archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('ARCHIVE_CORRUPTION',v.evidence)
d=v.evidence()
for opt in (0,2):
 name='final/o'+str(opt)+'.txt';d[name]=d[name].replace(b'INT12C_DIRECT_PMDIRECT_DYNAMIC_TOP_ACTIVE_ROOT_COMMITS=PASS',b'ABSENT')
with patch.object(v,'evidence',return_value=d):rejects('MISSING_NUMERICAL_PROOF',v.verify_qualification)
d=v.evidence();d['final/o2.txt']+=b'foreign output'
with patch.object(v,'evidence',return_value=d):rejects('OPTIMIZATION_DRIFT',v.verify_qualification)
