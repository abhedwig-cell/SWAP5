"""Real source-provider callback interface, immutable bindings and refusal O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from build_joint_drainage_candidate import render,ROOT
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir();shadow=render(out/'overlay')
sources=[ROOT/'src/solver/mod_soil_water_solver_contract.f90',
 shadow[ROOT/'src/solver/mod_b110_source_sink_provider.f90'],ROOT/'tests/dataqual15/joint_source_callback_driver.f90']
report=dict(status='RUNNING',scope='INTERFACE_ONLY_REAL_DRAINAGE_SCIENCE_REQUIRES_NATIVE_COMPOSITION',
 source_sha256={str(s):hashlib.sha256(s.read_bytes()).hexdigest()for s in sources},events=[])
for mode in ('O0','O2'):
 case=out/mode;case.mkdir();exe=case/'source.exe'
 commands=[('compile-link',[str(a.compiler.resolve()),'-'+mode,'-ffree-line-length-none','-fcheck=all',
  '-ffpe-trap=invalid,zero,overflow','-J'+str(case),*map(str,sources),'-o',str(exe)]),
  ('native',[str(exe)]),('refusal',[str(exe),'refuse'])]
 for label,command in commands:
  start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=60)
  (case/(label+'.stdout')).write_bytes(r.stdout);(case/(label+'.stderr')).write_bytes(r.stderr)
  report['events'].append(dict(optimization=mode,label=label,command=command,seconds=time.monotonic()-start,returncode=r.returncode))
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
  if label=='refusal':assert r.returncode!=0 and b'V4 current drainage source refused'in r.stderr
  else:assert r.returncode==0,r.stderr.decode(errors='replace')
report['status']='SCOPED_CURRENT_SOURCE_INTERFACE_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
