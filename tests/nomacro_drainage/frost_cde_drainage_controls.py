"""Reuse exact thermal compiled readers and test transactions during actual Frost."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/nomacro_scheduled_subsurface'))
import output_thermal_controls as inherited
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from original_output_baseline import assignment


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'profile', 'scratch', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    args = p.parse_args(); args.output.mkdir(); args.scratch.mkdir(parents=True, exist_ok=True)
    original = args.profile / 'RESULT.json'; m = inherited.m
    digest = m.sha(original); profile = json.loads(original.read_text(encoding='utf-8'))
    inputs = Path(profile['input_root']); build = Path(profile['build_root'])
    project = m.e.load(inputs, original_output=True, time_step_policy='original-adaptive-event-closure-v1')
    meta, _ = m.validate_bundle(build, args.reference_work, project)
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        actual_profile_sha256=digest, actual_BUILD_sha256=m.sha(build / 'BUILD.json'),
        native_refusals=[], transactions={}, descriptor_refusals=[], source_refusals=[])
    def save(): (args.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        full = args.profile / 'trajectory'
        q['native_refusals'] = inherited.native(build, args.reference_work, project, full, args.output / 'native')
        assert len(q['native_refusals']) == (44 if project.solute else 39)
        save()
        data = m.rows(full); source = full / 'accepted-column-1-day-19.zip'; before = m.sha(source)
        column = CoupledDailyColumn(build, args.reference_work, args.output / 'external', project,
            'original-output', origin=source, day=19, adopt_native=True)
        trial = column.prepare(); assert physical(trial) == m.physical([data[19]])
        column.discard(trial); assert column.day == 19
        replay = column.prepare(); assert replay.budget == trial.budget
        column.accept(replay); assert column.day == 20
        recovered = CoupledDailyColumn(build, args.reference_work, args.output / 'recovered', project,
            'original-output', origin=column.checkpoint, day=20)
        endpoint = recovered.prepare(); assert physical(endpoint) == m.physical([data[20]])
        recovered.discard(endpoint); assert m.sha(source) == before
        q['transactions'] = dict(discard_no_day_advance=True, replay_exact=True, accept_exact=True,
            recovered_next_day_exact=True, origin_unchanged=True, start_day=19)
        save()
        faults = [('implicit', 'SWKIMPL', 1), ('aquifer', 'SWBR', 1), ('age', 'SWSOLU', 2),
            ('other-bottom', 'SWBOTB', 5), ('interval', 'NPRINTDAY', 2), ('other-hysteresis', 'SWHYST', 0)]
        for label, key, value in faults:
            target = args.scratch / ('input-' + label); shutil.copytree(inputs, target)
            path = target / 'swap.swp'; path.write_text(assignment(path.read_text(encoding='cp1252'), key, value), encoding='cp1252')
            try:
                candidate = m.e.load(target, original_output=True, time_step_policy='original-adaptive-event-closure-v1')
                inherited.metadata(candidate)
            except ValueError as error:
                q['descriptor_refusals'].append(dict(attack=label, status='REFUSED', error=str(error)))
            else: raise AssertionError('Unqualified Frost composition accepted: ' + label)
        if project.solute:
            target = args.scratch / 'input-original-invalid-divd0'; shutil.copytree(inputs, target)
            path = target / 'swap.dra'; path.write_text(assignment(path.read_text(encoding='cp1252'), 'SWDIVD', 0), encoding='cp1252')
            try: m.e.load(target, original_output=True, time_step_policy='original-adaptive-event-closure-v1')
            except ValueError as error:
                assert 'SWDIVD0' in str(error)
                q['descriptor_refusals'].append(dict(attack='original-invalid-divd0', status='REFUSED', error=str(error)))
            else: raise AssertionError('Original invalid CDE drainage accepted')
        helpers = ['divdra.f90', 'frozencond.f90', 'timecontrol.f90', 'integral.f90']
        if project.solute: helpers += ['solute.f90', 'original_cde_output_state.f90']
        for helper in helpers:
            target = args.scratch / ('source-' + helper); shutil.copytree(build, target)
            m.validate_bundle(target, args.reference_work, project)
            path = target / helper; path.write_bytes(path.read_bytes() + b'\n! foreign actual Frost composition source\n')
            try: m.validate_bundle(target, args.reference_work, project)
            except ValueError as error:
                assert 'Foreign' in str(error) or 'Generated donor differs:' in str(error), str(error)
                q['source_refusals'].append(dict(provider=helper, status='REFUSED', error=str(error)))
            else: raise AssertionError('Foreign actual compiled source accepted: ' + helper)
            save()
        assert m.sha(original) == digest and m.validate_bundle(build, args.reference_work, project)[0] == meta
        q['status'] = 'ACTUAL_FROST_SWDIVD1_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS'
        print(q['status'], len(q['native_refusals']), flush=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
