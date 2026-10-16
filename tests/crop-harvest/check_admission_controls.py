"""Current dispatch/source/projection guards retain both old and new proofs."""
import copy,json,subprocess,sys
from unittest.mock import patch
from pathlib import Path
import verify_harvest_successor as v
from default_projection import validate,PROJECTORS
if (v.ROOT/'src/runtime/mod_fmr_b111_surface_solute_route.f90').exists():
 subprocess.run([sys.executable,'-B',str(v.ROOT/'tests/nut-sol/check_surface_evidence_controls.py')],check=True);raise SystemExit(0)
passed=[]
def reject(label,call):
 try:call()
 except (ValueError,KeyError,AssertionError):passed.append(label);return
 raise AssertionError('accepted '+label)
if v.composition() is not None:
 old=v.immutable_command(v.HARVEST_PROOF,'tests/crop-harvest/check_admission_controls.py');assert old['checks']==50
 positive=v.verify_qualification();assert positive['qualified']and positive['swrd2_successor']
 for mode in ['foreign_src','foreign_test','source_blob','source_tree','reference','dirty']:
  def reader(*a):
   result=v.git(*a)
   if mode.startswith('foreign_')and a[:2]==('diff','--name-status'):return result+'\nA\t'+('src/foreign.f90'if mode=='foreign_src'else'tests/foreign.py')
   if mode=='source_blob'and a==('rev-parse','HEAD:src/crop/mod_crop_soil_n_day.f90'):return'0'*40
   if mode=='source_tree'and a==('rev-parse','HEAD:src'):return'0'*40
   if mode=='reference'and a==('rev-parse','HEAD:reference'):return'0'*40
   if mode=='dirty'and a[:2]==('status','--porcelain'):return'M src/foreign.f90'
   return result
  reject(mode,lambda:v.verify_source(reader))
 for directory,name in [('root-growth','verify_swrd2_successor'),('root-growth','verify_swrd3_successor'),('nut-calendar','verify_calendar_successor'),('nut-senescence','verify_senescence_successor'),('crop-co2','verify_co2_successor'),('nut-input','verify_input_successor'),('nut-thermal','verify_thermal_successor')]:
  sys.path.insert(0,str(v.ROOT/'tests'/directory));module=__import__(name);route=module.verify_qualification
  r=route();assert r['qualified']and r['harvest_successor']and r['swrd2_successor'];passed.append(name+':positive')
  for label,target in [('current_science','scientific_proof'),('original_owners','baseline_qualification'),('current_source','verify_source')]:
   with patch.object(v,target,side_effect=ValueError(label)):reject(name+':'+label,route)
 m=v.composition()
 for key in ['canonical','harvest_proof','swrd2_proof','source_tree']:
  wrong=copy.deepcopy(m);wrong[key]='0'*40
  with patch.object(v,'composition',return_value=wrong):reject('composition_pin:'+key,v.verify_source)
 capsule=v.ROOT/m['evidence']['path'];read=Path.read_bytes
 with patch.object(Path,'read_bytes',lambda self:bytes([read(self)[0]^1])+read(self)[1:]if self==capsule else read(self)):
  reject('composed_scientific_capsule_corruption',v.scientific_proof)
 print(json.dumps(dict(status='PASS',original_controls=old['checks'],composition_controls=len(passed),controls=passed),indent=2));raise SystemExit(0)
source=v.verify_source();positive=v.verify_qualification();assert positive['qualified']and not positive['admitted']
actual={p:(v.ROOT/p).read_text()for p in PROJECTORS};old={p:subprocess.check_output(['git','show',v.BASE+':'+p],cwd=v.ROOT,text=True)for p in PROJECTORS}
for p in actual:
 for label,side in [('changed_default',actual),('changed_baseline',old)]:
  altered=dict(side);altered[p]+='\n! unqualified body\n'
  reject(label+':'+p,lambda:validate(altered,old)if side is actual else validate(actual,altered))
