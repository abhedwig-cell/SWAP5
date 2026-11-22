"""Compile-only integrated postimages for unchanged admitted paired9 configurations."""
import argparse,json,os,subprocess,sys
from contextlib import ExitStack
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_compiled_postimage import compare
from explicit_bottom9_analytical_source_inverse import complete_inverse,git,ANALYTICAL_CORE
import experimental_project as experimental


def role(proof,case,opt,stack):
 if case=='water-last-node-drainage':name='EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1'
 elif case in ('cde-monthly','cde-distributed-subdaily'):name='EXPLICIT_BOTTOM9_CDE_WINDOWS_RAW_V1'
 else:name='EXPLICIT_BOTTOM9_WINDOWS_RAW_V1'
 store=Archive(proof,name,stack);candidates=[]
 for item in store.record['roles']:
  q=json.loads(store.get(item['profile']+'/RESULT.json'))
  if q['case']==case and q['optimization']==opt:candidates.append((item,q))
 assert len(candidates)==1;item,q=candidates[0];source=Archive(proof,item['inputs_archive'],stack) if item.get('inputs_archive') else store
 projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[q['build_root']];old=ReadView(store,entry['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==entry['actual_BUILD_sha256']
 return store,source,item,q,old


def materialize(store,prefix,out,inventory):
 out.mkdir(parents=True);start=prefix+'/'
 actual={}
 for name in sorted(store.names):
  if not name.startswith(start):continue
  relative=name[len(start):];path=(out/relative).resolve();assert path.is_relative_to(out.resolve());raw=store.get(name);path.parent.mkdir(parents=True,exist_ok=True)
  with path.open('xb') as stream:stream.write(raw)
  actual[relative]=SHA(raw)
 assert actual==dict(inventory),'Actual old input directory differs from original accepted inventory'
 return actual


def audit(build,old,metadata):
 prior=json.loads((old/'BUILD.json').read_text());current=json.loads((build/'BUILD.json').read_text());assert prior['project']['nodes']==current['project']['nodes']==34
 source_names=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ('.f90','.f','.for','.inc')}
 a,b=source_names(build),source_names(old);assert a and set(a)==set(b),'Generated source inventory differs';source=[]
 for name,path in sorted(a.items()):
  raw=path.read_bytes();original=b[name].read_bytes();assert raw==original,'Actual integrated generated source differs: '+name
  source.append(dict(file=name,bytes=len(raw),sha256=SHA(raw),status='ACTUAL_COMPLETE_GENERATED_SOURCE_BYTES_EXACT'))
 binary=compare(build,old)
 return dict(status='ACTUAL_NEW_ANALYTICAL_GUARD_PRIOR_CONTEXT_COMPLETE_GENERATED_SOURCE_AND_WHOLE_COMPILED_POSTIMAGE_EXACT',composition_source=ANALYTICAL_CORE,case=metadata['case'],optimization=metadata['optimization'],actual_old_producer=metadata['source'],actual_new_producer=git('rev-parse','HEAD').decode().strip(),generated_source=source,compiled=binary,actual_old_BUILD_sha256=SHA((old/'BUILD.json').read_bytes()),actual_new_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),actual_old_identity=prior['identity'],actual_new_identity=current['identity'],identities_rewritten_or_projected=False,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--case',required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
 for key in ('reference-work','inputs','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();complete_inverse();a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01'
 with ExitStack() as stack:
  archive,inputs,item,q,old=role(proof,a.case,a.optimization,stack);inventory=materialize(inputs,item['inputs'],a.inputs,q['input_inventory']);project=experimental.load(a.inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');assert experimental.switches((a.inputs/'swap.swp').read_text(encoding='cp1252'))['SWBOTB']==9
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(a.build_root/'bundle')]
  with (a.output/'build.stdout').open('x') as stdout,(a.output/'build.stderr').open('x') as stderr:result=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=300)
  result.check_returncode();observation=audit(a.build_root/'bundle',old,q);observation.update(archive=archive.record['archive'],archive_sha256=archive.record['sha256'],original_profile=item['profile'],inputs=str(a.inputs),actual_input_inventory=inventory,build_root=str(a.build_root/'bundle'),compiler_invocation=command)
  (a.output/'RESULT.json').write_text(json.dumps(observation,indent=2)+'\n');print(observation['status'],a.case,a.optimization,flush=True)
