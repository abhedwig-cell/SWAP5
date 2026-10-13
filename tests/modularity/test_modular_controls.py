#!/usr/bin/env python3
"""Fail-closed graph and actual compiler/artifact mutation controls."""
import importlib.util,json,os,tempfile,unittest
from pathlib import Path
SPEC=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)

class DependencyControls(unittest.TestCase):
    def check_rejected(self,files,target,fragment):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'src').mkdir()
            for name,text in files.items():(root/'src'/name).write_text(text)
            with self.assertRaisesRegex(ValueError,fragment):M.DEP.strict_closure(root,['src/'+target])
    def test_duplicate(self):
        self.check_rejected({'a.f90':'module a\nend module','b.f90':'module a\nend module'},'a.f90','duplicate')
    def test_missing(self):
        self.check_rejected({'a.f90':'module a\nuse missing\nend module'},'a.f90','unresolved')
    def test_cycle(self):
        self.check_rejected({'a.f90':'module a\nuse b\nend module','b.f90':'module b\nuse a\nend module'},'a.f90','cycle')
    def test_include(self):
        self.check_rejected({'a.f90':"module a\ninclude 'unknown.inc'\nend module"},'a.f90','explicit include')
    def test_preprocessor(self):
        self.check_rejected({'a.f90':'#if SOMETHING\nmodule a\nend module'},'a.f90','explicit include')
    def test_intrinsic(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'src').mkdir();(root/'src/a.f90').write_text('module a\nuse, intrinsic :: iso_fortran_env\nend module')
            order,_=M.DEP.strict_closure(root,['src/a.f90']);self.assertEqual(len(order),1)

class ProductionClosureControls(unittest.TestCase):
    def test_component_closure_budgets(self):
        expected={'hydraulics':2,'richards':17,'timestep':2,'transaction':1,'evaporation':1,'root':3,'drainage':1,'crop':1,'temperature':5,'runtime':154}
        for name,target in M.COMPONENTS.items():
            order,_=M.DEP.strict_closure(M.ROOT,[target],[M.STUB])
            self.assertEqual(len(order),expected[name],name+' closure changed: reassess contract and build budget')
    def test_no_duplicate_original_or_focused_sources(self):
        for case in M.CASES:
            for broad in [False,True]:
                sources=M.plan(case,broad)
                self.assertEqual(len(sources),len(set(sources)))
    def test_zero_repeat_rejected(self):
        import subprocess
        with tempfile.TemporaryDirectory() as d:
            cp=subprocess.run(['python',str(Path(M.__file__)), '--output',d+'/out','--benchmark','--repeat','0'],capture_output=True)
            self.assertNotEqual(cp.returncode,0)
            self.assertNotIn(b'MODULAR_PRODUCTION_DRIVERS=PASS',cp.stdout)

class CompilerControls(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.saved_root=M.ROOT;M.ROOT=self.root
        sources=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_b110_default_mvg_provider.f90',M.CASES['mvg']['driver'],M.STUB,'tests/support/augment_bartholomeus_backend_sources.py']
        for path in sources:
            target=self.root/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((self.saved_root/path).read_bytes())
        self.session=M.Session(self.root/'evidence')
    def tearDown(self):M.ROOT=self.saved_root;self.tmp.cleanup()
    def test_actual_artifact_mutation_rejected(self):
        self.session.execute('mvg',0)
        _,artifacts=next(iter(self.session.artifacts.values()))
        obj=next(p for p in artifacts if p.suffix=='.o');obj.write_bytes(obj.read_bytes()+b'corruption')
        with self.assertRaisesRegex(RuntimeError,'artifact identity'):self.session.execute('mvg',0,reuse=True)
    def test_changed_source_recompiled(self):
        first=self.session.execute('mvg',0)
        p=self.root/'src/solver/mod_b110_default_mvg_provider.f90';p.write_text(p.read_text()+'\n! deliberate harmless mutation\n')
        second=self.session.execute('mvg',0,reuse=True)
        self.assertGreater(second['compiler_requests'],0);self.assertEqual(first['stdout_sha256'],second['stdout_sha256'])
    def test_actual_compiler_failure(self):
        p=self.root/M.CASES['mvg']['driver'];p.write_text(p.read_text()+'\nINVALID FORTRAN\n')
        with self.assertRaisesRegex(RuntimeError,'compile failed'):self.session.execute('mvg',0)
        self.assertFalse(self.session.artifacts)
    def test_scientific_failure(self):
        p=self.root/M.CASES['mvg']['driver'];s=p.read_text().replace('cof = 0.0_real64','error stop "deliberate scientific failure"\n  cof = 0.0_real64');p.write_text(s)
        with self.assertRaisesRegex(RuntimeError,'science failed'):self.session.execute('mvg',0)
    def test_environment_identity_failure(self):
        self.session.identity['version']='invalid identity'
        with self.assertRaisesRegex(RuntimeError,'toolchain/environment'):self.session.execute('mvg',0)
    def test_source_changed_during_build(self):
        original=self.session.command
        def mutate(args,cwd,label):
            result=original(args,cwd,label)
            if label=='link':
                p=self.root/M.CASES['mvg']['driver'];p.write_text(p.read_text()+'\n! changed during build\n')
            return result
        self.session.command=mutate
        with self.assertRaisesRegex(RuntimeError,'source changed during build'):self.session.execute('mvg',0)

if __name__=='__main__':unittest.main(verbosity=2)
