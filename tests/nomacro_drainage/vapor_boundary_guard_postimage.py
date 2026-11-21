"""Verify actual new compiled guard postimages without replaying old open runs."""
import argparse,json,subprocess,sys,time,types
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
import original_output_matrix as original


def guard_pair():
 base='\n         if(abs(model7_terminal_water_residual())>1d-10)flnonconv=.true.'
 old=base.replace('model7_terminal_water_residual()','model7_terminal_water_residual(merge(-kmean(NN+1)*hgrad(NN+1),0d0,flboth))')
 opening=base.replace('model7_terminal_water_residual()','model7_terminal_water_residual(-kmean(NN+1)*hgrad(NN+1))');closed=base.replace('model7_terminal_water_residual()','model7_terminal_water_residual(0d0)')
 new='\n         if(flboth)then'+opening+'\n         else'+closed+'\n         end if';return old,new


def compare(old,new):
 before=json.loads((old/'BUILD.json').read_text());actual=json.loads((new/'BUILD.json').read_text())
 for field in ('donor_objects','donor_flags','kernel_flags'):assert before['identity'][field]==actual['identity'][field]
 a={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in old.glob('*.f90')};b={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in new.glob('*.f90')};assert set(a)==set(b)
 old_guard,new_guard=guard_pair();head=b['headcalc.f90'].decode('cp1252');assert head.count(new_guard)==1;inverse=head.replace(new_guard,old_guard,1).encode('cp1252');assert inverse==a['headcalc.f90']
 assert all(a[name]==raw for name,raw in b.items() if name!='headcalc.f90')
 changed=differences(before['identity'],actual['identity']);required={'donor_generated.headcalc.f90','hydraulic_vapor.boundary_composition.source_sha256','model7_terminal_water.boundary_composition.source_sha256'};assert required<=set(changed)<=required|{'restart_publisher.library_sha256'}
 exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));pe=exact(old/'restart_publish.dll',new/'restart_publish.dll')
 return dict(status='ACTUAL_WHOLE_COMPILED_POSTIMAGE_EXACT_AFTER_ONLY_EXPLICIT_QUALIFIED_BOUNDARY_BRANCH_INVERSE',complete_original_HeadCalc_sha256=SHA(a['headcalc.f90']),complete_current_HeadCalc_sha256=SHA(b['headcalc.f90']),all_other_Fortran_provider_objects_flags_exact=True,only_identity_changes=changed,publisher_equivalence=pe,old_successful_physical_runs_preserved=True,selected_scalar_argument_identical_for_both_boolean_values=True,closed_branch_does_not_evaluate_inactive_gradient=True,compiler_executions_in_reader=0,model_executions=0)


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01';q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,build_root=str(a.build_root/'bundle'),input_root=str(a.output/'input'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   store=Archive(proof,'HYDRAULIC_VAPOR_BOUNDARY_WINDOWS_RAW_V1',stack);label=f'vapor-boundary-unit8-active-cde7-8-{a.optimization}-v3';role=next(r for r in store.record['roles'] if r['profile']=='profiles/'+label);prior=json.loads(store.get(role['profile']+'/RESULT.json'));projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old=store.view(projection[prior['build_root']]['archive_prefix']);q.update(original_archive_sha256=store.record['sha256'],original_profile=role['profile'],original_producer=prior['source'],original_RESULT_sha256=SHA(store.get(role['profile']+'/RESULT.json')));inputs=a.output/'input';inputs.mkdir();q['input_inventory']=prior['input_inventory']
   for name,digest in prior['input_inventory']:
    raw=store.get(role['inputs']+'/'+name);assert SHA(raw)==digest;path=inputs/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
   project=original.m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');build=a.build_root/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
   start=time.perf_counter();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(result.stdout);(a.output/'build.stderr').write_text(result.stderr);q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-start);save();result.check_returncode();original.m.validate_bundle(build,a.reference_work,project);q['postimage']=compare(old,build);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());q['status']='ACTUAL_NATIVE5_EXPLICIT_GUARD_COMPILED_POSTIMAGE_OLD_RUN_INHERITANCE_PASS_NO_MODEL_REPEAT'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.optimization,flush=True)


if __name__=='__main__':main()
