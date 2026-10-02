"""Verify split raw archive, per-run hashes and immutable source dependencies."""
import csv,gzip,hashlib,io,json,subprocess,tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
evidence=root/'docs/audits/evidence'
parts=sorted(evidence.glob('PPA_WU05A27_COHORT_EVIDENCE.tar.gz.part-*'))
assert len(parts)==16
packed=b''.join(p.read_bytes() for p in parts)
assert hashlib.sha256(packed).hexdigest()=='b816cd0920e91905403ac9c437b20b3b3c6b8c6b8b8a5adb40d443c0864ec245'
with tarfile.open(fileobj=io.BytesIO(gzip.decompress(packed)),mode='r:') as t:
    manifest=json.load(t.extractfile('manifest.json'))
    assert manifest==json.loads((evidence/'PPA_WU05A27_COHORT_RUN_MANIFEST.json').read_text())
    for run in manifest:
        for path,expected in run['files'].items():
            data=t.extractfile(path).read()
            assert len(data)==expected['bytes']
            assert hashlib.sha256(data).hexdigest()==expected['sha256']
            if path.endswith('column.csv'):
                rows=list(csv.DictReader(io.StringIO(data.decode())))
                assert len(rows)==10*int(run['run'])
        for path,expected in run['dependency_sha256'].items():
            data=subprocess.check_output(['git','show',run['code_sha']+':'+path],cwd=root)
            assert hashlib.sha256(data).hexdigest()==expected
print('A27_COHORT_ARCHIVE_AND_EXACT_REF_DEPENDENCIES=PASS')
