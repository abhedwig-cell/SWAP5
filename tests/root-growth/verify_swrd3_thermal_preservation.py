#!/usr/bin/env python3
"""Executed full scope preserved by exact default projection plus fresh opt-in science."""
import json,sys,subprocess
import verify_swrd3_successor as v
FULL='a6404e1f7fcf28b7faf9b46d210bc3d5b7098e04'
CANONICAL='e6fd1da26b647252a5c4020a0de23ccab7d11265'
FCI='tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'
OWN='tests/root-growth/verify_swrd3_thermal_preservation.py'
GUARDS={FCI,'tests/crop-co2/verify_co2_successor.py','tests/nut-calendar/verify_calendar_successor.py','tests/nut-input/verify_input_successor.py','tests/nut-input/check_input_controls.py','tests/root-growth/verify_swrd3_successor.py','tests/root-growth/check_combined_admission_controls.py'}

def validate(data,source,status,reader=v.git,read_file=lambda p:(v.ROOT/p).read_bytes()):
 sys.path.insert(0,str(v.ROOT/'tests/nut-thermal'))
 from thermal_default_projection import PROJECTORS,project_moving
 r=json.loads(data['RESULT.json']);inputs=json.loads(data['INPUTS.json'])
 v.check(r['status']=='PASS'and r['returncode']==0 and r['terminal_marker']and not r['changed_inputs'],'full not terminal PASS')
 v.check(r['execution_commit']==FULL and r['source_tree']=='9747341e2381a24f1b13022eda0524bc3f091ae8','wrong full execution')
 v.check(r['tracked_inputs']==len(inputs)==6423 and r['resume_mode']=='OFF'and r['highest_low_air']=='NOT_SELECTED_POLICY','full scope drift')
 v.check(reader('rev-parse',FULL+'^{tree}')==r['tree'],'executed tree drift')
 for stream in ['stdout','stderr']:v.check(v.sha(data['moving.'+stream])==r[stream+'_sha256'],'full raw drift')
 v.check(b'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS'in data['moving.stdout'],'full marker absent')
 rows={p:mode for mode,p in(row.split('\t')for row in reader('diff','--name-status',FULL,'HEAD','--','src','tests','tools','reference').splitlines())}
 additions={p for mode,p in(row.split('\t')for row in reader('diff','--name-status','cd64c5044a29643a068c6151720f76b2e70f570d',CANONICAL,'--','src','tests','tools','reference').splitlines())if mode=='A'}|{OWN}
 v.check(rows=={**{p:'M'for p in GUARDS|set(PROJECTORS)},**{p:'A'for p in additions}},'preservation delta widened')
 # Removing only the canonical reviewed eligibility dispatch must reveal the
 # exact complete numerical body that actually ran, including every assertion.
 original=subprocess.check_output(['git','show',FULL+':'+FCI],cwd=v.ROOT)
 v.check(project_moving(read_file(FCI).decode()).encode()==original,'moving numerical body changed')
 checked=0
 for p,h in inputs.items():
  if not p.startswith(('src/','tests/','tools/','reference/')):continue
  actual=v.sha(read_file(p))
  if p in GUARDS:
   v.check(status['thermal_full_guard_rebinding'].get(p)=={'before':h,'after':actual},'unbound guard pair '+p)
  elif p in PROJECTORS:
   old=subprocess.check_output(['git','show',FULL+':'+p],cwd=v.ROOT)
   v.check(v.sha(old)==h and PROJECTORS[p](read_file(p).decode()).encode()==old,'default branch changed '+p)
  else:v.check(actual==h,'native dependency changed '+p)
  checked+=1
 v.check(source['source_tree']==status['production_source_tree']==reader('rev-parse','HEAD:src'),'current tree mismatch')
 return dict(status='PASS',full_execution=FULL,executed_full_source_tree=r['source_tree'],current_source_tree=source['source_tree'],full_execution_at_current_tree=False,scope='All executed existing defaults: exact native inputs or three reviewed default projections; full numeric body byte-identical. New thermal opt-in requires separately fresh current-source science.',native_dependency_files=checked,guard_pairs=len(GUARDS),projected_dependencies=sorted(PROJECTORS),highest_low_air='NOT_SELECTED_POLICY')
def verify():
 source=v.verify_qualification();s=json.loads((v.ROOT/v.STATUS).read_text())
 return validate(v.capsule(s['full_preservation']['evidence']),source,s)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
