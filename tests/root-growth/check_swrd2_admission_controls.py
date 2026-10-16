"""All six admission routes require both current proofs without recursion."""
import json,sys
from unittest.mock import patch
import verify_swrd2_successor as current
ROOT=current.ROOT
if (ROOT/'src/crop/mod_wofost81_harvest_materials.f90').exists():
 sys.path.insert(0,str(ROOT/'tests/crop-harvest'));import verify_harvest_successor as harvest
 harvest.verify_qualification()
 old=harvest.immutable_command(harvest.SWRD2_PROOF,'tests/root-growth/check_swrd2_admission_controls.py')
 assert old['status']=='PASS'
 current=json.loads(__import__('subprocess').check_output([sys.executable,'-B',str(ROOT/'tests/crop-harvest/check_admission_controls.py')],cwd=ROOT))
 assert current['status']=='PASS'
 print(json.dumps({**old,'original_controls_at':harvest.SWRD2_PROOF,'current_composition_controls':current},indent=2));raise SystemExit(0)
sys.path[:0]=[str(ROOT/'tests'/p)for p in ['crop-co2','nut-senescence','nut-calendar','nut-input','nut-thermal']]
import verify_co2_successor as co2
import verify_senescence_successor as senescence
import verify_calendar_successor as calendar
import verify_input_successor as amendment_input
import verify_thermal_successor as thermal
import verify_swrd3_successor as swrd3
routes={'co2':co2.verify_qualification,'senescence':senescence.verify_qualification,'calendar':calendar.verify_qualification,
 'input':amendment_input.verify_qualification,'thermal':thermal.verify_qualification,'swrd3':swrd3.verify_qualification}
passed=[]
for name,fn in routes.items():
 r=fn();assert r['qualified']and r['swrd2_successor']and r['shared_owner_gates']==10
 for label,target in [('current_science','read_evidence'),('current_owner','status')]:
  if target=='status':
   value=current.status();value.pop('owner_evidence');context=patch.object(current,target,return_value=value)
  else:context=patch.object(current,target,return_value={})
  with context:
   try:fn()
   except (ValueError,KeyError):passed.append(name+':'+label)
   else:raise AssertionError('missing proof accepted '+name+':'+label)
print(json.dumps({'status':'PASS','negative_count':len(passed),'routes':list(routes),'controls':passed},indent=2))
