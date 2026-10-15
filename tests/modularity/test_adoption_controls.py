#!/usr/bin/env python3
"""Native negative controls for the added oracle and provider-sharing routes."""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
spec=importlib.util.spec_from_file_location('oracles',Path(__file__).with_name('contract_oracles.py'))
o=importlib.util.module_from_spec(spec);spec.loader.exec_module(o)


class Controls(unittest.TestCase):
    def session(self,name):
        root=Path(os.environ['ADOPTION_CONTROL_EVIDENCE_DIR'])/name
        return m.Session(root)

    def test_shared_root_providers_and_fresh_science(self):
        s=self.session('shared-root')
        a=s.execute('root_oxygen',0);b=s.execute('root_contract',0)
        self.assertEqual(b['compiler_requests'],2)
        self.assertEqual(b['reused_compilations'],3)
        self.assertNotEqual(a['stdout_sha256'],b['stdout_sha256'])
        self.assertEqual(sum(e['command'][0].endswith('/test') for e in s.events),2)
        m.write(s.out/'CONTROL.json',{'status':'PASS','records':[a,b],'events':s.events})

    def test_shared_module_corruption_fails_closed(self):
        s=self.session('corrupt-module');s.execute('root_oxygen',0)
        _,files=next(iter(s.module_artifacts.values()))
        mod=next(p for p in files if p.suffix=='.mod');mod.write_bytes(mod.read_bytes()+b'corrupt')
        with self.assertRaisesRegex(RuntimeError,'shared module artifact'):
            s.execute('root_contract',0)
        m.write(s.out/'CONTROL.json',{'status':'PASS_EXPECTED_REJECTION','events':s.events})

    def test_O0_O2_are_separate(self):
        s=self.session('optimization-isolation');s.execute('root_oxygen',0)
        b=s.execute('root_contract',2)
        self.assertEqual(b['reused_compilations'],0);self.assertEqual(b['compiler_requests'],5)
        m.write(s.out/'CONTROL.json',{'status':'PASS','record':b,'events':s.events})

    def test_oracle_wrong_count_and_wrong_science_rejected(self):
        for name in ['assimilation','drainage']:
            _,validate,_=o.prepare(m.ROOT,name)
            with self.assertRaisesRegex(RuntimeError,'count'):validate(b'0\n')
        _,validate,_=o.prepare(m.ROOT,'drainage')
        payload=b'0 1 9.0\n'*254
        with self.assertRaisesRegex(RuntimeError,'mismatch'):validate(payload)

    def test_native_malformed_stdin_rejected(self):
        s=self.session('malformed-input');s.execute('drainage',0)
        exe=next(iter(s.artifacts.values()))[0]
        cp=subprocess.run([str(exe)],input=b'2\ninvalid\n',capture_output=True)
        self.assertNotEqual(cp.returncode,0)
        (s.out/'malformed.stdout').write_bytes(cp.stdout);(s.out/'malformed.stderr').write_bytes(cp.stderr)
        m.write(s.out/'CONTROL.json',{'status':'PASS_EXPECTED_REJECTION','returncode':cp.returncode,'events':s.events})

    def test_default_has_no_runtime_or_audit(self):
        self.assertNotIn('accepted_heat',m.DEFAULT_CASES)
        self.assertNotIn('temperature',m.DEFAULT_CASES)
        for case in m.DEFAULT_CASES:
            self.assertLessEqual(len(m.plan(case)),4)


