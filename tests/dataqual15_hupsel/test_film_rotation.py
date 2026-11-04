"""Actual retained closure and relocation defects, no model substitute."""
import json,os,shutil,tempfile,unittest
from pathlib import Path
import film_rotation_audit as audit


class Closure(unittest.TestCase):
    def setUp(self):
        self.case=Path(os.environ.get('FILM_ROTATION_TEST_CASE',str(audit.ROOT.parent/'film-rotation-20261104/O0'))).resolve()
        self.platform=os.environ.get('FILM_ROTATION_TEST_PLATFORM','windows')

    def test_exact_existing_coherent_native_closure(self):
        audit.native_binding(self.case,'O0',self.platform)

    def test_actual_source_executable_and_metadata_corruption_refused(self):
        with tempfile.TemporaryDirectory(prefix='film-rotation-boundary-')as name:
            folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('film-rotation-boundary-')
            shutil.copytree(self.case/'native',folder/'native')
            source=next((folder/'native/build/providers').iterdir());original=source.read_bytes();source.write_bytes(original+b'\n')
            with self.assertRaises(AssertionError):audit.native_binding(folder,'O0',self.platform)
            source.write_bytes(original)
            exe=folder/'native/build'/('swap5_hupsel_germination.exe'if self.platform=='windows'else'swap5_hupsel_germination')
            original=exe.read_bytes();exe.write_bytes(original+b'corrupt')
            with self.assertRaises(AssertionError):audit.native_binding(folder,'O0',self.platform)
            exe.write_bytes(original)
            path=folder/'native/build/BUILD.json';record=json.loads(path.read_text());record['flags'].append('-ffast-math');path.write_text(json.dumps(record))
            with self.assertRaises(AssertionError):audit.native_binding(folder,'O0',self.platform)

    def test_false_admission_registration_refused_before_runtime(self):
        with tempfile.TemporaryDirectory(prefix='film-rotation-registration-')as name:
            folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('film-rotation-registration-')
            for field in ('production_admission','whole_scientific_admission'):
                record=json.loads((audit.BASE/audit.runner.REG).read_text());record[field]=True;(folder/'REGISTRATION.json').write_text(json.dumps(record))
                with self.assertRaises(AssertionError):audit.audit(folder,'O0',self.platform)

if __name__=='__main__':unittest.main(verbosity=2)
