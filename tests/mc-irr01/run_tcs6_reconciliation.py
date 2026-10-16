"""Reconcile admitted additive drainage using verified providers and fresh full TCS6 native matrix."""
from pathlib import Path
import argparse,sys,importlib.util,json,hashlib,subprocess,time,shutil
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
sys.path.insert(0,str(ROOT/'tests/mc-irr01'));from tcs6_cycle_driver import prepare_native
from tcs6_native_controls import execute
p=argparse.ArgumentParser();p.add_argument('--prior',required=True);p.add_argument('--output',required=True);a=p.parse_args();prior=Path(a.prior).resolve();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter();sha=m.sha
old=json.loads((prior/'RESULTS.json').read_text());inp=json.loads((prior/'INPUTS.json').read_text());changed='src/process/mod_drainage_spatial_distribution.f90'
assert old['status']=='PASS'
for q,h in inp['inputs'].items():
 if q!=changed:assert sha(ROOT/q)==h,q
# New entry point is an unused additive public routine. Original body is exact.
text=(ROOT/changed).read_text();before=subprocess.check_output(['git','show',old['head']+':'+changed],cwd=ROOT).decode()
import re
projected=text.replace('  public :: distribute_single_level_signed_divdra\n','');projected=re.sub(r'  ! SWDIVDINF=0 uses exactly.*?  end subroutine distribute_single_level_signed_divdra\n\n','',projected,flags=re.S);assert projected==before
for q in ['src/runtime/mod_fmr_divdra_runtime_binding.f90','src/runtime/mod_fmr_divdra_serialized_composition.f90','src/runtime/mod_fmr_divdra_serialized_runtime.f90']:assert q not in inp['providers']
fixture=prior/'fixture';drivers={n:prepare_native(ROOT,out/(n+'.f90'),d,t)for n,d,t in [('weekly_dcs1',1,True),('weekly_dcs2',2,True),('weekly_nontrigger',2,False)]};results=[];reuse={};generated={}
for n,f in drivers.items():assert f.read_bytes()==(prior/f.name).read_bytes();generated[f.name]=sha(f)
for q,h in old['generated_inputs'].items():
 if q not in generated:assert sha(prior/q)==h;target=out/q;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(prior/q,target);generated[q]=h
for opt in (0,2):
 build=out/f'o{opt}';build.mkdir(exist_ok=True);shared=prior/f'o{opt}';cost=json.loads((prior/f'COST_O{opt}.json').read_text())
 for q,h in cost['shared_provider_hashes'].items():assert sha(prior/q)==h;reuse[q]=h
 objects=[*sorted(shared.glob('provider-*.o')),*sorted(shared.glob('oracle-*.o'))];flags=[*inp['flags'],f'-O{opt}','-J',str(build),'-I',str(build),'-I',str(shared)]
 replacement=build/'drainage.o';session.command([session.compiler,*flags,'-c',str(ROOT/changed),'-o',str(replacement)],build,'reconcile-provider')
 index=inp['providers'].index(changed);objects=[replacement if q.name==f'provider-{index:03d}.o'else q for q in objects]
 for name,driver in drivers.items():
  obj=build/(name+'.o');exe=build/('test-'+name);session.command([session.compiler,*flags,'-c',str(driver),'-o',str(obj)],build,'driver-compile');session.command([session.compiler,*flags,str(obj),*map(str,objects),'-o',str(exe)],build,'link')
  for mode,phase in [('continuous','neutral')]+[(mode,phase)for phase in ('neutral','hydraulic')for mode in ('native-write','native-resume','native-write-active','native-resume-active')]:
   raw,e=session.command([str(exe),*[str(fixture/q)for q in ['weather.999','altered.999','bad.999','backup.999']],mode,phase],build,f'native-{name}-{phase}-{mode}');digest=hashlib.sha256(raw).hexdigest();priorrow=next(x for x in old['results']if(x['opt'],x['driver'],x['mode'],x['moisture'])==(opt,name,mode,phase));assert digest==priorrow['stdout_sha256']
   results.append(dict(opt=opt,driver=name,mode=mode,moisture=phase,stdout_sha256=digest,returncode=e['returncode'],wall_seconds=e['wall_seconds']))
  for phase,arg in [('morning','neutral'),('dayend','hydraulic')]:
   paths=[Path(str(exe)+'.'+phase+'.'+s)for s in ('full','opaque','resumed','active.resumed')];assert all(q.read_bytes()==paths[0].read_bytes()for q in paths)
   assert paths[0].read_bytes()==(prior/f'o{opt}'/paths[0].name).read_bytes()
   controls=execute(session,exe,fixture,arg,build,opt,name);(out/f'DECODER_{opt}_{name}_{arg}.json').write_text(json.dumps(controls,indent=2))
 print('RECONCILED_TCS6_O'+str(opt)+'=PASS',flush=True)
inputs={q:sha(ROOT/q)for q in inp['inputs']};inputs['tests/mc-irr01/run_tcs6_reconciliation.py']=sha(Path(__file__))
r=dict(status='PASS',head=old['head'],reconciliation_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),wall_seconds=time.perf_counter()-start,results=results,events=session.events,source_inputs=inputs,generated_inputs=generated,controlled_reuse=dict(original_execution=old['head'],original_source_inputs=inp['inputs'],compiled_artifacts=reuse,recompiled=[changed],original_positive_body_exact=True,all_native_results_fresh=True))
(out/'RESULTS.json').write_text(json.dumps(r,indent=2));print('TCS6_CANONICAL_RECONCILIATION=PASS')
