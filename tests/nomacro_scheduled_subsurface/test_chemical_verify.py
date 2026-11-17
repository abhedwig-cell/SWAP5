import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('chemical_owner',Path(__file__).with_name('chemical_verify.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)


class ChemicalEvidenceGuard(unittest.TestCase):
    def test_active_source_native_reference_and_scope_corruptions(self):
        q=json.loads((c.ROOT/c.PROOF/'CHEMICAL_QUALIFICATION.json').read_text());c.validate(q)
        attacks=[]
        def change(path,value):
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value;attacks.append(bad)
        for key,value in [('runtime',c.BASE),('ubuntu',c.RUNTIME),('full_trajectories',4),('full_model_days',1096),('native_windows',12),('water_guard_cm',1e-9),('solute_guard_mg_cm2',1e-9),('functional_completion','NOMACRO_FUNCTIONAL_COMPLETE'),('whole_scientific_equivalence','PASS'),('scheduled_chemical','ENABLED'),('b1_promotion',True),('active_macro_qualification',True),('new_persistent_codec',True),('tolerances_changed',True)]:change([key],value)
        for platform in ('Windows','Ubuntu'):
            for kind in ('point','interval'):
                base=['platforms',platform,kind,'profiles','O2']
                for key,value in [('max_water_cm',1.00001e-10),('max_kernel_cm',float('nan')),('max_solute_mg_cm2',-1)]:change(base+['budgets',key],value)
                change(base+['irrigation_mass_mg_cm2'],0)
                change(base+['own',1,'exact_native'],False)
                change(base+['controls','active_disk_recovery'],False)
                change(base+['controls','inconsistent_chemical_mass_refused'],False)
        for platform in ('Windows','Ubuntu'):
            base=['references',platform]
            change(base+['b1_promotion'],True)
            change(base+['corrected_irrigation_sha256'],'foreign')
            change(base+['checks','O0','surface_and_source_absent_all_rows_exact'],False)
            change(base+['profiles','corrected-O2','cases','interval-20','irrigation_mass_mg_cm2'],0)
        change(['input_controls','checks'],q['input_controls']['checks'][:-1])
        change(['salinity','profiles','O0','actual_salinity_reduction_cm'],0)
        change(['salinity','profiles','O2','actual_salinity_reduction_cm'],float('inf'))
        change(['salinity','profiles','O2','own',1,'exact_csv'],False)
        change(['salinity','profiles','O2','controls','actual_irrigation_day'],5)
        change(['salinity_reference','profiles','original-O0','salinity_reduction_cm'],1)
        change(['water_compare','profiles','point-O0','all_generated_sources_exact'],False)
        change(['named_compare','profiles','salt','complete_terminal_native_exact'],False)
        change(['named','grass','full_days'],4)
        change(['pulse','profiles','chemical-surface-history-O0','physical_csv_prefix_exact'],False)
        change(['pulse','profiles','water-surface-history-O2','changed_generated'],['solute.f90'])
        change(['base_consumer','returncode'],1)
        for index,bad in enumerate(attacks):
            with self.subTest(corruption=index),self.assertRaises(ValueError):c.validate(bad)
        print('CHEMICAL_EVIDENCE_CORRUPTIONS_REFUSED='+str(len(attacks)))


if __name__=='__main__':unittest.main()
