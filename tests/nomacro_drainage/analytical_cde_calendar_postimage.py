"""Compile old input bytes once to prove unselected native3/4/5 are unchanged."""
import argparse,copy,json,subprocess,sys,time,types
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
import original_output_matrix as original
CASES={
 'native3':('HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1','profiles/analytical-calendar-vapor8-nprint2-O0-v1','S5HVW003'),
 'native4':('HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1','profiles/snow-vapor-cde-O0-v3','S5HSC004'),
 'native5':('HYDRAULIC_VAPOR_BOUNDARY_GUARD_WINDOWS_RAW_V1','profiles/vapor-boundary-closed-unit8-active-cde7-8-O0-v2','S5HBC005')}


def compare(old,new):
 a=json.loads((old/'BUILD.json').read_text());b=json.loads((new/'BUILD.json').read_text())
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):assert a['identity'][field]==b['identity'][field]
 files=lambda root:{p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in root.glob('*.f90')}
 before,after=files(old),files(new);assert before and before==after
 projected=copy.deepcopy(b['identity']);extra=[]
 if 'cde_native_receipt' in a['identity']:
  left=a['identity']['cde_native_receipt']['optional_native_prefixes'];right=projected['cde_native_receipt']['optional_native_prefixes']
  assert set(right)==set(left)|{'S5HBC005','S5HCC006'}
  for key,value in [('S5HBC005','48 + 8*(14+2*actual_layers), checked duplicated bounded drainage/bottom vapor domain'),('S5HCC006','48 + 8*(14+2*actual_layers), checked duplicated CDE calendar vapor domain')]:
   if key not in left:assert right.pop(key)==value;extra.append('cde_native_receipt.optional_native_prefixes.'+key)
 changed=differences(a['identity'],projected)+extra
 allowed={'experimental_input_adapter','hydraulic_vapor.source_sha256','model7_terminal_water.source_sha256','original_output.source_sha256','original_output.ordinary_owner_sha256','cde_native_receipt.source_sha256','restart_publisher.library_sha256','cde_native_receipt.optional_native_prefixes.S5HBC005','cde_native_receipt.optional_native_prefixes.S5HCC006'}
 assert set(changed)<=allowed,changed
 exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));pe=exact(old/'restart_publish.dll',new/'restart_publish.dll')
 return dict(status='ACTUAL_COMPLETE_UNSELECTED_FORTRAN_PROVIDER_OBJECTS_FLAGS_NATIVE_ABI_AND_PUBLISHER_POSTIMAGE_UNCHANGED',complete_Fortran={name:SHA(raw) for name,raw in before.items()},only_source_descriptor_and_publisher_identity_changes=changed,publisher_equivalence=pe,compiler_executions_in_reader=0,model_executions=0)


def main():
 p=argparse.ArgumentParser()
 for key in ('proof','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--codec',choices=CASES,required=True);a=p.parse_args();a.output.mkdir();archive,prefix,magic=CASES[a.codec]
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),archive=archive,old_profile=prefix,codec=a.codec,build_root=str(a.build_root/'bundle'),input_root=str(a.output/'input'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   store=Archive(a.proof,archive,stack);role=next(r for r in store.record['roles'] if r['profile']==prefix);prior=json.loads(store.get(prefix+'/RESULT.json'));projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old=store.view(projection[prior['build_root']]['archive_prefix'])
   q.update(old_producer=prior['source'],old_RESULT_sha256=SHA(store.get(prefix+'/RESULT.json')),old_archive_sha256=store.record['sha256'],input_inventory=prior['input_inventory']);inputs=a.output/'input';inputs.mkdir()
   for name,digest in prior['input_inventory']:
    raw=store.get(role.get('inputs',prefix+'/input')+'/'+name);assert SHA(raw)==digest;target=inputs/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
   project=original.m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert original.m.e.auxiliary_magic(project).decode()==magic;build=a.build_root/'bundle'
   cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt','O0','--kernel-opt','O0','--output',str(build)]
   t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(r.stdout);(a.output/'build.stderr').write_text(r.stderr);q['build']=dict(command=cmd,returncode=r.returncode,seconds=time.perf_counter()-t);save();r.check_returncode()
   original.m.validate_bundle(build,a.reference_work,project);q['postimage']=compare(old,build);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());q['status']='ACTUAL_UNSELECTED_NATIVE3_4_OR5_COMPLETE_COMPILED_POSTIMAGE_PASS_NO_MODEL_PERIOD_REPEAT'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.codec,flush=True)


if __name__=='__main__':main()
