"""Negative controls for the narrowly inherited PR1686 CI authority."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('successor', Path(__file__).with_name('verify_successor.py'))
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


class Boundaries(unittest.TestCase):
    def test_foreign_source_and_historical_evidence_refused(self):
        for path in ('app/hybrid_water/daily_host.py', 'reference/new.txt', 'integration/dataqual12/STATUS.json', s.PROOF+'WINDOWS.json'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                s.validate_scope([path])

    def test_original_workflow_body_cannot_be_rewritten(self):
        for path in (s.FCI, s.MC, s.CHEM, s.QUALIFY):
            old = s.blob(s.RUNTIME if path == s.QUALIFY else s.SEALED, path).decode().replace('\r\n', '\n')
            new = (s.ROOT/path).read_text()
            if path in (s.CHEM,s.MC) and '          sparse-checkout: |\n' in new:
                # Current operational checkout has a separately exact projection;
                # the original workflow/test commands are still compared below.
                spec=importlib.util.spec_from_file_location('direct_checkout',s.ROOT/'tests/saltfarm_newton/direct_admission.py')
                checkout=importlib.util.module_from_spec(spec);spec.loader.exec_module(checkout)
                current_spec=importlib.util.spec_from_file_location('current_evidence_checkout',s.ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py')
                current=importlib.util.module_from_spec(current_spec);current_spec.loader.exec_module(current)
                new=current.strip_evidence_checkout(new)
                new=checkout.remove(new,checkout.CHECKOUT)
            if path in (s.FCI,s.QUALIFY):
                # Compare the exact canonical parent after independently proving
                # the complete current file differs solely by checkout inputs.
                spec=importlib.util.spec_from_file_location('bounded_checkout_protocol',s.ROOT/'tests/nomacro_drainage/ci_checkout_scope07.py')
                checkout=importlib.util.module_from_spec(spec);spec.loader.exec_module(checkout)
                if path==s.QUALIFY:
                    spec=importlib.util.spec_from_file_location('actual_hupsel_checkout_custody',s.ROOT/'tests/nomacro_drainage/implicit_hydraulic_state_ci_checkout_custody.py')
                    custody=importlib.util.module_from_spec(spec);spec.loader.exec_module(custody)
                    custody.validate_workflow_text(new)
                    with self.assertRaises(ValueError):
                        custody.validate_workflow_text(new.replace('python','echo',1))
                    # The actual current file is proved above. This separate
                    # legacy assertion reads its genuine canonical ancestor;
                    # it never substitutes a historical checkout for execution.
                    ancestor=custody.git('show',custody.BASE+':'+path).decode()
                    new=checkout.historical_workflow(path,ancestor)
                else:
                    spec=importlib.util.spec_from_file_location('actual_closed_default_checkout_custody',s.ROOT/'tests/nomacro_drainage/closed_default_calendar_checkout.py')
                    custody=importlib.util.module_from_spec(spec);spec.loader.exec_module(custody)
                    new=checkout.historical_workflow(path,custody.historical_parent(path,new))
            s.validate_workflow(path, new, old)
            with self.assertRaises(ValueError):
                s.validate_workflow(path, new.replace('python', 'echo', 1), old)

    def test_false_qualification_and_relaxed_budget_refused(self):
        source = json.loads((s.ROOT/s.PROOF/'WINDOWS.json').read_text())['Windows']
        s.validate_runs(source)
        for field, value in (('status', 'FAILED'), ('full_days', 51)):
            r = copy.deepcopy(source)
            r['O2']['undrained'][field] = value
            with self.assertRaises(ValueError):
                s.validate_runs(r)
        for value in (1.0001e-10, float('nan')):
            r = copy.deepcopy(source)
            r['O0']['undrained']['budgets']['max_water_cm'] = value
            with self.assertRaises(ValueError):
                s.validate_runs(r)

    def test_missing_native_or_nonexact_restart_refused(self):
        source = json.loads((s.ROOT/s.PROOF/'WINDOWS.json').read_text())['Windows']
        for key in ('exact_native_auxiliary', 'origin_unchanged'):
            r = copy.deepcopy(source)
            r['named']['hupsel']['restart_windows'][0][key] = False
            with self.assertRaises(ValueError):
                s.validate_runs(r)
        r = copy.deepcopy(source)
        r['O2']['undrained']['restart_windows'].pop()
        with self.assertRaises(ValueError):
            s.validate_runs(r)

    def test_current_l_source_full_native_and_mass_claims(self):
        load = lambda name: json.loads((s.ROOT/s.L_PROOF/(name+'.json')).read_text())
        q = load('BLOCK_L_QUALIFICATION')
        p = load('BLOCK_L_CURRENT_PRESERVATION')
        c = load('BLOCK_L_COMPONENT_RESULT')
        s.validate_l(q, p, c)
        attacks = []
        bad = copy.deepcopy(q); bad['runtime_source'] = s.RUNTIME; attacks.append((bad, p, c))
        bad = copy.deepcopy(q); bad['complete_model_days'] = 51; attacks.append((bad, p, c))
        bad = copy.deepcopy(q); bad['natural_regime_windows'].pop(); attacks.append((bad, p, c))
        bad = copy.deepcopy(q); bad['natural_regime_windows'][0]['native_exact'] = False; attacks.append((bad, p, c))
        bad = copy.deepcopy(q); next(iter(bad['reports'].values()))['configurations'][0]['maximum_water_residual_cm'] = 1.0001e-10; attacks.append((bad, p, c))
        bad = copy.deepcopy(q); bad['original_full_invalid_DATE5_refused'] = False; attacks.append((bad, p, c))
        bad = copy.deepcopy(p); bad['profiles']['O0']['all_1096_physical_daily_rows_exact'] = False; attacks.append((q, bad, c))
        bad = copy.deepcopy(p); bad['profiles']['grass']['publisher_source_exact'] = False; attacks.append((q, bad, c))
        bad = copy.deepcopy(c); bad['prescribed_head']['status'] = 'FAILED'; attacks.append((q, p, bad))
        for index, values in enumerate(attacks):
            with self.subTest(attack=index), self.assertRaises(ValueError):
                s.validate_l(*values)

    def test_m_physical_provenance_guard_and_retained_clock_diagnostic(self):
        load = lambda name: json.loads((s.ROOT/s.L_PROOF/(name+'.json')).read_text())
        q = load('BLOCK_M_QUALIFICATION')
        previous = load('BLOCK_M_PRIOR_SOURCE_PRESERVATION')
        pond = load('BLOCK_M_POND_SOURCE_PRESERVATION')
        components = load('BLOCK_M_LOCAL_ASSESSMENT')
        s.validate_m(q, previous, pond, components)
        attacks = []
        for field, value in (('runtime_source', s.L_RUNTIME), ('qualification_source', s.M_EXECUTED), ('complete_model_days', 51), ('mass_guard_cm', 1e-9), ('maximum_water_residual_cm', float('nan')), ('nominal_runon_1e10_accuracy', 'PASS')):
            bad = copy.deepcopy(q); bad[field] = value; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(q); bad['per_configuration_executed_sources']['water-pond-table'] = s.M_EXECUTED; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(q); bad['reports']['water-runon-file']['completed_physics_reexecuted'] = True; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(q); bad['reports']['water-runon-file']['configurations'][1]['surface_event_exact_native_windows']['native_exact'] = False; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(q); bad['reports']['water-runon-file']['original_references']['literal']['retained_original_output_failure'] = False; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(pond); bad['profiles'].pop('chemical-pond-table-O2'); attacks.append((q, previous, bad, components))
        bad = copy.deepcopy(components); bad['original_invalid_table']['status'] = 'PASS'; attacks.append((q, previous, pond, bad))
        for field, value in (('original_event_clock_bound_cm', 1e-3), ('nominal_cm', 0.0), ('difference_cm', 0.0)):
            bad = copy.deepcopy(q)
            record = next(r for r in bad['reports']['water-runon-file']['configurations'] if r['optimization'] == 'O2')['original_runon_event_witness']['records'][0]
            record[field] = value; attacks.append((bad, previous, pond, components))
        bad = copy.deepcopy(q); bad['reports']['chemical-runon-file']['configurations'][0]['maximum_solute_residual_mg_cm2'] = None; attacks.append((bad, previous, pond, components))
        for index, values in enumerate(attacks):
            with self.subTest(attack=index), self.assertRaises(ValueError):
                s.validate_m(*values)


    def test_n_source_delivery_native_domain_and_mass(self):
        load = lambda name: json.loads((s.ROOT/s.L_PROOF/('BLOCK_N_'+name+'.json')).read_text())
        values = [load(n) for n in ('QUALIFICATION','PRIOR_SOURCE_PRESERVATION','GUARDED_COMPONENT_RESULT','INLINE_FILE_EQUIVALENCE','ACTUAL_NATIVE_REFUSALS')]
        s.validate_n(*values)
        attacks = []
        for field,value in [('runtime_source',s.M_RUNTIME),('complete_model_days',51),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('chemical_subsurface','PASS'),('reversed_or_outside_depth','PASS'),('new_state_codec',True)]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for field,value in [('exact_native_auxiliary',False),('maximum_solute_residual_mg_cm2',None),('foreign_fixed_file_policy_refused_before_output',False)]:
            bad=copy.deepcopy(values);bad[0]['reports']['chemical-file-sprinkler']['configurations'][1][field]=value;attacks.append(bad)
        bad=copy.deepcopy(values);bad[0]['reports']['water-file-subsurface']['configurations'][1]['fixed_irrigation_event_exact_native_windows']['actual_fixed_irrigation_cm']['5']['subsurface']=0;attacks.append(bad)
        bad=copy.deepcopy(values);bad[0]['event_windows'].pop();attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['profiles']['registered-grass']['inputs']={};attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles'][0]['chemical_type2_refusals'][0]['refused']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['profiles'][0]['final_native_payload_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['profiles'][0]['status']='PASS';attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index), self.assertRaises(ValueError):
                s.validate_n(*bad)


    def test_o_complete_context_source_mass_and_native_ownership(self):
        load=lambda name:json.loads((s.ROOT/s.L_PROOF/('BLOCK_O_'+name+'.json')).read_text())
        values=[load(n) for n in ('QUALIFICATION','PRIOR_SOURCE_PRESERVATION','COMPONENT_RESULT','LEGACY_COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT')]
        s.validate_o(*values);attacks=[]
        for field,value in [('runtime_source',s.N_RUNTIME),('complete_model_days',4384),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('old_failed_mixture_evidence','PASS'),('physical_equations_changed',True),('whole_scientific_equivalence','PASS')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','window','native','physical','refusal','external'):
            bad=copy.deepcopy(values);r=bad[0]['platforms']['Windows']['chemical-surface-history']['profiles']['O2']
            if edit=='mass':r['budgets']['max_solute_mg_cm2']=1.0001e-10
            elif edit=='window':r['own'].pop()
            elif edit=='native':r['own'][1]['exact_native']=False
            elif edit=='physical':r['all_1096_physical_rows_exact_to_failed_source']=False
            elif edit=='refusal':r['controls']['native_refusals'][0]['accepted_days']=1
            else:r['controls']['external_discard_replay_exact']=False
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['profiles']['water-plate-history']['generated']={};attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles'][0]['staged_read_before_assignment']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['profiles'][1]['refusals'].pop();attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['profiles'][0]['every_exercised_native_exact']=False;attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_o(*bad)


    def test_p_partial_frost_scope_source_balances_and_all_year_native(self):
        load=lambda n:json.loads((s.ROOT/s.L_PROOF/('BLOCK_P_'+n+'.json')).read_text())
        values=[load(n) for n in ('QUALIFICATION','CURRENT_FREE_PRESERVATION','LATER_NATIVE_RESULT','PRIOR_SOURCE_PRESERVATION','COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT','ORIGINAL_REFERENCE_RESULT')]
        s.validate_p(*values);attacks=[]
        for field,value in [('runtime_source',s.O_RUNTIME),('complete_model_days',4384),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('retained_failures','PASS'),('solver_or_time_policy_changed',True),('new_persistent_frost_codec',True),('whole_scientific_equivalence','PASS')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','forcing','window','year','activation','initial','root'):
            bad=copy.deepcopy(values);report=bad[0]['platforms']['Ubuntu']['chemical-frost-free'];r=report['profiles']['O2']
            if edit=='mass':r['budgets']['max_solute_mg_cm2']=None
            elif edit=='forcing':report['selected_physical_controls']['SWDRA']=1
            elif edit=='window':r['own'][0]['exact_native']=False
            elif edit=='year':r['active_frost_exact_native_windows'].pop()
            elif edit=='activation':r['frost_witness']['days_with_reduction']=0
            elif edit=='initial':r['frost_witness']['initial_original_uncomputed_diagnostic'][-1]=1
            else:r['frost_witness']['total_original_frost_uptake_reduction_cm']=0
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['profiles']['water-O0']['generated']={};attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles']['chemical-O2']['own'][0]['exact_csv']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles']['water-O0']['own'][0]['full_trace_origin_day']=0;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['profiles'].pop('chemical-surface-history');attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['original_reporting_differences']['O0']=0;attacks.append(bad)
        bad=copy.deepcopy(values);bad[5]['profiles'][0]['every_exercised_native_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[6]['profiles']['chemical']['scientific_equivalence']='PASS';attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_p(*bad)


    def test_q_actual_event_terminal_mass_native_and_external_scope(self):
        load=lambda n:json.loads((s.ROOT/s.L_PROOF/('BLOCK_Q_'+n+'.json')).read_text())
        values=[load(n) for n in ('QUALIFICATION','PRIOR_SOURCE_PRESERVATION','PRIOR_P_FREE_PRESERVATION','COMPONENT_RESULT','TIME_COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT')]
        values.extend([dict(Windows=load('PREFLIGHT_WINDOWS'),Ubuntu=load('PREFLIGHT_UBUNTU')),load('ORIGINAL_REFERENCE_RESULT')])
        s.validate_q(*values);attacks=[]
        for field,value in [('runtime_source',s.CURRENT_RUNTIME),('complete_model_days',1096),('numerical_policy','original-adaptive-day-seed-v1'),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('new_Jacobian',True),('new_persistent_codec',True),('whole_scientific_equivalence','PASS'),('retained_failures','PASS')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','year','native','external','initial','forcing'):
            bad=copy.deepcopy(values);report=bad[0]['platforms']['Ubuntu'];r=report['profiles']['O2']
            if edit=='mass':r['budgets']['max_water_cm']=1.00001e-10
            elif edit=='year':r['active_frost_exact_native_windows'].pop()
            elif edit=='native':r['own'][0]['exact_native']=False
            elif edit=='external':r['controls']['external_disk_recovery']=False
            elif edit=='initial':r['frost_witness']['initial_original_uncomputed_diagnostic'][-1]=1
            else:report['selected_physical_controls']['SWSOLU']=1
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['profiles'].pop('water-plate-history');attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles']['chemical']['prefix']['own'][1]['exact_csv']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['physical_cases_per_optimization']=11;attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['profiles']['O2-corrected']['values'][0][4]=-1e-12;attacks.append(bad)
        bad=copy.deepcopy(values);bad[5]['profiles'][0]['every_exercised_native_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[6]['Windows']['negative_controls'].pop();attacks.append(bad)
        bad=copy.deepcopy(values);bad[7]['science']='PASS';attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_q(*bad)


    def test_r_complete_table_fluxes_native_external_and_preservation(self):
        load=lambda n:json.loads((s.ROOT/s.L_PROOF/('BLOCK_R_'+n+'.json')).read_text())
        values=[load(n) for n in ('QUALIFICATION','PRIOR_SOURCE_PRESERVATION','PRIOR_P_FREE_PRESERVATION','PRIOR_Q_PRESERVATION','COMPONENT_RESULT','DEFAULT_PRESERVATION_RESULT')]
        values.extend([dict(Windows=load('PREFLIGHT_WINDOWS'),Ubuntu=load('UBUNTU_PREFLIGHT')),load('POND_COMPONENT_INHERITANCE'),load('REPAIRED_PREFIX53')]);s.validate_r(*values);attacks=[]
        for field,value in [('runtime_source',s.Q_RUNTIME),('complete_model_days',8768),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('maximum_solute_residual_mg_cm2',1.01e-10),('new_persistent_codec',True),('new_tangent_formula',True),('clock_policy_changed',True),('whole_scientific_equivalence','PASS'),('retained_failures','PASS')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','native','external','sign','source','forcing'):
            bad=copy.deepcopy(values);rep=bad[0]['platforms']['Ubuntu']['chemical-drain-signed'];r=rep['profiles']['O2']
            if edit=='mass':r['budgets']['max_solute_mg_cm2']=float('nan')
            elif edit=='native':r['own'][0]['exact_native']=False
            elif edit=='external':r['controls']['external_disk_recovery']=False
            elif edit=='sign':r['drainage_signed_exposure']['days_negative']=0
            elif edit=='source':rep['source_commit']=s.R_WINDOWS
            else:rep['selected_physical_controls']['DRAMET']=2
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['profiles'].pop('prescribed-head5');attacks.append(bad)
        bad=copy.deepcopy(values);bad[2]['profiles']['chemical']['prefix']['own'][1]['exact_csv']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['all_21_physical_rows_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['physical_cases_per_optimization']=14;attacks.append(bad)
        bad=copy.deepcopy(values);bad[5]['profiles'][0]['every_exercised_native_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[6]['Windows']['custom_file_probe']['actual_selected_drain_file']='swap.dra';attacks.append(bad)
        bad=copy.deepcopy(values);bad[7]['actual_template_git_diff_empty']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[8]['profiles']['O0']['own']['exact_native']=False;attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_r(*bad)


if __name__ == '__main__':
    unittest.main()
