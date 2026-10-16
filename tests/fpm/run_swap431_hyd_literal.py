#!/usr/bin/env python3
"""Independent MODEL2/3 values/cutoffs against the full unchanged B1.11 MOD_MvG."""
import base64,hashlib,io,json,os,pathlib,subprocess,tarfile,tempfile,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
REFERENCE='reference/swap-4.3.1/b1_11_frost_source/SWAP/MOD_MvG_functions.f90'
assert hashlib.sha256((ROOT/REFERENCE).read_bytes()).hexdigest()=='6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104'
ARCHIVE='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/ARCHIVE).read_bytes()))) as archive:
 WC=archive.extractfile('SWAP/WC_K_models_04_11.f90').read()
assert hashlib.sha256(WC).hexdigest()=='d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126'
PATHS=['tests/fpm/hyd_literal_stubs.f90','@WC',REFERENCE,'src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_b110_default_mvg_provider.f90','tests/fpm/test_swap431_hyd_literal.f90']
evidence=pathlib.Path(os.environ['HYD_LITERAL_EVIDENCE']);evidence.mkdir(parents=True,exist_ok=False)
result={'scope':'Literal MODEL2/3/6 and POWER,16heads x4nodes x4profiles=256 cases; theta/K/C and analytical dKdh, saturated/dry, hcrit and POWER boundary. POWER typed dKdh is reserved0 forSWKIMPL0; no implicit derivative claim.','source_sha256':{p:hashlib.sha256(WC if p=='@WC' else (ROOT/p).read_bytes()).hexdigest() for p in PATHS},'optimizations':{}}
(evidence/'compiler.txt').write_bytes(subprocess.check_output(['gfortran','--version']))
with tempfile.TemporaryDirectory(prefix='hyd-literal-') as tmp:
 for opt in ['O0','O2']:
  build=pathlib.Path(tmp)/opt;build.mkdir();objects=[];compile_seconds=0
  logs=[]
  for name in PATHS:
   file=ROOT/name
   if name=='@WC':
    file=build/'WC_K_models_04_11.f90';file.write_bytes(WC)
   obj=build/(file.stem+'.o');t=time.monotonic()
   run=subprocess.run(['gfortran','-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-ffunction-sections','-J'+str(build),'-I'+str(build),'-c',str(file),'-o',str(obj)],capture_output=True,cwd=build)
   compile_seconds+=time.monotonic()-t;logs.append(run.stdout+run.stderr)
   if run.returncode:
    (evidence/(opt+'-compile.log')).write_bytes(b''.join(logs));run.check_returncode()
   objects.append(str(obj))
  (evidence/(opt+'-compile.log')).write_bytes(b''.join(logs));t=time.monotonic();exe=build/'test'
  subprocess.run(['gfortran','-Wl,--gc-sections',*objects,'-o',str(exe)],check=True,capture_output=True);link_seconds=time.monotonic()-t;t=time.monotonic()
  run=subprocess.run([str(exe)],capture_output=True,cwd=build);native_seconds=time.monotonic()-t
  (evidence/(opt+'.stdout')).write_bytes(run.stdout);(evidence/(opt+'.stderr')).write_bytes(run.stderr)
  result['optimizations'][opt]={'exit':run.returncode,'compile_seconds':compile_seconds,'link_seconds':link_seconds,'native_seconds':native_seconds,'stdout_sha256':hashlib.sha256(run.stdout).hexdigest()}
  print(run.stdout.decode(),end='')
result['byte_identity']=(evidence/'O0.stdout').read_bytes()==(evidence/'O2.stdout').read_bytes()
result['pass']=all(x['exit']==0 for x in result['optimizations'].values()) and result['byte_identity']
(evidence/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print('SWAP431_HYD_LITERAL_O0_O2='+('PASS' if result['pass'] else 'FAIL'))
raise SystemExit(0 if result['pass'] else 1)
