"""Preserve the completed source-bound Grassgrowth proof without rerunning it."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--full', type=Path, required=True)
    p.add_argument('--restarts', type=Path, required=True)
    p.add_argument('--spec', type=Path, required=True)
    p.add_argument('--receipt', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    receipt = json.loads(a.receipt.read_text())
    assert receipt['status'] == 'FULL_ORIGINAL_GRASS_SUBSTEP16_AND_OWN_RESTARTS_PASS'
    spec = json.loads(a.spec.read_text())
    files = {}
    index = {}
    for root, prefix in [(a.bundle, 'bundle'), (a.full, 'full'), (a.restarts, 'restarts')]:
        for path in sorted(root.rglob('*')):
            if path.is_file():
                member = prefix+'/'+path.relative_to(root).as_posix()
                files[member] = path
                index[str(path.resolve())] = member
    release = spec['release']
    pins = release['source_sha256'] | release['object_sha256'] | {
        release['input_library']: release['input_library_sha256']}
    for n, (name, expected) in enumerate(sorted(pins.items())):
        path = Path(name)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, name
        if str(path.resolve()) not in index:
            member = f'bound/{n:03d}/{path.name}'
            files[member] = path
            index[str(path.resolve())] = member
        index[name] = index[str(path.resolve())]
    for parent in sorted({Path(name).parent for name in release['object_sha256']}):
        manifest = parent/'BUILD.json'
        if manifest.exists():
            files[f'compile-provenance/{parent.name}/BUILD.json'] = manifest
    reader_events = Path(release['input_library']).with_name('events.json')
    if reader_events.exists():
        files['compile-provenance/ttutil/events.json'] = reader_events
    files['spec.json'] = a.spec
    files['receipt.json'] = a.receipt
    repo = Path(__file__).resolve().parents[2]
    for relative in ['research/hybrid-water01/qualify_grass_substep16_full.py',
                     'research/hybrid-water01/audit_grass_current.py',
                     'research/hybrid-water01/pack_grass_substep16_full.py',
                     'tests/dataqual15/run_original.py',
                     'tests/dataqual15/restart_snapshot.py',
                     'tests/dataqual15/checkpoint_layout.py']:
        files['verification/'+relative] = repo/relative
    hashes = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()}
    assert not a.output.exists(), 'Never overwrite published evidence'
    with tarfile.open(a.output, 'x:xz', preset=3) as archive:
        for name, path in sorted(files.items()):
            archive.add(path, arcname=name, recursive=False)
        for name, value in [('FILE_INDEX.json', index), ('MEMBER_SHA256.json', hashes)]:
            data = (json.dumps(value, indent=2)+'\n').encode()
            item = tarfile.TarInfo(name)
            item.size = len(data)
            archive.addfile(item, io.BytesIO(data))
    print(json.dumps(dict(archive=str(a.output), bytes=a.output.stat().st_size,
                         sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),
                         retained_files=len(files), original_bound_paths=len(index))))


if __name__ == '__main__':
    main()
