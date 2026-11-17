import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('fixed_age_owner',Path(__file__).with_name('age_fixed_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class FixedAgeEvidence(unittest.TestCase):
    def test_fixed_source_units_native_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_FIXED_QUALIFICATION.json').read_text());s.validate(q);attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('baseline',s.RUNTIME),('functional_completion','COMPLETE'),
                          ('whole_scientific_equivalence','PASS'),('water_guard_cm',1e-9),('chemical_mass_guard_changed',True),
                          ('age_tolerance','1e-10'),('age_units','mg/cm2'),('native_codec','S5AGE001'),('new_persistent_fields',True)]:change([key],value)
        change(['scope','macro'],True);change(['scope','irrigation_age_day'],1.)
        for platform in ('Windows','Ubuntu'):
            for name in sorted(s.PROFILES):
                base=['platforms',platform,'profiles',name]
                change(base+['full','days'],1095)
                change(base+['full','budgets','max_water_cm'],1.00001e-10)
                change(base+['maximum_age_tolerance_fraction'],1.00001)
                change(base+['full','own',1,'exact_native'],False)
                change(base+['short','own','all_four_age_csv_exact'],False)
                change(['builds',platform,name,'identity','original_age_fixed_irrigation','source_sha256'],'0'*64)
                change(['builds',platform,name,'identity','original_age_fixed_irrigation','irrigation_age_day'],1.)
                change(['original_reference',platform,'profiles',name,'days'],1095)
                change(['original_reference',platform,'profiles',name,'final',5],1.)
                change(['controls',platform,'profiles',name,'metrics','actual_fixed_irrigation_cm'],0.)
                change(['controls',platform,'profiles',name,'disk_recovery_exact'],False)
                change(['inline',platform,'profiles',name,'physical_all_csv_and_four_native_payloads_exact'],False)
            change(['controls',platform,'reader_refusals'],q['controls'][platform]['reader_refusals'][:-1])
            change(['controls',platform,'reader_refusals',0,'status'],'PASS')
            change(['inactive',platform,'profiles','100-O2','generated_provider_inputs_exact'],False)
            change(['inline',platform,'zero_initial','O0','own','exact_native'],False)
        for name in q['age_off_preservation']['profiles']:change(['age_off_preservation','profiles',name,'generated_provider_inputs_exact'],False)
        change(['boundary_refusals','checks',3,'committed_state_unchanged'],False)
        change(['boundary_refusals','checks',0,'status'],'PASS')
        change(['public_cli','complete_native_payload_exact'],False)
        change(['base_consumer','actual_detached_owner','returncode'],1)
        change(['original_reference_inheritance','fresh_compile'],True)
        change(['workflow','status'],'FAILURE')
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):s.validate(bad)
        print('AGE_FIXED_EVIDENCE_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
