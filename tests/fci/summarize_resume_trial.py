#!/usr/bin/env python3
"""Recompute bounded full-trial measurements from original controls and logs."""
import argparse
import hashlib
import hmac
import json
from pathlib import Path
import re

from compare_resume_trial import compare


def summarize(directory, key=None):
    controls = {}
    for name in ['baseline', 'interrupted', 'resumed']:
        control = json.loads((directory / (name + '.control.json')).read_text())
        expected = 1 if name == 'interrupted' else 0
        assert control['terminal_exit_code'] == expected
        assert control['terminal_status'] == ('FAIL' if expected else 'PASS')
        assert control['executed_head'] == control['end_head']
        for stream in ['stdout', 'stderr']:
            data = (directory / (name + '.' + stream)).read_bytes()
            assert hashlib.sha256(data).hexdigest() == control[stream + '_sha256']
        controls[name] = control
    assert len({c['executed_head'] for c in controls.values()}) == 1
    assert [controls[n]['mode'] for n in controls] == ['OFF', 'SHADOW', 'RESUME']
    comparison = compare(directory)
    assert comparison['qualification_pass']

    def events(name, kind):
        prefix = 'FCI_RESUME_' + kind + ' '
        return [json.loads(line[len(prefix):]) for line in
                (directory / (name + '.stdout')).read_text().splitlines()
                if line.startswith(prefix)]

    executed = events('interrupted', 'EXECUTED')
    inherited = events('resumed', 'DECISION')
    groups = ['frost-invalid', 'frost-independent']
    assert [e['group'] for e in executed] == groups
    assert [e['group'] for e in inherited] == groups
    assert all(e['decision'] == 'INHERIT' for e in inherited)
    assert events('resumed', 'EXECUTED') == []
    receipt_checks = []
    for group in groups:
        envelope = json.loads((directory / 'receipts' / (group + '.json')).read_text())
        record = envelope['record']
        assert record['status'] == 'PASS' and record['exit_code'] == 0
        assert record['started_utc'] and record['ended_utc']
        assert record['input'] == record['end_input']
        assert record['required_outputs'] == [] and record['shared_state'] is False
        assert record['private_cwd_removed'] is True
        assert record['executed_head'] == controls['baseline']['executed_head']
        log = (directory / 'receipts' / (group + '.log')).read_bytes()
        assert len(log) == record['log_bytes']
        assert hashlib.sha256(log).hexdigest() == record['log_sha256']
        assert record['input']['marker'].encode() in log.splitlines()
        authenticated = 'UNKNOWN_PRIVATE_KEY_NOT_SUPPLIED'
        if key is not None:
            encoded = json.dumps(record, sort_keys=True, separators=(',', ':'),
                                 ensure_ascii=True).encode()
            assert hmac.compare_digest(hmac.new(key, encoded, hashlib.sha256).hexdigest(),
                                       envelope['hmac_sha256'])
            authenticated = True
        receipt_checks.append({'group': group, 'log_sha256': record['log_sha256'],
                               'hmac_verified': authenticated,
                               'input_sha256': hashlib.sha256(json.dumps(record['input'],
                                   sort_keys=True, separators=(',', ':')).encode()).hexdigest()})

    calls = {}
    for name in ['baseline', 'resumed']:
        calls[name] = re.findall(r'^\+ ((?:bash|python3) tests/[^\n]+)$',
                                 (directory / (name + '.stderr')).read_text(), re.M)
    leaves = ['bash tests/frost/run_frost_invalid_input_preservation.sh',
              'bash tests/frost/run_frost_nan_guard_independent.sh']
    assert all(calls['baseline'].count(leaf) == 1 for leaf in leaves)
    assert calls['resumed'] == [c for c in calls['baseline'] if c not in leaves]
    verifiers = sum(c.startswith('python3 ') or c.endswith(' --verify-only')
                    for c in calls['baseline'])
    return {
        'schema': 'swap5.fci.resume-measurements.v1',
        'actual_execution_head': controls['baseline']['executed_head'],
        'baseline_calendar_seconds': controls['baseline']['wall_seconds'],
        'resumed_calendar_seconds': controls['resumed']['wall_seconds'],
        'controlled_prefix_seconds': controls['interrupted']['wall_seconds'],
        'observed_calendar_baseline_minus_resume_seconds':
            controls['baseline']['wall_seconds'] - controls['resumed']['wall_seconds'],
        'calendar_difference_is_not_causal_saved_work': True,
        'scientific_group_wall_actually_avoided_seconds': sum(e['wall_seconds'] for e in executed),
        'scientific_compile_link_invocations_avoided': sum(e['compilations'] for e in executed),
        'scientific_compile_link_invocations_repeated_in_inherited_groups': 0,
        'checkpoint_receipt_write_seconds': sum(e['checkpoint_write_seconds'] for e in executed),
        'initial_input_verification_seconds': sum(e['verification_seconds'] for e in executed),
        'post_run_input_revalidation_seconds': sum(e['end_input_verification_seconds'] for e in executed),
        'evidence_and_input_verification_seconds_on_resume': sum(e['verification_seconds'] for e in inherited),
        'recovery_execution_seconds': controls['resumed']['wall_seconds'],
        'recovery_setup_cpu_seconds': 'UNKNOWN_NOT_SEPARATELY_INSTRUMENTED',
        'pure_cpu_compilation_seconds_saved': 'UNKNOWN',
        'unqualified_groups_compilation_total': 'UNKNOWN_NOT_INSTRUMENTED',
        'filesystem_cache_and_host_load_contribution': 'UNKNOWN',
        'build_object_cache_enabled_by_this_mechanism': False,
        'repeat_experiment_count_same_functional_candidate': 1,
        'top_level_original_calls': {n: len(c) for n, c in calls.items()},
        'scientific_top_level_invocations': {n: len(c) - verifiers for n, c in calls.items()},
        'pure_verifier_calls_per_run': verifiers,
        'inherited_groups': groups,
        'all_other_original_top_level_calls_same_sequence': True,
        'executed_group_measurements': executed,
        'inherited_group_decisions': inherited,
        'receipt_checks': receipt_checks,
        'comparison': comparison,
        'controls': controls,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--key', type=Path, help='optional private key; never emitted')
    args = parser.parse_args()
    print(json.dumps(summarize(args.directory, args.key.read_bytes() if args.key else None), indent=2))
