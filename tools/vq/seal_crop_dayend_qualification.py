#!/usr/bin/env python3
"""Seal exact current-day MC-CROP01 raw evidence; never run or invent a gate."""
import argparse
import base64
import gzip
import hashlib
import io
import json
import pathlib
import subprocess
import tarfile
import textwrap

ROOT = pathlib.Path(__file__).resolve().parents[2]
STATUS = ROOT / 'integration/audits/MC_CROP01_DAYEND_PRODUCTION_STATUS.json'
SOURCE = 'b52c70dc50742fdbf5b03f71ec68709b191d0ec7'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def seal(name, members, extra):
    manifest = dict(extra, qualified_head=git('rev-parse', 'HEAD'),
                    qualified_tree=git('rev-parse', 'HEAD^{tree}'), source_tree=SOURCE,
                    reference_tree=git('rev-parse', 'HEAD:reference'),
                    full_lifecycle_closed=False, canonically_admitted=False,
                    member_sha256={p: sha(data) for p, data in sorted(members.items())})
    members['MANIFEST.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w') as archive:
        for path, data in sorted(members.items()):
            info = tarfile.TarInfo(path)
            info.size, info.mtime = len(data), 0
            archive.addfile(info, io.BytesIO(data))
    raw = gzip.compress(buffer.getvalue(), mtime=0)
    path = 'integration/audits/evidence/MC_CROP01_DAYEND_' + name + '_20261011.tar.gz.b64'
    (ROOT / path).write_text('\n'.join(textwrap.wrap(base64.b64encode(raw).decode(), 76)) + '\n')
    return {'path': path, 'decoded_sha256': sha(raw), 'members': len(members),
            'scientific_head': manifest['qualified_head'], 'source_tree': SOURCE}


def checked_logs(scratch, markers, exits):
    members = {}
    for name, marker in markers.items():
        assert exits[name] == 0, name
        data = (scratch / name).read_bytes()
        assert marker.encode() in data, (name, marker)
        members[name] = data
    return members


def frost(scratch, status):
    original_path = 'integration/audits/evidence/FROST_NAN_GUARD_QUALIFICATION_20261011.tar.gz.b64'
    original_raw = base64.b64decode((ROOT / original_path).read_bytes())
    assert sha(original_raw) == 'f7b95b481c3d2f389647a52a74ce7f152b2c8dae365a6748d72df92537e5f316'
    markers = {'dayend-frost-normal.log': 'PPA_WU05B15_NORMAL_O0_O2_IDENTITY=PASS',
               'dayend-frost-low_air.log': 'PPA_WU05B15_LOW_AIR_O0_O2_IDENTITY=PASS'}
    members = checked_logs(scratch, markers, status['observed_terminal_exit_codes'])
    dependencies = {}
    with tarfile.open(fileobj=io.BytesIO(original_raw)) as original:
        for route in ('normal', 'low-air'):
            build = pathlib.Path('/tmp/ppa-wu05b15-' + route + '-runtime-crop-dayend')
            assert ('BUILD=' + str(build)).encode() in members['dayend-frost-' + route.replace('-', '_') + '.log']
            sources = (build / 'sources').read_bytes()
            members['highest/' + route + '/sources.txt'] = sources
            for name in sources.decode().splitlines():
                path = pathlib.Path(name)
                try:
                    relative = path.relative_to(ROOT).as_posix()
                except ValueError:
                    assert path == build / 'consistent_grid_stubs.f90'
                    old = b'  real(8), parameter :: disnod(numnod+1) = 1.0d0'
                    new = b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
                    donor = (ROOT / 'tests/fsi/fsi04_real_headcalc_stubs.f90').read_bytes()
                    assert donor.count(old) == 1 and path.read_bytes() == donor.replace(old, new)
                    members['highest/' + route + '/consistent_grid_stubs.f90'] = path.read_bytes()
                    continue
                assert subprocess.check_output(['git', 'show', 'HEAD:' + relative], cwd=ROOT) == path.read_bytes()
                dependencies[relative] = git('rev-parse', 'HEAD:' + relative)
            for opt in (0, 2):
                pieces = []
                for config in range(1, 7):
                    name = f'highest/{route}/o{opt}/configuration-{config}.txt'
                    data = (build / f'o{opt}' / f'configuration-{config}.txt').read_bytes()
                    assert data.count(b'_RUNTIME=PASS') == 1 and data.count(b'FINE_COMPARISON') == 6
                    assert data == original.extractfile(name).read()
                    members[name] = data
                    members[name[:-3] + 'err'] = (build / f'o{opt}' / f'configuration-{config}.err').read_bytes()
                    pieces.append(data)
                name = f'highest/{route}/o{opt}/output.txt'
                data = (build / f'o{opt}' / 'output.txt').read_bytes()
                assert data == b''.join(pieces) == original.extractfile(name).read()
                members[name] = data
            assert members[f'highest/{route}/o0/output.txt'] == members[f'highest/{route}/o2/output.txt']
    extra = {'current_source_tree': SOURCE, 'complete_configurations': 24, 'fine_comparisons': 144,
             'original_archive': original_path, 'original_archive_sha256': sha(original_raw),
             'dependency_blobs': dict(sorted(dependencies.items()))}
    receipt = seal('COMPLETE_FROST_QUALIFICATION', members, extra)
    receipt.update(complete_configurations=24, required_configurations=24, partial_only=False,
                   dependency_blob_count=len(dependencies))
    status['frost_successor_evidence'] = receipt


