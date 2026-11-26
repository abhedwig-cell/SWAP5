"""Preserve actual parent ordinary and Frost compiler surfaces without periods."""
import argparse,json,subprocess,sys,time
from contextlib import ExitStack
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_runtime import m
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'

def main():
 p=argparse.ArgumentParser()
 for n in ['output','build-root','reference-work']:p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args();a.output.mkdir();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=R)
 q=dict(status='RUNNING_ORIGINAL_PARENT_ORDINARY_FROST_COMPLETE_OBJECT_POSTIMAGES',actual_compiler_source=head,actual_canonical_parent=BASE,optimization=a.optimization,compiler_executions=0,model_executions=0,model_days=0,contexts=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   data=GitArchiveSource(R,head);stores={name:Archive(data,name,stack) for name in ['IMPLICIT_HYDRAULIC_STATE11_GUARD_RAW_V1','FROST_UNDRAINED_STATE08_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2']};opt=a.optimization;profiles=[]
   guard=stores['IMPLICIT_HYDRAULIC_STATE11_GUARD_RAW_V1'];profiles.append(('ordinary-implicit-model1',guard,'actual-feedback/hys0-with-alfaw/inputs','actual-builds/'+opt+'/old-baseline/bundle',BASE))
   for name in ['cde-d0-b5-i1-h2-p2-dense','water-d0-b8-i1-h2-p1-dates-r0-year-seam']:
    store=stores['FROST_UNDRAINED_STATE08_LOCAL_WINDOWS_O0_O2_RAW_V1'];prefix='current/'+opt+'-'+name;old=json.loads(store.get(prefix+'/science/RESULT.json'));projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));profiles.append(('implicit-hys2-'+name,store,prefix+'/inputs',projection[old['build_root']]['archive_prefix'],old['source']))
   for name in ['default-model1-water-d0-b6-dense','model7-cde-d1-b8-dense']:
    store=stores['FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V1'];prefix='original07/'+opt+'-'+name;old=json.loads(store.get(prefix+'/science/RESULT.json'));projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));profiles.append(('explicit-'+name,store,prefix+'/inputs',projection[old['build_root']]['archive_prefix'],old['source']))
   store=stores['FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2'];projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
   for item in store.record['contexts']:
    if item['optimization']!=opt:continue
    prefix=item['archive_prefix'];old=json.loads(store.get(prefix+'/science/RESULT.json'));profiles.append(('explicit-'+item['case']['name'],store,prefix+'/inputs',projection[old['build_root']]['archive_prefix'],old['source']))
   assert len(profiles)==8
   for name,store,input_prefix,build_prefix,producer in profiles:
    folder=a.output/name;inputs=folder/'inputs';inputs.mkdir(parents=True);before=ReadView(store,build_prefix);old=json.loads((before/'BUILD.json').read_text())
    for n in store.names:
     if n.startswith(input_prefix+'/'):
      target=inputs/n[len(input_prefix)+1:];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(store.get(n))
    assert inputs.is_dir() and (inputs/'swap.swp').is_file();build=a.build_root/name/'bundle';policy=old['identity']['time_step_policy'];command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)];start=time.perf_counter()
    with (folder/'build.stdout').open('xb') as out,(folder/'build.stderr').open('xb') as err:child=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=300)
    q['compiler_executions']+=1;child.check_returncode();project=m.e.load(inputs,original_output=True,time_step_policy=policy);meta,_=m.validate_bundle(build,a.reference_work,project)
    for key in ['compiler','compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert old['identity'][key]==meta['identity'][key],(name,key)
    assert old['inputs']==meta['inputs']
    sources={v.name:v.read_bytes() for v in before.glob('*.f90')};current={v.name:v.read_bytes() for v in build.glob('*.f90')};assert sources and sources.keys()==current.keys() and all(raw==current[n] for n,raw in sources.items()),(name,'source')
    objects={v.name:v.read_bytes() for v in before.glob('*.o')};current={v.name:v.read_bytes() for v in build.glob('*.o')};assert objects and objects.keys()==current.keys() and all(raw==current[n] for n,raw in objects.items()),(name,'whole object')
    q['contexts'].append(dict(case=name,actual_original_producer=producer,actual_original_archive_sha256=store.record['sha256'],original_build_prefix=build_prefix,original_input_prefix=input_prefix,actual_original_BUILD_sha256=SHA((before/'BUILD.json').read_bytes()),actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),build_root=str(build),input_root=str(inputs),command=command,seconds=time.perf_counter()-start,all_complete_source_files_identical=True,whole_objects={n:SHA(raw) for n,raw in objects.items()},all_input_bytes_identical=True,PE_link_bytes_retained_separately_not_normalized=True,model_periods_replayed=0));save();print('ACTUAL_PARENT_WHOLE_SOURCE_OBJECT_POSTIMAGES_PASS',opt,name,len(objects),flush=True)
   assert len(q['contexts'])==8 and subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head;q['status']='EIGHT_ORIGINAL_PARENT_ORDINARY_EXPLICIT_IMPLICIT_HYS2_DRAINAGE01_FROST_COMPLETE_SOURCE_AND_WHOLE_OBJECTS_PASS_ZERO_MODEL_DAYS'
 except Exception as error:q.update(status='FAILED_ORIGINAL_PARENT_COMPILER_POSTIMAGES',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)
if __name__=='__main__':main()
