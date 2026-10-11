#!/usr/bin/env python3
"""Route the unchanged B15 oracle/build body to one exact NaN-guard successor."""
import pathlib
import subprocess
import sys
import base64
import hashlib
import io
import json
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'cd530867dc8a41e8cd5b46dfbaff1007d14c3a75'
EFFECT = 'src/process/mod_frost_hydraulic_effect.f90'
GUARD = '0dd5b541af936d292d23575f798c3cdd5be19c47'
RUNNER = 'tests/frost/run_ppa_wu05b15_runtime.py'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

assert not git('diff', '--name-only', 'HEAD', '--', 'src').strip()
assert git('rev-parse', 'HEAD:' + EFFECT).decode().strip() == GUARD
assert git('diff', '--name-only', BASE, 'HEAD', '--', 'src').decode().splitlines() == [EFFECT]
assert git('show', BASE + ':' + RUNNER) == (ROOT / RUNNER).read_bytes()
if sys.argv[1:] == ['--verify-source-only']:
    print('FROST_NAN_GUARD_EXACT_SOURCE_ONLY_NOT_HIGHEST_QUALIFICATION=PASS')
    sys.exit(0)
if sys.argv[1:] == ['--verify-only']:
    status = json.loads((ROOT / 'integration/audits/PPA_WU05B_NAN_GUARD_STATUS.json').read_text())
    record = status['regie_current_requalification']['scientific_archive']
    raw = base64.b64decode((ROOT / record['path']).read_bytes())
    assert hashlib.sha256(raw).hexdigest() == record['decoded_sha256']
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json'))
        assert manifest['source_tree'] == git('rev-parse', 'HEAD:src').decode().strip()
        for name, digest in manifest['member_sha256'].items():
            assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == digest, name
        for route in ['normal', 'low-air']:
            log = archive.extractfile('logs/frost-nan-highest-' + route + '.log').read().decode()
            assert log.count('_FRESH_PROCESS=PASS') == 12
            assert '_O0_O2_IDENTITY=PASS' in log
    print('FROST_NAN_GUARD_COMPLETE_HIGHEST_ARCHIVE=PASS')
    sys.exit(0)
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
