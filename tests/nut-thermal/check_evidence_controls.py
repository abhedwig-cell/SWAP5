"""Incomplete, stale or altered scoped science must not become PASS."""
import copy,json
import verify_thermal_evidence as v
if (v.ROOT/'integration/audits/MC_CROP01_TRAJECTORY4_SWRD2_STATUS.json').exists():
 import sys
 sys.path.insert(0,str(v.ROOT/'tests/root-growth'));import verify_swrd2_successor as swrd2
 print(json.dumps(swrd2.predecessor_controls('tests/nut-thermal/check_evidence_controls.py'),indent=2))
 raise SystemExit(0)
s=v.source();d=v.read(s);v.validate(d,s);passed=[]
def reject(data,label):
 try:v.validate(data,s)
 except(ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
for label,path,mutate in [
 ('small_running','profile/result.json',lambda r:r.update(status='RUNNING')),
 ('small_stale','profile/result.json',lambda r:r.update(source_tree='0'*40)),
 ('small_missing_cases','profile/result.json',lambda r:r.update(fixtures=22)),
 ('joint_running','joint/result.json',lambda r:r.update(status='RUNNING')),
 ('joint_stale','joint/result.json',lambda r:r.update(source_tree='0'*40)),
 ('joint_missing_O2','joint/result.json',lambda r:r['runs'].pop('O2')),
 ('joint_missing_BASE','joint/result.json',lambda r:r['runs']['O0']['drivers'].pop('test_calendar_joint')),
 ('joint_missing_thermal','joint/result.json',lambda r:r['runs']['O2']['drivers'].pop('test_thermal_joint')),
 ('joint_missing_calendar','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_thermal_joint'].pop('calendar')),
 ('joint_missing_native_assertions','joint/result.json',lambda r:r['runs']['O0']['drivers']['test_thermal_joint']['manual'].update(stdout='')),
 ('joint_missing_fresh','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_thermal_joint']['manual'].update(fresh_stdout='')),
 ('joint_endpoint_identity','joint/result.json',lambda r:r['runs']['O2']['drivers']['test_thermal_joint']['manual'].update(endpoint_sha256='0'*64)),
 ('policy_running','policy/result.json',lambda r:r.update(status='RUNNING')),
 ('policy_incomplete','policy/result.json',lambda r:r.update(cases=12)),
 ('restart_running','restart/results.json',lambda r:r.update(status='RUNNING')),
 ('restart_incomplete','restart/results.json',lambda r:r.update(cases=21))]:
 data=copy.deepcopy(d);r=json.loads(data[path]);mutate(r);data[path]=json.dumps(r).encode();reject(data,label)
for prefix in ['profile/','joint/','policy/']:
 for category in ['driver_compile','link','native']:
  data=copy.deepcopy(d);path=prefix+'events.json';es=json.loads(data[path]);next(e for e in es if e['category']==category)['returncode']=1;data[path]=json.dumps(es).encode();reject(data,prefix+'failed_'+category)
for path in ['joint/drivers/test_thermal_joint.f90','joint/O0/thermal-manual-restart.bin','joint/O2/thermal-calendar-fresh.bin','joint/O0/manual-expected.bin','policy/O0-initial.bin']:
 data=copy.deepcopy(d);data[path]+=b'foreign';reject(data,'raw_drift:'+path)
print(json.dumps(dict(status='PASS',negative_count=len(passed),controls=passed),indent=2))
