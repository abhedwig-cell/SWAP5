"""Positive current proof first; independent mutations must then fail closed."""
import copy,json,sys
import verify_swrd2_successor as v
source=v.verify_source();data=v.read_evidence();v.validate(data,source);passed=[]
def bad(label,path,mutation):
 d=data.copy();r=json.loads(d[path]);mutation(r);d[path]=json.dumps(r).encode()
 try:v.validate(d,source)
 except (ValueError,KeyError):passed.append(label)
 else:raise AssertionError('accepted '+label)
for label,mutation in [
 ('unfinished',lambda r:r.update(status='RUNNING')),
 ('missing_native',lambda r:r['results'].pop()),
 ('duplicate_native',lambda r:r['results'].__setitem__(0,r['results'][1])),
 ('failed_native',lambda r:r['results'][0].update(returncode=1)),
 ('nonfinite_cost',lambda r:r['results'][0].update(wall_seconds=float('nan'))),
 ('forged_output',lambda r:r['results'][0].update(stdout_sha256='0'*64)),
 ('failed_compile',lambda r:r['events'][2].update(returncode=1)),
 ('missing_event',lambda r:r['events'].remove(next(e for e in r['events']if v.Path(e['command'][0]).name.startswith('test-')))),
 ('unchecked_compile',lambda r:next(e for e in r['events']if '-c'in e['command'])['command'].remove('-fcheck=all'))]:
 bad(label,'physical/RESULTS.json',mutation)
for label,mutation in [
 ('direct_unfinished',lambda r:r.update(status='FAIL')),
 ('direct_missing',lambda r:r['runs'].pop()),
 ('direct_duplicate',lambda r:r['runs'].__setitem__(0,r['runs'][1])),
 ('direct_stale',lambda r:r['inputs'].update({'src/runtime/mod_fmr_wofost_crop_transaction.f90':'0'*64}))]:
 bad(label,'direct/result.json',mutation)
for mode in ['extra_source','foreign_blob','reference']:
 def reader(*args):
  result=v.git(*args)
  if mode=='extra_source'and args[:2]==('diff','--name-status'):return result+'\nA\tsrc/foreign.f90'
  if mode=='foreign_blob'and args==('rev-parse','HEAD:'+v.prior.BOOT):return'0'*40
  if mode=='reference'and args==('rev-parse','HEAD:reference'):return'0'*40
  return result
 try:v.verify_source(reader)
 except ValueError:passed.append(mode)
 else:raise AssertionError(mode)
print(json.dumps({'status':'PASS','negative_count':len(passed),'controls':passed},indent=2))
