"""Seal actual Frost evidence once, including original failures and source bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from groundwater_snow_archive_storage import store_original

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'FROST_DRAINAGE_'


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--work', type=Path, required=True)
    a = p.parse_args(); evidence = a.work / 'evidence'; proof = ROOT / 'integration/f-ci/nomacro-complete01'
    files = {}; builds = set(); sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    def visit(value):
        if isinstance(value, dict):
            if isinstance(value.get('build_root'), str):
                path = Path(value['build_root'])
                if path.is_relative_to(a.work) and path.relative_to(a.work).parts[0].startswith(('frost-divdra-daily-', 'frost-unselected-postimages-')) and (path / 'BUILD.json').is_file():
                    builds.add(path)
            for child in value.values(): visit(child)
        elif isinstance(value, list):
            for child in value: visit(child)
    for item in sorted(evidence.iterdir()):
        if item.is_dir() and item.name.startswith(('frost-',)):
            for file in sorted(item.rglob('*')):
                if file.is_file():
                    assert not file.is_symlink(); files['profiles/' + file.relative_to(evidence).as_posix()] = file
                    if file.name == 'RESULT.json':
                        try: visit(json.loads(file.read_text(encoding='utf-8')))
                        except (ValueError, UnicodeError): pass
        elif item.is_file() and item.name.startswith('FROST_DIVDRA_') and item.suffix.lower() != '.zip':
            files['observations/' + item.name] = item
    for file in sorted(evidence.glob('frost-drainage-controller-source-*.tar')):
        files['observations/' + file.name] = file
    provider = Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
    files['provider-PREPARED.json'] = provider / 'PREPARED.json'
    projection = {}
    for index, bundle in enumerate(sorted(builds)):
        prefix = 'compiled/' + str(index)
        projection[str(bundle)] = dict(prefix=prefix, actual_BUILD_sha256=sha(bundle / 'BUILD.json'))
        for file in sorted(bundle.iterdir()):
            if file.is_file() and (file.name == 'BUILD.json' or file.suffix.lower() in ('.f90', '.exe', '.dll', '.so')):
                files[prefix + '/' + file.name] = file
    # Actual source-refusal inputs are private disposable copies, while these
    # changed bytes and their unchanged BUILD binding are scientific evidence.
    for scratch in sorted(a.work.glob('frost-divdra-daily-*-controls-O?-v1')):
        for target in sorted(scratch.glob('source-*')):
            name = target.name[len('source-'):]
            for file in (target / name, target / 'BUILD.json'):
                assert file.is_file()
                files['control-sources/' + scratch.name + '/' + target.name + '/' + file.name] = file
    assigned = {}
    for name, file in files.items():
        opt = None if name.startswith(('observations/', 'provider-')) else 'O0' if 'O0' in name or name.startswith('compiled/') and 'O0' in str(file) else 'O2' if 'O2' in name or name.startswith('compiled/') and 'O2' in str(file) else None
        assigned[name] = 'SUPPORT' if opt is None else opt + ('_CONTROLS' if 'controls' in name or name.startswith('control-sources/') else '_SCIENCE')
    for group in ('O0_SCIENCE', 'O0_CONTROLS', 'O2_SCIENCE', 'O2_CONTROLS', 'SUPPORT'):
        name = PREFIX + 'WINDOWS_' + group + '_RAW_ARCHIVE.zip'; path = evidence / name
        record = proof / Path(name).with_suffix('.json'); assert not path.exists() and not record.exists()
        members = {}
        with zipfile.ZipFile(path, 'x', compression=zipfile.ZIP_DEFLATED) as z:
            for member, file in sorted(files.items()):
                if assigned[member] != group: continue
                raw = file.read_bytes(); z.writestr(member, raw)
                members[member] = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
            if group == 'SUPPORT':
                raw = (json.dumps(projection, indent=2) + '\n').encode(); member = 'COMPILED_PROJECTION_V1.json'
                z.writestr(member, raw); members[member] = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        with zipfile.ZipFile(path) as z:
            assert set(z.namelist()) == set(members)
            for member, item in members.items():
                raw = z.read(member); assert len(raw) == item['bytes'] and hashlib.sha256(raw).hexdigest() == item['sha256']
        stored = store_original(path, proof, name)
        q = dict(status='ORIGINAL_FROST_WINDOWS_RAW_SEALED_PENDING_ADMISSION', **stored, members=members,
            sealer_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            role='Actual successful and original failed compiler/native/input/output/source roles; component-only implicit derivative evidence grants no implicit model authority',
            canonical_admission=False)
        record.write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
        print(group, q['bytes'], q['sha256'], len(members), flush=True)


if __name__ == '__main__': main()
