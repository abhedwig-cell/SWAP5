#!/usr/bin/env python3
"""Route the unchanged B15 oracle/build body to one exact NaN-guard successor."""
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'a3859c89eaf97256a6330bb9f6370013c4a9e2f2'
EFFECT = 'src/process/mod_frost_hydraulic_effect.f90'
GUARD = '0dd5b541af936d292d23575f798c3cdd5be19c47'
RUNNER = 'tests/frost/run_ppa_wu05b15_runtime.py'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

assert not git('diff', '--name-only', 'HEAD', '--', 'src').strip()
assert git('rev-parse', 'HEAD:' + EFFECT).decode().strip() == GUARD
assert git('diff', '--name-only', BASE, 'HEAD', '--', 'src').decode().splitlines() == [EFFECT]
assert git('show', BASE + ':' + RUNNER) == (ROOT / RUNNER).read_bytes()
original = (ROOT / RUNNER).read_text()
old = "assert subprocess.check_output([\"git\",\"rev-parse\",\"HEAD:src\"],cwd=ROOT,text=True).strip()==source"
assert original.count(old) == 1
code = original.replace(old, "assert subprocess.check_output(['git','rev-parse','HEAD:src/process/mod_frost_hydraulic_effect.f90'],cwd=ROOT,text=True).strip()=='" + GUARD + "'")
old_prefix = "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')"
assert code.count(old_prefix) == 1
code = code.replace(old_prefix, "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime-nan-guard'")
print('FROST_NAN_GUARD_EXACT_ONE_SOURCE_SUCCESSOR=PASS', flush=True)
# Only source admission and owned scratch prefix change. Every scientific
# fixture, compiler flag, complete configuration, comparator and budget is
# executed through the sealed original runner body.
exec(compile(code, str(ROOT / RUNNER), 'exec'), {'__file__': str(ROOT / RUNNER), '__name__': '__main__'})