def focused(scratch, status):
    markers = {'dayend-focused-final.log': 'CROP_DAYEND_CURRENT_WINDOW_FINAL_FLUSH_RETRY_RESTART_O0_O2=PASS',
               'dayend-owner.log': 'SW431_CROP_LIFECYCLE_FKT_OWNER_PRESERVATION=PASS',
               'dayend-ppa.log': 'PPA-WU03 COMMON FORCING OWNER QUALIFICATION PASS',
               'dayend-cross.log': 'CROP_FKT_B110_SHARED_OWNER_SCIENTIFIC_SUCCESSOR=PASS'}
    members = checked_logs(scratch, markers, status['observed_terminal_exit_codes'])
    predecessor = ROOT / 'integration/audits/evidence/MC_CROP01_ROOTED_WEATHER_FOCUSED_OWNER_QUALIFICATION_20261011.tar.gz.b64'
    raw = base64.b64decode(predecessor.read_bytes())
    assert sha(raw) == '68655ca085e2f78b70c58ba66d9043307b0bcc385ff9fa4f08e39aa8d22777fe'
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        old = archive.extractfile('rooted-weather-full-oracle.log').read().splitlines()
    new = members['dayend-focused-final.log'].splitlines()
    for prefix in (b'CROP_ROOTED_WEATHER_OWNER_BITS=', b'CROP_ROOTED_WEATHER_POSTIMAGE_BITS='):
        before = [line for line in old if line.startswith(prefix)]
        assert before and before == [line for line in new if line.startswith(prefix)]
    status['focused_evidence'] = seal('FOCUSED_OWNER_QUALIFICATION', members,
                                   {'terminal_markers': markers, 'admitted_morning_full_vectors_unchanged': True})
    status['stages']['tested'] = True


