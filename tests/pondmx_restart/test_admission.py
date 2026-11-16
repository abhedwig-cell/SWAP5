"""Do not accept weaker mass/native/source/science claims in the new scope."""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('owner',Path(__file__).with_name('verify.py'));owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)


class Admission(unittest.TestCase):
    def test_positive_and_corruption_controls(self):
        q=json.loads((owner.ROOT/owner.PROOF/'QUALIFICATION.json').read_text());owner.validate(q)
        attacks=[]
        for field,value in [('science','PASS'),('water_guard_cm',1e-8),('runtime_source',owner.BASE)]:
            bad=copy.deepcopy(q);bad[field]=value;attacks.append(bad)
        for field,value in [('days',201),('prior_failed_source_full_physics_and_csv_exact',False)]:
            bad=copy.deepcopy(q);bad['results']['full']['reports']['water-surface-history']['O2']['full'][field]=value;attacks.append(bad)
        bad=copy.deepcopy(q);bad['results']['full']['reports']['chemical-surface-history']['O0']['full']['own'][1]['exact_native']=False;attacks.append(bad)
        bad=copy.deepcopy(q);bad['results']['full']['reports']['chemical-surface-history']['O0']['full']['budgets']['max_water_cm']=1.001e-10;attacks.append(bad)
        bad=copy.deepcopy(q);bad['results']['full']['reports']['water-surface-history']['O2']['old_source_checkpoint_refused']=False;attacks.append(bad)
        bad=copy.deepcopy(q);bad['results']['probe']['results']['unseeded']['native']['macro.bin']=True;attacks.append(bad)
        bad=copy.deepcopy(q);bad['results']['component']['profiles']['O2']['state_bytes']=72;attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(index=index),self.assertRaises(ValueError):owner.validate(bad)


if __name__=='__main__':unittest.main()
