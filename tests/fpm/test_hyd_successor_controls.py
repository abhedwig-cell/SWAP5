#!/usr/bin/env python3
"""Reject foreign/dirty source and absent, corrupt or optimization-drifted proof."""
import copy
from unittest.mock import patch
import verify_hyd_successor as v

def rejects(label,call):
 try:call()
 except (AssertionError,ValueError):print('HYD_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
original=v.git
def foreign(*a):
 value=original(*a)
 if a[:2]==('diff','--name-status'):value+='\nA\tsrc/unknown_hyd.f90'
 return value
rejects('FOREIGN_SOURCE',lambda:v.verify_source(foreign))
def dirty(*a):return ' M src/unknown_hyd.f90' if a[:2]==('status','--porcelain') else original(*a)
rejects('DIRTY_SOURCE',lambda:v.verify_source(dirty))
r=copy.deepcopy(v.record());r['evidence']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_ARCHIVE',v.evidence)
d=v.evidence()
for opt in ['O0','O2']:
 name='runtime/'+opt+'-runtime.stdout';d[name]=d[name].replace(b'SWAP431_HYD_RUNTIME_MODEL6=PASS',b'ABSENT')
with patch.object(v,'evidence',return_value=d):rejects('MISSING_MODEL6_NATIVE',v.verify_qualification)
d=v.evidence();d['literal/O2.stdout']+=b'output drift'
with patch.object(v,'evidence',return_value=d):rejects('LITERAL_OPTIMIZATION_DRIFT',v.verify_qualification)
d=v.evidence()
name=next(p for p in d if p.startswith('root_receiving/') and 'native-density-neutral-continuous.stdout' in p)
d[name]=b'absent joint density proof'
with patch.object(v,'evidence',return_value=d):rejects('JOINT_ROOT_NATIVE_MISSING',v.verify_qualification)
