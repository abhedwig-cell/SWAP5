"""Lossless S5PT full-source/object/native capsule and independent remeasurement."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess
import tarfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / 'integration/dataqual15_hupsel'
ORIGINAL_BLOBS = {}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def audit(files):
    recovery = json.loads((STORE/'POND_THERMAL_NATIVE_RECOVERY_20261106.json').read_text())
    canonical = ORIGINAL_BLOBS

    def original(name):
        if name not in canonical:
            canonical[name] = subprocess.check_output(['git', 'show', recovery['baseline']+':'+name], cwd=ROOT)
        return canonical[name]

    results = {role: json.loads(files[role+'/RESULT.json']) for role in ('baseline', 'candidate')}
    actual = dict(positive_files=0, malformed_controls=0, baseline_failed_reject_assertions=0, compiler_objects=0)
    for role, result in results.items():
        assert result['role'] == role and result['production_admission'] is False
        assert result['status'] == 'PRIVATE_COMPLETE_COMPOSITION_NATIVE_LOGICAL_MEASUREMENT'
        assert len(result['events']) == 2 and all(e['returncode'] == 0 for e in result['events'])
        for entry in result['positives']:
            key = role+'/'+entry['path'].replace('\\', '/')
            assert digest(files[key]) == entry['sha256']
            blob = files[key]
            assert blob[:8] in (b'S5PT0001', b'S5PT0004')
            assert zlib.crc32(blob[:-4]) == struct.unpack_from('=I', blob, len(blob)-4)[0]
        for recipe in ('base', 'rutter'):
            report = json.loads(files[role+'/'+recipe+'/result.json'])
            assert report['results']['O0'] == report['results']['O2']
            assert report['provider_count'] > 270
            # Map original absolute host paths into the capsule without host filesystem access.
            runner_event = next(e for e in result['events'] if '--black-rutter' in e['command'])
            runner = runner_event['command'][2].replace('\\', '/')
            source_prefix = runner.split('/source/')[0] + '/source/'
            out_prefix = source_prefix[:-len('source/')]

            def mapped(path):
                path = path.replace('\\', '/')
                assert path.startswith(out_prefix), path
                return role+'/'+path[len(out_prefix):]

            for name, expected in report['inputs'].items():
                name = name.replace('\\', '/')
                actual_source = files[role+'/source/'+name]
                assert digest(actual_source) == expected
                expected_source = original(name).replace(b'\r\n', b'\n')
                if name == 'src/adapter/mod_pond_thermal_restart_file.f90' and role == 'candidate':
                    expected_source = (ROOT/recovery['candidate']).read_bytes()
                    assert digest(expected_source) == recovery['candidate_sha256']
                if name == 'tests/nut-sol/run_pond_thermal.py':
                    before = b"run(fc + flags + objects + ['-o', exe], build, 'link')"
                    after = b"run(fc + flags + objects + (['-Wl,--stack,67108864'] if os.name == 'nt' else []) + ['-o', exe], build, 'link')"
                    assert expected_source.count(before) == 1
                    expected_source = expected_source.replace(before, after)
                assert actual_source.replace(b'\r\n', b'\n') == expected_source, 'source authority drift: '+name
            events = report['events']
            assert all(e['returncode'] == 0 for e in events)
            compiles = [e for e in events if e['category'] in ('compile', 'compile-publication')]
            links = [e for e in events if e['category'] == 'link']
            assert len(links) == 2
            for event in compiles:
                cmd = event['command']; src = mapped(cmd[cmd.index('-c')+1]); obj = mapped(cmd[cmd.index('-o')+1])
                assert files[src] and files[obj]
                actual['compiler_objects'] += 1
            for link in links:
                command = link['command']; members = [p for p in command if p.endswith('.o')]
                assert len(members) == report['provider_count']+2
                assert any(p.endswith('restart_publish.o') for p in members)
                for member in members:
                    assert files[mapped(member)]
                assert files[mapped(command[-1])]
    left = {e['path'].replace('\\', '/'): e['sha256'] for e in results['baseline']['positives']}
    right = {e['path'].replace('\\', '/'): e['sha256'] for e in results['candidate']['positives']}
    assert left == right and left, 'proper native generations changed'
    actual['positive_files'] = len(left)
    baseline = results['baseline']['malformed']; candidate = results['candidate']['malformed']
    assert len(baseline) == len(candidate) == 48
    for old, new in zip(baseline, candidate):
        for field in ('recipe', 'optimization', 'field', 'word'):
            assert old[field] == new[field]
        assert new['rejected'] is True and new['event']['returncode'] == 0
        actual['malformed_controls'] += 1
        actual['baseline_failed_reject_assertions'] += old['event']['returncode'] != 0
        for role, entry in [('baseline', old), ('candidate', new)]:
            label = entry['field']+'-'+str(entry['word'])
            parent = role+'/'+entry['recipe']+'/'+entry['optimization']+'/logical-controls/'
            blob = files[parent+label+'.bin']
            assert zlib.crc32(blob[:-4]) == struct.unpack_from('=I', blob, len(blob)-4)[0]
            original = files[role+'/'+entry['recipe']+'/'+entry['optimization']+'/2/restart.bin']
            assert len(blob) == len(original)
            n, _, _, count = struct.unpack_from('=iiqi', original, 148)
            params = 168+8*count+8*(3*n+2)+8+12+12+44
            offsets = dict(time_bound=144, history=152, rutter_bound=params, irrigation_intercepted=params+52)
            offset = offsets[entry['field']]
            assert struct.unpack_from('=i', blob, offset)[0] == entry['word']
            assert blob[:offset] == original[:offset] and blob[offset+4:-4] == original[offset+4:-4]
            stdout = files[parent+entry['event']['stdout']]
            stderr = files[parent+entry['event']['stderr']]
            if role == 'candidate':
                assert b'THERMAL_INVALID_RESTART=PASS' in stdout
            elif entry['event']['returncode'] != 0:
                assert b'invalid generation atomic reject' in stdout+stderr, 'unclassified original failure'
    return actual


def pack(source, stem):
    files = {}
    for role in ('baseline', 'candidate'):
        for path in sorted((source/role).rglob('*')):
            if path.is_file() and path.name != '.git':
                files[path.relative_to(source).as_posix()] = path.read_bytes()
    result = audit(files)
    manifest = dict(status='PRIVATE_NATIVE_LOGICAL_CAPSULE_REMEASURED', remeasurement=result,
                    production_admission=False, members={p:digest(b) for p,b in files.items()}, parts=[])
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w:xz') as tar:
        for name, blob in files.items():
            info = tarfile.TarInfo(name); info.size = len(blob); tar.addfile(info, io.BytesIO(blob))
    raw = buffer.getvalue()
    for offset in range(0, len(raw), 40*1024*1024):
        name = stem+f'.tar.xz.part{len(manifest["parts"]):02d}'
        blob = raw[offset:offset+40*1024*1024]; (STORE/name).write_bytes(blob)
        manifest['parts'].append(dict(path=name, sha256=digest(blob), size=len(blob)))
    (STORE/(stem+'.json')).write_text(json.dumps(manifest, indent=2)+'\n')
    return manifest


def verify(stem, self_test=False):
    manifest = json.loads((STORE/(stem+'.json')).read_text()); chunks=[]
    for part in manifest['parts']:
        raw = (STORE/part['path']).read_bytes()
        assert digest(raw) == part['sha256'] and len(raw) == part['size']; chunks.append(raw)
    with tarfile.open(fileobj=io.BytesIO(b''.join(chunks)), mode='r:xz') as tar:
        files = {member.name:tar.extractfile(member).read() for member in tar.getmembers()}
    assert {p:digest(b) for p,b in files.items()} == manifest['members']
    assert audit(files) == manifest['remeasurement']
    if self_test:
        selected = [
            'candidate/source/src/adapter/mod_pond_thermal_restart_file.f90',
            next(p for p in files if p.startswith('candidate/base/O0/') and p.endswith('.o')),
            'candidate/rutter/O2/logical-controls/rutter_bound-2.bin',
            'candidate/base/O0/logical-controls/history-2.stdout',
            'candidate/base/O0/2/restart.bin',
        ]
        for path in selected:
            blob = files[path]
            files[path] = b'' if path.endswith('.o') else b'corrupt'
            try:
                audit(files)
            except (AssertionError, KeyError, ValueError, struct.error):
                pass
            else:
                raise AssertionError('evidence mutation accepted: '+path)
            finally:
                files[path] = blob
    return manifest['remeasurement']


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--pack',type=Path)
    p.add_argument('--stem',default='POND_THERMAL_NATIVE_WINDOWS_20261106'); p.add_argument('--self-test',action='store_true'); a=p.parse_args()
    if a.pack: pack(a.pack, a.stem)
    print(json.dumps(verify(a.stem, a.self_test), sort_keys=True))
