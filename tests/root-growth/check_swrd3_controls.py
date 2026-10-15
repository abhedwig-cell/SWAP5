#!/usr/bin/env python3
"""Strict source, scientific coverage and raw evidence corruption controls."""
import copy,json
import verify_swrd3_successor as v
v.verify_physical();source=v.verify_source();original=v.read_evidence();passed=[]
def bad(label,mutation):
 d=original.copy();r=json.loads(d['physical/RESULTS.json']);mutation(r,d);d['physical/RESULTS.json']=json.dumps(r).encode()
 try:v.validate_physical(d,source)
 except (ValueError,KeyError):passed.append(label)
 else:raise AssertionError('accepted '+label)
bad('unfinished',lambda r,d:r.update(status='RUNNING'))
bad('missing_profile',lambda r,d:r['results'].pop())
bad('duplicate_profile',lambda r,d:r['results'].__setitem__(0,r['results'][1]))
bad('failed_native',lambda r,d:r['results'][0].update(returncode=1))
bad('invalid_native_time',lambda r,d:r['results'][0].update(wall_seconds=float('nan')))
bad('forged_output',lambda r,d:r['results'][0].update(stdout_sha256='0'*64))
bad('failed_event',lambda r,d:r['events'][0].update(returncode=1))
bad('unchecked_flags',lambda r,d:next(e for e in r['events']if '-c'in e['command'])['command'].remove('-fcheck=all'))
bad('forged_incumbent_identity',lambda r,d:r['results'][0].update(stdout_sha256=r['results'][10]['stdout_sha256']))
bad('missing_native_execution',lambda r,d:r['events'].remove(next(e for e in r['events']if v.Path(e['command'][0]).name.startswith('test-'))))
def forged_input(r,d):r['source_inputs'][v.BOOT]='0'*64
bad('stale_bootstrap',forged_input)
for label,change in [
 ('probe_missing_profile',lambda r:r['results'].pop()),
 ('probe_failed_native',lambda r:r['results'][0].update(returncode=1)),
 ('probe_missing_native',lambda r:r['events'].remove(next(e for e in r['events']if v.Path(e['command'][0]).name.startswith('test-'))))]:
 d=original.copy();r=json.loads(d['probe/RESULTS.json']);change(r);d['probe/RESULTS.json']=json.dumps(r).encode()
 try:v.validate_physical(d,source)
 except (ValueError,KeyError):passed.append(label)
 else:raise AssertionError(label)
for mode in ['extra_source','foreign_blob','reference']:
 def reader(*args):
  value=v.git(*args)
  if mode=='extra_source'and args[:2]==('diff','--name-status'):return value+'\nA\tsrc/foreign.f90'
  if mode=='foreign_blob'and args==('rev-parse','HEAD:'+v.BOOT):return'0'*40
  if mode=='reference'and args==('rev-parse','HEAD:reference'):return'0'*40
  return value
 try:v.verify_source(reader)
 except ValueError:passed.append(mode)
 else:raise AssertionError(mode)
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed},indent=2))
