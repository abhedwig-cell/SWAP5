import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
def load(path):
    spec=importlib.util.spec_from_file_location('tested',ROOT/path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
identity=load('tools/performance/irrigation_build_identity.py')
compare=load('tests/performance/compare_mc_irr01_shared_build.py')

class SharedBuildControls(unittest.TestCase):
    def graph(self, sources, driver='program t\nuse a\nend program'):
        with tempfile.TemporaryDirectory() as td:
            files=[]
            for i,text in enumerate(sources):
                p=Path(td)/f'{i}.f90';p.write_text(text);files.append(p)
            d=Path(td)/'driver.f90';d.write_text(driver)
            return [p.name for p in identity.discover(files,[d])]
    def test_module_order(self):
        self.assertEqual(self.graph(['module a\nuse b\nend module','module b\nend module']),['1.f90','0.f90'])
    def test_multi_module_file_once(self):
        self.assertEqual(self.graph(['module a\nend module\nmodule b\nuse a\nend module'],driver='use a\nuse b'),['0.f90'])
    def test_missing_module(self):
        with self.assertRaisesRegex(ValueError,'unresolved'):
            self.graph(['module a\nuse missing\nend module'])
    def test_duplicate_provider(self):
        with self.assertRaisesRegex(ValueError,'duplicate'):
            self.graph(['module a\nend module','module a\nend module'])
    def test_cycle(self):
        with self.assertRaisesRegex(ValueError,'cycle'):
            self.graph(['module a\nuse b\nend module','module b\nuse a\nend module'])
    def test_changed_science_fails(self):
        arms={'root':{'science_sha256':'a'},'sensor':{'science_sha256':'b'},
              'combined':{'root_science_sha256':'a','sensor_science_sha256':'WRONG'}}
        with self.assertRaisesRegex(ValueError,'mismatch'):
            compare.verify_science(arms)
    def test_changed_executable_fails(self):
        arms={'root':{'executables':{'0.exe':'r0','1.exe':'r2'}},
              'sensor':{'executables':{'0.exe':'s0','1.exe':'s2'}},
              'combined':{'executables':{'0.exe':'r0','1.exe':'s0','2.exe':'r2','3.exe':'s2'}}}
        compare.verify_executables(arms)
        arms['combined']['executables']['3.exe']='modified'
        with self.assertRaisesRegex(ValueError,'executable identity'):
            compare.verify_executables(arms)
    def test_missing_duplicate_marker(self):
        for text in ['', 'MARK='+'a'*64+'\nMARK='+'a'*64]:
            with self.assertRaisesRegex(ValueError,'missing/duplicate'):
                compare.extract(text,'MARK')

if __name__=='__main__':unittest.main()
