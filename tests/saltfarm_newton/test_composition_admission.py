"""Reject composition scope/source/guard and live production changes."""
from pathlib import Path
import copy,importlib.util,json,unittest
spec=importlib.util.spec_from_file_location('composition',Path(__file__).with_name('composition_admission.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Composition(unittest.TestCase):
 def test_literal_implicit_owner_and_nonselected_production(self):m.literal_guards()
 def test_wrong_scope_refuses(self):
  q=json.loads((m.ROOT/m.PROOF/'COMPOSITION_QUALIFICATION.json').read_text());m.validate(q)
  for key in ('status','baseline','runtime','pr','full_periods','cold_windows','water_guard_cm','solute_guard_mg_cm2','whole_scientific_equivalence','RC3_changed'):
   bad=copy.deepcopy(q);v=bad[key];bad[key]=not v if type(v)is bool else v+1 if type(v)in(int,float) else v+'-FOREIGN'
   with self.subTest(key=key),self.assertRaises(ValueError):m.validate(bad)
if __name__=='__main__':unittest.main()
