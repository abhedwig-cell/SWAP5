import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('aquifer_owner',Path(__file__).with_name('aquifer_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class AquiferEvidence(unittest.TestCase):
    def test_source_mass_state_reference_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AQUIFER_QUALIFICATION.json').read_text());s.validate(q);attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('baseline',s.RUNTIME),('water_guard_cm',1e-9),
                          ('solute_guard_mg_cm2',1e-9),('new_persistent_codec',False),('tolerances_changed',True),
                          ('active_macro_qualification',True),('b1_promotion',True),('safety_factor',1.),
                          ('functional_completion','NOMACRO_FUNCTIONAL_COMPLETE'),('whole_scientific_equivalence','PASS')]:change([key],value)
        for platform in ('Windows','Ubuntu'):
            for name in sorted(s.CASES):
                path=['platforms',platform,'cases',name]
                change(path+['trajectory','days'],1095)
                change(path+['maximum_residuals','soil_aquifer_residual_mg_cm2'],1.00001e-10)
                change(path+['maximum_residuals','aquifer_exchange_residual_mg_cm2'],float('nan'))
                change(path+['own',2,'exact_native'],False)
            change(['platforms',platform,'cases','stiff-loss-O2','final_aquifer_state',6],0.)
            for opt in ('O0','O2'):
                change(['controls',platform,opt,'discard_replay_exact'],False)
                change(['controls',platform,opt,'checks',0,'refused'],False)
                change(['original_reference',platform,'profiles','corrected-'+opt,'cases','soil-transfer','max_residual_mg_cm2','compound'],1e-9)
                change(['original_reference',platform,'profiles','legacy-index-only-'+opt,'cases','soil-transfer','max_residual_mg_cm2','compound'],0.)
        change(['component','records',0,'compiler_requests'],4)
        change(['original_bounds','profiles','O2','upper_bound'],35)
        change(['original_nonfinite','nonfinite_values'],0)
        change(['native_refusals','checks'],q['native_refusals']['checks'][:-1])
        change(['native_refusals','checks',0,'status'],'PASS')
        for opt in ('O0','O2'):
            change(['chemical_composition','profiles',opt,'actual_ssdi_mass_mg_cm2'],0.)
            change(['chemical_composition','profiles',opt,'maximum_compound_residual_mg_cm2'],float('inf'))
        for name in ('salt','pulse-chemical','scheduled-chemical-interval-O2','fixed-point-O0'):
            change(['preservation','profiles',name,'all_generated_sources_exact'],False)
            change(['preservation','profiles',name,'prefix','own',0,'exact_csv'],False)
        change(['base_consumer','returncode'],1)
        change(['reference_comparison','soil-transfer-O0','whole_model_equivalence'],'PASS')
        change(['reference_rendering','current_production_patch_matches_actual_generated_source'],False)
        change(['workflow','status'],'RUNNING')
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):s.validate(bad)
        print('AQUIFER_EVIDENCE_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
