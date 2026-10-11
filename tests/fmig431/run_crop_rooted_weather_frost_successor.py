#!/usr/bin/env python3
"""Exact delayed emergence/rooted weather composition over admitted frost; sealed B15 science unchanged."""
import base64, hashlib, io, json, pathlib, subprocess, sys, tarfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = 'e35ea0c6801ad0c225ff02e60f24996d2bc0156d'
EXPECTED = {'src/adapter/mod_swap_daily_weather_file_adapter.f90': '22c1d4f7c0aec3600dadc0ad346a1e4fc3374783', 'src/crop/mod_crop_lifecycle_continuation.f90': '6b27f366b7c352e6dfd8a3d720acc45d2d307b05', 'src/runtime/mod_fmr_production_application_bootstrap.f90': '851cb80954e1be909f6ec54661c0b12b80f225cd', 'src/runtime/mod_fmr_wofost_crop_transaction.f90': '39b4f75c92ea44d6b4e4be326ddf731f54522dfd'}

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
if sys.argv[1:] == ['--verify-only']:
 status = json.loads((ROOT/'integration/audits/MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json').read_text())
 record = status['frost_successor_evidence']
 raw = base64.b64decode((ROOT/record['path']).read_bytes())
 assert hashlib.sha256(raw).hexdigest() == record['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  manifest = json.load(archive.extractfile('MANIFEST.json'))
  assert manifest['current_source_tree'] == git('rev-parse','HEAD:src').decode().strip()
  assert manifest['complete_configurations'] == 24
  assert manifest['fine_comparisons'] == 144
  original_raw = base64.b64decode((ROOT/manifest['original_archive']).read_bytes())
  assert hashlib.sha256(original_raw).hexdigest() == manifest['original_archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(original_raw)) as original:
   for route in ['normal','low-air']:
    for opt in [0,2]:
     current = archive.extractfile(f'highest/{route}/o{opt}/output.txt').read()
     assert current == original.extractfile(f'highest/{route}/o{opt}/output.txt').read()
     assert current.count(b'_RUNTIME=PASS') == 6 and current.count(b'FINE_COMPARISON') == 36
    assert archive.extractfile(f'highest/{route}/o0/output.txt').read() == archive.extractfile(f'highest/{route}/o2/output.txt').read()
  for name, digest in manifest['member_sha256'].items():
   assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == digest, name
  for path, blob in manifest['dependency_blobs'].items():
   assert git('rev-parse','HEAD:'+path).decode().strip() == blob, path
 print('CROP_ROOTED_WEATHER_FROST_COMPLETE_24_SOURCE_BOUND_CONFIGURATIONS=PASS')
 print('CROP_ROOTED_WEATHER_FROST_IMMUTABLE_HIGHEST_OUTPUT_O0_O2_IDENTITY=PASS')
 sys.exit(0)
source = (ROOT/runner).read_text()
old = 'assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source'
assert source.count(old) == 1
source = source.replace(old, "assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip() == '" + git('rev-parse','HEAD:src').decode().strip() + "'")
old_prefix = "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')"
assert source.count(old_prefix) == 1
source = source.replace(old_prefix, "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime-crop-rooted-weather'")
# Preserve every original fixture, flag, physical assertion and six complete
# configurations at both optimizations; only exact admission/prefix differ.
exec(compile(source,str(ROOT/runner),'exec'), {'__file__':str(ROOT/runner),'__name__':'__main__'})
