"""Current complete old numerical objects; original native readers, zero model days."""
import argparse,json,subprocess,sys,time,zipfile,io
from contextlib import ExitStack
from pathlib import Path,PureWindowsPath
from closed_default_calendar_feedback import R,PARENT,SHA,git,m
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual,compare


def native(checkpoint,build,project,folder):
    folder.mkdir();checkpoint_path=folder/'original-accepted-day4.zip';checkpoint_path.write_bytes(checkpoint)
    with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:meta=json.loads(z.read('checkpoint.json'));good=z.read('macro.bin')
    assert meta['receipt']['day']==4
    suffixes=[i for i in range(len(good)-8) if good[i:i+8] in (b'S5IHX001',b'S5IFX001')];assert len(suffixes)==1;pos=suffixes[0]
    attacks=[('own-positive',good),('foreign-magic',b'S5BAD999'+good[8:]),('missing-domain',good[:pos]),('truncated',good[:-1]),('trailing',good+b'x')];result=[]
    for name,raw in attacks:
        out=folder/name;out.mkdir();origin=out/'origin';receipt=m.h.verify_checkpoint(checkpoint_path,4,meta['binding'],origin);(origin/'macro.bin').write_bytes(raw)
        worker=out/'original';m.h.prepare_column(Path(project.input_directory),worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (out/'donor.stdout').write_bytes(child.stdout);(out/'donor.stderr').write_bytes(child.stderr)
        assert b'HYBRID_DAY_RETURN' not in child.stdout and SHA(checkpoint_path.read_bytes())==SHA(checkpoint)
        if name=='own-positive':
            assert child.returncode in (0,100) and not child.stderr and b'HYBRID_READY' in child.stdout
            lines=child.stdout.decode().splitlines();ready=next(i for i,line in enumerate(lines) if line.startswith('HYBRID_READY '));lines=lines[:ready]
            stocks=[list(map(float,line.split()[1:])) for line in lines if line.startswith('HYBRID_STOCK_FLUX ')];heads=[list(map(float,line.split()[1:])) for line in lines if line.startswith('HYBRID_HYDRAULIC ')]
            assert stocks[-1][:6]==receipt['stock_end_cm'] and heads[-1][2:]==receipt['pressure_head_cm'] and heads[-1][0]==receipt['groundwater_cm']
        else:assert child.returncode not in (0,100) and b'ERROR STOP' in child.stderr and b'HYBRID_READY' not in child.stdout
        result.append(dict(control=name,mutant_sha256=SHA(raw),returncode=child.returncode,actual_compiled_reader=True,model_days=0))
    return dict(actual_original_checkpoint_sha256=SHA(checkpoint),actual_original_binding=meta['binding'],actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),controls=result,model_days=0)


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-root','reference-work']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args();a.output.mkdir()
    head=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    result=dict(status='RUNNING_CURRENT_OLD_NUMERICAL_OBJECT_PRESERVATION',actual_compiler_source=head,actual_accepted_parent=PARENT,optimization=a.optimization,model_days=0,model_executions=0,contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    save()
    try:
        with ExitStack() as stack:
            store=Archive(GitArchiveSource(R,PARENT),'CLOSED_IMPLICIT_STATE13_FORTY_NATIVE_PRESERVATION_RAW_V8',stack)
            assert store.record['sha256']=='1e07ff4764eeae2c5f705a1985d1897237f6c50fc7145abc196f4fa23df9cd68'
            for role,count in [('current',12),('parent',8)]:
                prefix='actual/evidence/closure13-native-preservation-v2/'+a.optimization+'/'+role
                old_result=json.loads(store.get(prefix+'/RESULT.json'));assert len(old_result['contexts'])==count
                for item in old_result['contexts']:
                    name=role+'-'+item['case'];folder=a.output/name;inputs=folder/'inputs';inputs.mkdir(parents=True)
                    before=actual(store,item['build_root']);old=json.loads((before/'BUILD.json').read_text());assert SHA((before/'BUILD.json').read_bytes())==item['actual_current_BUILD_sha256']
                    origin=actual(store,item['input_root'])
                    for member in store.names:
                        if member.startswith(origin.path+'/'):
                            relative=member[len(origin.path)+1:];target=inputs/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(store.get(member))
                    assert dict(m.e.inventory(inputs))==old['inputs']
                    policy=old['identity']['time_step_policy'];build=a.build_root/name/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                    started=time.perf_counter()
                    with (folder/'build.stdout').open('xb') as out,(folder/'build.stderr').open('xb') as err:child=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
                    child.check_returncode();project=m.e.load(inputs,original_output=True,time_step_policy=policy);meta,_=m.validate_bundle(build,a.reference_work,project)
                    proof=compare(before,build,item['actual_current_BUILD_sha256'],SHA((build/'BUILD.json').read_bytes()))
                    controls=None
                    if role=='current':controls=native(store.get(prefix+'/'+item['case']+'/native-controls/original-accepted-day4.zip'),build,project,folder/'native-controls')
                    result['contexts'].append(dict(case=name,actual_source=head,actual_original_archive_sha256=store.record['sha256'],original_build_prefix=before.path,actual_original_BUILD_sha256=item['actual_current_BUILD_sha256'],actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),build_root=str(build),input_root=str(inputs),whole_object_proof=proof,compiled_original_native=controls,seconds=time.perf_counter()-started,actual_command=command))
                    save();print('ACTUAL_COMPLETE_OLD_SOURCES_OBJECTS_AND_NATIVE_PASS',name,a.optimization,proof['actual_complete_objects'],flush=True)
            assert len(result['contexts'])==20
        assert git('rev-parse','HEAD').decode().strip()==head
        result['status']='TWENTY_ACTUAL_OLD_COMPLETE_GENERATED_AND_OBJECT_CONTEXTS_CURRENT_NATIVE_READERS_PASS_ZERO_MODEL_DAYS'
    except Exception as error:result.update(status='FAILED_CURRENT_OLD_NUMERICAL_OBJECT_PRESERVATION',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
