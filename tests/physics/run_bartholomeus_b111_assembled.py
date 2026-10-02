#!/usr/bin/env python3
"""Compile unchanged corrected B1.11 and compare the complete assembled route."""
import base64,gzip,hashlib,json,os,pathlib,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get('FC','gfortran'))
carrier=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text())
raw=gzip.decompress(base64.b64decode(carrier['gzip_base64']))
if hashlib.sha256(raw).hexdigest()!=carrier['sha256']:raise RuntimeError('exact source identity failure')
base=pathlib.Path(os.environ.get('TMPDIR','/tmp'))/'c3a_active'
evidence={'tested_postimage':os.environ.get('C3A_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),
          'source_sha256':carrier['sha256'],'runs':{}}
for opt in ('O0','O2'):
 subprocess.run(['bash','tests/physics/run_bartholomeus_active_chain.sh'],cwd=ROOT,check=True,
                env=dict(os.environ,C3A_OPT=opt))
 with tempfile.TemporaryDirectory(prefix='c3a-b111-') as temp:
  build=pathlib.Path(temp);source=build/'oxygenstress.f90';source.write_bytes(raw)
  flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-J'+str(build),'-I'+str(build),'-I'+str(base)]
  objects=[]
  for p in [ROOT/'tests/physics/support/c3a_b111_oxygen_owners.f90',source]:
   obj=build/(p.stem+'.o');objects.append(str(obj))
   subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True)
  exe=build/'assembled'
  subprocess.run(FC+flags+[str(ROOT/'tests/physics/test_bartholomeus_b111_assembled.f90')]+objects+
                 [str(p) for p in base.glob('*.o')]+['-o',str(exe)],check=True)
  result=subprocess.run([str(exe)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  print(opt+' '+result.stdout,flush=True)
  evidence['runs'][opt]={'returncode':result.returncode,'output':result.stdout}
  result.check_returncode()
pathlib.Path(os.environ.get('C3A_SOURCE_RESULT','c3a_b111_assembled_result.json')).write_text(json.dumps(evidence,indent=2)+'\n')
