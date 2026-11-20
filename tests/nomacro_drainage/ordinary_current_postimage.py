"""Current read-only guard on actual qualified ordinary native origins.

Reuse actual numeric bundles without recompilation or repeating full periods.
The original strict physical, complete-native and user-output comparator runs
the current public coupler on every selected cold continuation.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m = original.m


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--reference-work', type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir()
    q = dict(status='RUNNING', current_controller_source=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=original.ROOT, text=True).strip(),
        fresh_compilations=0, repeated_full_periods=0, cases={})
    def save():
        (a.output/'RESULT.json').write_text(json.dumps(q, indent=2)+'\n', encoding='utf-8')
    def run(name, receipt, windows, phase):
        before = m.sha(receipt)
        record = json.loads(receipt.read_text(encoding='utf-8'))
        build, inputs = Path(record['build_root']), Path(record['input_root'])
        build_before = m.sha(build/'BUILD.json')
        project = m.e.load(inputs, original_output=True)
        m.validate_bundle(build, a.reference_work, project)
        warm = receipt.parent/('full/trajectory' if phase == 'full' else 'trajectory')
        data = m.rows(warm)
        out = a.output/name
        out.mkdir()
        item = q['cases'][name] = dict(actual_original_receipt=str(receipt),
            receipt_sha256=before, actual_build_sha256=build_before, build_root=str(build),
            input_root=str(inputs), cold=[])
        save()
        for start, end in windows:
            item['cold'].append(original.previous.own(build, a.reference_work, project,
                warm, data, start, end, out/f'own-{start}'))
            save()
        assert m.sha(receipt) == before and m.sha(build/'BUILD.json') == build_before
        item['original_receipt_and_BUILD_unchanged'] = True
        save()
    save()
    try:
        cohort = json.loads((a.evidence/f'ordinary-pond-matrix-recovered-{a.optimization}-v1/RESULT.json').read_text())
        # Five actual compiler forms: groundwater, water step, CDE nonstep,
        # water nonstep, CDE step. All other selectors keep their actual origin.
        for name in ('water-groundwater', 'water-history1-head', 'cde-plate-history',
                     'water-plate', 'cde-head-history1'):
            item = cohort['cases'][name]
            case = Path(item.get('actual_case_root', a.evidence/f'ordinary-pond-matrix-recovered-{a.optimization}-v1'/name))
            run(name, case/'short/RESULT.json', [(30, 34)], 'short')
        for name, root in (
                ('water-full', f'ordinary-pond-chain-weighted-water-{a.optimization}-qualified-budget-v1'),
                ('cde-full', f'ordinary-pond-cde-groundwater-full-{a.optimization}-v1')):
            run(name, a.evidence/root/'RESULT.json', [(163, 165), (364, 367)], 'full')
        q['status'] = 'ACTUAL_CURRENT_ORDINARY_GUARD_NINE_NATIVE_POSTIMAGES_PASS'
    except Exception as error:
        q.update(status='FAILED', error=repr(error))
        raise
    finally:
        save()
    print(q['status'])


if __name__ == '__main__':
    main()
