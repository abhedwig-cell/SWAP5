"""Verify retained boundary/interval execution evidence; never admission."""
from pathlib import Path
import base64,hashlib,io,json,tarfile
ROOT=Path(__file__).resolve().parents[2]
status=json.loads((ROOT/'integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json').read_text())
evidence=status['execution_evidence']
raw=base64.b64decode((ROOT/evidence['path']).read_bytes(),validate=False)
assert hashlib.sha256(raw).hexdigest()==evidence['decoded_sha256'],'capsule digest'
with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as archive:
    members={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for path,digest in evidence['members'].items():
    assert hashlib.sha256(members[path]).hexdigest()==digest,path
result=json.loads(members['final/result.json'])
assert result['status']=='SYNTHETIC_EVENT_AND_INCUMBENT_INTERVAL_PASS_NOT_ADMITTED'
assert not result['dirty_scientific_surface']
for path,digest in result['inputs'].items():
    assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
    assert hashlib.sha256(members['sources/'+path]).hexdigest()==digest,path
natives=[e for e in result['events'] if e['category']=='native']
assert len(natives)==4 and all(e['exit']==0 for e in result['events'])
outputs=[members['final/'+e['stdout']] for e in natives]
assert outputs[0]==outputs[2] and outputs[1]==outputs[3]
assert b'KERNEL_BOUNDARY_SYNTHETIC_ASSERTIONS=169' in outputs[0]
assert b'KERNEL_BOUNDARY_TRANSACTION_CONTRACT=PASS' in outputs[0]
assert b'FKT22_KERNEL_TRAJECTORY_TRANSPORT=PASS' in outputs[1]
assert b'FKT22_KERNEL_TYPED_PROVENANCE=PASS' in outputs[1]
assert b'FKT22_KERNEL_DEFAULT_OFF=PASS' in outputs[1]
print(json.dumps(dict(status='RETAINED_SYNTHETIC_EVENT_AND_FKT22_EVIDENCE_VERIFIED',
    execution_commit=result['execution_commit'],assertions_per_optimization=169,
    native_executions=4,canonical_admission=False,physical_harvest_qualification=False),indent=2))
