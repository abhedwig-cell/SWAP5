"""Compiler-only Ubuntu preservation of all sixteen new sibling contexts."""
import argparse,json,subprocess,sys,time
from contextlib import ExitStack
from pathlib import Path
from explicit_bottom9_combined_postimages import ROOT,Archive,SHA,ReadView,materialize,generated,compare,experimental,git,verify

def main():
 p=argparse.ArgumentParser();p.add_argument('--optimization',choices=('O0','O2'),required=True)
 for key in ('build-root','output','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();source=verify();head=source['actual_head'];a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01';result=dict(status='RUNNING',actual_source=head,source_proof=source,optimization=a.optimization,contexts=[],model_executions=0,canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   selections=[];prefix='/home/runner/work/_temp/proof/'
   def relative(path):assert path.startswith(prefix);return path[len(prefix):]
   for family in ('HISTORY','SNOW','ANALYTICAL'):
    name='EXPLICIT_BOTTOM9_'+family+'_UBUNTU_'+a.optimization+('_ORIGINAL_V1' if family=='HISTORY' else '_RAW_V1');store=Archive(proof,name,stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
    if family=='HISTORY':roles=json.loads(store.get('RESULT.json'))['profiles']
    else:roles=json.loads(store.get(family+'-'+a.optimization+'-BATCH.json'))['contexts']
    for role in roles:
     profile=role['profile'] if family=='HISTORY' else relative(role['profile']);q=json.loads(store.get(profile+'/RESULT.json'));entry=projection[q['build_root']];old=ReadView(store,entry['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']
     inputs=role['primary_input'] if family=='HISTORY' else relative(q['input_root']);selections.append((family,store,role,q,old,profile,inputs))
   assert len(selections)==16
   for index,(family,store,role,q,old,profile,inputs) in enumerate(selections):
    label=f'{index:02d}-'+family.lower()+'-'+Path(profile).name;out=a.output/label;out.mkdir();directory=out/'input';materialize(store,inputs,directory,q['input_inventory']);project=experimental.load(directory,original_output=True,time_step_policy='original-adaptive-day-seed-v1');build=a.build_root/label/'bundle'
    cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',str(project.model),'--experimental-project',str(directory),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
    before=git('rev-parse','HEAD').decode().strip();assert before==head;start=time.monotonic()
    with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:run=subprocess.run(cmd,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
    after=git('rev-parse','HEAD').decode().strip();assert after==before and run.returncode==0,(label,run.returncode)
    observation=dict(family=family,role=role,original_source=q['source'],original_archive_sha256=store.record['sha256'],original_profile_RESULT_sha256=SHA(store.get(profile+'/RESULT.json')),actual_compiler_start_HEAD=before,actual_compiler_end_HEAD=after,command=cmd,seconds=time.monotonic()-start,build_root=str(build),input_root=str(directory),actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),complete_generated_sources=generated(old,build),all_compiled=compare(old,build),model_executions=0)
    (out/'RESULT.json').write_text(json.dumps(observation,indent=2)+'\n');result['contexts'].append(dict(label=label,family=family,output=str(out),build_root=str(build)));save();print('ACTUAL_UBUNTU_INTEGRATED_WHOLE_SOURCE_AND_COMPILED_POSTIMAGE_PASS',label,flush=True)
   assert git('rev-parse','HEAD').decode().strip()==head;verify();result.update(status='ALL16_OPT_UBUNTU_INTEGRATED_ANALYTICAL_SNOW_HISTORY_WHOLE_COMPILED_POSTIMAGES_PASS_NO_MODEL_PERIODS',compiler_executions=16)
 except Exception as error:result.update(status='FAILED',error=repr(error));raise
 finally:save()

if __name__=='__main__':main()
