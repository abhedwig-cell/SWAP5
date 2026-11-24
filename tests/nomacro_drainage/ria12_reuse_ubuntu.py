"""Restore immutable completed RIA periods at their real original runner paths."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import zipfile
from analytical_hydraulic_archives import SHA

R = Path(__file__).resolve().parents[2]
P = R / 'integration/f-ci/nomacro-complete01'
PRODUCER = '7283cbba514f5fa2d82d3adde7551d63bff74a26'


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--runner-root', type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    root = a.runner_root.resolve()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip()
    assert not subprocess.check_output(['git', 'diff', PRODUCER, head, '--', 'app', 'src', 'tools', 'reference'], cwd=R)
    observed = {}
    def restore(archive, target_for):
        declaration = json.loads((P / (archive + '.json')).read_text())
        path = P / declaration['archive']
        assert path.stat().st_size == declaration['bytes'] and SHA(path.read_bytes()) == declaration['sha256']
        with zipfile.ZipFile(path) as z:
            assert len(z.namelist()) == len(set(z.namelist())) == len(declaration['members'])
            assert set(z.namelist()) == set(declaration['members'])
            if 'cases' in declaration:
                for case in declaration['cases']:
                    q = json.loads(z.read(case['profile_prefix'] + '/RESULT.json'))
                    # Refuse a different physical runner layout; no path aliases.
                    assert Path(q['build_root']) == root / 'builds' / case['kind'] / 'bundle'
                    assert Path(q['input_root']) == root / 'proof/current/inputs/prepared' / case['kind']
            for name, item in declaration['members'].items():
                raw = z.read(name)
                assert len(raw) == item['bytes'] and SHA(raw) == item['sha256']
                target = target_for(name)
                if target is None:
                    continue
                target = target.resolve()
                assert target.is_relative_to(root) and not target.exists()
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
                if target.name in ('day_donor', 'day_kernel', 'original_ria12_probe') or target.suffix == '.so':
                    target.chmod(target.stat().st_mode | 0o111)
                observed[str(target)] = dict(archive=archive, member=name, bytes=len(raw), sha256=SHA(raw))
    def destination(name):
        if name.startswith('current/'):
            return root / 'proof' / name
        if name.startswith('compiled/'):
            return root / 'builds' / name[len('compiled/'):]
        if name.startswith('original-provider-build/'):
            return root / 'provider/build' / name[len('original-provider-build/'):]
        if name == 'provider-PREPARED.json':
            return root / 'provider/PREPARED.json'
    restore('RIA12_UBUNTU_' + a.optimization + '_ORIGINAL_V1', destination)
    restore('RIA12_NATIVE_CONTROL_ORIGINS_V1', lambda name: root / 'origins' / name)
    for name in ('SWAP.ZIP', 'TTUTIL.ZIP'):
        target = root / 'provider/distribution/SWAP_4.3.1/tools/SWAP/source' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R / 'reference/swap-4.3.1/source-archives' / name, target)
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip() == head
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(dict(status='ORIGINAL_RIA_FULL35_BYTES_RESTORED_AT_UNCHANGED_REAL_PATHS_NO_MODEL_REPLAY',
                                      actual_observer=head, original_producer=PRODUCER, observed_files=observed,
                                      scientific_metadata_or_binding_rewritten=False, compiler_executions=0, model_executions=0), indent=2) + '\n')


if __name__ == '__main__':
    main()
