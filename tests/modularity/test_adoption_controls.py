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


if __name__=='__main__':unittest.main(verbosity=2)
