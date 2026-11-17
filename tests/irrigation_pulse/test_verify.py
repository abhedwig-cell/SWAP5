import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('pulse',Path(__file__).with_name('verify.py'));s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
class Admission(unittest.TestCase):
 def test_real_and_corruption(self):
  q=json.loads((s.ROOT/s.PROOF/'QUALIFICATION.json').read_text());c=json.loads((s.ROOT/s.PROOF/'COMPOSITION.json').read_text());s.validate(q,c)
  for field,value in [('full_model_days',4384),('full_native_windows',47),('science','PASS'),('default_policy_changed',True),('water_guard_cm',1e-9),('substeps_per_active_pulse',1)]:
   x=copy.deepcopy(q);x[field]=value
   with self.subTest(field=field),self.assertRaises(ValueError):s.validate(x,c)
  for change in ('native','mass','origin','reference','rollback','cost'):
   x=copy.deepcopy(q);platform=x['platforms']['WINDOWS'];v=platform['result']['cases']['water-surface-history']['O0']['full'];f=platform['finish']['cases']['water-surface-history']
   if change=='native':v['own'].pop()
   elif change=='mass':v['budgets']['max_water_cm']=1.0001e-10
   elif change=='origin':v['own'][0]['origin_unchanged']=False
   elif change=='reference':f['reference']['original_rows']=100
   elif change=='rollback':f['O0']['inconsistent_mass_refused']=False
   else:v['model_seconds']=31
   with self.subTest(change=change),self.assertRaises(ValueError):s.validate(x,c)
  for change in ('dependency','window','source'):
   x=copy.deepcopy(c);v=x['profiles']['water-surface-history-O0']
   if change=='dependency':v['all_emitted_dependencies_and_inputs_exact']=False
   elif change=='window':v['prefix']['own'].pop()
   else:x['source']='foreign'
   with self.subTest(change=change),self.assertRaises(ValueError):s.validate(q,x)
if __name__=='__main__':unittest.main()
