"""Verify sealed measured evidence and current compiled-owner dependency bytes."""
import hashlib,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
base=ROOT/'integration/dataqual15_hupsel'
m=json.loads((base/'NATIVE_CANOPY_PUBLICATION_WINDOWS_20261103.tar.json').read_text())
archive=base/'NATIVE_CANOPY_PUBLICATION_WINDOWS_20261103.tar.xz'
assert sha(archive.read_bytes())==m['archive_sha256']
for name,digest in m['normalized_repository_source_sha256'].items():
 assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest,name
with tarfile.open(archive)as t:
 actual={x.name:sha(t.extractfile(x).read())for x in t.getmembers()if x.isfile()}
 assert actual==m['files_sha256']
 assert len(m['results'])==2
 for r in m['results']:
  assert r['outer_controls']==7 and r['nested_controls']==37 and r['crc_cases']==8,r
  q=json.loads(t.extractfile(r['optimization']+'/qualification/RESULT.json').read())
  assert q['status']=='NATIVE_TWO_DAY_PUBLICATION_RESTART_AND_CORRUPTION_PASS'
  assert all(e['status']=='PASS'for e in json.loads(t.extractfile(r['optimization']+'/nested-decoder/RESULT.json').read())['events'])
assert not m['scientific_admission']and not m['physical_correction']
posix=json.loads((base/'NATIVE_CANOPY_PUBLICATION_POSIX_20261103.tar.json').read_text())
assert posix['status']=='POSIX_CHECKED_O0_O2_NATIVE_IO_PASS'
assert sha((base/'NATIVE_CANOPY_PUBLICATION_POSIX_20261103.tar.xz').read_bytes())==posix['archive_sha256']
for name,digest in posix['normalized_repository_source_sha256'].items():
 assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest,name
with tarfile.open(base/'NATIVE_CANOPY_PUBLICATION_POSIX_20261103.tar.xz')as t:
 assert {x.name:sha(t.extractfile(x).read())for x in t.getmembers()if x.isfile()}==posix['files_sha256']
for r in posix['results']:
 assert r['outer_controls']==7 and r['crc_cases']==8
 assert r['checkpoint_sha256']==m['results'][0]['checkpoint_sha256']
composed=json.loads((base/'COMPOSED_PUBLICATION_WINDOWS_20261103.tar.json').read_text())
assert composed['status']=='FOCUSED_BLACK_RUTTER_HEAT_REACTIVE_PASS_NOT_ADMITTED'
assert sha((base/'COMPOSED_PUBLICATION_WINDOWS_20261103.tar.xz').read_bytes())==composed['archive_sha256']
for name,digest in composed['normalized_repository_source_sha256'].items():
 assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest,name
with tarfile.open(base/'COMPOSED_PUBLICATION_WINDOWS_20261103.tar.xz')as t:
 assert {x.name:sha(t.extractfile(x).read())for x in t.getmembers()if x.isfile()}==composed['files_sha256']
print('SEALED_NATIVE_CANOPY_IO_EVIDENCE_PASS_PHYSICS_OPEN')
