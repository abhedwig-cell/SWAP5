"""Negative admission controls, independent of producer PASS summaries."""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('owner',Path(__file__).with_name('direct_admission.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
class Admission(unittest.TestCase):
 def test_literal_nonselected_projection(self):owner.nonselected_projection()
 def test_scope_source_guards_and_denominator_refuse_corruption(self):
  q=json.loads((owner.ROOT/owner.PROOF/'ADMISSION.json').read_text());owner.validate(q)
  for field in ('status','base','runtime','native_producer','model','protocol','water_guard_cm','solute_guard_mg_cm2','full_periods','cold_windows','whole_scientific_equivalence','RC3_changed','predecessor','owner'):
   bad=copy.deepcopy(q);value=bad[field];bad[field]=not value if type(value)is bool else value+1 if type(value) in (int,float) else value+'-FOREIGN'
   with self.subTest(field=field),self.assertRaises(ValueError):owner.validate(bad)
 def test_historical_body_not_replaced(self):
  current=(owner.ROOT/owner.ENTRY).read_text(encoding='utf8');self.assertEqual(current.replace(owner.HOOK,'',1).encode(),owner.normalized(owner.blob(owner.BASE,owner.ENTRY)))
if __name__=='__main__':unittest.main()
