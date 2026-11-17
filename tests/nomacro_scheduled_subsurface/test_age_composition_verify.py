import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('age_composition_owner',Path(__file__).with_name('age_composition_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class AgeCompositionEvidence(unittest.TestCase):
    def test_composed_source_output_native_and_repaired_pulse_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_COMPOSITION_QUALIFICATION.json').read_text());s.validate(q);attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',s.PARENT),('ubuntu',s.RUNTIME),('canonical_parent',s.PARENT),
                          ('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),
                          ('active_macro_qualification',True),('water_guard_cm',1e-9),('chemical_mass_guard_changed',True)]:change([key],value)
        for platform in ('Windows','Ubuntu'):
            for name in q['age'][platform]['profiles']:
                base=['age',platform,'profiles',name]
                for field in ('generated_sources_exact','compiled_closure_inputs_exact','complete_physical_age_output_rows_exact','all_five_csv_exact','all_nine_full_native_payloads_exact'):change(base+[field],False)
                change(base+['prior_native_adopted'],True)
                change(base+['own',2,'exact_native'],False)
            for name in q['wetting'][platform]['profiles']:
                change(['wetting',platform,'profiles',name,'all_other_identity_fields_exact'],False)
                change(['wetting',platform,'profiles',name,'coverage','own',1,'exact_native'],False)
            for opt in ('O0','O2'):
                change(['controls',platform,opt,'checks',15,'status'],'PASS')
                change(['controls',platform,opt,'committed_state_unchanged'],False)
            for case in q['pulse'][platform]['cases']:
                for opt in ('O0','O2'):
                    base=['pulse',platform,'cases',case,opt]
                    change(base+['full','days'],1095)
                    change(base+['full','budgets','max_solute_mg_cm2'],1.00001e-10)
                    change(base+['full','own',5,'exact_native'],False)
            change(['pulse',platform,'science'],'PASS')
        for name in q['preservation']['profiles']:change(['preservation','profiles',name,'all_generated_sources_exact'],False)
        change(['parent_owner','status'],'NOT_RUN')
        change(['workflow','status'],'FAILURE')
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):s.validate(bad)
        print('AGE_COMPOSITION_EVIDENCE_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
