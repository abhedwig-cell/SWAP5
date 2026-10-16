"""Retain all historical controls and reject unknown source/default-path changes."""
from pathlib import Path
import copy,json,subprocess,sys
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tests/nut-thermal'))
import verify_thermal_successor as v
from thermal_default_projection import validate as project,project_moving
if (ROOT/'integration/audits/MC_CROP01_TRAJECTORY4_SWRD2_STATUS.json').exists():
 import sys
 sys.path.insert(0,str(ROOT/'tests/root-growth'));import verify_swrd2_successor as swrd2
 print(json.dumps(swrd2.predecessor_controls('tests/nut-thermal/check_thermal_successor_controls.py'),indent=2))
 raise SystemExit(0)
v.verify_qualification()
prior=v.baseline_command('tests/nut-input/check_input_controls.py')
v.check(prior['status']=='PASS'and prior['negative_count']==245,'historical controls incomplete')
local=subprocess.run([sys.executable,'-B',str(ROOT/'tests/nut-thermal/check_evidence_controls.py')],cwd=ROOT,capture_output=True,text=True,check=True)
current=json.loads(local.stdout);v.check(current['status']=='PASS'and current['negative_count']==30,'thermal evidence controls incomplete')
passed=['historical:'+x for x in prior['controls']]+['thermal:'+x for x in current['controls']]
actual={p:(ROOT/p).read_text()for p in v.PROJECTORS}
old={p:subprocess.check_output(['git','show',v.BASE+':'+p],cwd=ROOT,text=True)for p in v.PROJECTORS}
for path in actual:
 for label,mutate in [
  ('foreign_body',lambda s:s.replace('module ','module foreign_',1)),
  ('wrong_base',lambda s:s+'\n! foreign\n')]:
  data=copy.deepcopy(actual);base=copy.deepcopy(old)
  if label=='wrong_base':base[path]=mutate(base[path])
  else:data[path]=mutate(data[path])
  try:project(data,base)
  except ValueError:passed.append(label+':'+path);continue
  raise AssertionError('accepted '+label+':'+path)
for path,old_text,new_text,label in [
 ('src/runtime/mod_fmr_serialized_reference_backend.f90','soil_n_heat_trace=.false.','soil_n_heat_trace=.true.','default_optin_changed'),
 ('src/runtime/mod_fmr_b111_reactive_n_joint_application.f90','ok=states_match(water,chemical,.false.)','ok=states_match(water,chemical,.true.)','BASE_matcher_opens_heat'),
 ('src/adapter/mod_crop_soil_n_joint_restart_file.f90',"PENDING_MAGIC='S5NC0002'","PENDING_MAGIC='S5NC0099'",'old_native_tag_changed')]:
 data=copy.deepcopy(actual);assert old_text in data[path];data[path]=data[path].replace(old_text,new_text,1)
 try:project(data,old)
 except ValueError:passed.append(label);continue
 raise AssertionError('accepted '+label)
original=v.v.git
moving='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
moving_body=(ROOT/moving).read_text()
moving_base=subprocess.check_output(['git','show',('a6404e1f7fcf28b7faf9b46d210bc3d5b7098e04'if (ROOT/'src/runtime/mod_fmr_biomass_root_uptake_input.f90').exists()else v.BASE)+':'+moving],cwd=ROOT,text=True)
for label,body in [('moving_numerics_changed',moving_body+'\nfalse\n'),('moving_optin_pin_changed',moving_body.replace('NUT_THERMAL_BACKEND=7e1b','NUT_THERMAL_BACKEND=ffff',1))]:
 try:
  if project_moving(body)!=moving_base:raise ValueError('changed moving body')
 except ValueError:passed.append(label);continue
 raise AssertionError('accepted '+label)
for label,row in [('foreign_source','M\tsrc/crop/mod_wofost81_nitrogen.f90'),('foreign_test','A\ttests/foreign.py'),('foreign_reference','M\treference/foreign')]:
 def changed(*a):
  result=original(*a);return result+'\n'+row if a[:2]==('diff','--name-status')else result
 try:
  with patch.object(v.v,'git',side_effect=changed):v.verify_source()
 except ValueError:passed.append(label);continue
 raise AssertionError('accepted '+label)
print(json.dumps(dict(status='PASS',negative_count=len(passed),historical_count=245,thermal_evidence_count=30,controls=passed),indent=2))
