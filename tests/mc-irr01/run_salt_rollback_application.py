"""Fresh measured current production build and actual DCSLIM application/native trajectories."""
from pathlib import Path
import argparse,sys,importlib.util,json,hashlib,subprocess,time,base64,io,tarfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
sys.path.insert(0,str(ROOT/'tests/mc-irr01'))
from salt_rollback_cycle_driver import rollback
from batch_activation_cycle_driver import rooted as root_preservation
from availability_cycle_driver import rooted as original_root,sensor
from tcs6_cycle_driver import prepare_native
from salt_completion_native_controls import execute as decoder_controls

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 rec=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['tcs6_completion_20261016']['science_archive']
 raw=base64.b64decode((ROOT/rec['path']).read_bytes());assert hashlib.sha256(raw).hexdigest()==rec['decoded_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  data={q.name:t.extractfile(q).read()for q in t.getmembers()if q.isfile()}
 manifest=json.loads(data.pop('MANIFEST.json'));assert set(data)==set(manifest)and all(hashlib.sha256(data[q]).hexdigest()==h for q,h in manifest.items())
 inp=json.loads(data['physical/INPUTS.json']);providers=list(inp['providers']);assert len(providers)==295
 # Canonical DRAMET3 adds a real module dependency to the retained binder.
 added='src/process/mod_drainage_dramet3_response.f90';assert added not in providers
 providers.insert(providers.index('src/runtime/mod_fmr_drainage_response_binding.f90'),added)
 assert len(providers)==296
 providers.insert(providers.index('src/runtime/mod_fmr_irrigation_material_root_binding.f90'),'src/crop/mod_crop_rotation_calendar.f90')
 assert len(providers)==297
 fixture=out/'fixture';fixture.mkdir();fixture_pins={}
 for name,b in data.items():
  if name.startswith('physical/fixture/'):
   rel=name[len('physical/fixture/'):];assert '/'not in rel
   (fixture/rel).write_bytes(b);fixture_pins[rel]=hashlib.sha256(b).hexdigest()
 flags=inp['flags'];assert '-fcheck=all'in flags and '-ffpe-trap=invalid,zero,overflow'in flags
 drivers={'salt_rollback':rollback(ROOT,out/'salt_rollback.f90')}
 paths=set(providers)|set(inp['inputs'])
 paths|={'tests/mc-irr01/run_salt_rollback_application.py','tests/mc-irr01/salt_rollback_cycle_driver.py','tests/mc-irr01/salt_completion_cycle_driver.py','tests/mc-irr01/salt_completion_native_controls.py','tests/mc-irr01/batch_activation_cycle_driver.py','tests/mc-irr01/sensor_batch_cycle_driver.py','tests/mc-irr01/availability_cycle_driver.py','tests/mc-irr01/availability_native_controls.py'}
 inputs={q:m.sha(ROOT/q)for q in paths};generated={q.name:m.sha(q)for q in drivers.values()}
 identity=session.identity;head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 m.write(out/'INPUTS.json',dict(head=head,inputs=inputs,generated=generated,providers=providers,flags=flags,compiler=identity,fixture=fixture_pins,fixture_authority=rec))
 rows=[];costs=[]
 for opt in(0,2):
  build=out/f'o{opt}';build.mkdir();opts=[*flags,f'-O{opt}','-J',str(build),'-I',str(build)];objects=[];compile_seconds=0
  for index,q in enumerate(providers):
   source=fixture/'grid_stubs.f90'if q=='tests/fsi/fsi04_real_headcalc_stubs.f90'else ROOT/q
   obj=build/f'provider-{index:03d}.o';_,e=session.command([session.compiler,*opts,'-c',str(source),'-o',str(obj)],build,'provider');objects.append(obj);compile_seconds+=e['wall_seconds']
  oracles=['astro_oracle.f90','daily_meteo_oracle.f90','crop_germination_oracle.f90','initial_owner_oracle.f90','task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90','co2_oracle.f90']
  for i,source in enumerate([ROOT/'src/legacy/b1_10_port/headcalc.f90',*[fixture/q for q in oracles]]):
   obj=build/f'oracle-{i:02d}.o';_,e=session.command([session.compiler,*opts,'-c',str(source),'-o',str(obj)],build,'oracle');objects.append(obj);compile_seconds+=e['wall_seconds']
  artifacts={q.name:m.sha(q)for q in build.iterdir()if q.suffix in('.o','.mod')}
  m.write(out/f'COST_O{opt}.json',dict(provider_compiles=len(providers),external_compiles=len(oracles)+1,compile_seconds=compile_seconds,shared_provider_hashes=artifacts))
  for name,driver in drivers.items():
   assert session.toolchain_identity()==identity and all(m.sha(ROOT/q)==h for q,h in inputs.items())
   assert all(m.sha(build/q)==h for q,h in artifacts.items())
   obj=build/(name+'.o');exe=build/('test-'+name);session.command([session.compiler,*opts,'-c',str(driver),'-o',str(obj)],build,'driver');session.command([session.compiler,*opts,str(obj),*map(str,objects),'-o',str(exe)],build,'link');exe_sha=m.sha(exe)
   modes=[('continuous','neutral'),('restart','neutral')]
   for mode,phase in modes:
    assert m.sha(exe)==exe_sha
    stdout,e=session.command([str(exe),*[str(fixture/q)for q in ['weather.999','altered.999','bad.999','backup.999']],mode,phase],build,'native-'+name+'-'+mode+'-'+phase)
    assert b'SALT_REAL_INCOMPLETE_PREFIX_MASS_EVENT_RETRY_OPAQUE=PASS'in stdout
    rows.append(dict(opt=opt,driver=name,mode=mode,phase=phase,returncode=e['returncode'],stdout_sha256=hashlib.sha256(stdout).hexdigest()))
    m.write(out/'PROGRESS.json',dict(rows=rows,events=session.events))
   exe.unlink()
  costs.append(json.loads((out/f'COST_O{opt}.json').read_text()))
 for r in rows:assert r['stdout_sha256']==next(x for x in rows if x['opt']==2-r['opt']and all(x[q]==r[q]for q in ['driver','mode','phase']))['stdout_sha256']
 for q in(out/'o0').iterdir():
  if q.name.endswith(('.full','.final')):assert q.read_bytes()==(out/'o2'/q.name).read_bytes()
 assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=head,inputs=inputs,generated=generated,rows=rows,events=session.events,costs=costs,wall_seconds=time.perf_counter()-start));print('SALT_REAL_INCOMPLETE_PREFIX_O0_O2=PASS',flush=True)
if __name__=='__main__':main()
