import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('hysteresis_owner',Path(__file__).with_name('output_hysteresis_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class HysteresisOutputEvidence(unittest.TestCase):
    def test_actual_report_and_period_paths_exist(self):
        q=json.loads((s.ROOT/s.PROOF/'OUTPUT_HYSTERESIS_QUALIFICATION.json').read_text())
        available={record+'|'+path for record,r in q['archives'].items() for path in r['members']}
        self.assertFalse(set(q['report_paths'])-available)
        self.assertFalse(set(q['daily_paths'])-available)

    def test_source_native_output_and_state_claims_refuse_corruption(self):
        q=json.loads((s.ROOT/s.PROOF/'OUTPUT_HYSTERESIS_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            bad=q.copy();node=bad;original=q
            for key in path[:-1]:
                child=original[key].copy();node[key]=child;node=child;original=original[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):s.validate(bad)
            count+=1
        for key,value in [('baseline',s.RUNTIME),('runtime',s.BASE),('status','PASS'),('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),('release_readiness','READY'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_mg_cm2',1.0001e-10),('age_units','mg/cm2'),('age_tolerance','1e-10')]:change([key],value)
        for key in ('macro','snow','frost','aquifer','detailed_weather','original_output_default','physical_providers_changed'):change(['scope',key],True)
        change(['scope','perstep_reset'],1);change(['scope','cde_cadence'],'monthly')
        for path in q['source_sha256']:change(['source_sha256',path],'0'*64)
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                for case in s.CASES:
                    key=s.name(case);base=['platforms',platform,opt,'cases',key]
                    change(base+['full','trajectory','days'],1095)
                    change(base+['short','trajectory','budgets','max_water_cm'],1.0001e-10)
                    change(base+['full','trajectory','budgets','max_kernel_cm'],1.0001e-10)
                    change(base+['full','trajectory','budgets','max_solute_mg_cm2'],1.0001e-10)
                    change(base+['full','trajectory','build_sha256'],'0'*64)
                    for field,value in [('policy','foreign'),('native_codec','S5IOW001'),('swhyst',3),('source_sha256','0'*64),('domain_source_sha256','0'*64),('ordinary_owner_sha256','0'*64),('original_hysteresis_sha256','0'*64),('num_decimals',4),('groups','foreign'),('conserved_cde_prefix_offset_bytes',49),('preserves_requested_groups_and_precision',False),('undefined_allocation_tails_serialized',True)]:change(base+['full','original_output',field],value)
                    for i in range(len(q['platforms'][platform][opt]['cases'][key]['full']['own'])):change(base+['full','own',i,'exact_complete_native'],False)
                    change(base+['full','native_domains','4','exact_actual_flags'],False)
                    change(base+['full','actual_hysteresis_history','4','mode'],3)
                    for filename in q['platforms'][platform][opt]['cases'][key]['short']['own'][0]['exact_user_output']:change(base+['short','own',0,'exact_user_output',filename,'exact'],False)
                    change(['builds',platform,opt,key,'identity','original_output','policy'],'foreign')
                    if case[0]=='cde':change(base+['full','active_chemical_source_mg_cm2'],0.)
                for key,r in q['controls'][platform][opt]['profiles'].items():
                    base=['controls',platform,opt,'profiles',key]
                    for i in range(len(r['native_refusals'])):change(base+['native_refusals',i,'status'],'ACCEPTED')
                    for i in range(8):change(base+['policy_refusals',i,'status'],'ACCEPTED')
                    for field in r['transactions']:change(base+['transactions',field],False)
                change(['receipt_components',platform,opt,'cases'],41)
                for key,r in q['domain_components'][platform]['profiles'][opt]['contexts'].items():
                    for field in ('exact_forty_byte_header','stream_position_exact','live_flags_unchanged'):change(['domain_components',platform,'profiles',opt,'contexts',key,field],False)
                    for i in range(7):change(['domain_components',platform,'profiles',opt,'contexts',key,'native_refusals',i,'returncode'],0)
            for key in q['public_cli'][platform]['profiles']:change(['public_cli',platform,'profiles',key,'exact_complete_native'],False)
            for i in range(20):change(['reader_controls',platform,'invalid',i,'status'],'ACCEPTED')
            for key in q['reader_controls'][platform]['profiles']:change(['reader_controls',platform,'profiles',key,'own',0,'exact_complete_native'],False)
        for opt,r in q['preservation'].items():
            for key in r['profiles']:
                for field in ('generated_provider_exact','all_physical_exact','complete_native_exact'):change(['preservation',opt,'profiles',key,field],False)
        for opt,r in q['baselines'].items():
            for key in r['profiles']:change(['baselines',opt,'profiles',key,'active_scanning_observed'],False)
        for key in q['workflows']:change(['workflows',key,'status'],'FAILURE');change(['workflows',key,'id'],1)
        for key in q['archives']:change(['archives',key,'sha256'],'0'*64);change(['archives',key,'member_count'],0)
        change(['report_paths'],{});change(['daily_paths'],{});change(['base_consumer','actual_detached_owner','returncode'],1)
        print('HYSTERESIS_OUTPUT_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
