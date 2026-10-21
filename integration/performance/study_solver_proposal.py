#!/usr/bin/env python3
"""Diagnostic generated-runtime experiment; never edits production providers.

Reuse the registered temporal study's actual driver, observations and assertions.
Recompile its generated runtime and relink for one explicitly named hypothesis.
All policies retain the diagnostic exact-endpoint targeting correction.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROVIDER = ROOT / 'tools/performance/study_perf01_temporal.py'
REGISTERED_SHA = '1b0fed6a387b42da90afb9831b031ea1f93e32ef0804c571bbfc31284c3cecb5'


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--solver-policy', choices=['cap', 'ceiling', 'recover', 'fallback'], required=True)
    option, remaining = parser.parse_known_args()
    if hashlib.sha256(PROVIDER.read_bytes()).hexdigest() != REGISTERED_SHA:
        raise ValueError('registered diagnostic provider changed')
    spec = importlib.util.spec_from_file_location('temporal', PROVIDER)
    study = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(study)
    original_build = study.build_main

    def build(base, manifest, out, proposal, snap_endpoint):
        record = original_build(base, manifest, out, proposal, True)
        # Off is the unmodified production policy with identical instrumentation.
        if not proposal:
            return record
        runtime = out / 'mod_canonical_interval_runtime.f90'
        text = runtime.read_text()
        replace = study.replace_once
        if option.solver_policy == 'fallback':
            text = replace(text, '    integer :: isub, max_retries_cap',
                           '    logical :: solver_limited\n    integer :: isub, max_retries_cap')
            text = replace(text, '    proposed_dt = 0.0_real64',
                           '    proposed_dt = 0.0_real64\n    solver_limited = .false.')
            needle = '      if (config%retain_accepted_step_proposal .and. (proposal_active .or. tx%temporal_rejections > 0)) then'
            text = replace(text, needle, '''      ! Diagnostic policy memory is private to this requested interval.
      solver_limited = solver_limited .or. tx%solver_rejections > 0
      if (solver_limited) proposal_active = .false.
      if (config%retain_accepted_step_proposal .and. .not. solver_limited .and. &
          (proposal_active .or. tx%temporal_rejections > 0)) then''')
        elif option.solver_policy != 'cap':
            text = replace(text, '    integer :: isub, max_retries_cap',
                           '    real(real64) :: solver_ceiling\n'
                           '    integer :: solver_successes\n    integer :: isub, max_retries_cap')
            text = replace(text, '    proposed_dt = 0.0_real64',
                           '    proposed_dt = 0.0_real64\n'
                           '    solver_ceiling = huge(1.0_real64)\n    solver_successes = 0')
        needle = '        proposed_dt = tx%accepted_dt * proposal_factor'
        if option.solver_policy == 'fallback':
            patch = ''
        elif option.solver_policy == 'cap':
            patch = '''        if (tx%solver_rejections > 0) proposal_factor = min(proposal_factor, 1.0_real64)
'''
        else:
            patch = '''        if (tx%solver_rejections > 0) then
          solver_ceiling = min(solver_ceiling, tx%accepted_dt)
          solver_successes = 0
        else
          solver_successes = solver_successes + 1
        end if
'''
            if option.solver_policy == 'recover':
                patch += '''        if (solver_successes >= 8 .and. solver_ceiling < huge(1.0_real64)/2.0_real64) then
          solver_ceiling = 1.25_real64 * solver_ceiling
          solver_successes = 0
        end if
'''
        text = replace(text, needle, patch + needle)
        if option.solver_policy in ['ceiling', 'recover']:
            text = replace(text, needle, needle + '\n        proposed_dt = min(proposed_dt, solver_ceiling)')
        runtime.write_text(text)
        commands = [record['commands'][0], record['commands'][-1]]
        with (out / 'solver-build.log').open('w') as log:
            for command in commands:
                subprocess.run(command, stdout=log, stderr=log, check=True)
        record.update(solver_policy=option.solver_policy,
                      runtime_sha256=study.sha(runtime), executable_sha256=study.sha(out/'column'),
                      diagnostic_initial_build=record['commands'], solver_rebuild_commands=commands)
        record['object_sha256'][str(out/'runtime.o')] = study.sha(out/'runtime.o')
        return record

    study.build_main = build
    sys.argv = [str(PROVIDER), *remaining, '--snap-proposal-endpoint']
    output = Path(remaining[remaining.index('--output')+1]).resolve()
    try:
        study.main()
    finally:
        # Preserve driver identity even when native execution fails.
        if output.exists():
            (output/'solver-driver.py').write_bytes(Path(__file__).read_bytes())
            if (output/'CONTROL.json').exists():
                control = json.loads((output/'CONTROL.json').read_text())
                control['solver_policy'] = option.solver_policy
                control['solver_driver_sha256'] = study.sha(output/'solver-driver.py')
                (output/'CONTROL.json').write_text(json.dumps(control, indent=2)+'\n')


if __name__ == '__main__':
    main()
