"""Build exact old native3/4 inputs and compare full compiled source postimages."""
import argparse,ast,json,subprocess,sys,time,types
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
import original_output_matrix as original


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--codec',choices=('native3','native4'),required=True);a=p.parse_args();a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01'
 archive,prefix=('HYDRAULIC_ANALYTICAL_CALENDAR_WINDOWS_RAW_V1','profiles/analytical-calendar-vapor8-nprint2-O0-v1') if a.codec=='native3' else ('HYDRAULIC_SNOW_VAPOR_WINDOWS_RAW_V1','profiles/snow-vapor-cde-O0-v3')
 q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),archive=archive,old_profile=prefix,codec=a.codec,build_root=str(a.build_root/'bundle'),input_root=str(a.output/'input'),model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   store=Archive(proof,archive,stack);profile=store.view(prefix);prior=json.loads((profile/'RESULT.json').read_text());projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));old=store.view(projection[prior['build_root']]['archive_prefix']);q.update(old_producer=prior['source'],old_RESULT_sha256=SHA((profile/'RESULT.json').read_bytes()),old_archive_sha256=store.record['sha256'],input_inventory=prior['input_inventory']);inputs=a.output/'input';inputs.mkdir()
   for name,digest in prior['input_inventory']:
    target=inputs/name;target.parent.mkdir(parents=True,exist_ok=True);raw=(profile/'input'/name).read_bytes();assert SHA(raw)==digest;target.write_bytes(raw)
   project=original.m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert original.m.e.auxiliary_magic(project)==(b'S5HVW003' if a.codec=='native3' else b'S5HSC004');build=a.build_root/'bundle'
   command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt','O0','--kernel-opt','O0','--output',str(build)]
   start=time.perf_counter();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/'build.stdout').write_text(result.stdout);(a.output/'build.stderr').write_text(result.stderr);q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-start);save();result.check_returncode()
   actual,_=original.m.validate_bundle(build,a.reference_work,project);before=json.loads((old/'BUILD.json').read_text())
   for field in ('donor_objects','donor_flags','kernel_flags'):assert before['identity'][field]==actual['identity'][field]
   old_sources={file.name:file.read_bytes().replace(b'\r\n',b'\n') for file in old.glob('*.f90')};new_sources={file.name:file.read_bytes().replace(b'\r\n',b'\n') for file in build.glob('*.f90')};assert old_sources==new_sources
   q['complete_generated_Fortran']={name:SHA(raw) for name,raw in new_sources.items()};q['identity_changes']=differences(before['identity'],actual['identity']);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes())
   exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda path:path));q['publisher_equivalence']=exact(old/'restart_publish.dll',build/'restart_publish.dll')
   # For both old prefixes the new branch is unreachable, and the entire old
   # decoder function remains exact after removing that single literal branch.
   path='app/hybrid_water/cde_native_receipt.py';current=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');base=subprocess.check_output(['git','show','70bae8871ec71b3c0969a6628cae596354f9c2e8:'+path],cwd=ROOT)
   function=lambda raw:next(node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='decode');now=function(current);previous=function(base);matches=[node for node in now.body if isinstance(node,ast.If) and ast.unparse(node.test)=="aux[:8] == b'S5HBC005'"];assert len(matches)==1;now.body.remove(matches[0]);assert ast.dump(now,include_attributes=False)==ast.dump(previous,include_attributes=False)
   q['status']='ACTUAL_UNSELECTED_NATIVE3_OR_NATIVE4_COMPLETE_FORTRAN_PROVIDER_FLAGS_AND_PE_POSTIMAGE_EXACT_NO_MODEL_PERIOD_REPEATED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.codec,flush=True)


if __name__=='__main__':main()
