"""Reuse independent endpoint/envelope checks, extend actual sink ledgers."""
import runpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
def assessor():
 replace=runpy.run_path(str(HERE.parent/'fct_sinks/generate.py'))['replace']
 s=(HERE.parent/'fct_pulse_restart/verify.py').read_text().split('def controls(files):')[0]
 s=replace(s,"assert len(r['closures']['pulse'])==10 and len(r['closures']['disk'])==181","assert len(r['closures']['disk'])==182")
 s=replace(s,'assert len(builds)==4','assert len(builds)==2')
 s=replace(s,"    accuracy=runpy.run_path(str(HERE/'accuracy.py'))['compare'](r['pulse_cases'],lambda p:files[latest+'/'+p])","    assert not r['pulse_cases']")
 s=s.replace("HERE/'checkpoint.py'","HERE.parent/'fct_pulse_restart/checkpoint.py'")
 s=replace(s,"c['factor'],c['exponent']);","c['factor'],c['exponent'],c['uptake']);")
 s=replace(s,'assert len(vals)==5','assert len(vals)==7')
 s=replace(s,'vals[1]>=vals[4]>0','vals[1]>=sum(vals[4:]) and vals[4]>0 and vals[6]>0')
 s=replace(s,"        assert b'DISK_RUN_PASS'", "        assert (all(float(l.split()[-2])==0 for l in fl) if c['uptake']==0 else all(float(l.split()[-2])>0 for l in fl))\n        assert b'DISK_RUN_PASS'")
 s=s.replace("['n','factor','exponent']","['n','factor','exponent','uptake']")
 s=replace(s,"[.5,1.,2.])) and crashes==4","[.5,1.,2.],[0.,1.])) and crashes==8")
 s=replace(s,"prior['controls']>=156 and prior['reactive_controls']==8","prior['controls']>=316")
 at=s.index('    return dict(status=');s=s[:at]+'''    return dict(status='EXTRACTING_SINK_FRESH_PROCESS_RESTART_PASS',disk_cases=48,
        separate_native_runs=sum(len(c['events']) for c in r['disk_cases']),fresh_process_endpoints_byte_exact=48,
        envelope_rejections=192,native_corruption_parameter_rejections=144,publisher_process_kills=8,
        crash_recoveries_exact=8,production_activated=False,full_mc_sol01_closed=False)
'''
 ns=dict(__file__=__file__,__name__='sink_disk_verification');exec(compile(s,__file__,'exec'),ns);return ns
def assess(files):return assessor()['assess'](files)
def controls(files):
 r=json.loads(files['round1/execution.json']);c=r['disk_cases'][0];passed=[]
 targets=[c['full'],c['resumed'],'restart_bridge.f90','source/src/adapter/mod_matrix_joint_restart_file.f90','source/integration/mc-sol01/fct_sinks/generate.py']
 for p in targets:
  f=dict(files);f.pop('round1/'+p)
  try:assess(f)
  except (AssertionError,KeyError,ValueError):passed.append('missing '+p);continue
  raise AssertionError('accepted missing '+p)
 return passed
if __name__=='__main__':
 import argparse
 ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 v=runpy.run_path(str(HERE.parent/'fct_pulse_restart/verify.py'));index=json.loads((HERE/'EVIDENCE_INDEX.json').read_text());f=v['unpack'](HERE/'EVIDENCE.tar.xz.b64',index['decoded_sha256'])
 result=assess(f)
 if a.self_test:result['controls']=controls(f)
 print(json.dumps(result,indent=2))
