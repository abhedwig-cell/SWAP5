"""Real coherent-build defects; never a substitute trajectory."""
import contextlib,copy,io,json,os,tempfile,unittest
from pathlib import Path
from unittest import mock
import pressure_film_evidence as evidence


class Composition(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder=Path(os.environ.get('PRESSURE_FILM_TEST_CASE',str(evidence.ROOT.parent/'pressure-film-20261105/O0'))).resolve()
        cls.files=evidence.collect(cls.folder,'O0')

    def test_actual_complete_two_source_build(self):evidence.audit.source_binding(self.files,'O0')

    def test_pressure_predicate_cannot_be_reverted_with_updated_digest(self):
        files=dict(self.files);build=json.loads(files['O0/build/BUILD.json']);context=evidence.audit.paths(build,'O0')
        source=next(p for p in build['source_sha256']if p.endswith('private_mod_root_micro_de_willigen_process.f90'));key=evidence.audit.key(source,context,'O0')
        raw=files[key].decode().replace(evidence.audit.runner.pressure.NEW,evidence.audit.runner.pressure.OLD).encode();files[key]=raw;build['source_sha256'][source]=evidence.sha(raw);files['O0/build/BUILD.json']=json.dumps(build).encode()
        with self.assertRaises(AssertionError):evidence.audit.source_binding(files,'O0')

    def test_film_criterion_cannot_be_changed_with_updated_digest(self):
        files=dict(self.files);build=json.loads(files['O0/build/BUILD.json']);context=evidence.audit.paths(build,'O0')
        source=next(p for p in build['source_sha256']if p.endswith('private_mod_bartholomeus_waterfilm_independent.f90'));key=evidence.audit.key(source,context,'O0')
        assert files[key].count(b'1.0e-5_real64')==1
        raw=files[key].replace(b'1.0e-5_real64',b'2.0e-5_real64');files[key]=raw;build['source_sha256'][source]=evidence.sha(raw);files['O0/build/BUILD.json']=json.dumps(build).encode()
        with self.assertRaises(AssertionError):evidence.audit.source_binding(files,'O0')

    def test_unchecked_flags_refused(self):
        files=dict(self.files);record=json.loads(files['O0/build/BUILD.json']);record['flags'].append('-ffast-math');files['O0/build/BUILD.json']=json.dumps(record).encode()
        with self.assertRaises(AssertionError):evidence.audit.source_binding(files,'O0')

    def test_failed_compile_refused(self):
        files=dict(self.files);record=json.loads(files['O0/build/BUILD.json']);record['events'][0]['returncode']=1;files['O0/build/BUILD.json']=json.dumps(record).encode()
        with self.assertRaises(AssertionError):evidence.audit.source_binding(files,'O0')

    def test_false_admission_refused(self):
        with tempfile.TemporaryDirectory(prefix='pressure-film-policy-')as name:
            folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('pressure-film-policy-')
            for flag in ('production_admission','whole_scientific_admission'):
                registration=json.loads((evidence.BASE/evidence.audit.runner.REG).read_text());registration[flag]=True;(folder/'REGISTRATION.json').write_text(json.dumps(registration))
                with self.assertRaises(AssertionError):evidence.audit.audit(folder,'O0')

    def test_missing_proof_requires_actual_native_execution(self):
        with tempfile.TemporaryDirectory(prefix='pressure-film-policy-')as name:
            folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('pressure-film-policy-');output=io.StringIO()
            with mock.patch.object(evidence,'BASE',folder),mock.patch('sys.argv',['pressure_film_evidence.py','--native-mode']),contextlib.redirect_stdout(output):evidence.main()
            self.assertEqual(output.getvalue(),'reused=false\n')

    def test_changed_dependency_refuses_native_proof_reuse(self):
        with tempfile.TemporaryDirectory(prefix='pressure-film-policy-')as name:
            folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('pressure-film-policy-')
            deps=evidence.dependencies();deps[next(iter(deps))]='0'*64;(folder/'PRESSURE_FILM_POSIX_20261105.json').write_text(json.dumps(dict(qualification_dependencies=deps)))
            with mock.patch.object(evidence,'BASE',folder),mock.patch('sys.argv',['pressure_film_evidence.py','--native-mode']):
                with self.assertRaises(AssertionError):evidence.main()

if __name__=='__main__':unittest.main(verbosity=2)
