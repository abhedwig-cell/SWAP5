"""Prove unchanged compiled state and native ABI using a build-only old selector."""
import argparse,json,subprocess,sys,time,types
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import SHA
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from original_output_baseline import assignment
from initial_profile_calendar_source_inverse import CORE,FIRST_CORE,git
import original_output_matrix as original


def compare(old,new):
 a=json.loads((old/'BUILD.json').read_text());b=json.loads((new/'BUILD.json').read_text())
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):assert a['identity'][field]==b['identity'][field]
 files=lambda root:{p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in root.glob('*.f90')}
 before,after=files(old),files(new);assert before and before==after
 changed=differences(a['identity'],b['identity']);assert set(changed)<={'restart_publisher.library_sha256'}
 pairs=[(old/name,new/name) for name in ('restart_publish.dll','restart_publish.so') if (old/name).is_file() and (new/name).is_file()];assert len(pairs)==1
 left,right=pairs[0];x,y=left.read_bytes(),right.read_bytes()
 if x==y:publisher=dict(status='ACTUAL_PUBLISHER_BYTES_EXACT',sha256=SHA(x))
 else:
  assert x[:2]==y[:2]==b'MZ','Changed non-PE publisher requires independent qualification'
  exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));publisher=exact(left,right)
 return dict(status='ACTUAL_INITIAL2_TO_INITIAL1_WHOLE_FORTRAN_PROVIDER_FLAGS_NATIVE_ABI_AND_PUBLISHER_POSTIMAGE_EXACT',complete_Fortran={name:SHA(raw) for name,raw in before.items()},only_publisher_identity_changes=changed,publisher_equivalence=publisher,unchanged_existing_native_ABI=True,compiler_executions_in_reader=0,model_executions=0)


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();prior=json.loads((a.profile/'RESULT.json').read_text());assert prior['status']=='ACTUAL_ORIGINAL_INITIAL_PROFILE_CALENDAR_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED'
 source=git('rev-parse','HEAD').decode().strip()
 for sha in (source,prior['source']):assert sum(not git('diff',epoch,sha,'--','app','src','tools/solute','tools/vq','reference') for epoch in (FIRST_CORE,CORE))==1
 q=dict(status='RUNNING',source=source,case=prior['case'],optimization=prior['optimization'],initial1_profile=str(a.profile),initial1_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),initial1_build_root=prior['build_root'],build_root=str(a.build_root/'bundle'),input_root=str(a.output/'input'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  inputs=a.output/'input';inputs.mkdir();old_inputs=Path(prior['input_root'])
  for name,digest in prior['input_inventory']:
   raw=(old_inputs/name).read_bytes();assert SHA(raw)==digest;target=inputs/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  path=inputs/'swap.swp';text=path.read_text(encoding='cp1252');path.write_text(assignment(text,'SWINCO',2),encoding='cp1252');q['input_inventory']=original.m.e.inventory(inputs)
  project=original.m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert original.m.e.auxiliary_magic(project).decode()==prior['native_codec'];build=a.build_root/'bundle';opt=prior['optimization']
  cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
  t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t);save();r.check_returncode()
  original.m.validate_bundle(build,a.reference_work,project);q['postimage']=compare(build,Path(prior['build_root']));q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());q['status']='ACTUAL_COMPILED_INITIAL2_BASELINE_WITH_UNCHANGED_INITIAL1_CALENDAR_ABI_PASS_NO_MODEL_REPEAT'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],prior['case'],opt,flush=True)


if __name__=='__main__':main()
