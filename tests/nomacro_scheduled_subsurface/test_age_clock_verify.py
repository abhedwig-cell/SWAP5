import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('clock_owner',Path(__file__).with_name('age_clock_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class ClockEvidence(unittest.TestCase):
    def test_actual_clock_native_reference_and_preservation_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_CLOCK_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            bad=q.copy();node=bad;original=q
            for key in path[:-1]:
                child=original[key].copy();node[key]=child;node=child;original=original[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):
                s.validate(bad)
            count+=1
        for key,value in [('runtime',s.BASE),('ubuntu',s.RUNTIME),('baseline',s.RUNTIME),('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),('release_readiness','READY'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_changed',True),('age_tolerance','1e-10'),('age_units','mg/cm2'),('native_codec','S5AGE004'),('policy','foreign'),('trial_receipt_policy','foreign'),('source_canonical_sha256','0'*64),('original_watstor_canonical_sha256','0'*64)]:change([key],value)
        for key in ('macro','snow','aquifer','flprintdt'):change(['scope',key],True)
        change(['scope','subdaily_frequencies'],[2]);change(['scope','initial_age_day'],0)
        for platform in ('Windows','Ubuntu'):
            for name,(mode,n,kind,opt) in sorted(s.PROFILES.items()):
                base=['platforms',platform,'profiles',name]
                change(base+['full','days'],1095);change(base+['full','budgets','max_water_cm'],1.0001e-10)
                change(base+['short','budgets','max_kernel_cm'],1.0001e-10)
                change(base+['full','maximum_age_tolerance_fraction'],1.0001)
                for index in range(8):change(base+['full','own',index,'exact_complete_native'],False)
                change(base+['short','own',0,'exact_original_five_csv'],False)
                if mode=='annual':
                    change(base+['short','output','original_sparse_cadence_retained'],False)
                else:
                    change(base+['full','output','primary_rows'],1)
                    change(base+['full','output','actual_final_age_output_interval_days'],1.)
                    change(base+['short','output','original_datetime_formatter_status'],'ISO_VALID')
                identity=['builds',platform,name,'identity','conserved_original_age']
                for key,value in [('source_sha256','0'*64),('regular_owner_sha256','0'*64),('schedule_owner_sha256','0'*64),('original_output_epoch',37257),('nprintday',1440),('original_watstor_sha256','0'*64),('trial_receipt_policy','foreign')]:change(identity+['output_clock',key],value)
                change(identity+['native_codec'],'S5AGE004')
                ref=['original_reference',platform,'profiles',name]
                change(ref+['days'],1095);change(ref+['maximum_fraction_of_accepted_age_tolerance'],1.0001)
                residual=q['original_reference'][platform]['profiles'][name]['maximum_observed_water_residual_cm']
                change(ref+['original_water_balance_status'],'PASS' if residual>1e-10 else 'NOT_QUALIFIED')
                change(ref+['executable_sha256'],'0'*64)
                if mode=='subdaily':
                    before=q['original_reference'][platform]['profiles'][name]['output']['original_cadence_status']
                    change(ref+['output','original_cadence_status'],'NOT_QUALIFIED' if before=='PASS' else 'PASS')
            for opt in ('O0','O2'):change(['components',platform,opt,'cases'],41)
            change(['original_reference',platform,'fresh_compile'],True)
            for name in sorted(s.CONTROLS):
                base=['controls',platform,'profiles',name]
                for index in range(21):change(base+['native_refusals',index,'status'],'PASS')
                for index in range(5):change(base+['policy_refusals',index,'status'],'PASS')
                if s.PROFILES[name][2]!='plain':
                    for key in ('committed_state_unchanged','discard_replay_exact','disk_recovery_exact'):change(base+['transactions',key],False)
                    change(base+['transactions','independent_steps'],5)
            for name in q['reader_controls'][platform]['omissions']:
                change(['reader_controls',platform,'omissions',name,'generated_provider_exact'],False)
                change(['reader_controls',platform,'omissions',name,'coverage','own','exact_complete_native'],False)
            for index in range(10):change(['reader_controls',platform,'invalid',index,'status'],'PASS')
            for kind in ('schedule_preservation','regular_preservation'):
                for name in q[kind][platform]['profiles']:
                    change([kind,platform,'profiles',name,'generated_provider_inputs_exact'],False)
                    change([kind,platform,'profiles',name,'coverage','own',1,'exact_complete_native'],False)
            for name in q['inactive'][platform]['profiles']:change(['inactive',platform,'profiles',name,'coverage','own',0,'exact_native'],False)
            for name in q['daily_fixed_preservation'][platform]['profiles']:change(['daily_fixed_preservation',platform,'profiles',name,'coverage','own','exact_native'],False)
        for name in q['age_off_preservation']['profiles']:change(['age_off_preservation','profiles',name,'coverage','own',0,'exact_native'],False)
        change(['public_cli','complete_native_exact'],False);change(['base_consumer','actual_detached_owner','returncode'],1)
        for path,value in [(['status'],'FAILURE'),(['artifact','sha256'],'0'*64),(['artifact','member_count'],0),(['id'],1)]:change(['workflow',*path],value)
        print('CLOCK_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
