import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('age_owner',Path(__file__).with_name('age_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class AgeEvidence(unittest.TestCase):
    def test_source_units_state_reference_and_output_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_QUALIFICATION.json').read_text());s.validate(q);attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('core_runtime',s.RUNTIME),
                          ('full_model_days',8767),('full_native_windows',31),('prior_core_native_projections',71),
                          ('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),
                          ('chemical_mass_guard_changed',True),('water_guard_cm',1e-9),('units','mg/cm2'),
                          ('age_tolerance','1e-10'),('native_codec','S5AGE001'),('effluent_missing',0),
                          ('effluent_policy','time-weighted'),('active_macro_qualification',True),('b1_promotion',True)]:change([key],value)
        change(['scope','fixed_irrigation'],True)
        change(['scope','qualified_output'],'all')
        for platform in ('Windows','Ubuntu'):
            for name in sorted(s.PROFILES):
                path=['platforms',platform,'profiles',name]
                change(path+['full','days'],1095)
                change(path+['full','budgets','max_water_cm'],1.00001e-10)
                change(path+['maximum_fraction_of_accepted_age_tolerance'],1.00001)
                change(path+['maximum_residual_cm_day','age_combined_residual_cm_day'],float('nan'))
                change(path+['own',2,'exact_native'],False)
                change(path+['short','own','all_four_age_csv_exact'],False)
                change(path+['effluent_output','all_daily_mean_and_volume_fields_match_full_precision_probe'],False)
                change(path+['prior_core_preservation'],{'physical':False})
                change(['builds',platform,name,'identity','donor_generated','solute.f90'],'0'*64)
            for opt in ('O0','O2'):
                change(['controls',platform,opt,'committed_state_unchanged'],False)
                change(['controls',platform,opt,'checks',15,'status'],'PASS')
                change(['original_provider_reference',platform,'profiles',opt,'cases','0','all_core_reference_rows_exact'],False)
        for name in ('clock','surface_default','effluent'):change(['components',name,'records',0,'compiler_requests'],99)
        change(['native_refusals','checks'],q['native_refusals']['checks'][:-1])
        change(['native_refusals','checks',0,'status'],'PASS')
        for name in q['preservation']['profiles']:
            change(['preservation','profiles',name,'all_generated_sources_exact'],False)
            change(['preservation','profiles',name,'prefix','own',0,'exact_csv'],False)
        change(['existing_owner_inheritance','fresh_execution'],True)
        change(['base_consumer','returncode'],1)
        change(['legacy_source_baseline_failure','returncode'],0)
        change(['public_cli','all_five_csv_windows_exact'],False)
        change(['workflow','status'],'RUNNING')
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):s.validate(bad)
        print('AGE_EVIDENCE_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
