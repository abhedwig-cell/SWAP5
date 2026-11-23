"""Observe real clean14 public/PUB commands and preserve unmodified streams."""
import argparse, hashlib, json, os, subprocess, sys, time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cwd', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--publication', action='store_true')
    args = parser.parse_args()
    root = args.cwd.resolve()
    git = lambda *a: subprocess.check_output(['git', *a], cwd=root, text=True).strip()

    def snapshot():
        sparse = Path(git('rev-parse', '--git-path', 'info/sparse-checkout'))
        if not sparse.is_absolute():
            sparse = root / sparse
        fixtures = root / 'reference/swap-4.3.1/projects'
        files = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in sorted(fixtures.rglob('*')) if p.is_file()}
        return dict(head=git('rev-parse', 'HEAD'), tree=git('rev-parse', 'HEAD^{tree}'),
                    status=git('status', '--porcelain=v1', '--untracked-files=all', '--ignored'),
                    sparse=sparse.read_text().splitlines(), original_project_files=files)

    before = snapshot()
    assert not before['status'] and len(before['sparse']) == 14
    assert len(before['original_project_files']) == 56
    command = [sys.executable, '-B', 'tests/nomacro_drainage/frost_publication_scope.py'
               if args.publication else 'tests/hupsel51/verify_successor.py']
    record = dict(status='RUNNING', command=command, before=before,
                  compiler_executions=0, model_executions=0,
                  read_only_observer_timeout_seconds=3600)
    started = time.perf_counter()
    try:
        with args.output.with_suffix('.stdout.txt').open('xb') as out, args.output.with_suffix('.stderr.txt').open('xb') as err:
            env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONUTF8='1')
            if args.publication:
                env['GITHUB_EVENT_NAME'] = 'pull_request'
            result = subprocess.run(command, cwd=root, env=env, stdout=out, stderr=err, timeout=3600)
        record.update(status='ACTUAL_PUBLIC_COMMAND_RETURNED', returncode=result.returncode)
    except subprocess.TimeoutExpired as error:
        record.update(status='READ_ONLY_OBSERVER_TIMEOUT_NOT_A_SCIENTIFIC_REFUSAL',
                      returncode=None, error=repr(error))
    finally:
        record.update(seconds=time.perf_counter()-started, after=snapshot())
        record['actual_checkout_unchanged'] = record['before'] == record['after']
        with args.output.with_suffix('.json').open('x', encoding='utf8') as stream:
            json.dump(record, stream, indent=2)
            stream.write('\n')
    assert record['actual_checkout_unchanged']
    print(record['status'], record['returncode'], record['seconds'], before['head'], flush=True)


if __name__ == '__main__':
    main()
