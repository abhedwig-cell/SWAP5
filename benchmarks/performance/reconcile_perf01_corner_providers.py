"""Recompile only concurrent mode3/macro admission providers; verify their ABI.

Every other executed source/object stays bound to the checked repair build.
Execute the real 54-case macro/Robin oracle and original positive-chemistry BBC.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
CHANGED = ['src/adapter/mod_reference_richards_legacy_binding.f90',
           'src/runtime/mod_fmr_serialized_reference_backend.f90']


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', type=Path, required=True)
    ap.add_argument('--bbc', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sha = lambda b: hashlib.sha256(b).hexdigest()
    physical = json.loads((a.bundle / 'shared/build-complete.json').read_text())
    column = json.loads((a.bundle / 'column/build-complete.json').read_text())
    r = dict(status='RUNNING_RECONCILIATION', events=[], input_sha256={}, unchanged_compiled_interfaces={})

    def save():
        (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')

    def run(cmd, cwd, label):
        cmd = list(map(str, cmd))
        t = time.perf_counter()
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=120)
        (out / (label + '.stdout')).write_bytes(p.stdout)
        (out / (label + '.stderr')).write_bytes(p.stderr)
        r['events'].append(dict(label=label, command=cmd, returncode=p.returncode, seconds=time.perf_counter() - t))
        save()
        assert p.returncode == 0, p.stderr.decode()[-2000:]
        return p.stdout

    for p, h in column['input_sha256'].items():
        if p not in CHANGED:
            assert sha((ROOT / p).read_bytes()) == h, p
        r['input_sha256'][p] = sha((ROOT / p).read_bytes())
    replacements = {}
    for source in CHANGED:
        old = next(e['command'] for e in physical['events'] if str(ROOT / source) in e['command'])
        obj = out / (Path(source).stem + '.o')
        cmd = [str(obj) if x == old[-1] else '-J' + str(out) if x.startswith('-J') else x for x in old]
        run(cmd, out, 'compile-' + Path(source).stem)
        module = Path(source).stem + '.mod'
        assert (out / module).read_bytes() == (a.bundle / 'shared' / module).read_bytes(), module
        r['unchanged_compiled_interfaces'][module] = sha((out / module).read_bytes())
        replacements[old[-1]] = str(obj)
    old_link = next(e['command'] for e in column['events'] if e['category'] == 'project_compile_link')
    exe = out / 'project'
    link = [replacements.get(x, str(exe) if x == str(a.bundle / 'column/swap5_solute_project') else
                             '-J' + str(out) if x.startswith('-J') else x) for x in old_link]
    run(link, out, 'project-link')
    oracle = out / 'macro-oracle'
    cmd = [str(ROOT / 'tests/nut-sol/test_cauchy3_macropore_oracle.f90') if x == str(ROOT / 'app/solute_project/main.f90') else
           str(oracle) if x == str(exe) else x for x in link]
    run(cmd, out, 'oracle-link')
    text = run([oracle], out, 'oracle-native')
    assert b'CAUCHY_MACRO_INDEPENDENT_PASS' in text and text.splitlines()[-1].split()[1] == b'54'
    r['input_sha256']['tests/nut-sol/test_cauchy3_macropore_oracle.f90'] = sha((ROOT / 'tests/nut-sol/test_cauchy3_macropore_oracle.f90').read_bytes())
    case = out / 'bbc'
    case.mkdir()
    for n in ['input.nml', 'input.swp']:
        (case / n).write_bytes((a.bbc / n).read_bytes())
    run([exe, 'input.nml', '-', '481', 'input.swp'], case, 'bbc-native')
    r['bbc_physical_identity'] = {}
    for n in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
        r['bbc_physical_identity'][n] = (case / n).read_bytes() == (a.bbc / n).read_bytes()
    assert all(r['bbc_physical_identity'].values())
    r['used_artifacts'] = {x: sha(Path(x).read_bytes()) for x in link if x.endswith(('.o', '.a'))}
    r['status'] = 'CURRENT_COMPOSED_54_MACRO_CASES_AND_BBC481_EXACT'
    save()
    print(r['status'])


if __name__ == '__main__':
    main()
