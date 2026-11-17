import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('scheduled_owner',Path(__file__).with_name('scheduled_chemical_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class ScheduledEvidence(unittest.TestCase):
    def test_scheduled_source_state_reference_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'SCHEDULED_CHEMICAL_QUALIFICATION.json').read_text());s.validate(q);attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('full_trajectories',4),('full_model_days',1096),('full_native_windows',24),('short_native_windows',4),('water_guard_cm',1e-9),('solute_guard_mg_cm2',1e-9),('new_physical_formula',True),('new_persistent_codec',True),('tolerances_changed',True),('active_macro_qualification',True),('b1_promotion',True),('functional_completion','NOMACRO_FUNCTIONAL_COMPLETE'),('whole_scientific_equivalence','PASS')]:change([key],value)
        for platform in ('Windows','Ubuntu'):
            for kind in ('point','interval'):
                p=['platforms',platform,kind,'profiles','O2']
                for key,value in [('max_water_cm',1.00001e-10),('max_solute_mg_cm2',float('nan')),('max_kernel_cm',-1)]:change(p+['budgets',key],value)
                change(p+['irrigation_mass_mg_cm2'],0)
                change(p+['first_actual_source_day'],545)
                change(p+['own',3,'exact_native'],False)
                change(p+['short','own','origin_unchanged'],False)
                change(p+['controls','active_disk_recovery'],False)
                change(p+['controls','committed_state_unchanged'],False)
        for opt in ('O0','O2'):
            change(['original_reference','profiles','corrected-'+opt,'interval-20','irrigation_mass_mg_cm2'],0)
            change(['original_reference','profiles','original-'+opt,'point-20','irrigation_mass_mg_cm2'],64)
        change(['native_controls','checks'],q['native_controls']['checks'][:-1])
        change(['native_controls','checks',10,'active_source'],False)
        change(['native_controls','checks',11,'alternating_steps'],2)
        for name in ('fixed-point-O0','scheduled-water-O2','salt','pulse-chemical'):
            change(['preservation','profiles',name,'all_generated_sources_exact'],False)
            change(['preservation','profiles',name,'prefix','own',0,'exact_csv'],False)
        change(['base_consumer','returncode'],1)
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):s.validate(bad)
        print('SCHEDULED_CHEMICAL_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
