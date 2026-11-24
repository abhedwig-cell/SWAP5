"""Fresh four-case RIA heat/Snow batch, actual native and external interfaces."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
from ria12_boundary_batch import extract

R = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser()
    for key in ('reference-work', 'build-root', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args()
    a.output.mkdir()
    for archive, stem in (('RIA12_THERMAL_SNOW_INPUTS_V1', 'inputs'), ('RIA12_NATIVE_CONTROL_ORIGINS_V1', 'origins/legacy'),
                          ('RIA12_BOUNDARY_NATIVE_ORIGINS_V1', 'origins/parent')):
        extract(archive, a.output / stem)
    def run(script, *args):
        subprocess.run([sys.executable, '-B', str(R / 'tests/nomacro_drainage' / script), *map(str, args)], cwd=R, check=True)
    record = dict(status='RUNNING_RIA_THERMAL_SNOW_NOT_QUALIFIED', actual_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R).decode().strip(),
                  optimization=a.optimization, canonical_admission=False, cases=[])
    def save():
        (a.output / 'BATCH.json').write_text(json.dumps(record, indent=2) + '\n')
    save()
    for kind in ('water', 'cde'):
        for snow in (0, 1):
            label=f'{kind}-snow{snow}'
            profile=a.output / label
            run('ria12_thermal_period.py', '--input', a.output / 'inputs' / label, '--reference-work', a.reference_work,
                '--build-root', a.build_root / label, '--output', profile, '--optimization', a.optimization)
            sample=a.output / (label + '-original-samples')
            run('ria12_thermal_reference_samples.py', '--profile', profile, '--reference-work', a.reference_work,
                '--build-root' if not record['cases'] else '--reuse-component', a.build_root / 'original-ria-component', '--output', sample)
            independent=a.output / (label + '-INDEPENDENT.json')
            run('ria12_thermal_science.py', '--profile', profile, '--reference-samples', sample, '--output', independent)
            postimage=a.output / (label + '-opposite-initial')
            run('ria12_thermal_postimage.py', '--profile', profile, '--reference-work', a.reference_work,
                '--build-root', a.build_root / (label + '-opposite'), '--output', postimage, *(['--short-native'] if kind=='cde' else []))
            record['cases'].append(dict(kind=kind, snow=snow, label=label, profile=str(profile), original_samples=str(sample), independent=str(independent), opposite_initial=str(postimage)))
            save()
    for case in record['cases']:
        label=case['label'];kind=case['kind'];snow=case['snow']
        control=a.output / (label + '-controls')
        run('ria12_thermal_controls.py', '--profile', case['profile'], '--reference-work', a.reference_work, '--reference-samples', case['original_samples'],
            '--model1-origin', a.output / 'origins/legacy/model1/accepted-column-1-day-1.zip',
            '--legacy-ria-origin', a.output / 'origins/legacy/legacy-ria/accepted-column-1-day-1.zip',
            '--primary-origin', a.output / f'origins/parent/primary-{kind}/accepted-column-1-day-2.zip',
            '--other-kind-origin', a.output / f"{'cde' if kind=='water' else 'water'}-snow{snow}/trajectory/accepted-column-1-day-2.zip",
            '--foreign-context-origin', a.output / f'{kind}-snow{1-snow}/trajectory/accepted-column-1-day-2.zip', '--output', control)
        case['controls']=str(control)
        if snow or kind=='cde':
            transaction=a.output / (label + '-transactions')
            run('ria12_thermal_transactions.py', '--profile', case['profile'], '--reference-work', a.reference_work, '--current-controls', control, '--output', transaction)
            case['transactions']=str(transaction)
        save()
    record['status']='ACTUAL_FOUR_RIA_THERMAL_SNOW_FULL35_NATIVE_OPPOSITE_INITIAL_AND_EXTERNAL_BATCH_PASS_NOT_ADMITTED'
    save()
    print(record['status'],a.optimization)


if __name__=='__main__':
    main()
