"""Decode retained original ordinary Actions ZIPs without executing models.

The ZIP is never repacked and producer paths/receipts are never rebound. Explicit
compiled projections locate the same actual bytes on the auditing machine.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import zipfile

from ordinary_pond_evidence import audit_root, audit_short, digest, read, require


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--artifacts', type=Path, required=True)
    p.add_argument('--artifact-id', type=int, required=True)
    p.add_argument('--extract', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    entries = read(args.artifacts)['artifacts']
    actual = next(a for a in entries if a['id'] == args.artifact_id)
    require(args.archive.stat().st_size == actual['size_in_bytes'] and
            'sha256:'+digest(args.archive) == actual['digest'], 'Original GitHub ZIP identity differs')
    require(not args.output.exists(), 'Refuse overwriting archive observation')
    # Windows long member names retain their original archive spelling. Resume
    # partial extraction only when every existing byte matches this same ZIP.
    if os.name == 'nt':
        args.extract = Path('\\\\?\\'+str(args.extract.resolve()))
    members = {}
    with zipfile.ZipFile(args.archive) as z:
        require(z.testzip() is None, 'Original archive CRC failure')
        for item in z.infolist():
            path = PurePosixPath(item.filename)
            require(not path.is_absolute() and '..' not in path.parts and
                    '\\' not in item.filename and ':' not in item.filename and
                    not stat.S_ISLNK(item.external_attr >> 16), 'Unsafe original archive member')
            require(item.filename not in members, 'Duplicate original archive member')
            raw = z.read(item)
            members[item.filename] = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
        args.extract.mkdir(exist_ok=True)
        for item in z.infolist():
            target = args.extract.joinpath(*PurePosixPath(item.filename).parts)
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                require(digest(target) == members[item.filename]['sha256'], 'Existing extraction differs')
            else:
                with target.open('xb') as stream:
                    stream.write(z.read(item))
    root = args.extract
    projection = read(root/'COMPILED_PROJECTION_V1.json')
    def bundle(q):
        projected = projection[q['build_root']]
        result = root/projected['archive_prefix']
        require(digest(result/'BUILD.json') == projected['actual_BUILD_sha256'], 'Compiled projection differs')
        return result
    matrix = root/'ordinary-matrix'
    cases = read(matrix/'RESULT.json')['cases']
    shorts = {}
    for name in cases:
        case = matrix/name
        q = read(case/'short/RESULT.json')
        shorts[name] = audit_short(case, bundle(q), case/'input')
    fulls = {}
    for name in ('ordinary-water', 'ordinary-cde'):
        if (root/name/'RESULT.json').is_file():
            q = read(root/name/'RESULT.json')
            inputs = root/name/'input'
            if not inputs.exists():
                inputs = matrix/'cde-groundwater-history/input'
            fulls[name] = audit_root(root/name, bundle(q), inputs)
    result = dict(status='ORIGINAL_UBUNTU_ORDINARY_ARCHIVE_INDEPENDENT_PASS',
                  original_archive=args.archive.name, sha256=digest(args.archive),
                  original_artifact=actual, members=members, full=fulls, short=shorts,
                  functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED')
    args.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(status=result['status'], full=list(fulls), short=list(shorts), members=len(members))))


if __name__ == '__main__':
    main()
