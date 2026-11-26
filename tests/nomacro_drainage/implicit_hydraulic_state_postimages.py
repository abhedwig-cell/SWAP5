"""Current genuine public builds versus whole original implicit-state objects."""
import argparse,json,subprocess,sys,time
from contextlib import ExitStack
from pathlib import Path,PureWindowsPath
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from implicit_hydraulic_state_local_science import CASES,SHA
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_runtime import m
DATA='eec8ed3edd0ce957065d52d3966dc434c01f0827'
W=PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600')


def main():
 p=argparse.ArgumentParser()
 for n in ['output','build-root','reference-work']:p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args();a.output.mkdir()
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=R)
 result=dict(status='RUNNING_ACTUAL_IMPLICIT_HYDRAULIC_WHOLE_GENERATED_AND_OBJECT_POSTIMAGES',actual_current_compiler_source=head,actual_original_data_source=DATA,optimization=a.optimization,compiler_executions=0,model_executions=0,model_days=0,contexts=[])
 save=lambda:(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   archive=Archive(GitArchiveSource(R,DATA),'IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2',stack)
   def locate(path):
    relative=PureWindowsPath(path).relative_to(W);assert '..' not in relative.parts
    return ReadView(archive,'actual/'+relative.as_posix())
   for name,suffix in CASES.items():
    original=ReadView(archive,'actual/ih11-analysis-v1/'+name+'-'+a.optimization+suffix);q=json.loads((original/'RESULT.json').read_text());before=locate(q['build_root']);old=json.loads((before/'BUILD.json').read_text());assert SHA((before/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    inputs=a.output/name/'inputs';inputs.mkdir(parents=True);origin=locate(q['input_root'])
    for member in archive.names:
     if member.startswith(origin.path+'/'):
      relative=member[len(origin.path)+1:];target=inputs/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.get(member))
    assert list(m.e.inventory(inputs))==[tuple(v) for v in q['input_inventory']]
    build=a.build_root/name/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)];start=time.perf_counter()
    with (a.output/name/'build.stdout').open('xb') as out,(a.output/name/'build.stderr').open('xb') as err:child=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
    result['compiler_executions']+=1;child.check_returncode();project=m.e.load(inputs,original_output=True);meta,_=m.validate_bundle(build,a.reference_work,project)
    for key in ['compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert old['identity'][key]==meta['identity'][key],(name,key)
    sources={f.name:f.read_bytes() for f in before.glob('*.f90')};current={f.name:f.read_bytes() for f in build.glob('*.f90')};assert sources.keys()==current.keys() and all(raw==current[n] for n,raw in sources.items()),name
    objects={f.name:f.read_bytes() for f in before.glob('*.o')};after={f.name:f.read_bytes() for f in build.glob('*.o')};assert objects and objects.keys()==after.keys() and all(raw==after[n] for n,raw in objects.items()),name
    item=dict(case=name,actual_current_source=head,actual_original_scientific_source=q['actual_source'],actual_original_BUILD_sha256=q['actual_BUILD_sha256'],actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),original_archive_sha256=archive.record['sha256'],build_root=str(build),input_root=str(inputs),actual_command=command,seconds=time.perf_counter()-start,generated_files={n:SHA(v) for n,v in sources.items()},whole_objects={n:SHA(v) for n,v in objects.items()},all_input_bytes_identical=True,all_complete_generated_sources_identical=True,all_complete_objects_identical=True,PE_link_bytes_retained_separately_not_normalized=True,old_model_periods_replayed=0)
    result['contexts'].append(item);save();print('ACTUAL_WHOLE_OBJECT_POSTIMAGES_PASS',name,a.optimization,len(objects),flush=True)
   assert len(result['contexts'])==9
  assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
  result['status']='NINE_ACTUAL_CURRENT_PUBLIC_IMPLICIT_MODEL_STATE_BUILDS_COMPLETE_GENERATED_WHOLE_OBJECTS_AND_SDK_POSTIMAGES_PASS_NO_MODEL_REPLAY'
 except Exception as error:result.update(status='FAILED_ACTUAL_IMPLICIT_HYDRAULIC_POSTIMAGES',error=repr(error));raise
 finally:save()
 print(result['status'],flush=True)


if __name__=='__main__':main()
