#!/usr/bin/env python3
"""The new source/evidence authority must reject partial or stale qualification."""
import copy,json
from unittest.mock import patch
import verify_annual_successor as gate
count=0
def reject(name,data):
 global count
 try:gate.validate(data,check_inputs=False)
 except(ValueError,KeyError,TypeError):count+=1;return
 raise AssertionError('invalid admission accepted: '+name)
def mutate(path,fn):
 d=copy.deepcopy(original);x=json.loads(d[path]);fn(x);d[path]=json.dumps(x).encode();return d
original=gate.capsule();gate.validate(original)
reject('missing optimization',mutate('source/result.json',lambda x:x['runs'].pop()))
reject('failed source native',mutate('source/result.json',lambda x:x['runs'][0].update(native_exit=1)))
reject('foreign B111',mutate('source/result.json',lambda x:x.update(source_member_sha256='0'*64)))
reject('foreign AFGEN',mutate('source/result.json',lambda x:x.update(source_functions_sha256='0'*64)))
reject('missing organ mapping',mutate('source/result.json',lambda x:x['source_state_completeness'].update(mapping_complete_for_tested_trajectories=False)))
reject('missing fresh restart',mutate('restart/result.json',lambda x:x.update(exit=1)))
reject('missing source owner',mutate('owners/result.json',lambda x:x.update(exit=1)))
reject('failed WOFOST81',mutate('wof81/result.json',lambda x:x.update(exit=1)))
reject('codec false acceptance',mutate('codec-o0/result.json',lambda x:x['controls'][1].update(pass_=True,exit=1)))
reject('codec1 drift',mutate('zero/result.json',lambda x:x.update(zero_counter_codec1_bytes_identical=False)))
reject('failed real weather',mutate('weather/result.json',lambda x:x.update(exit=1)))
d=copy.deepcopy(original);d['weather/o0/dry-restart.txt']=b'';reject('empty native weather',d)
d=copy.deepcopy(original);d['source/o0/native.stdout']+=b'forged';reject('forged raw source output',d)
d=copy.deepcopy(original);d['restart/o2/restarted_end.artifact']+=b'forged';reject('fresh endpoint drift',d)
d=copy.deepcopy(original);d['zero/o2-current/zero.restart']+=b'forged';reject('legacy endpoint drift',d)
reject('unqualified actual predecessor',mutate('incumbent/qualification.stdout',lambda x:x.update(qualified=False)))
r=gate.record()
def source_reject(name,fn):
 global count
 try:fn()
 except(ValueError,KeyError):count+=1;return
 raise AssertionError('source accepted '+name)
bad=copy.deepcopy(r);bad['baseline']='0'*40
with patch.object(gate,'record',return_value=bad):source_reject('foreign baseline',gate.verify_source)
first=next(p for p in r['postimages']if p.startswith('src/'))
def reader(*args):
 if args==('rev-parse','HEAD:'+first):return '0'*40
 return gate.git(*args)
source_reject('stale production blob',lambda:gate.verify_source(reader))
print('CLASSIC_ANNUAL_SOURCE_EVIDENCE_CORRUPTION_CONTROLS='+str(count)+' PASS')
