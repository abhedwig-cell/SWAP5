import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('current_age_owner',Path(__file__).with_name('age_irrigation_source_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class CurrentFixedAgeEvidence(unittest.TestCase):
    def test_actual_producer_paths_exist(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_IRRIGATION_SOURCE_QUALIFICATION.json').read_text());available={r+'|'+p for r,d in q['archives'].items() for p in d['members']}
        self.assertFalse(set(q['report_paths'])-available);self.assertFalse(set(q['daily_paths'])-available);self.assertFalse(set(q['zero_paths'])-available)

    def test_literal_predecessor_on_qualified_source_image(self):
        self.assertEqual(s.predecessor(),'LITERAL_QUALIFIED_PREDECESSOR_IMAGE_AND_ACTUAL_ARCHIVES_PASS')

    def test_current_source_ledger_native_and_default_claim_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'AGE_IRRIGATION_SOURCE_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            bad=q.copy();node=bad;old=q
            for key in path[:-1]:
                child=old[key].copy();node[key]=child;node=child;old=old[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):s.validate(bad)
            count+=1
        for key,value in [('baseline',s.RUNTIME),('runtime',s.BASE),('status','PASS'),('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),('release_readiness','READY'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_mg_cm2',1.0001e-10),('age_units','mg/cm2'),('age_tolerance','1e-10')]:change([key],value)
        for key in ('default_source_flag','macro','snow','frost','aquifer','detailed_weather','subsurface','physical_age_providers_changed'):change(['scope',key],True)
        change(['scope','incoming_age_range_day'],[0,1001]);change(['scope','native_domain_bytes'],48)
        for path in q['source_sha256']:change(['source_sha256',path],'0'*64)
        specs,controls=s.cases()
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                for key,case in specs.items():
                    base=['platforms',platform,opt,'cases',key,'short'];full=['platforms',platform,opt,'cases',key,'full']
                    for field,value in [('policy','foreign'),('units','mg/cm3'),('native_codec','S5AGE002'),('base_native_codec','S5AGE999'),('source_sha256','0'*64),('domain_source_sha256','0'*64),('correction_sha256','0'*64),('source','initial CIRR'),('native_static_parameters_preserved',False),('physical_age_providers_changed',True),('subsurface',True)]:change(base+['age_irrigation_source',field],value)
                    change(base+['actual_event_age_cm_day'],-1.)
                    if case[7]=='varying':change(base+['actual_second_age_cm_day'],0.)
                    for i in range(len(q['platforms'][platform][opt]['cases'][key]['short']['own'])):change(base+['own',i,'exact_complete_native'],False)
                    change(base+['native_domains','4','bytes'],40)
                    change(base+['trajectory','budgets','max_water_cm'],1.0001e-10)
                    change(base+['trajectory','build_sha256'],'0'*64)
                    change(['builds',platform,opt,key,'identity','original_age_fixed_irrigation','policy'],'foreign')
                    if case[8]:
                        change(full+['trajectory','days'],1095)
                        change(full+['trajectory','budgets','max_kernel_cm'],1.0001e-10)
                        change(full+['actual_event_age_cm_day'],0.)
                        change(full+['own',-1,'exact_physical'],False)
                for key,r in q['controls'][platform][opt].items():
                    base=['controls',platform,opt,key]
                    for i in range(25):change(base+['native_refusals',i,'status'],'ACCEPTED')
                    for i in range(7):change(base+['policy_refusals',i,'status'],'ACCEPTED')
                    for field in r['transactions']:change(base+['transactions',field],False)
                for key,r in q['domain_components'][platform]['profiles'][opt]['contexts'].items():
                    base=['domain_components',platform,'profiles',opt,'contexts',key]
                    for field in ('exact_fifty_six_byte_headers','stream_position_exact','live_flags_unchanged'):change(base+[field],False)
                    for i in range(9):change(base+['refusals',i,'returncode'],0)
                for kind in ('surface','sprinkler'):
                    change(['original_components',platform,'profiles',opt,'comparisons',kind,'original_ignores_nonzero_fixed_age'],False)
                    change(['original_components',platform,'profiles',opt,'comparisons',kind,'actual_source_cm_day'],0.)
                for key in q['reference_components'][platform]['profiles'][opt]['cases']:change(['reference_components',platform,'profiles',opt,'cases',key,'exact_to_actual_refreshed_diagnostic'],False)
            for key in q['public_cli'][platform]['profiles']:change(['public_cli',platform,'profiles',key,'exact_complete_native'],False)
            for i in range(6):change(['reader_controls',platform,'reader_refusals',i,'status'],'ACCEPTED')
            for i in range(7):change(['reader_controls',platform,'descriptor_refusals',i,'status'],'ACCEPTED')
            change(['reader_controls',platform,'young_default_refusal','status'],'ACCEPTED')
        for opt,r in q['preservation']['Windows']['output_hysteresis'].items():
            for key in r['profiles']:change(['preservation','Windows','output_hysteresis',opt,'profiles',key,'generated_provider_exact'],False)
        for key in q['preservation']['Windows']['young_named']['profiles']:change(['preservation','Windows','young_named','profiles',key,'original_route_exact'],False)
        for key in q['preservation']['Ubuntu']['profiles']:change(['preservation','Ubuntu','profiles',key,'four_complete_native_endpoints_exact'],False)
        for opt in ('O0','O2'):change(['boundary','profiles',opt,'first_day_source_cm_day'],0.);change(['boundary','profiles',opt,'terminal_cumulative_source_cm_day'],0.)
        for key in q['archives']:change(['archives',key,'sha256'],'0'*64)
        for key in q['workflows']:change(['workflows',key,'status'],'FAILURE');change(['workflows',key,'id'],1)
        change(['actual_report_count'],0);change(['daily_paths'],{});change(['base_consumer','actual_detached_owner','returncode'],1)
        print('CURRENT_AGE_SOURCE_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
