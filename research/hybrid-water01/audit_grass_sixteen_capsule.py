"""Verify retained members and regenerate the full sixteen-step receipt exactly."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--archive', type=Path, required=True)
p.add_argument('--sha256', required=True)
p.add_argument('--receipt', type=Path, required=True)
a = p.parse_args()
assert hashlib.sha256(a.archive.read_bytes()).hexdigest() == a.sha256
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='s5-sixteen-full-reaudit-') as temp:
    folder = Path(temp)
    with tarfile.open(a.archive) as archive:
        archive.extractall(folder, filter='data')
    members = json.loads((folder/'MEMBER_SHA256.json').read_text())
    for name, digest in members.items():
        path = (folder/name).resolve()
        assert path.is_relative_to(folder.resolve())
        assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, name
    for relative in ['research/hybrid-water01/qualify_grass_substep16_full.py',
                     'research/hybrid-water01/audit_grass_current.py',
                     'tests/dataqual15/checkpoint_layout.py']:
        assert (folder/'verification'/relative).read_bytes() == (root/relative).read_bytes()
    output = folder/'independent-receipt.json'
    command = [sys.executable, '-B', str(Path(__file__).with_name('qualify_grass_substep16_full.py')),
               '--bundle', str(folder/'bundle'), '--full', str(folder/'full'),
               '--restarts', str(folder/'restarts'), '--spec', str(folder/'spec.json'),
               '--file-index', str(folder/'FILE_INDEX.json'), '--output', str(output)]
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
    assert output.read_bytes() == a.receipt.read_bytes() == (folder/'receipt.json').read_bytes()
    print(json.dumps({'status': 'RAW_MEMBERS_AND_BYTE_EXACT_INDEPENDENT_FULL_RECEIPT_PASS',
                      'retained_files': len(members), 'archive_sha256': a.sha256,
                      'receipt_sha256': hashlib.sha256(output.read_bytes()).hexdigest()}))
