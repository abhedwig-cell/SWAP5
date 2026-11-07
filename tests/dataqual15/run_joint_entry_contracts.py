"""Small real Reference border and explicit corrected entry/history contracts."""
import argparse, hashlib, json, subprocess, time
from pathlib import Path
from build_joint_entry_candidate import render, ROOT

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--joint-contact', action='store_true')
p.add_argument('--current-drainage', action='store_true')
p.add_argument('--bottom-contact', action='store_true')
a = p.parse_args()
out = a.output.resolve()
out.mkdir()
if a.joint_contact:
    from build_joint_contact_candidate import render
if a.current_drainage:
    from build_joint_drainage_candidate import render
    a.joint_contact = True
if a.bottom_contact:
    from build_joint_bottom_contact_candidate import render
    a.joint_contact = a.current_drainage = True
shadow = render(out / 'overlay')
contracts = {
    'border': ['src/solver/mod_reference_linear_solver.f90',
               'src/solver/mod_reference_bordered_solver.f90',
               'tests/dataqual15/joint_entry_bordered_driver.f90'],
    'rate': ['src/runtime/mod_macropore_continuation_state.f90',
             'src/process/macropore/mod_ppa_wu05a6_sorptivity_rate.f90',
             'src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90',
             'src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90',
             'tests/dataqual15/joint_entry_rate_driver.f90']}
if a.joint_contact:
    contracts['perched'] = contracts['rate'][:-1] + ['tests/dataqual15/joint_contact_rate_driver.f90']
if a.current_drainage:
    contracts['ordinary'] = contracts['perched']
if a.bottom_contact:
    contracts['bottom'] = contracts['rate'][:-1] + ['tests/dataqual15/joint_bottom_contact_driver.f90']
report = dict(status='RUNNING', scope='COMPONENT_ONLY_NOT_TRAJECTORY_OR_HISTORICAL_EQUIVALENCE',
              events=[], source_sha256={})
for mode in ('O0', 'O2'):
    for name, relative in contracts.items():
        case = out / (mode + '-' + name)
        case.mkdir()
        sources = [shadow.get(ROOT / n, ROOT / n) for n in relative]
        for source in sources:
            report['source_sha256'][str(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
        exe = case / (name + '.exe')
        commands = [[str(a.compiler.resolve()), '-' + mode, '-ffree-line-length-none',
                     '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', '-J' + str(case),
                     *map(str, sources), '-o', str(exe)], [str(exe)] + (['ordinary-contact-extension'] if name == 'ordinary' else [])]
        for label, command in zip(('compile-link', 'native'), commands):
            start = time.monotonic()
            r = subprocess.run(command, cwd=case, capture_output=True, timeout=60)
            (case / (label + '.stdout')).write_bytes(r.stdout)
            (case / (label + '.stderr')).write_bytes(r.stderr)
            report['events'].append(dict(optimization=mode, contract=name, label=label,
                                         command=command, seconds=time.monotonic()-start,
                                         returncode=r.returncode))
            (out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
            assert r.returncode == 0, r.stderr.decode(errors='replace')
report['status'] = 'BORDER_AND_CORRECTED_RATE_HISTORY_O0_O2_PASS'
(out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
print(report['status'])
