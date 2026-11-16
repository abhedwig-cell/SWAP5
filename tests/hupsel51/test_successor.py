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


if __name__ == '__main__':
    unittest.main()
