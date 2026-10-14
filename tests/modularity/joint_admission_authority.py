"""Exact joint MC-MET01/HY/RT/F-KT eligibility, never a numerical PASS.

The delegated joint admission preserves both owner's exact implementations.
Only the three specified postimages are eligible. Scientific qualification,
preservation and canonical admission remain separate terminal gates.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = 'c591205c5e03f1c96c6488eb53c562265f749556'
PINS = {
    'src/adapter/mod_swap_daily_weather_file_adapter.f90':
        ('44b07cd1046632a38b36e9b1ed5608f67ca41fdd', '8ea1c1551c185112ad3f84db598eff8b823e0aeb'),
    'src/runtime/mod_canonical_contracts.f90':
        ('764483414f037502660d33711693063985064d72', '732cf70f9aeec59bb7dfb136ba4d6e61b918780b'),
    'src/runtime/mod_canonical_interval_runtime.f90':
        ('9d6e931b4cb3562c946aa6c2c0cd1fcb49407490', '770bcd93a2222114c9b1e44a4facac4437b6fe04'),
}


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def blob(raw):
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def validate(old, new, reference, baseline_reference):
    if set(old) != set(PINS) or set(new) != set(PINS):
        raise ValueError('unknown joint source delta')
    for path, (before, after) in PINS.items():
        if blob(old[path]) != before or blob(new[path]) != after:
            raise ValueError('unknown joint preimage/postimage: ' + path)
    if reference != baseline_reference:
        raise ValueError('immutable reference mutation')
    # The new adapter procedure cannot rewrite incumbent weather physics.
    import sys
    sys.path.insert(0, str(ROOT / 'tests/mc-met01'))
    from verify_raintb_legacy_source_eligibility import validate_change
    adapter = 'src/adapter/mod_swap_daily_weather_file_adapter.f90'
    validate_change(old[adapter], new[adapter])
    config = new['src/runtime/mod_canonical_contracts.f90']
    if b'logical :: retain_accepted_step_proposal = .false.' not in config:
        raise ValueError('proposal policy default changed')
    return {'baseline': BASE, 'postimages': {p: pair[1] for p, pair in PINS.items()},
            'claim': 'EXACT_JOINT_SOURCE_ELIGIBLE_SCIENCE_AND_PRESERVATION_REQUIRED',
            'qualified': False, 'admitted': False}


def verify_source():
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    if git('status', '--porcelain', '--', 'src', 'reference'):
        raise ValueError('dirty production/reference')
    changed = git('diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines()
    if changed != sorted(PINS):
        raise ValueError('unknown additional production mutation')
    old = {p: subprocess.check_output(['git', 'show', BASE + ':' + p], cwd=ROOT) for p in PINS}
    new = {p: (ROOT / p).read_bytes() for p in PINS}
    result = validate(old, new, git('rev-parse', 'HEAD:reference'), git('rev-parse', BASE + ':reference'))
    for p, (_, expected) in PINS.items():
        if git('rev-parse', 'HEAD:' + p) != expected:
            raise ValueError('unpersisted joint postimage')
    result['source_tree'] = git('rev-parse', 'HEAD:src')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--negative-controls', action='store_true')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    result = verify_source()
    if args.negative_controls:
        old = {p: subprocess.check_output(['git', 'show', BASE + ':' + p], cwd=ROOT) for p in PINS}
        new = {p: (ROOT / p).read_bytes() for p in PINS}
        reference = git('rev-parse', 'HEAD:reference')
        specimens = []
        for path in PINS:
            specimen = dict(new); specimen[path] += b'\n'
            specimens.append((path, old, specimen, reference))
        specimen = dict(old); specimen[next(iter(PINS))] += b'\n'
        specimens.append(('unknown-baseline', specimen, new, reference))
        specimen = dict(new); specimen['src/solver/unregistered.f90'] = b'! extra'
        specimens.append(('additional-solver', old, specimen, reference))
        specimens.append(('changed-reference', old, new, '0' * 40))
        result['negative_controls'] = {}
        for name, before, after, ref in specimens:
            try:
                validate(before, after, ref, reference)
            except ValueError as error:
                result['negative_controls'][name] = str(error)
            else:
                raise ValueError('unknown successor accepted: ' + name)
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
