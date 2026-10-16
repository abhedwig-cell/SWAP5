#!/usr/bin/env python3
"""Existing real crop/Soil-N build, unchanged defaults and opt-in request science."""
import hashlib,json,os,runpy,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.environ.setdefault('CROP_N_RESULT_DIR',str(ROOT.parent/'b111-request-evidence'))
# Use the incumbent runner and its full literal soil, default growth, native
# decoder, mineral and reactive assertions. New drivers link this same build.
ns=runpy.run_path(str(ROOT/'tests/nut-crop/run_crop_supply.py'))
OUT=ns['OUT'];cmd=ns['cmd'];FC=ns['FC'];sha=ns['sha'];result=ns['results']
result['b111_request']={}
for opt in ['O0','O2']:
 build=OUT/opt
 flags=[s.replace(str(OUT/'O2'),str(build))for s in ns['flags']]
 flags[0]='-'+opt
 objects=sorted(build.glob('provider-*.o'),key=lambda p:int(p.stem.split('-')[-1]))
 driver=ROOT/'tests/nut-crop/test_b111_request_day.f90'
 obj=build/(driver.stem+'.o');exe=build/driver.stem
 cmd(FC+flags+['-c',driver,'-o',obj],build,'driver_compile')
 cmd(FC+flags+objects+[obj,'-o',exe],build,'link')
 output=cmd([exe],build,'native')
 assert 'B111_REQUEST_REAL_SOIL_CROP_CASES=72' in output
 joint=build/'test_crop_soil_joint';restart=build/'b111-restart.bin';expected=build/'b111-expected.bin';fresh=build/'b111-fresh.bin'
 original=cmd([joint,'write',restart,expected,'b111'],build,'native')
 continuation=cmd([joint,'resume',restart,fresh,'b111'],build,'native')
 assert expected.read_bytes()==fresh.read_bytes()==Path(str(expected)+'.opaque').read_bytes()
 # An absent or differing selected policy may not reinterpret native state.
 for policy in ['','wrong-policy']:
  assert 'INVALID_DISK=PASS' in cmd([joint,'reject',restart,'unused',policy],build,'native')
 result['b111_request'][opt]={'direct_stdout':output,'joint_stdout':original,'fresh_stdout':continuation,'endpoint_sha256':sha(expected),'restart_sha256':sha(restart),'policy_identity_negatives':2}
result['input_sha256'][str(driver.relative_to(ROOT))]=sha(driver)
for p in [Path(__file__),ROOT/'src/crop/mod_crop_b111_n_request_binding.f90']:
 result['input_sha256'][str(p.relative_to(ROOT))]=sha(p)
assert result['b111_request']['O0']==result['b111_request']['O2']
result['cost_seconds']={c:sum(e['seconds']for e in ns['events']if e['category']==c)for c in sorted({e['category']for e in ns['events']})}
result['status']='B111_REQUEST_AFFECTED_SCIENCE_PASS_NOT_ADMITTED'
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
