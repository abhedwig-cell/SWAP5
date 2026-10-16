"""Fresh actual native trajectories using byte-verified unchanged admitted providers."""
from pathlib import Path
import argparse,sys,importlib.util,json,hashlib,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
sys.path.insert(0,str(ROOT/'tests/mc-irr01'))
from availability_cycle_driver import rooted,sensor
from tcs6_cycle_driver import prepare_native
from availability_native_controls import execute as decoder_controls

def main():
 p=argparse.ArgumentParser();p.add_argument('--prior',required=True);p.add_argument('--output',required=True);p.add_argument('--feedback',action='store_true');a=p.parse_args();prior=Path(a.prior).resolve();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 old=json.loads((prior/'RESULTS.json').read_text());inp=json.loads((prior/'INPUTS.json').read_text());assert old['status']=='PASS'
 changed={'src/runtime/mod_fmr_production_application_bootstrap.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90'}
 frost='src/process/mod_frost_divdra_drainage_effect.f90';frost_receipt=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['availability_completion_20261016']['inherited_frost_reconciliation']
 assert m.sha(ROOT/frost)==frost_receipt['current_sha256']
 changed.add(frost)
 # The admitted TCS6 execution predates two unused drainage insertions. Verify
 # their exact current projection with its owning current source proof later.
 drain='src/process/mod_drainage_spatial_distribution.f90'
 projection=json.loads((ROOT/'integration/audits/MC_IRR01_STATUS.json').read_text())['tcs6_completion_20261016']['inherited_input_projections'][drain]
 for q,h in inp['inputs'].items():
  if q in changed:continue
  if q==drain:
   text=(ROOT/q).read_text().splitlines(True)
   assert m.sha(ROOT/q)==projection['new_sha256']and h==projection['old_sha256']
   for patch in reversed(projection['insertions']):
    lo,hi=patch['range'];assert text[lo:hi]==patch['current']and not patch['baseline'];text[lo:hi]=[]
   assert hashlib.sha256(''.join(text).encode()).hexdigest()==h
  else:assert m.sha(ROOT/q)==h,q
 assert len(inp['providers'])==295 and changed<=set(inp['providers'])
 # Compiler binary/helpers/runtime and flags must match the actual donor.
 identity=inp['compiler']
 for key in ['launcher','launcher_sha256','version','-print-prog-name=f951','-print-file-name=libgfortran.a','-print-file-name=libgfortran.so.5','-print-libgcc-file-name']:
  assert session.identity[key]==identity[key],key
 fixture=prior/'fixture';drivers={};kind={}
 for name,criterion,dcs,rate in [('root2',2,1,.08),('root3',3,2,.08),('root4zero',4,1,0.),('root7',7,2,.08),('root8',8,1,.08)]:
  if a.feedback and name!='root2':continue
  drivers[name]=rooted(ROOT,out/(name+'.f90'),criterion,dcs,rate);kind[name]='rooted'
 for name,c,n,day in [('sensor7',7,1,20),('sensor8',8,3,21)]:
  if a.feedback and name!='sensor7':continue
  drivers[name]=sensor(ROOT,out/(name+'.f90'),c,n,day);kind[name]='sensor'
 if not a.feedback:drivers['weekly_dcs1']=prepare_native(ROOT,out/'weekly_dcs1.f90',1,True);kind['weekly_dcs1']='preservation'
 generated={q.name:m.sha(q)for q in drivers.values()};inputs={q:m.sha(ROOT/q)for q in inp['inputs']}
 for q in ['tests/mc-irr01/run_availability_application.py','tests/mc-irr01/availability_cycle_driver.py','tests/mc-irr01/availability_native_controls.py']:inputs[q]=m.sha(ROOT/q)
 m.write(out/'INPUTS.json',dict(inputs=inputs,generated=generated,prior_execution=old['head'],providers=inp['providers'],flags=inp['flags'],compiler=session.identity,donor_input_sha256=m.sha(prior/'INPUTS.json')))
 rows=[];reuse={};costs=[]
 for opt in ((0,)if a.feedback else(0,2)):
  build=out/f'o{opt}';build.mkdir();shared=prior/f'o{opt}';cost=json.loads((prior/f'COST_O{opt}.json').read_text())
  for q,h in cost['shared_provider_hashes'].items():assert m.sha(prior/q)==h;reuse[q]=h
  flags=[*inp['flags'],f'-O{opt}','-J',str(build),'-I',str(build),'-I',str(shared)]
  objects=[*sorted(shared.glob('provider-*.o')),*sorted(shared.glob('oracle-*.o'))];count=0
  for index,q in enumerate(inp['providers']):
   if q not in changed:continue
   obj=build/f'provider-{index:03d}.o';session.command([session.compiler,*flags,'-c',str(ROOT/q),'-o',str(obj)],build,'affected-provider');objects=[obj if x.name==obj.name else x for x in objects];count+=1
  # Only executable guards changed. .mod ABI must remain byte-identical.
  for module in build.glob('*.mod'):
   if module.name!='mod_frost_divdra_drainage_effect.mod':assert m.sha(module)==m.sha(shared/module.name),module.name
  for name,driver in drivers.items():
   assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
   obj=build/(name+'.o');exe=build/('test-'+name);session.command([session.compiler,*flags,'-c',str(driver),'-o',str(obj)],build,'driver');session.command([session.compiler,*flags,str(obj),*map(str,objects),'-o',str(exe)],build,'link');exe_sha=m.sha(exe)
   modes=[('continuous','neutral'),('restart','neutral'),('native-write','neutral'),('native-resume','neutral')]if kind[name]=='sensor'else [('continuous','neutral')]+[(mode,phase)for phase in ['neutral','hydraulic']for mode in ['native-write','native-resume','native-write-active','native-resume-active']]
   for mode,phase in modes:
    assert m.sha(exe)==exe_sha
    raw,e=session.command([str(exe),*[str(fixture/q)for q in ['weather.999','altered.999','bad.999','backup.999']],mode,phase],build,f'native-{name}-{mode}-{phase}')
    rows.append(dict(opt=opt,driver=name,kind=kind[name],mode=mode,phase=phase,stdout_sha256=hashlib.sha256(raw).hexdigest(),returncode=e['returncode'],wall_seconds=e['wall_seconds']))
    m.write(out/'PROGRESS.json',dict(rows=rows,events=session.events))
   if kind[name]=='sensor':
    paths=[Path(str(exe)+'.'+mode+'.final')for mode in ['continuous','restart','native-resume']];assert all(x.read_bytes()==paths[0].read_bytes()for x in paths)
   else:
    for phase in ['morning','dayend']:
     paths=[Path(str(exe)+'.'+phase+'.'+s)for s in ['full','opaque','resumed','active.resumed']];assert all(x.read_bytes()==paths[0].read_bytes()for x in paths)
     if kind[name]=='preservation':assert paths[0].read_bytes()==(prior/f'o{opt}'/paths[0].name).read_bytes()
   if not a.feedback and kind[name]!='preservation':
    for phase in (['neutral']if kind[name]=='sensor'else['neutral','hydraulic']):
     controls=decoder_controls(session,exe,fixture,phase,build,opt,name,kind[name]=='sensor')
     m.write(out/f'DECODER_{opt}_{name}_{phase}.json',controls)
   # Binaries are reproducible; retain raw executions and exact hashes, not
   # repeated large executables on the shared finite scratch volume.
   exe.unlink()
  costs.append(dict(opt=opt,provider_compiles=count,reused_providers=295-count))
 if not a.feedback:
  for r in rows:assert r['stdout_sha256']==next(x for x in rows if all(x[k]==r[k]for k in ['driver','mode','phase'])and x['opt']==2-r['opt'])['stdout_sha256']
  for p in (out/'o0').glob('*.final'):
   assert p.read_bytes()==(out/'o2'/p.name).read_bytes()
  for p in (out/'o0').glob('*.full'):assert p.read_bytes()==(out/'o2'/p.name).read_bytes()
 m.write(out/'RESULTS.json',dict(status='PASS_FEEDBACK'if a.feedback else'PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),wall_seconds=time.perf_counter()-start,source_inputs=inputs,generated_inputs=generated,rows=rows,events=session.events,reuse=dict(prior_execution=old['head'],compiler=identity,compiled_artifacts=reuse,donor_input_sha256=m.sha(prior/'INPUTS.json'),drainage_projection=projection,frost_reconciliation=frost_receipt),costs=costs));print('AVAIL_ACTUAL_NATIVE_APPLICATION=PASS',flush=True)
if __name__=='__main__':main()
