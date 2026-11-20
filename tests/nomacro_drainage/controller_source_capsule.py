"""Preserve exact selected controller bytes without broad partial-clone archive fetches.

The explicit tracked inventory and Git blob identity are checked for every
working-copy file; raw and LF identities remain separate. No proof is replayed.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
PATHS = ('tests/nomacro_drainage', 'tests/nomacro_scheduled_subsurface',
         'tests/nomacro_mixtures', '.github/workflows/nomacro-extended-implicit.yml')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    start = time.monotonic()
    def git(*a):
        return subprocess.check_output(['git', *a], cwd=ROOT)
    if git('status', '--porcelain', '--', *PATHS):
        raise ValueError('Dirty actual controller source surface')
    head = git('rev-parse', 'HEAD').decode().strip()
    entries = git('ls-tree', '-r', head, '--', *PATHS).decode().splitlines()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    record = args.output.with_suffix('.json')
    assert not args.output.exists() and not record.exists()
    members = {}
    def blob(raw):
        return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    with tarfile.open(args.output, 'x') as archive:
        for line in entries:
            header, name = line.split('\t', 1)
            mode, kind, expected = header.split()
            path = ROOT/name
            if kind != 'blob' or mode == '120000' or not path.is_file() or path.is_symlink():
                raise ValueError('Missing/nonregular actual controller source: '+name)
            raw = path.read_bytes()
            normalized = raw.replace(b'\r\n', b'\n')
            if expected not in (blob(raw), blob(normalized)):
                raise ValueError('Actual controller bytes differ from pinned Git: '+name)
            info = tarfile.TarInfo(name)
            info.size = len(raw)
            info.mode = 0o755 if mode == '100755' else 0o644
            archive.addfile(info, io.BytesIO(raw))
            members[name] = dict(git_blob=expected, bytes=len(raw),
                sha256=hashlib.sha256(raw).hexdigest(),
                lf_normalized_sha256=hashlib.sha256(normalized).hexdigest())
    result = dict(status='ACTUAL_SELECTED_CONTROLLER_BYTES_AND_GIT_IDENTITIES_PRESERVED',
                  producer_head=head, archive=args.output.name,
                  sha256=hashlib.sha256(args.output.read_bytes()).hexdigest(),
                  bytes=args.output.stat().st_size, members=members,
                  seconds=time.monotonic()-start, model_executions=0)
    record.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(result['status'], len(members), result['seconds'])


if __name__ == '__main__':
    main()