class SelectionControls(unittest.TestCase):
    def setUp(self):
        import json
        self.json = json
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.saved_root = m.ROOT
        m.ROOT = self.root
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Selection control')
        for path in ['docs/authority.md', 'src/process/local.f90', 'integration/owner/STATUS.json']:
            p = self.root/path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text('{}\n')
        self.git('add', '.'); self.git('commit', '-qm', 'fixture')
        self.head = self.git('rev-parse', 'HEAD')
        self.decision = dict(changed_dependency='shared solver contract', scientific_claim='mass/restart preservation',
            owner='HY/RT/F-CI', authority='docs/authority.md#owner', expected_seconds=1850,
            existing_evidence='UNKNOWN; fresh required by owner', prior_execution='NONE')
        self.path = self.root/'integration/owner/STATUS.json'
        self.save()

    def tearDown(self):
        m.ROOT = self.saved_root; self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True).strip()

    def save(self, group='full_fci'):
        self.path.write_text(self.json.dumps({'test_selection': {'candidate':self.head, 'groups':{group:self.decision}}}))
        self.git('add', str(self.path)); self.git('commit', '--allow-empty', '-qm', 'persist selection')

    def test_local_function_uses_own_small_driver(self):
        x=m.select_changes(['src/process/mod_drainage_hooghoudt_equivalent_depth.f90'])
        self.assertEqual(x['cases'], ['drainage']); self.assertEqual(x['status'], 'FEEDBACK_SELECTED')
        self.assertIn('owning admission', x['required_followup'][0]); self.assertFalse(x['inherited_pass'])

    def test_shared_state_and_solver_retain_owner_obligations(self):
        for path in ['src/runtime/mod_fmr_runtime_core.f90', 'src/solver/mod_soil_water_solver_contract.f90', 'src/transaction/mod_transaction_reference.f90']:
            x=m.select_changes([path]); self.assertEqual(x['status'], 'BLOCKED_OWNER_SELECTION')
            self.assertIn('low_air_policy', x['cases']); self.assertTrue(any('full moving F-CI' in s for s in x['required_followup']))
            self.assertEqual(x['highest_low_air'], 'NOT_SELECTED_POLICY')

    def test_docs_only_no_numerics_and_config_is_not_docs(self):
        self.assertEqual(m.select_changes(['AGENTS.md', 'docs/audit.md'])['cases'], [])
        self.assertEqual(m.select_changes(['docs/input.json'])['status'], 'BLOCKED_OWNER_SELECTION')

    def test_unknown_deleted_and_untracked_inputs_block(self):
        (self.root/'src/process/local.f90').unlink()
        (self.root/'untracked-input.dat').write_text('changed')
        paths=m.changed_since(self.head)
        self.assertIn('src/process/local.f90', paths); self.assertIn('untracked-input.dat', paths)
        self.assertEqual(m.select_changes(paths)['status'], 'BLOCKED_OWNER_SELECTION')

    def test_full_fci_explicitly_selected_no_pass_inferred(self):
        x=m.require_selection(self.path, 'full_fci')
        self.assertEqual(x['status'], 'SELECTED_NOT_QUALIFIED')

    def test_missing_decision_and_unjustified_cost_rejected(self):
        with self.assertRaisesRegex(ValueError, 'record required'): m.require_selection(None, 'full_fci')
        for key in ['owner','authority','changed_dependency','scientific_claim','existing_evidence','expected_seconds']:
            old=self.decision.pop(key); self.save()
            with self.assertRaises(ValueError): m.require_selection(self.path, 'full_fci')
            self.decision[key]=old
        for value in [-1, True, float('nan'), float('inf')]:
            self.decision['expected_seconds']=value; self.save()
            with self.assertRaises(ValueError): m.require_selection(self.path, 'full_fci')

    def test_changed_source_blocks_but_docs_successor_does_not(self):
        (self.root/'docs/note.md').write_text('descriptive update')
        m.require_selection(self.path, 'full_fci')
        (self.root/'src/process/local.f90').write_text('changed')
        with self.assertRaisesRegex(ValueError,'dependency drift'): m.require_selection(self.path, 'full_fci')

    def test_unexpected_long_or_duplicate_pass_requires_diagnosis(self):
        for prior in ['UNEXPECTED_LONG','PASS','FAILED']:
            self.decision['prior_execution']=prior; self.save()
            with self.assertRaisesRegex(ValueError,'diagnose'): m.require_selection(self.path, 'full_fci')
            self.decision['diagnosis']='Identified source drift; changed owner source requires fresh evidence'; self.save()
            m.require_selection(self.path, 'full_fci'); self.decision.pop('diagnosis')

    def test_highest_stress_needs_unique_scientific_gap(self):
        self.save('highest_low_air')
        with self.assertRaisesRegex(ValueError,'stress justification'): m.require_selection(self.path, 'highest_low_air')
        for k in ['research_question','unique_failure','fast_coverage_gap','why_small_test_insufficient']: self.decision[k]='explicit investigated risk'
        self.save('highest_low_air'); m.require_selection(self.path, 'highest_low_air')

    def test_actual_full_runner_rejects_before_science(self):
        env=dict(os.environ);env.pop('SWAP5_TEST_SELECTION_RECORD',None)
        cp=subprocess.run(['bash',str(self.saved_root/'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh')], env=env,capture_output=True)
        self.assertNotEqual(cp.returncode,0); self.assertIn(b'selection record required',cp.stderr)
        self.assertNotIn(b'PRESERVATION=PASS',cp.stdout)

    def test_workflows_preserve_manual_full_and_exclude_auto_highest(self):
        import yaml
        workflows=self.saved_root/'.github/workflows'
        frost=yaml.safe_load((workflows/'ppa-wu05b-frost-admission.yml').read_text())
        for key,job in frost['jobs'].items():
            if key!='modular-feedback': self.assertIn("workflow_dispatch",job['if'])
        high=frost['jobs']['highest-runtime']['steps']
        science=next(s for s in high if s.get('name','').startswith('Actual highest'))
        self.assertIn('inputs.highest_low_air',science['if'])
        full=yaml.safe_load((workflows/'fci-canonical.yml').read_text())['jobs']['current-restricted-canonical-preservation']
        self.assertIn('workflow_dispatch', full['if'])
        self.assertIn('run_fci_canonical_p2e05_moving_preservation.sh',full['steps'][-1]['run'])
        b19=yaml.safe_load((workflows/'ppa-wu05b19-runtime-admission.yml').read_text())
        events=b19.get('on',b19.get(True));self.assertEqual(set(events), {'workflow_dispatch'})

if __name__=='__main__':unittest.main(verbosity=2)
