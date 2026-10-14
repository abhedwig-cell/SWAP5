"""Reject re-sealed partial, weakened and foreign closeout authorities."""
import base64, hashlib, importlib.util, io, json, pathlib, tarfile, tempfile, unittest
from unittest.mock import patch

path = pathlib.Path(__file__).with_name('verify_low_air_continuation.py')
spec = importlib.util.spec_from_file_location('continuation', path)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)

class Controls(unittest.TestCase):
    def test_actual_complete(self):
        result = verifier.verify_continuation()
        self.assertEqual(result['original_fine_comparisons'], 72)
        self.assertFalse(result['tenfold_proved'])

    def mutate(self, change):
        raw = base64.b64decode((verifier.ROOT / verifier.CAPSULE).read_bytes())
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            files = {name: archive.extractfile(name).read() for name in archive.getnames()}
        change(files)
        files['INDEX.json'] = json.dumps({name: hashlib.sha256(data).hexdigest() for name, data in files.items() if name != 'INDEX.json'}).encode()
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w:xz') as archive:
            for name, data in files.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        raw = stream.getvalue()
        with tempfile.TemporaryDirectory() as temporary:
            seal = pathlib.Path(temporary) / 'negative.b64'
            seal.write_bytes(base64.b64encode(raw))
            with patch.object(verifier, 'CAPSULE', str(seal)), patch.object(verifier, 'CAPSULE_SHA', hashlib.sha256(raw).hexdigest()):
                with self.assertRaises((ValueError, AssertionError)):
                    verifier.verify_continuation()

    def test_partial_highest(self):
        def change(files):
            name = 'final-workspace-qualification/qual-o0/RESULTS.json'
            report = json.loads(files[name])
            report['runs'].pop()
            files[name] = json.dumps(report).encode()
        self.mutate(change)

    def test_weakened_assertion(self):
        name = 'final-workspace-qualification/qual-o2/candidate.f90'
        self.mutate(lambda files: files.__setitem__(name, files[name].replace(b'head_diff<=1.e-6_real64', b'head_diff<=1.e-3_real64')))

    def test_missing_preservation(self):
        name = 'moving-qualified/stdout'
        self.mutate(lambda files: files.__setitem__(name, files[name].replace(b'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS', b'MISSING')))

    def test_foreign_provider(self):
        name = 'final-workspace-qualification/build-o0/mod_canonical_interval_runtime.f90'
        self.mutate(lambda files: files.__setitem__(name, files[name] + b'! unqualified provider\n'))

    def test_false_tenfold(self):
        def change(files):
            name = 'final-workspace-qualification/RESULTS.json'
            report = json.loads(files[name])
            report['tenfold_proved'] = True
            files[name] = json.dumps(report).encode()
        self.mutate(change)

if __name__ == '__main__':
    unittest.main()
