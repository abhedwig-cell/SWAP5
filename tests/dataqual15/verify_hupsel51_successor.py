"""PR1686-only current CI selection; historical admissions stay immutable.

This is not a replacement historical oracle or whole-science admission. It
inherits sealed full-run evidence only for the exact tested runtime and permits
two literal CI forwarding insertions. Any subsequent runtime change must choose
and qualify its own successor.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SEALED = '4ee0e08b095b945870dce54032e0d886478fb4c4'
RUNTIME = '6e2cd26f873f9a935af92816a2f1d947df9293c7'
BASE = '3fb625da73031885624987d42ad922cb184c96e5'
PROOF = 'integration/f-ci/hupsel51-water-balance/'
SELF = 'tests/dataqual15/verify_hupsel51_successor.py'
TEST = 'tests/dataqual15/test_hupsel51_successor.py'
FCI = '.github/workflows/fci-canonical.yml'
MC = '.github/workflows/mc-sol01-column-input.yml'
FCI_INSERT = '''          if [[ -f tests/dataqual15/verify_hupsel51_successor.py ]]; then
            # Exact current repair proof, not a relabelled historical admission.
            python3 -B tests/dataqual15/test_hupsel51_successor.py
            python3 -B tests/dataqual15/verify_hupsel51_successor.py
            python3 -m pip install -r tests/dataqual15_hupsel/requirements-science.txt
            python3 -B tests/modularity/run_modular_tests.py \\
              --case assimilation --case boesten --case drainage --case low_air_policy \\
              --case root_contract --case root_oxygen --output "$RUNNER_TEMP/modular-feedback"
          el'''
MC_OLD = '        run: python -B tests/nut-sol/verify_surface_age_successor.py\n'
MC_NEW = '''        run: |
          if [[ -f tests/dataqual15/verify_hupsel51_successor.py ]]; then
            # The actual column O0/O2/restart test above still runs unchanged.
            python -B tests/dataqual15/verify_hupsel51_successor.py
          else
            python -B tests/nut-sol/verify_surface_age_successor.py
          fi
'''


def require(ok, label):
    if not ok:
        raise ValueError(label)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def blob(ref, path):
    return git('show', ref + ':' + path)


def validate_scope(paths):
    allowed = {SELF, TEST, FCI, MC, PROOF+'README.md', PROOF+'RECOVERY.md'}
    require(set(paths) <= allowed, 'unqualified successor delta: '+str(set(paths)-allowed))


def validate_workflow(path, current, previous):
    if path == FCI:
        require(current.count(FCI_INSERT) == 1, 'missing/duplicate bounded F-CI selection')
        current = current.replace(FCI_INSERT, '          ', 1)
    else:
        require(current.count(MC_NEW) == 1, 'missing/duplicate bounded column selection')
        current = current.replace(MC_NEW, MC_OLD, 1)
    require(current == previous, 'historical workflow body changed: '+path)


def validate_runs(profiles):
    for opt in ('O0', 'O2', 'named'):
        expected = {'undrained': 1096} if opt != 'named' else {'grass': 1827, 'hupsel': 1096, 'salt': 1461}
        require(set(profiles[opt]) == set(expected), 'missing full trajectory')
        for name, days in expected.items():
            r = profiles[opt][name]
            require(r['status'] == 'FULL_PASS' and r['full_days'] == days, 'incomplete trajectory')
            require(r['budgets']['days'] == days, 'incomplete daily balances')
            for key in ('max_water_cm', 'max_kernel_cm', 'max_solute_mg_cm2'):
                v = r['budgets'][key]
                require(math.isfinite(v) and 0 <= v <= 1e-10, 'balance limit: '+key)
            windows = {(w['start'], w['end']) for w in r['restart_windows']}
            target = {(50, 52), (530, 532)} if name == 'undrained' else ({(109, 111)} if name == 'salt' else {(365, 367)})
            require(windows == target, 'missing own restart window')
            for w in r['restart_windows']:
                require(all(w[k] is True for k in ('exact_physical', 'exact_csv', 'exact_native_auxiliary', 'origin_unchanged')), 'nonexact native own restart')


def verify():
    git('merge-base', '--is-ancestor', SEALED, 'HEAD')
    require(not git('diff', RUNTIME, 'HEAD', '--', 'src', 'app', 'reference', 'tools'), 'runtime differs from qualified source')
    paths = git('diff', '--name-only', SEALED, 'HEAD').decode().splitlines()
    validate_scope(paths)
    require(not git('diff', 'HEAD', '--', 'src', 'app', 'reference', 'tools', 'tests', '.github', 'integration'), 'dirty qualified surface')
    for p in (FCI, MC):
        validate_workflow(p, (ROOT/p).read_text(), blob(SEALED, p).decode().replace('\r\n', '\n'))
    # Fixed Git anchor, not a manifest that can be resealed on the current head.
    for p in ('WINDOWS.json', 'WINDOWS_RAW.json', 'WINDOWS_RAW.zip', 'UBUNTU.json', 'UBUNTU_RAW.zip', 'CI_ADJUDICATION.json'):
        require((ROOT/PROOF/p).read_bytes() == blob(SEALED, PROOF+p), 'sealed proof changed: '+p)
    w = json.loads((ROOT/PROOF/'WINDOWS.json').read_text())
    u = json.loads((ROOT/PROOF/'UBUNTU.json').read_text())
    require(w['runtime_source_commit'] == u['head_sha'] == RUNTIME, 'wrong runtime identity')
    require(w['water_guard_cm'] == w['solute_guard_mg_cm2'] == 1e-10 and w['tolerances_changed'] is False, 'changed tolerance')
    require(w['RC2_modified'] is False and w['release_unchanged'] is True, 'RC2 mutated')
    require(w['science'].startswith('NOT_QUALIFIED'), 'whole science promoted')
    validate_runs(w['Windows'])
    validate_runs(u['profiles'])
    for case in w['named_RC2_preservation'].values():
        require(case['generated_original_units_byte_exact'] and case['all_physical_daily_fields_exact_to_RC2'] and case['max_groundwater_difference_cm'] == 0, 'named RC2 changed')
    m = json.loads((ROOT/PROOF/'WINDOWS_RAW.json').read_text())
    digest = lambda data: hashlib.sha256(data).hexdigest()
    raw = ROOT/PROOF/'WINDOWS_RAW.zip'
    require(digest(raw.read_bytes()) == m['sha256'], 'Windows capsule hash')
    with zipfile.ZipFile(raw) as z:
        require(len(z.namelist()) == len(set(z.namelist())) and set(z.namelist()) == set(m['members']), 'Windows raw inventory')
        for p, h in m['members'].items():
            require(digest(z.read(p)) == h, 'Windows raw member: '+p)
    require(digest((ROOT/PROOF/'UBUNTU_RAW.zip').read_bytes()) == u['artifact_sha256'], 'Ubuntu capsule hash')
    return dict(status='HUPSEL51_BOUNDED_CURRENT_SUCCESSOR_PASS', runtime=RUNTIME,
                proof_anchor=SEALED, canonical_parent=BASE,
                historical_guards='UNCHANGED; not current-source authorities',
                column_physics='UNCHANGED; live O0/O2 column test remains required',
                whole_scientific_equivalence='NOT_QUALIFIED')


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
