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


if __name__ == '__main__':
    unittest.main()
