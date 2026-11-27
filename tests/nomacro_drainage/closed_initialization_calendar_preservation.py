"""Current old SWINCO1 source/object postimages and original native state, zero days."""
import argparse,io,json,struct,subprocess,sys,time,zipfile
from pathlib import Path
from contextlib import ExitStack
from closed_initialization_calendar_feedback import R,PARENT,SHA,git,m
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual,compare
from closed_default_calendar_feedback import prepare as prepare_original_initial1
from closed_default_calendar import selection


def native(checkpoint,build,project,folder):
    folder.mkdir();original=folder/'original-accepted-day4.zip';original.write_bytes(checkpoint)
    with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:receipt=json.loads(z.read('checkpoint.json'));good=z.read('macro.bin')
    assert receipt['receipt']['day']==4 and good[:8] in [b'S5IOW001',b'S5IHW001',b'S5CIC001',b'S5CIH001']
    wrong=bytearray(good);struct.pack_into('<i',wrong,8,project.nodes+1)
    attacks=[('own-positive',good),('foreign-magic',b'S5BAD999'+good[8:]),('truncated',good[:-1]),('trailing',good+b'x'),('foreign-node-count',bytes(wrong))]
    controls=[]
    for name,raw in attacks:
        out=folder/name;out.mkdir();origin=out/'origin';old=m.h.verify_checkpoint(original,4,receipt['binding'],origin);(origin/'macro.bin').write_bytes(raw)
        worker=out/'original';m.h.prepare_column(Path(project.input_directory),worker,m.h.ColumnStart('original',4,origin,old),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (out/'donor.stdout').write_bytes(child.stdout);(out/'donor.stderr').write_bytes(child.stderr)
        assert b'HYBRID_DAY_RETURN' not in child.stdout and SHA(original.read_bytes())==SHA(checkpoint)
        if name=='own-positive':
            assert child.returncode in (0,100) and not child.stderr and b'HYBRID_READY' in child.stdout
            lines=child.stdout.decode().splitlines();ready=next(i for i,v in enumerate(lines) if v.startswith('HYBRID_READY '));lines=lines[:ready]
            stock=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_STOCK_FLUX ')][-1]
            heads=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_HYDRAULIC ')][-1]
            assert stock[:6]==old['stock_end_cm'] and heads[2:]==old['pressure_head_cm'] and heads[0]==old['groundwater_cm']
        else:assert child.returncode not in (0,100) and b'ERROR STOP' in child.stderr and b'HYBRID_READY' not in child.stdout
        controls.append(dict(control=name,actual_mutant_sha256=SHA(raw),returncode=child.returncode,model_days=0))
    return dict(actual_original_checkpoint_sha256=SHA(checkpoint),actual_original_binding=receipt['binding'],actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),controls=controls,model_days=0)


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-root','reference-work']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args();a.output.mkdir()
    head=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    result=dict(status='RUNNING_CURRENT_OLD_INITIAL1_COMPLETE_OBJECT_AND_NATIVE_PRESERVATION',actual_compiler_source=head,actual_accepted_parent=PARENT,optimization=a.optimization,contexts=[],model_days=0,model_executions=0,canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');save()
    try:
        with ExitStack() as stack:
            data=GitArchiveSource(R,PARENT);store=Archive(data,'CLOSED_DEFAULT_CALENDAR_STATE14_ALL_LOCAL_FAILURES_AND_SUCCESSES_RAW_V2',stack)
            assert store.record['sha256']=='736057de6b483eb42bb3e36e57b6277d0cc3136c15f35fce625f98d693c8106a'
            plan=json.loads((data/'CLOSED_DEFAULT_CALENDAR_STATE14_FINITE_CASE_PLAN_V1.json').read_text())
            for spec in plan['cases']:
                name=spec['name'];version='v3' if name in ['implicit-perstep-water','hys1-clock-water'] else 'v1'
                prefix='actual/evidence/closure14-feedback-'+version+'/'+a.optimization+'/'+name
                old_result=json.loads(store.get(prefix+'/RESULT.json'));assert old_result['status']=='ACTUAL_CLOSED_DEFAULT_CALENDAR_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED'
                before=actual(store,old_result['build_root']);old=json.loads((before/'BUILD.json').read_text());assert SHA((before/'BUILD.json').read_bytes())==old_result['actual_BUILD_sha256']
                folder=a.output/name;folder.mkdir();inputs=folder/'inputs';authority=prepare_original_initial1(spec,inputs)
                assert dict(m.e.inventory(inputs))==old['inputs'];project=m.e.load(inputs,original_output=True)
                assert selection(project)['initial']==1 and selection(project)['policy']=='original-closed-default-pressure-nondaily-calendar-composition-v1'
                build=a.build_root/name/'bundle';command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                started=time.perf_counter()
                with (folder/'build.stdout').open('xb') as out,(folder/'build.stderr').open('xb') as err:child=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
                child.check_returncode();meta,_=m.validate_bundle(build,a.reference_work,project)
                assert meta['identity']['original_output']==old['identity']['original_output']
                proof=compare(before,build,old_result['actual_BUILD_sha256'],SHA((build/'BUILD.json').read_bytes()))
                controls=native(store.get(prefix+'/trajectory/accepted-column-1-day-4.zip'),build,project,folder/'native-controls')
                result['contexts'].append(dict(case=name,actual_original_scientific_producer=old_result['actual_source'],actual_original_archive_sha256=store.record['sha256'],actual_original_profile=prefix,actual_original_build_prefix=before.path,actual_original_BUILD_sha256=old_result['actual_BUILD_sha256'],actual_current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),build_root=str(build),input_root=str(inputs),actual_input_authority=authority,whole_object_proof=proof,compiled_original_native=controls,seconds=time.perf_counter()-started,actual_command=command));save()
                print('CURRENT_ORIGINAL_INITIAL1_COMPLETE_OBJECTS_AND_NATIVE_PASS',a.optimization,name,proof['actual_complete_objects'],flush=True)
            assert len(result['contexts'])==5
        assert git('rev-parse','HEAD').decode().strip()==head
        result['status']='FIVE_CURRENT_OLD_INITIAL1_COMPLETE_GENERATED_OBJECTS_AND_ORIGINAL_NATIVE_READERS_PASS_ZERO_MODEL_DAYS'
    except Exception as error:result.update(status='FAILED_CURRENT_OLD_INITIAL1_PRESERVATION',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
