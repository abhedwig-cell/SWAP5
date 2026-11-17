import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('calendar_owner',Path(__file__).with_name('age_calendar_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class CalendarEvidence(unittest.TestCase):
    def test_calendar_scope_source_state_reference_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_CALENDAR_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            bad=copy.deepcopy(q);node=bad
            for key in path[:-1]:node=node[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):
                s.validate(bad)
            count+=1
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('baseline',s.RUNTIME),('functional_completion','COMPLETE'),
                          ('whole_scientific_equivalence','PASS'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_changed',True),
                          ('age_tolerance','1e-10'),('age_units','mg/cm2'),('native_codec','S5AGE002'),('daily_native_codec_preserved','S5AGE003'),
                          ('calendar_source_canonical_sha256','0'*64),('receipt_provider_canonical_sha256','0'*64)]:change([key],value)
        change(['scope','macro'],True);change(['scope','initial_age_day'],0);change(['scope','periods'],[1,3,7]);change(['scope','heat'],0)
        for platform in ('Windows','Ubuntu'):
            for name in sorted(s.PROFILES):
                base=['platforms',platform,'profiles',name]
                change(base+['full','days'],1095)
                change(base+['full','budgets','max_water_cm'],1.0001e-10)
                change(base+['full','maximum_age_tolerance_fraction'],1.0001)
                change(base+['short','output','original_sparse_cadence_retained'],False)
                change(base+['full','output','all_means_and_volumes_match_actual_daily_probe'],False)
                for index in range(7):change(base+['full','own',index,'exact_complete_native'],False)
                change(['builds',platform,name,'identity','conserved_original_age','output_calendar','undefined_allocation_tails_serialized'],True)
                change(['builds',platform,name,'identity','conserved_original_age','output_calendar','source_sha256'],'0'*64)
                change(['builds',platform,name,'identity','conserved_original_age','native_codec'],'S5AGE002')
                change(['original_reference',platform,'profiles',name,'days'],1095)
                change(['original_reference',platform,'profiles',name,'maximum_fraction_of_accepted_age_tolerance'],1.0001)
                residual=q['original_reference'][platform]['profiles'][name]['maximum_observed_water_residual_cm']
                change(['original_reference',platform,'profiles',name,'original_water_balance_status'],'PASS' if residual>1e-10 else 'NOT_QUALIFIED')
            for name in sorted(s.CONTROL_PROFILES):
                base=['controls',platform,'profiles',name]
                for index in range(19):change(base+['native_refusals',index,'status'],'PASS')
                change(base+['native_refusals'],q['controls'][platform]['profiles'][name]['native_refusals'][:-1])
                if s.PROFILES[name][0]!='plain':
                    change(base+['transactions','committed_state_unchanged'],False)
                    change(base+['transactions','independent_steps'],5)
                    change(base+['transactions','discard_replay_exact'],False)
                    change(base+['transactions','disk_recovery_exact'],False)
            change(['inactive',platform,'profiles','100-O2','generated_provider_inputs_exact'],False)
            change(['daily_fixed_preservation',platform,'profiles','surface-O2','physical_all_csv_four_native_payloads_exact'],False)
            change(['components',platform,'records',0,'compiler_requests'],4)
        change(['age_off_preservation','profiles','grass','generated_provider_inputs_exact'],False)
        change(['public_cli','complete_native_exact'],False);change(['base_consumer','actual_detached_owner','returncode'],1)
        change(['workflow','status'],'FAILURE')
        change(['workflow','artifact','sha256'],'0'*64)
        change(['workflow','artifact','member_count'],16092)
        print('CALENDAR_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
