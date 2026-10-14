"""Verify sealed fresh owner science before the exact backend can enter F-CI.

This is an owner prerequisite, not a claim that the moving F-CI gate passed.
"""
from pathlib import Path
import base64
import hashlib
import io
import json
import tarfile
import subprocess
from backend_allocation_authority import ROOT, BASE, BACKEND, PUBLICATION, blob, verify_source, git

MARKERS = {
    'source.stdout': b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS',
    'reference.stdout': b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS',
    'focused.stdout': b'MC_MET01_ACTUAL_DAILY_DEMAND_PRODUCTION_O0_O2=PASS',
    'default-crop.stdout': b'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS',
    'old-raintb.stdout': b'MC_MET01_ACTUAL_RAINTB_PRODUCTION_O0_O2=PASS',
    'boesten.stdout': b'PPA-WU04-B BOESTEN PRESERVATION PASS',
    'macro-top.stdout': b'PPA_WU05A9_TOP_INPUT_GATE=PASS',
    'heat-runtime.stdout': b'MC_HEAT01_RUNTIME_O0_O2_REPEAT_DETERMINISM=PASS',
    'fkt22.stdout': b'FKT22_FMR_PRODUCTION_RUNTIME_GATE=PASS',
}

REQUIRED = {'highest-normal', 'highest-low-air', 'source', 'reference', 'focused',
            'default-crop', 'old-raintb', 'heat-runtime', 'fkt22', 'boesten', 'macro-top'}


def head_blobs():
    return {line.split('\t', 1)[1]: line.split('\t', 1)[0].split()[2]
            for line in git('ls-tree', '-r', 'HEAD').splitlines()}


def verify_dependencies(dependencies, head=None):
    """One tree read; hash actual bytes without spawning Git twice per file."""
    assert dependencies, 'empty dependency binding'
    if head is None:
        head = head_blobs()
    for path, expected in dependencies.items():
        assert head.get(path) == expected and blob((ROOT / path).read_bytes()) == expected, path


def verify_owner_binding(manifest, control, recipes, source):
    assert manifest['baseline'] == BASE and manifest['highest_cases_inherited'] == 0
    assert manifest['highest_configurations'] == 24 and manifest['fine_comparisons'] == 144
    assert control['status'] == 'PASS' and all(s['exit'] == 0 for s in control['steps'])
    assert len(control['steps']) == len(REQUIRED)
    assert {s['name'] for s in control['steps']} == REQUIRED
    assert manifest['source_tree'] == control['source_tree']
    assert git('rev-parse', control['head'] + ':src') == control['source_tree']
    policy = recipes.get('highest_controller_policy_binding')
    if policy is not None:
        path = 'tests/mc-met01/run_daily_demand_frost_successor.py'
        executed = subprocess.check_output(['git', 'show', control['head'] + ':' + path], cwd=ROOT)
        current = (ROOT / path).read_bytes()
        assert hashlib.sha256(executed).hexdigest() == policy['old_sha256']
        assert hashlib.sha256(current).hexdigest() == policy['new_sha256']
        old = (b' from backend_allocation_authority import BACKEND,verify_source\n'
               b' verify_source() # Source eligibility only: all scientific cases still execute.\n'
               b' assert changed==sorted([*PINS,BACKEND])\n')
        new = (b' from backend_allocation_authority import verify_source\n'
               b" source=verify_source() # Source eligibility only: all scientific cases still execute.\n"
               b" assert changed==sorted([*PINS,*source['changed_paths']])\n")
        assert executed.count(old) == 1 and executed.replace(old, new) == current
    delta = git('diff', '--name-only', control['head'], 'HEAD', '--', 'src').splitlines()
    assert delta in [[], [PUBLICATION]], 'science source changed inside owner surface'
    assert REQUIRED <= recipes['recipes'].keys()
    head = head_blobs()
    for name in REQUIRED:
        recipe = recipes['recipes'][name]
        assert not recipe['publication_compiled']
        assert PUBLICATION not in recipe['sources']
        assert set(recipe['source_blobs']) == set(recipe['sources'])
        verify_dependencies(recipe['source_blobs'], head)
    verify_dependencies(manifest['dependency_blobs'], head)
    # Cover the entire production surface conservatively, except the one module
    # explicitly proved absent from every owner recipe. Its science is separate.
    expected_sources = set(git('ls-tree', '-r', '--name-only', 'HEAD', '--', 'src').splitlines())
    assert expected_sources - {PUBLICATION} <= manifest['dependency_blobs'].keys()
    if not delta:
        assert manifest['source_tree'] == source['source_tree']


def read_archive(record):
    raw = base64.b64decode((ROOT / record['path']).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == record['decoded_sha256'], 'archive corruption'
    return tarfile.open(fileobj=io.BytesIO(raw))


def verify_owner():
    source = verify_source()
    if source.get('joint_successor') and (ROOT / 'integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json').exists():
        from verify_joint_preservation import verify_qualification
        return verify_qualification()
    status = json.loads((ROOT / 'integration/audits/MODULAR_TESTABILITY_20261013.json').read_text())
    owner = status['backend_qualification']['owner_evidence']
    # A status bool alone is never sufficient. All actual evidence is checked.
    with read_archive(owner) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json'))
        for name, expected in manifest['member_sha256'].items():
            assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == expected, name
        control = json.load(archive.extractfile('CONTROL.json'))
        recipes = json.load(archive.extractfile('OWNER_DEPENDENCIES.json'))
        verify_owner_binding(manifest, control, recipes, source)
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