def partial(scratch, status):
    """Persist completed immutable child receipts, never an admission authority."""
    original_path = 'integration/audits/evidence/FROST_NAN_GUARD_QUALIFICATION_20261011.tar.gz.b64'
    original_raw = base64.b64decode((ROOT / original_path).read_bytes())
    assert sha(original_raw) == 'f7b95b481c3d2f389647a52a74ce7f152b2c8dae365a6748d72df92537e5f316'
    members, completed = {}, []
    with tarfile.open(fileobj=io.BytesIO(original_raw)) as original:
        for route in ('normal', 'low-air'):
            build = pathlib.Path('/tmp/ppa-wu05b15-' + route + '-runtime-crop-dayend')
            controller = (scratch / ('dayend-frost-' + route.replace('-', '_') + '.log')).read_bytes()
            members['controllers/' + route + '.log'] = controller
            for opt in (0, 2):
                for config in range(1, 7):
                    path = build / f'o{opt}' / f'configuration-{config}.txt'
                    if not path.exists():
                        continue
                    marker = f'PPA_WU05B15_{route.replace("-", "_").upper()}_O{opt}_CONFIGURATION_{config}_FRESH_PROCESS=PASS'
                    if marker.encode() not in controller:
                        continue
                    name = f'highest/{route}/o{opt}/configuration-{config}.txt'
                    data = path.read_bytes()
                    assert data.count(b'_RUNTIME=PASS') == 1 and data.count(b'FINE_COMPARISON') == 6
                    assert data == original.extractfile(name).read()
                    members[name] = data
                    members[name[:-3] + 'err'] = path.with_suffix('.err').read_bytes()
                    completed.append(name)
    assert completed and len(completed) < 24
    status['partial_frost_evidence'] = seal('PARTIAL_FROST_QUALIFICATION', members,
                                         {'partial_only': True, 'completed_children': completed,
                                          'complete_configurations': len(completed), 'required_configurations': 24,
                                          'original_archive': original_path, 'original_archive_sha256': sha(original_raw)})
    status['partial_frost_evidence'].update(partial_only=True, complete_configurations=len(completed),
                                          required_configurations=24, fine_comparisons=6 * len(completed))


def full(scratch, status):
    markers = {'dayend-full-moving.log': 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS',
               'dayend-ppa-preservation.log': 'PPA-WU03 PRESERVATION GATE PASS'}
    members = {}
    qualified_head = git('rev-parse', 'HEAD')
    for name, marker in markers.items():
        data = (scratch / name).read_bytes()
        assert marker.encode() in data
        control_name = name[:-4] + '.control.json'
        control_data = (scratch / control_name).read_bytes()
        control = json.loads(control_data)
        assert control['terminal_exit_code'] == 0 and control['worktree_clean_at_end']
        assert control['head'] == control['end_head'] == qualified_head
        assert control['source_tree'] == SOURCE
        members[name], members[control_name] = data, control_data
    for key in ('frost_successor_evidence', 'focused_evidence'):
        receipt = status[key]
        assert receipt['source_tree'] == SOURCE
        assert sha(base64.b64decode((ROOT / receipt['path']).read_bytes())) == receipt['decoded_sha256']
    changed = git('diff', '--name-only', status['baseline'], 'HEAD', '--', 'src', 'tests', 'tools', '.github').splitlines()
    blobs = {path: git('rev-parse', 'HEAD:' + path) for path in changed}
    status['full_qualification'] = seal('CURRENT_FULL_QUALIFICATION', members,
                                     {'terminal_markers': markers, 'execution_delta_blobs': blobs,
                                      'focused_owner_authority': status['focused_evidence'],
                                      'complete_frost_authority': status['frost_successor_evidence']})
    status['stages']['qualified'] = status['stages']['preserved'] = True
    status['status'] = 'QUALIFIED_PRESERVED_BOUNDED_DAYEND_PRODUCTION_PENDING_ADMISSION'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=('focused', 'partial', 'frost', 'full'))
    parser.add_argument('--scratch', type=pathlib.Path, required=True)
    args = parser.parse_args()
    assert not git('status', '--porcelain')
    assert git('rev-parse', 'HEAD:src') == SOURCE
    status = json.loads(STATUS.read_text())
    {'focused': focused, 'partial': partial, 'frost': frost, 'full': full}[args.phase](args.scratch, status)
    STATUS.write_text(json.dumps(status, indent=2) + '\n')
    print(json.dumps({'phase': args.phase, 'source_tree': SOURCE, 'status': status['status']}))
