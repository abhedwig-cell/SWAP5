"""Refuse source/scope/guard inflation without rerunning unchanged physics."""
from pathlib import Path
import copy,importlib.util,json,unittest
spec=importlib.util.spec_from_file_location('typed07',Path(__file__).with_name('typed_admission07.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class TypedAdmission(unittest.TestCase):
 def test_literal_nonselected_projection(self):m.projection()
 def test_wrong_scope_source_and_guards(self):
  q=json.loads((m.ROOT/m.PROOF/'QUALIFICATION.json').read_bytes());m.validate(q)
  for key in ('status','baseline','runtime','incoming_canonical','composed_runtime','model','water_guard_cm','solute_guard_mg_cm2','full_periods_ubuntu','cold_windows_ubuntu','windows_role','whole_scientific_equivalence','functional_completion','RC3_changed'):
   bad=copy.deepcopy(q);v=bad[key];bad[key]=not v if type(v)is bool else v+1 if type(v)in(int,float) else v+'-FOREIGN'
   with self.subTest(key=key),self.assertRaises(ValueError):m.validate(bad)
if __name__=='__main__':unittest.main()
