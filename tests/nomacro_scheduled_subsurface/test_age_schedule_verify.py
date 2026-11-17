import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('schedule_owner',Path(__file__).with_name('age_schedule_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class ScheduleEvidence(unittest.TestCase):
    def test_source_calendar_native_reference_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_SCHEDULE_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            # Only clone containers along the changed path. Validation reads
            # immutable sibling evidence and does not mutate it.
            bad=q.copy();node=bad;original=q
            for key in path[:-1]:
                child=original[key].copy();node[key]=child;node=child;original=original[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):
                s.validate(bad)
            count+=1
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('baseline',s.RUNTIME),('functional_completion','COMPLETE'),
                          ('whole_scientific_equivalence','PASS'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_changed',True),
                          ('age_tolerance','1e-10'),('age_units','mg/cm2'),('native_codec','S5AGE003'),('daily_native_codec_preserved','S5AGE004'),
                          ('regular_native_codec_preserved','S5AGE004'),('source_canonical_sha256','0'*64),('regular_owner_canonical_sha256','0'*64)]:change([key],value)
        change(['scope','macro'],True);change(['scope','subdaily'],True);change(['scope','initial_age_day'],0);change(['scope','heat'],0)
        for platform in ('Windows','Ubuntu'):
            for name in sorted(s.PROFILES):
                base=['platforms',platform,'profiles',name]
                change(base+['full','days'],1095);change(base+['full','budgets','max_water_cm'],1.0001e-10)
                change(base+['full','maximum_age_tolerance_fraction'],1.0001)
                change(base+['short','output','original_sparse_cadence_retained'],False)
                change(base+['full','output','all_means_and_volumes_match_actual_daily_probe'],False)
                for index in range(8):change(base+['full','own',index,'exact_complete_native'],False)
                change(['builds',platform,name,'identity','conserved_original_age','output_schedule','source_sha256'],'0'*64)
                change(['builds',platform,name,'identity','conserved_original_age','output_schedule','regular_owner_sha256'],'0'*64)
                change(['builds',platform,name,'identity','conserved_original_age','output_schedule','period'],366)
                change(['builds',platform,name,'identity','conserved_original_age','native_codec'],'S5AGE003')
                change(['original_reference',platform,'profiles',name,'days'],1095)
                change(['original_reference',platform,'profiles',name,'maximum_fraction_of_accepted_age_tolerance'],1.0001)
                residual=q['original_reference'][platform]['profiles'][name]['maximum_observed_water_residual_cm']
                change(['original_reference',platform,'profiles',name,'original_water_balance_status'],'PASS' if residual>1e-10 else 'NOT_QUALIFIED')
            change(['original_reference',platform,'fresh_compile'],True)
            for name in sorted(s.CONTROLS):
                base=['controls',platform,'profiles',name]
                for index in range(20):change(base+['native_refusals',index,'status'],'PASS')
                change(base+['native_refusals'],q['controls'][platform]['profiles'][name]['native_refusals'][:-1])
                change(base+['policy_refusals',0,'status'],'PASS')
                if s.PROFILES[name][1]!='plain':
                    change(base+['transactions','committed_state_unchanged'],False)
                    change(base+['transactions','independent_steps'],5)
                    change(base+['transactions','discard_replay_exact'],False)
                    change(base+['transactions','disk_recovery_exact'],False)
            for index in range(4):change(['reader_controls',platform,'checks',index,'status'],'PASS')
            for name in sorted(q['regular_preservation'][platform]['profiles']):
                change(['regular_preservation',platform,'profiles',name,'generated_provider_inputs_exact'],False)
                change(['regular_preservation',platform,'profiles',name,'coverage','own',1,'exact_complete_native'],False)
            change(['inactive',platform,'profiles','100-O2','generated_provider_inputs_exact'],False)
            change(['inactive',platform,'profiles','100-O2','coverage','own',0,'exact_native'],False)
            change(['daily_fixed_preservation',platform,'profiles','surface-O2','physical_all_csv_four_native_payloads_exact'],False)
            change(['daily_fixed_preservation',platform,'profiles','surface-O2','coverage','own','exact_native'],False)
        change(['age_off_preservation','profiles','grass','generated_provider_inputs_exact'],False)
        change(['age_off_preservation','profiles','grass','coverage','own',0,'exact_native'],False)
        change(['public_cli','complete_native_exact'],False);change(['base_consumer','actual_detached_owner','returncode'],1)
        change(['unchanged_reference_inheritance','fresh_compile'],True)
        change(['workflow','status'],'FAILURE');change(['workflow','artifact','sha256'],'0'*64);change(['workflow','artifact','member_count'],22845)
        print('SCHEDULE_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