for mode in ['foreign_src','foreign_test','source_blob','source_tree','reference','dirty']:
 def reader(*a):
  value=v.git(*a)
  if mode.startswith('foreign_')and a[:2]==('diff','--name-status'):return value+'\nA\t'+('src/foreign.f90'if mode=='foreign_src'else'tests/foreign.py')
  if mode=='source_blob'and a==('rev-parse','HEAD:src/crop/mod_crop_soil_n_day.f90'):return'0'*40
  if mode=='source_tree'and a==('rev-parse','HEAD:src'):return'0'*40
  if mode=='reference'and a==('rev-parse','HEAD:reference'):return'0'*40
  if mode=='dirty'and a[:2]==('status','--porcelain'):return'M src/foreign.f90'
  return value
 reject(mode,lambda:v.verify_source(reader))
m=v.metadata()
for label,mutation in [('missing_postimage',lambda s:s['postimages'].pop(next(iter(s['postimages'])))),('wrong_pin',lambda s:s.update(production_source_frozen='0'*40))]:
 altered=copy.deepcopy(m);mutation(altered)
 with patch.object(v,'metadata',return_value=altered):reject(label,v.verify_source)
# Optional implementation may project away only because current qualification
# independently pins all production bytes; even its body mutation must reject.
path=v.ROOT/'src/crop/mod_wofost81_crop_owner_state.f90';original=Path.read_bytes
with patch.object(Path,'read_bytes',lambda self:original(self)+b'\n! forged optional harvest\n'if self==path else original(self)):
 reject('projected_optional_body_still_exact_bound',v.verify_source)
moving=(v.ROOT/v.MOVING).read_text();baseline=subprocess.check_output(['git','show',v.BASE+':'+v.MOVING],cwd=v.ROOT,text=True)
for label,text in [('moving_numerical_body',moving+'\nfalse\n'),('moving_option_removed',moving.replace(v.OWNER_OPTION,''))]:
 def check():assert v.project_moving(text)==baseline
 reject(label,check)
for name,directory in [('swrd3','root-growth'),('calendar','nut-calendar'),('senescence','nut-senescence'),('co2','crop-co2'),('input','nut-input'),('thermal','nut-thermal')]:
 sys.path.insert(0,str(v.ROOT/'tests'/directory))
 module=__import__({'swrd3':'verify_swrd3_successor','calendar':'verify_calendar_successor','senescence':'verify_senescence_successor','co2':'verify_co2_successor','input':'verify_input_successor','thermal':'verify_thermal_successor'}[name])
 route=module.verify_qualification;r=route();assert r['qualified']and r['harvest_successor']and r['swrd3_successor']and r['thermal_successor'];passed.append(name+':both-proof-positive')
 for label,target in [('missing_current_science','scientific_proof'),('missing_baseline_owner','baseline_qualification'),('invalid_current_source','verify_source')]:
  with patch.object(v,target,side_effect=ValueError(label)):reject(name+':'+label,route)
# The unchanged immutable scientific verifier must refuse corruption itself.
import contextlib,io,runpy
capsule=v.ROOT/json.loads((v.ROOT/v.STATUS).read_text())['retirement_stage']['execution_evidence']['path']
with patch.object(Path,'read_bytes',lambda self:original(self)+b'!'if self==capsule else original(self)):
 # Base64 ignores a trailing nonalphabet byte, so alter its first encoded byte.
 with patch.object(Path,'read_bytes',lambda self:bytes([original(self)[0]^1])+original(self)[1:]if self==capsule else original(self)):
  with contextlib.redirect_stdout(io.StringIO()):reject('scientific_capsule_corruption',lambda:runpy.run_path(str(v.ROOT/'tests/crop-harvest/verify_evidence.py'),run_name='__main__'))
print(json.dumps(dict(status='PASS',checks=len(passed),controls=passed,original_owning_baseline=v.BASE,qualified_source=v.SOURCE_TREE,full_fci='NOT_SELECTED'),indent=2))
