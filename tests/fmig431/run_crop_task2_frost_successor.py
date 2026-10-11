#!/usr/bin/env python3
"""Exact crop task2 composition over admitted frost; sealed B15 science unchanged."""
import base64, hashlib, io, pathlib, subprocess, sys, tarfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'da9ef1e5d37cd49f996dc48e24fcd09110cff777'
EXPECTED = {
 'src/crop/mod_crop_lifecycle_continuation.f90': 'd465dfe184048797d3932e8783869e7f25a6e38d',
 'src/crop/mod_crop_lifecycle_daily_composition.f90': '0a80e03bf2dd013eec61bbe972f8eeb64f05b2f8',
 'src/runtime/mod_fmr_crop_weather_physical_event_composition.f90': '14b8d5e07c7abb08416a3d64e05fc06e9737af4a',
 'src/runtime/mod_fmr_production_application_bootstrap.f90': 'bc04a4239b2b0d8ef21f962af14be6ef28fbe436',
 'src/runtime/mod_fmr_wofost_crop_transaction.f90': '0f7fccc714a908083f4550394ca1fdd28f354d47',
}
def git(*args):
 return subprocess.check_output(['git', *args], cwd=ROOT)
assert not git('status','--porcelain','--','src').strip()
assert git('diff','--name-only',BASE,'HEAD','--','src').decode().splitlines() == sorted(EXPECTED)
for path, blob in EXPECTED.items():
 assert git('rev-parse','HEAD:'+path).decode().strip() == blob, path
assert git('rev-parse','HEAD:reference') == git('rev-parse',BASE+':reference')
runner = 'tests/frost/run_ppa_wu05b15_runtime.py'
assert git('show',BASE+':'+runner) == (ROOT/runner).read_bytes()
assert git('rev-parse','HEAD:src/process/mod_frost_hydraulic_effect.f90').decode().strip() == '0dd5b541af936d292d23575f798c3cdd5be19c47'
source = (ROOT/runner).read_text()
old = 'assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source'
assert source.count(old) == 1
source = source.replace(old, "assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip() == '" + git('rev-parse','HEAD:src').decode().strip() + "'")
old_prefix = "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')"
assert source.count(old_prefix) == 1
source = source.replace(old_prefix, "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime-crop-task2'")
# Preserve every original fixture, flag, physical assertion and six complete
# configurations at both optimizations; only exact admission/prefix differ.
exec(compile(source,str(ROOT/runner),'exec'), {'__file__':str(ROOT/runner),'__name__':'__main__'})
