"""Build only integrated closures against original immutable Windows periods."""
import argparse,json,subprocess,sys,time
from pathlib import Path
from contextlib import ExitStack
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_compiled_postimage import compare
from explicit_bottom9_analytical_parent_postimages import materialize,role as prior_role
from explicit_bottom9_combined_source import verify
from explicit_bottom9_source_inverse import git
import experimental_project as experimental

def generated(left,right):
 suffixes={'.f90','.f','.for','.inc'}
 files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in suffixes}
 a,b=files(left),files(right);assert a and set(a)==set(b);observations=[]
 for name,path in sorted(a.items()):
  old=path.read_bytes();new=b[name].read_bytes();assert old.replace(b'\r\n',b'\n')==new.replace(b'\r\n',b'\n'),name
  observations.append(dict(file=name,original_sha256=SHA(old),integrated_sha256=SHA(new),original_bytes=len(old),integrated_bytes=len(new)))
 x=json.loads((left/'BUILD.json').read_text())['identity'];y=json.loads((right/'BUILD.json').read_text())['identity']
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):assert x[field]==y[field],field
 return observations

def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=('O0','O2'),required=True)
 for key in ('build-root','output','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();source=verify();head=source['actual_head'];a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01';result=dict(status='RUNNING',actual_source=head,source_proof=source,optimization=a.optimization,contexts=[],model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   selections=[]
   for family in ('HISTORY','SNOW','ANALYTICAL'):
    store=Archive(proof,'EXPLICIT_BOTTOM9_'+family+'_WINDOWS_RAW_V1',stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
    for role in store.record['roles']:
     if role['optimization']!=a.optimization:continue
     q=json.loads(store.get(role['profile']+'/RESULT.json'));entry=projection[q['build_root']];old=ReadView(store,entry['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']
     selections.append((family,store,role,q,old))
   for case in ('water-pressure-step','age-pressure-step','cde-pressure-daily','cde-monthly','cde-distributed-subdaily','water-last-node-drainage'):
    store,inputs,role,q,old=prior_role(proof,case,a.optimization,stack);selections.append(('PRIOR',inputs,role,q,old))
   assert len(selections)==22
   for index,(family,inputs,role,q,old) in enumerate(selections):
    label=f'{index:02d}-'+family.lower()+'-'+Path(role['profile']).name;out=a.output/label;out.mkdir();directory=out/'input';materialize(inputs,role['inputs'],directory,q['input_inventory']);project=experimental.load(directory,original_output=True,time_step_policy='original-adaptive-day-seed-v1');build=a.build_root/label/'bundle'
    cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',str(project.model),'--experimental-project',str(directory),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
    before=git('rev-parse','HEAD').decode().strip();assert before==head;start=time.monotonic()
    with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:run=subprocess.run(cmd,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
    after=git('rev-parse','HEAD').decode().strip();assert after==before and run.returncode==0,(label,run.returncode)
    observation=dict(family=family,role=role,original_source=q['source'],original_profile_RESULT_sha256=SHA(inputs.get(role['profile']+'/RESULT.json')) if family!='PRIOR' else None,actual_compiler_start_HEAD=before,actual_compiler_end_HEAD=after,command=cmd,seconds=time.monotonic()-start,build_root=str(build),input_root=str(directory),actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),complete_generated_sources=generated(old,build),all_compiled=compare(old,build),model_executions=0)
    (out/'RESULT.json').write_text(json.dumps(observation,indent=2)+'\n');result['contexts'].append(dict(label=label,family=family,output=str(out),build_root=str(build)));save();print('ACTUAL_INTEGRATED_WHOLE_SOURCE_AND_COMPILED_POSTIMAGE_PASS',label,flush=True)
   assert git('rev-parse','HEAD').decode().strip()==head;verify()
   result.update(status='ALL22_OPT_INTEGRATED_ANALYTICAL_SNOW_HISTORY_AND_PRIOR_WHOLE_COMPILED_POSTIMAGES_PASS_NO_MODEL_PERIODS',compiler_executions=22)
 except Exception as error:result.update(status='FAILED',error=repr(error));raise
 finally:save()

if __name__=='__main__':main()
