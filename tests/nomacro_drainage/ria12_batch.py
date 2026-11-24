"""Fresh RIA12 platform periods; independent original reader and short postimages."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
P = R / 'integration/f-ci/nomacro-complete01'
SHA = lambda b: hashlib.sha256(b).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    for name in ('reference-work', 'build-root', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    args = parser.parse_args()
    args.output.mkdir()
    inputs = args.output / 'inputs'
    declaration = json.loads((P / 'RIA12_INPUTS_V1.json').read_text())
    raw = (P / declaration['archive']).read_bytes()
    assert len(raw) == declaration['bytes'] and SHA(raw) == declaration['sha256']
    with zipfile.ZipFile(P / declaration['archive']) as z:
        assert set(z.namelist()) == set(declaration['members'])
        for name, item in declaration['members'].items():
            data = z.read(name)
            assert len(data) == item['bytes'] and SHA(data) == item['sha256']
            target = inputs / name
            assert target.resolve().is_relative_to(inputs.resolve())
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip()
    record = dict(status='RUNNING_NOT_QUALIFIED', actual_source=head, optimization=args.optimization, cases=[])
    def save():
        (args.output / 'BATCH.json').write_text(json.dumps(record, indent=2) + '\n')
    def run(script, *arguments):
        subprocess.run([sys.executable, '-B', str(R / 'tests/nomacro_drainage' / script), *map(str, arguments)], cwd=R, check=True)
    save()
    for kind in ('water', 'cde'):
        profile = args.output / kind
        run('ria12_period.py', '--input', inputs / 'prepared' / kind, '--reference-work', args.reference_work,
            '--build-root', args.build_root / kind, '--output', profile, '--optimization', args.optimization)
        sample = args.output / (kind + '-original-samples')
        component = args.build_root / 'original-ria-component'
        option = '--build-root' if kind == 'water' else '--reuse-component'
        run('ria12_reference_samples.py', '--profile', profile, '--reference-work', args.reference_work,
            option, component, '--output', sample)
        independent = args.output / (kind + '-INDEPENDENT.json')
        run('ria12_science.py', '--profile', profile, '--reference-samples', sample, '--output', independent)
        postimage = args.output / (kind + '-opposite-initial')
        short = ['--short-native'] if kind == 'cde' else []
        run('ria12_postimage.py', '--profile', profile, '--reference-work', args.reference_work,
            '--build-root', args.build_root / (kind + '-opposite'), '--output', postimage, *short)
        record['cases'].append(dict(kind=kind, profile=str(profile), original_samples=str(sample), independent=str(independent), opposite_initial=str(postimage)))
        save()
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip() == head
    record.update(status='RIA12_TWO_FRESH_FULL35_ORIGINAL_SCIENCE_NATIVE_COLD_AND_OPPOSITE_INITIAL_PASS_NOT_ADMITTED', full35_periods=2)
    save()


if __name__ == '__main__':
    main()
