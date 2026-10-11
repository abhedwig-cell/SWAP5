#!/usr/bin/env python3
"""Exact central application successor of the unchanged B15 scientific runner."""
import base64,hashlib,io,json,pathlib,subprocess,sys,tarfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
BASE='8216240ddcbfcf1c8ea44219cc7149f90fa9408c'
RUNNER='tests/frost/run_ppa_wu05b15_runtime.py'
EXPECTED={
 'src/runtime/mod_fmr_irrigation_allocation_binding.f90':'dfe51ab8e50204e8a7adc84219757a7b77df68e2',
 'src/runtime/mod_fmr_production_application_bootstrap.f90':'d3a0719dfd5c7fb7a0061502c56fe4eede1ca9de'}
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
assert not git('status','--porcelain','--','src').strip()
assert git('diff','--name-only',BASE,'HEAD','--','src').decode().splitlines()==sorted(EXPECTED)
for path,blob in EXPECTED.items():assert git('rev-parse','HEAD:'+path).decode().strip()==blob,path
assert git('show',BASE+':'+RUNNER)==(ROOT/RUNNER).read_bytes()
assert git('rev-parse','HEAD:src/process/mod_frost_hydraulic_effect.f90').decode().strip()=='0dd5b541af936d292d23575f798c3cdd5be19c47'
if sys.argv[1:]==['--verify-source-only']:
 print('MC_IRR01_MANAGED_WEATHER_HIGHEST_EXACT_SOURCE_ONLY=PASS');sys.exit(0)
if sys.argv[1:]==['--verify-only']:
 status=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())
 record=status['managed_weather_checkpoint']['highest_preservation_archive']
 raw=base64.b64decode((ROOT/record['path']).read_bytes())
 assert hashlib.sha256(raw).hexdigest()==record['sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  manifest=json.load(archive.extractfile('MANIFEST.json'))
  assert manifest['source_tree']==git('rev-parse','HEAD:src').decode().strip()
  for name,digest in manifest['member_sha256'].items():assert hashlib.sha256(archive.extractfile(name).read()).hexdigest()==digest,name
  for route in ['normal','low-air']:
   log=archive.extractfile('highest-'+route+'.log').read().decode()
   assert log.count('_FRESH_PROCESS=PASS')==12 and '_O0_O2_IDENTITY=PASS' in log
   assert archive.extractfile(route+'/o0/output.txt').read()==archive.extractfile(route+'/o2/output.txt').read()
 print('MC_IRR01_MANAGED_WEATHER_COMPLETE_HIGHEST_ARCHIVE=PASS');sys.exit(0)
original=(ROOT/RUNNER).read_text()
old='assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source'
assert original.count(old)==1
code=original.replace(old,'pass # Exact two-path source admission was validated above; science body is unchanged.')
old_prefix="prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')"
assert code.count(old_prefix)==1
code=code.replace(old_prefix,"prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime-managed-weather'")
print('MC_IRR01_MANAGED_WEATHER_EXACT_HIGHEST_SUCCESSOR=PASS',flush=True)
exec(compile(code,str(ROOT/RUNNER),'exec'),{'__file__':str(ROOT/RUNNER),'__name__':'__main__'})
