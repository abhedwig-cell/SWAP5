import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('original_output_owner',Path(__file__).with_name('original_output_verify.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)


class OriginalOutputEvidence(unittest.TestCase):
    def test_all_claimed_actual_producer_paths_exist(self):
        q=json.loads((s.ROOT/s.PROOF/'ORIGINAL_OUTPUT_QUALIFICATION.json').read_text());reports,builds,daily=s.reports(q)
        available={(record,name) for record,r in q['archives'].items() for name in r['members']}
        self.assertFalse(set(reports)-available);self.assertFalse(set(builds)-available);self.assertFalse(set(daily)-available)

    def test_source_native_user_files_and_actual_component_corruptions(self):
        q=json.loads((s.ROOT/s.PROOF/'ORIGINAL_OUTPUT_QUALIFICATION.json').read_text());s.validate(q);count=0
        def change(path,value):
            nonlocal count
            bad=q.copy();node=bad;original=q
            for key in path[:-1]:
                child=original[key].copy();node[key]=child;node=child;original=original[key]
            node[path[-1]]=value
            with self.subTest(path=path),self.assertRaises((ValueError,KeyError)):s.validate(bad)
            count+=1
        for key,value in [('baseline',s.RUNTIME),('runtime',s.BASE),('status','PASS'),('functional_completion','COMPLETE'),('whole_scientific_equivalence','PASS'),('release_readiness','READY'),('water_guard_cm',1.0001e-10),('chemical_mass_guard_mg_cm2',1.0001e-10),('age_units','mg/cm2'),('age_tolerance','1e-10'),('policy','foreign'),('source_canonical_sha256','0'*64),('cde_state_canonical_sha256','0'*64)]:change([key],value)
        for key,value in [('active_macro',True),('original_output_default',True),('snow',True),('physical_providers_changed',True),('perstep_reset',1),('cde_cadence','perstep')]:change(['scope',key],value)
        change(['source_producer_refs'],[])
        for platform in ('Windows','Ubuntu'):
            for opt in ('O0','O2'):
                for case in s.CASES:
                    path=['platforms',platform,opt,'cases',case]
                    change(path+['full','trajectory','days'],1095)
                    change(path+['short','trajectory','budgets','max_kernel_cm'],1.0001e-10)
                    change(path+['full','trajectory','budgets','max_solute_mg_cm2'],1.0001e-10)
                    change(path+['full','requested_controls_preserved'],False)
                    for field,value in [('policy','foreign'),('native_codec','S5AGE005'),('original_output_epoch',37257),('groups','foreign'),('num_decimals',4),('cde_output_state_sha256','0'*64),('vector_catalog_correction_sha256','0'*64),('binary_correction_sha256','0'*64),('preserves_requested_groups_and_precision',False),('undefined_allocation_tails_serialized',True)]:
                        change(path+['full','original_output',field],value)
                    for i,w in enumerate(q['platforms'][platform][opt]['cases'][case]['full']['own']):
                        change(path+['full','own',i,'exact_complete_native'],False)
                    first=q['platforms'][platform][opt]['cases'][case]['short']['own'][0]['exact_user_output']
                    for filename in first:change(path+['short','own',0,'exact_user_output',filename,'exact'],False)
                    change(['builds',platform,case+'-'+opt,'identity','original_output','policy'],'foreign')
                for name,record in q['controls'][platform][opt]['profiles'].items():
                    base=['controls',platform,opt,'profiles',name]
                    for i in range(len(record['native_refusals'])):change(base+['native_refusals',i,'status'],'PASS')
                    for i in range(5):change(base+['policy_refusals',i,'status'],'PASS')
                    for key in ('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'):change(base+['transactions',key],False)
                change(['components','integral',platform,opt,'cases'],41)
            for name in q['age_bounds'][platform]:change(['age_bounds',platform,name,'maximum_accepted_tolerance_fraction'],1.0001)
            for name in q['source_events'][platform]:change(['source_events',platform,name,'actual_gift_mg_cm2'],0.)
            for name in q['format_independence'][platform]:change(['format_independence',platform,name,'five_complete_native_endpoints_exact'],False)
            for name in q['preservation'][platform]['default']['profiles']:change(['preservation',platform,'default','profiles',name,'source_provider_inputs_exact'],False)
            for name in q['preservation'][platform]['daily002']['profiles']:change(['preservation',platform,'daily002','profiles',name,'physical_all_csv_four_native_payloads_exact'],False)
            for name in q['public_cli'][platform]['profiles']:change(['public_cli',platform,'profiles',name,'exact_complete_native'],False)
            for i in range(16):change(['reader_controls',platform,'invalid',i,'status'],'PASS')
            for name in q['reader_controls'][platform]['profiles']:change(['reader_controls',platform,'profiles',name,'own',0,'exact_complete_native'],False)
            for opt in ('O0','O2'):
                change(['components','binary',platform,'profiles',opt,'roundtrip','real4_values_exact'],False)
                change(['components','vector',platform,'profiles',opt,'scalar_output_unchanged'],False)
                change(['components','cde_state',platform,'profiles',opt,'staged_read_nonmutation'],False)
            change(['components','vector',platform,'catalog_rows',0,0],'FOREIGN')
            change(['components','binary',platform,'corrected_source_sha256'],'0'*64)
            change(['components','cde_state',platform,'source_sha256'],'0'*64)
        for key in s.WORKFLOWS:change(['workflows',key,'status'],'FAILURE');change(['workflows',key,'id'],1)
        for name in q['archives']:change(['archives',name,'sha256'],'0'*64);change(['archives',name,'member_count'],0)
        change(['base_consumer','actual_detached_owner','returncode'],1)
        print('ORIGINAL_OUTPUT_EVIDENCE_CORRUPTIONS_REFUSED',count)


if __name__=='__main__':unittest.main()
