"""Current actual scope/source guards reject metadata mutations without models."""
import copy,json,unittest
import groundwater_water_composition_verify as v


class Composition(unittest.TestCase):
 def test_actual_composed_source_and_corrupted_authority(self):
  q=json.loads((v.ROOT/v.PROOF/'GROUNDWATER_WATER_COMPOSITION_QUALIFICATION.json').read_text());v.source(q)
  changes={'status':'FOREIGN','runtime':'0'*40,'incoming_canonical':'0'*40,'groundwater_qualified_head':'0'*40,'functional_completion':'COMPLETE','whole_scientific_equivalence':'PASS','water_guard_cm':1e-9,'chemical_guard_mg_cm2':1e-9,'RC3_changed':True,'full_model_periods_repeated':1}
  for key,value in changes.items():
   bad=copy.deepcopy(q);bad[key]=value
   with self.subTest(key=key),self.assertRaises(ValueError):v.source(bad)
  for field in ('source_sha256','controller_sha256','locations'):
   bad=copy.deepcopy(q);bad[field].pop(next(iter(bad[field])))
   with self.subTest(field=field),self.assertRaises(ValueError):v.source(bad)
  bad=copy.deepcopy(q);bad['workflow']['conclusion']='failure'
  with self.assertRaises(ValueError):v.source(bad)


if __name__=='__main__':unittest.main()
