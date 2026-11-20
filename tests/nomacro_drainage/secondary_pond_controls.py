"""Reject actual foreign secondary pond source/policy before a worker starts."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import subprocess

import calendar_runtime as runtime
m = runtime.m


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('profile', 'reference-work', 'output'):
        p.add_argument('--'+key, type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir()
    q = json.loads((a.profile/'RESULT.json').read_text())
    original = Path(q['build_root'])
    project = m.e.load(a.profile/'input', original_output=True)
    meta, _ = m.validate_bundle(original, a.reference_work, project)
    result = dict(status='RUNNING', source=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=runtime.ROOT, text=True).strip(),
        actual_build_sha256=m.sha(original/'BUILD.json'), refusals=[])
    for field in ('zero_pond_switch_renderer_sha256', 'zero_pond_reference_correction',
                  'original_positive_head_deadband_preserved', 'actual-boundtop-deadband',
                  'actual-boundtop-unrelated'):
        target = a.output/field
        target.mkdir()
        for path in original.iterdir():
            if path.name == 'BUILD.json' or path.suffix.lower() in ('.f90', '.dll', '.so'):
                shutil.copyfile(path, target/path.name)
        if field.startswith('actual-boundtop'):
            path = target/'boundtop.f90'
            text = path.read_text(encoding='cp1252')
            if field.endswith('deadband'):
                assert text.count('if (h0 <= 0.0d0) then') == 1
                text = text.replace('if (h0 <= 0.0d0) then', 'if (h0 <= 1.0d-6) then', 1)
            else:
                text += '\n! deliberately foreign actual boundary source\n'
            path.write_text(text, encoding='cp1252')
            expected = 'Foreign actual secondary implicit zero-pond boundary provider'
        else:
            bad = copy.deepcopy(meta)
            for identity in (bad['identity'], bad['binding']['build']):
                identity['extended_drainage'][field] = 'foreign'
            (target/'BUILD.json').write_text(json.dumps(bad, indent=2))
            expected = 'Foreign extended drain state policy'
        try:
            m.validate_bundle(target, a.reference_work, project)
        except ValueError as error:
            assert expected in str(error), str(error)
            assert not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
            result['refusals'].append(dict(field=field, error=str(error), expected=expected,
                                           before_worker=True, no_publication=True))
        else:
            raise AssertionError('Foreign secondary pond source/policy accepted: '+field)
        (a.output/'RESULT.json').write_text(json.dumps(result, indent=2))
    result['status'] = 'ACTUAL_FIVE_SECONDARY_SOURCE_AND_POLICY_REFUSALS_BEFORE_WORKER_PASS'
    (a.output/'RESULT.json').write_text(json.dumps(result, indent=2))
    print(result['status'])


if __name__ == '__main__':
    main()
