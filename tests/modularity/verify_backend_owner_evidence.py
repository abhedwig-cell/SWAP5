"""Verify sealed fresh owner science before the exact backend can enter F-CI.

This is an owner prerequisite, not a claim that the moving F-CI gate passed.
"""
from pathlib import Path
import base64
import hashlib
import io
import json
import tarfile
from backend_allocation_authority import ROOT, BASE, BACKEND, verify_source, git

MARKERS = {
    'source.stdout': b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS',
    'reference.stdout': b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS',
    'focused.stdout': b'MC_MET01_ACTUAL_DAILY_DEMAND_PRODUCTION_O0_O2=PASS',
    'default-crop.stdout': b'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS',
    'old-raintb.stdout': b'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS',
    'boesten.stdout': b'PPA-WU04-B BOESTEN PRESERVATION PASS',
    'macro-top.stdout': b'PPA_WU05A9_TOP_INPUT_GATE=PASS',
}


def read_archive(record):
    raw = base64.b64decode((ROOT / record['path']).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == record['decoded_sha256'], 'archive corruption'
    return tarfile.open(fileobj=io.BytesIO(raw))


def verify_owner():
    source = verify_source()
    status = json.loads((ROOT / 'integration/audits/MODULAR_TESTABILITY_20261013.json').read_text())
    owner = status['backend_qualification']['owner_evidence']
    # A status bool alone is never sufficient. All actual evidence is checked.
    with read_archive(owner) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json'))
        assert manifest['source_tree'] == source['source_tree']
        assert manifest['baseline'] == BASE and manifest['highest_cases_inherited'] == 0
        for path, expected in manifest['dependency_blobs'].items():
            assert git('rev-parse', 'HEAD:' + path) == expected, path
            assert git('hash-object', path) == expected, path
        for name, expected in manifest['member_sha256'].items():
            assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == expected, name
        control = json.load(archive.extractfile('CONTROL.json'))
        assert control['status'] == 'PASS' and all(s['exit'] == 0 for s in control['steps'])
        required = {'highest-normal', 'highest-low-air', 'source', 'reference', 'focused',
                    'default-crop', 'old-raintb', 'heat-runtime', 'fkt22', 'boesten', 'macro-top'}
        assert {s['name'] for s in control['steps']} == required
        for name, marker in MARKERS.items():
            assert marker in archive.extractfile(name).read(), name
        old_status = json.loads((ROOT / 'integration/audits/MC_MET01_STATUS.json').read_text())
        with read_archive(old_status['daily_demand_successor']['owner_evidence']) as prior:
            for route in ('normal', 'low-air'):
                for opt in (0, 2):
                    path = f'highest/{route}/o{opt}/output.txt'
                    actual = archive.extractfile(path).read()
                    assert actual == prior.extractfile(path).read(), 'highest output drift: ' + path
                    assert actual.count(b'_RUNTIME=PASS') == 6
                    assert actual.count(b'FINE_COMPARISON') == 36
    return manifest


if __name__ == '__main__':
    verify_owner()
    print('BACKEND_ALLOCATION_FRESH_OWNER_SOURCE_AND_HIGHEST=PASS')
