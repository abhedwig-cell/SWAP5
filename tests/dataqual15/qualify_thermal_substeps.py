"""Cold O0/O2 real heat policy contracts for one/four/sixteen and refusal.

Only the owning production contract closure is compiled. The original implicit
body is a separate control; no O2 dependency is substituted into the O0 chain.
"""
import argparse,hashlib,json,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path)
p.add_argument('--compiler',type=Path)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
build=None
if a.bundle:
 build=json.loads((a.bundle/'BUILD.json').read_text())
 assert all(sha(s)==h for s,h in build['source_sha256'].items())
 assert all(sha(s)==h for s,h in build['object_sha256'].items())
fc=str(a.compiler.resolve()) if a.compiler else (next(e['command'][0] for e in build['events'] if e['label']=='link') if build else shutil.which('gfortran'))
assert fc
original=subprocess.check_output(['git','cat-file','blob','f96c9f23ed2234255c0ceeb64e82c3e87f2e77fe:src/process/mod_restricted_soil_temperature.f90'],cwd=ROOT).decode()
control=out/'original_control.f90';control.write_text(original.replace('mod_restricted_soil_temperature','mod_restricted_soil_temperature_control'),newline='\n')
driver=ROOT/'tests/dataqual15/thermal_substep_driver.f90'
sources=[ROOT/s for s in ['src/transaction/mod_transaction_reference.f90','src/solver/mod_soil_water_solver_contract.f90',
 'src/solver/mod_process_hydraulic_view.f90','src/process/mod_soil_temperature_contract.f90',
 'src/process/mod_restricted_soil_temperature.f90','src/runtime/mod_fmr_thermal_substep_receipt.f90']]+[control,driver]
hashes={str(s):sha(s) for s in sources};events=[]
def run(cmd,folder,label):
 start=time.perf_counter()
 try:
  r=subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True,timeout=60);rc=r.returncode
 except subprocess.TimeoutExpired as e:r=e;rc=None
 (folder/(label+'.stdout')).write_bytes(r.stdout or b'');(folder/(label+'.stderr')).write_bytes(r.stderr or b'')
 events.append(dict(label=label,profile=folder.name,command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=rc))
 (out/'events.json').write_text(json.dumps(events,indent=2)+'\n',newline='\n')
 assert rc==0,(label,rc)
 return r.stdout
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir()
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(folder),'-J'+str(folder)]
 objects=[]
 for i,source in enumerate(sources):
  obj=folder/f'{i}.o';run([fc,*flags,'-c',source,'-o',obj],folder,f'compile-{i}');objects.append(obj)
 exe=folder/'control.exe';run([fc,*objects,'-o',exe],folder,'link')
 for steps in [4,16]:
  raw=run([exe,str(steps)],folder,f'native-{steps}')
  assert b'THERMAL_SUBSTEP_POLICY_DEFAULT_FACES_AND_REFUSAL=PASS' in raw
assert all(sha(s)==h for s,h in hashes.items())
r=dict(status='HEAT_POLICY_BODY_O0_O2_DEFAULT_FACES_AND_REFUSAL_PASS',compiler=subprocess.check_output([fc,'--version']).decode().splitlines()[0],events=events,source_sha256=hashes,driver_counts=[4,16],scope=__doc__,native_graph_build_sha256=sha(a.bundle/'BUILD.json') if a.bundle else None)
(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n',newline='\n');print(r['status'])
