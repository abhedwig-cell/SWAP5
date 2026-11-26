"""Current eight unchanged boundary contexts against their exact real producers."""
import argparse,json,platform,subprocess,sys,time
from pathlib import Path
from contextlib import ExitStack
from frost_analytical_boundary_input_contract import source
from frost_analytical_boundary_inputs import prepare
from frost_boundary_git_archive import GitArchiveSource
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
R=Path(__file__).resolve().parents[2]
FIRST='b4ffcc914453225562ffe0e847faa21a765432ce'
CONTINUATION='9d53d55a0ae5aa7567ee62bfcbc60fece1629905'
UNCHANGED=[0,1,2,4,6,9,11,13]


def main():
    p=argparse.ArgumentParser()
    for n in ('reference-work','build-root','output'):p.add_argument('--'+n,type=Path,required=True)
    p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
    assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,contract=source();git=lambda *x:subprocess.check_output(['git',*x],cwd=R)
    assert not git('diff','b24cebc3993b0f350c7aef7fb773a177d00425ce',head,'--','app','src','tools','reference')
    a.output.mkdir();q=dict(status='RUNNING_EIGHT_UNAFFECTED_CURRENT_BOUNDARY_POSTIMAGES',actual_source=head,platform=a.platform,optimization=a.optimization,contexts=[],model_executions=0,compiler_identity_equality_required=True,object_normalization=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');save()
    try:
        with ExitStack() as stack:
            originals={phase:Archive(GitArchiveSource(R,head),f'FROST_ANALYTICAL_BOUNDARY10_{phase}_{a.platform.upper()}_{a.optimization}_ORIGINAL_V1',stack) for phase in ['FIRST','CONTINUATION']}
            for index in UNCHANGED:
                assert source()[0]==head
                phase='FIRST' if index<7 else 'CONTINUATION';producer=FIRST if phase=='FIRST' else CONTINUATION;old=originals[phase];case=contract['representative_cases'][index]
                original_contract=json.loads(git('show',producer+':integration/f-ci/nomacro-complete01/FROST_ANALYTICAL_BOUNDARY10_INPUT_CONTRACT_PROPOSED_V1.json'));assert original_contract['representative_cases'][index]==case
                prior=json.loads(old.get('current/'+case['name']+'/science/RESULT.json'));assert prior['source']==prior['actual_controller_source']==producer and prior['status']=='ACTUAL_ANALYTICAL_BOUNDARY_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_MODEL_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
                folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs';prepare(case,inputs);build=a.build_root/case['name']/'bundle'
                command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                started=time.perf_counter()
                with (folder/'compiler.stdout').open('xb') as out,(folder/'compiler.stderr').open('xb') as err:result=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=300)
                result.check_returncode();meta=json.loads((build/'BUILD.json').read_text());projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'));parent=ReadView(old,projection[prior['build_root']]['archive_prefix']);before=json.loads((parent/'BUILD.json').read_text())
                for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert meta['identity'][key]==before['identity'][key],('Actual unchanged boundary postimage',index,case['name'],key)
                assert meta['inputs']==before['inputs']
                for n,digest in meta['identity']['donor_generated'].items():assert (build/n).read_bytes()==(parent/n).read_bytes() and SHA((build/n).read_bytes())==digest
                objects={p.name for p in build.glob('*.o')};assert objects=={p.name for p in parent.glob('*.o')} and objects
                records=[]
                for n in sorted(objects):
                    raw=(build/n).read_bytes();assert raw==(parent/n).read_bytes(),('Unchanged actual whole object differs',index,n);records.append(dict(file=n,bytes=len(raw),sha256=SHA(raw)))
                q['contexts'].append(dict(case=case,index=index,actual_build_root=str(build),actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),original_BUILD_sha256=SHA((parent/'BUILD.json').read_bytes()),original_source=producer,original_archive_sha256=old.record['sha256'],original_phase=phase,command=command,actual_build_wall_seconds=time.perf_counter()-started,objects=records,model_executions=0));save()
                print('CURRENT_UNCHANGED_BOUNDARY_WHOLE_OBJECT_POSTIMAGE_PASS',index,case['name'],len(objects),flush=True)
        assert source()[0]==head and len(q['contexts'])==8
        q['status']='EIGHT_CURRENT_UNAFFECTED_BOUNDARY_COMPLETE_GENERATED_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY'
    except Exception as exc:q.update(status='FAILED_CURRENT_UNAFFECTED_BOUNDARY_POSTIMAGE',error=repr(exc));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()