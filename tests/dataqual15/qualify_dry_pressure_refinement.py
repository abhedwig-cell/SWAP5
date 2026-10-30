"""Actual original dry-event comparison; changed source is one numerical budget.

Both event origins retain the exact same physical bytes. Binding replacement is
explicitly diagnostic and is never restart or day1 qualification. The independent
original day1 runs provide that qualification.
"""
import argparse,csv,hashlib,json,shutil,subprocess,time
from pathlib import Path
from checkpoint_layout import layout,payload

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--coarse-run',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args()
base=a.bundle.resolve();out=a.output.resolve();out.mkdir();fc=str(a.compiler.resolve())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((base/'BUILD.json').read_text());assert all(sha(Path(s))==h for s,h in old['source_sha256'].items());assert all(sha(Path(s))==h for s,h in old['object_sha256'].items())
sources=list(old['source_sha256']);objects=list(old['object_sha256']);idx=next(i for i,s in enumerate(sources)if s.endswith('/app/grass_project/initial_interval.f90'))
original=Path(sources[idx]).read_text();needle='numerical%transaction%temporal_tolerance=1d-4;';assert original.count(needle)==1
driver=out/'initial_interval_refinement.f90';driver.write_text(original.replace(needle,'numerical%transaction%temporal_tolerance=1d-5;'))
flags=[f for f in old['flags']if not f.startswith(('-I','-J'))]+['-I'+str(base),'-I'+str(out),'-J'+str(out)]
report=dict(scope='ORIGINAL_DRY_EVENT_NUMERICAL_REFINEMENT_NOT_RESTART_QUALIFICATION',compiler=old['compiler'],coarse_budget=1e-4,fine_budget=1e-5,only_source_change='One literal temporal budget in original application; physical inputs and process sources unchanged',events=[],source_sha256={s:h for s,h in old['source_sha256'].items()if s!=sources[idx]},reused_object_sha256={s:h for s,h in old['object_sha256'].items()if s!=objects[idx]})
report['source_sha256'][str(driver)]=sha(driver)
def command(cmd,label,cwd=out,timeout=120):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);(out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr);report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-t));(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');assert r.returncode==0,(label,r.returncode)
obj=out/'refinement.o';command([fc,*flags,'-c',driver,'-o',obj],'compile')
objects[idx]=str(obj)
link=next(e['command']for e in old['events']if e['label']=='link');library=Path(link[-3]);assert library.suffix=='.a'and sha(library)==old['original_input_archive_sha256']
exe=out/'swap5_grass_startup';command([fc,'-fopenmp',*objects,library,'-o',exe],'link')
case=out/'original-interval';case.mkdir()
for n,h in old['original_inputs_sha256'].items():assert sha(base/'original-interval'/n)==h;shutil.copyfile(base/'original-interval'/n,case/n)
binding=dict(executable_sha256=sha(exe),compiler=old['compiler'],source_sha256=report['source_sha256']);(case/'application.binding').write_text(json.dumps(binding,sort_keys=True))
build=dict(old);build.update(status='BUILT_REFINEMENT',source_sha256=report['source_sha256'],executable_sha256=sha(exe),flags=flags,object_sha256={s:sha(Path(s))for s in objects},events=report['events'],application_binding_sha256=sha(case/'application.binding'))
(out/'BUILD.json').write_text(json.dumps(build,indent=2)+'\n')
origin=out/'origin-diagnostic.bin';command(['python','-B',ROOT/'tests/dataqual15/diagnostic_predecessor.py','--checkpoint',a.checkpoint.resolve(),'--bundle',out,'--output',origin],'prepare_diagnostic_origin')
day=int(layout(origin.read_bytes())['clock']);assert day==926
coarse=a.coarse_run.resolve();assert payload(origin.read_bytes())==payload((coarse/'restart-origin.bin').read_bytes())
run=out/'native';command(['python','-B',ROOT/'tests/dataqual15/run_original.py','--bundle',out,'--output',run,'--end',day+1,'--restart',origin,'--timeout','1200'],'native_controller',timeout=1230)
native=json.loads((run/'RESULT.json').read_text());assert native['returncode']==0 and not native['censored']and native['completed_days']==927
read=lambda f:list(csv.DictReader(f.open()))
budget=read(run/'budget.csv');other=read(coarse/'budget.csv');assert len(budget)==len(other)==1
assert budget[0]['water_start_cm']==other[0]['water_start_cm']
for r in [*budget,*other]:assert abs(float(r['residual_cm']))<1e-10
fine=read(run/'state.csv');rough=read(coarse/'state.csv');assert len(fine)==len(rough)==113
report.update(status='NATIVE_ORIGINAL_DRY_EVENT_REFINEMENT_MEASURED',origin_day=926,end_day=927,physical_origin_exact=True,coarse_seconds=json.loads((coarse/'RESULT.json').read_text())['seconds'],fine_seconds=native['seconds'],maximum_profile_differences={k:max(abs(float(x[k])-float(y[k]))for x,y in zip(fine,rough))for k in ['head_cm','water_content','temperature_c']},daily_budget_differences={k:float(budget[0][k])-float(other[0][k])for k in ['water_end_cm','uptake_cm','potential_cm','drought_cm','oxygen_cm']},maximum_water_residual_cm=max(abs(float(r['residual_cm']))for r in [*budget,*other]),scientific_equivalence=False)
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items()if k not in ['source_sha256','reused_object_sha256','events']},indent=2))
