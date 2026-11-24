"""Two complementary fresh boundary representatives and targeted native controls."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from analytical_hydraulic_archives import SHA

R = Path(__file__).resolve().parents[2]
P = R / 'integration/f-ci/nomacro-complete01'


def extract(name, target):
    declaration = json.loads((P / (name + '.json')).read_text())
    path = P / declaration['archive']
    assert path.stat().st_size == declaration['bytes'] and SHA(path.read_bytes()) == declaration['sha256']
    with zipfile.ZipFile(path) as z:
        assert len(z.namelist()) == len(set(z.namelist())) == len(declaration['members']) and set(z.namelist()) == set(declaration['members'])
        for name, item in declaration['members'].items():
            raw = z.read(name)
            assert len(raw) == item['bytes'] and SHA(raw) == item['sha256']
            path = (target / name).resolve()
            assert path.is_relative_to(target.resolve()) and not path.exists()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)


def main():
    p = argparse.ArgumentParser()
    for key in ('reference-work', 'build-root', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args()
    a.output.mkdir()
    for name, folder in (('RIA12_BOUNDARY_INPUTS_V1', 'inputs/dry'), ('RIA12_BOUNDARY_WET8_INPUTS_V1', 'inputs/wet'),
                         ('RIA12_NATIVE_CONTROL_ORIGINS_V1', 'origins/legacy'), ('RIA12_BOUNDARY_NATIVE_ORIGINS_V1', 'origins/boundary')):
        extract(name, a.output / folder)
    def run(script, *args):
        subprocess.run([sys.executable, '-B', str(R / 'tests/nomacro_drainage' / script), *map(str, args)], cwd=R, check=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip()
    record = dict(status='RUNNING_RIA_BOUNDARY_NOT_QUALIFIED', actual_source=head, optimization=a.optimization, cases=[])
    def save():
        (a.output / 'BATCH.json').write_text(json.dumps(record, indent=2) + '\n')
    save()
    for kind, relative in (('water', 'dry/water-drain0-bottom5'), ('cde', 'wet/cde-drain1-bottom8')):
        profile = a.output / kind
        run('ria12_boundary_period.py', '--input', a.output / 'inputs' / relative, '--reference-work', a.reference_work,
            '--build-root', a.build_root / kind, '--output', profile, '--optimization', a.optimization)
        sample = a.output / (kind + '-original-samples')
        run('ria12_boundary_reference_samples.py', '--profile', profile, '--reference-work', a.reference_work,
            '--build-root' if kind == 'water' else '--reuse-component', a.build_root / 'original-ria-component', '--output', sample)
        independent = a.output / (kind + '-INDEPENDENT.json')
        run('ria12_boundary_science.py', '--profile', profile, '--reference-samples', sample, '--output', independent)
        postimage = a.output / (kind + '-opposite-initial')
        run('ria12_boundary_postimage.py', '--profile', profile, '--reference-work', a.reference_work,
            '--build-root', a.build_root / (kind + '-opposite'), '--output', postimage, *(['--short-native'] if kind == 'cde' else []))
        record['cases'].append(dict(kind=kind, profile=str(profile), original_samples=str(sample), independent=str(independent), opposite_initial=str(postimage)))
        save()
    for case in record['cases']:
        kind = case['kind']
        other = 'cde' if kind == 'water' else 'water'
        controls = a.output / (kind + '-native-controls')
        run('ria12_boundary_controls.py', '--profile', case['profile'], '--reference-work', a.reference_work,
            '--model1-origin', a.output / 'origins/legacy/model1/accepted-column-1-day-1.zip',
            '--legacy-ria-origin', a.output / 'origins/legacy/legacy-ria/accepted-column-1-day-1.zip',
            '--primary-origin', a.output / ('origins/boundary/primary-' + kind + '/accepted-column-1-day-2.zip'),
            '--foreign-context-origin', a.output / ('origins/boundary/foreign-boundary-' + kind + '/accepted-column-1-day-2.zip'),
            '--other-kind-origin', a.output / other / 'trajectory/accepted-column-1-day-2.zip', '--output', controls)
        transactions = a.output / (kind + '-transactions')
        run('ria12_boundary_transactions.py', '--profile', case['profile'], '--reference-work', a.reference_work, '--output', transactions)
        case.update(native_controls=str(controls), external_transactions=str(transactions))
        save()
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip() == head
    record.update(status='TWO_FRESH_RIA_BOUNDARY35_ORIGINAL_NATIVE_COLD_INITIAL_POSTIMAGES_AND_EXTERNAL_PASS_NOT_ADMITTED', full35_periods=2)
    save()


if __name__ == '__main__':
    main()
