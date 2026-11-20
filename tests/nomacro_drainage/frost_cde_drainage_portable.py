"""One coherent actual Frost SWDIVD1 component, model and control campaign."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'scratch', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); a.output.mkdir(); a.build_root.mkdir(parents=True)
    logs = a.output / 'commands'; logs.mkdir()
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        optimization=a.optimization, steps=[], canonical_admission=False)
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    def run(label, script, arguments, cap):
        command = [sys.executable, '-B', str(HERE / script), *map(str, arguments)]
        step = dict(label=label, command=command, status='RUNNING'); q['steps'].append(step); save()
        start = time.perf_counter()
        try:
            with (logs / (label + '.stdout')).open('x') as out, (logs / (label + '.stderr')).open('x') as err:
                result = subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, timeout=cap)
            step['returncode'] = result.returncode; result.check_returncode(); step['status'] = 'PASS'
        except Exception as error:
            step.update(status='FAILED_OR_CENSORED', error=repr(error)); raise
        finally: step['seconds'] = time.perf_counter()-start; save()
    common = ['--reference-work', a.reference_work]
    try:
        for label, script in [('overlap', 'frost_cde_drainage_overlap_component.py'),
                              ('rates', 'frost_cde_drainage_rates_component.py'),
                              ('cde', 'frost_cde_drainage_cde_component.py')]:
            run(label, script, [*common, '--build-root', a.build_root / label,
                '--output', a.output / label, '--optimization', a.optimization,
                *(['--correct-divdra-overlap'] if label == 'rates' else [])], 180)
        run('independent-component', 'frost_cde_drainage_component_forensics.py', [*common,
            '--evidence', a.output, '--component', a.output / 'cde', '--optimization', a.optimization,
            '--output', a.output / 'INDEPENDENT_COMPONENT_V1.json'], 60)
        for kind in ('water', 'cde'):
            build = a.build_root / kind
            short = a.output / (kind + '-short'); full = a.output / (kind + '-full')
            run(kind + '-short', 'frost_cde_drainage_runtime.py', [*common, '--kind', kind,
                '--optimization', a.optimization, '--build-root', build, '--output', short], 300)
            run(kind + '-full', 'frost_cde_drainage_runtime.py', [*common, '--kind', kind,
                '--optimization', a.optimization, '--build-root', build, '--reuse-build', build / 'bundle',
                '--existing-input', short / 'input', '--phase', 'full', '--output', full], 300)
            for phase, profile in [('short', short), ('full', full)]:
                run(kind + '-' + phase + '-independent', 'frost_cde_drainage_model_forensics.py',
                    [*common, '--profile', profile, '--output', a.output / (kind + '-' + phase + '-INDEPENDENT_V1.json')], 60)
            run(kind + '-controls', 'frost_cde_drainage_controls.py', [*common, '--profile', short,
                '--scratch', a.scratch / kind, '--output', a.output / (kind + '-controls')], 300)
        q['status'] = 'ACTUAL_PORTABLE_FROST_SWDIVD1_COMPONENTS_DAILY_MODELS_AND_CONTROLS_PASS_NOT_ADMITTED'
        print(q['status'], flush=True)
    except Exception as error:
        q.update(status='FAILED_OR_CENSORED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
