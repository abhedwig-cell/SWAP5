"""Fresh whole-object builds of unchanged implicit plate branches, no models."""
import argparse,json,platform,subprocess,sys,time
from pathlib import Path
from contextlib import ExitStack
from frost_implicit_hys2_input_contract import source
from frost_implicit_plate_metadata import read as read_parent
from frost_implicit_plate_inputs import prepare
from frost_boundary_git_archive import GitArchiveSource
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
R=Path(__file__).resolve().parents[2]
NAMES={'water-b8-i1-h2-p2-parent-dense','cde-b8-i1-h2-p2-parent-dense','cde-b8-i1-h0-p2-dates-r1','cde-b8-i1-h1-p1-dense-r1'}


def main():
    p=argparse.ArgumentParser()
    for n in ('reference-work','build-root','output'):p.add_argument('--'+n,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,_=source();contract=read_parent('FROST_IMPLICIT_PLATE05_CONTRACT_V1.json');cases=contract['representative_cases'];assert len(cases)==8
    a.output.mkdir();q=dict(status='RUNNING_CURRENT_UNCHANGED_IMPLICIT_PLATE_COMPILED_POSTIMAGES_NOT_ADMITTED',actual_source=head,platform=a.platform,optimization=a.optimization,contexts=[],model_executions=0,compiler_identity_equality_required=True,object_normalization=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        with ExitStack() as stack:
            archives={v:Archive(GitArchiveSource(R,head),f'FROST_IMPLICIT_PLATE05_{a.platform.upper()}_{a.optimization}_ORIGINAL_V{v}',stack) for v in (1,2)}
            for case in cases:
                old=archives[1 if case['name'] in NAMES else 2]
                original_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'))
                assert source()[0]==head
                folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs';prepare(case,inputs);build=a.build_root/case['name']/'bundle'
                cmd=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                started=time.perf_counter()
                with (folder/'compiler.stdout').open('xb') as out,(folder/'compiler.stderr').open('xb') as err:result=subprocess.run(cmd,cwd=R,stdout=out,stderr=err,timeout=300)
                result.check_returncode();meta=json.loads((build/'BUILD.json').read_text());prior=json.loads(old.get('current/'+case['name']+'/science/RESULT.json'));parent=ReadView(old,original_projection[prior['build_root']]['archive_prefix']);before=json.loads((parent/'BUILD.json').read_text())
                for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:
                    assert meta['identity'][key]==before['identity'][key],('Actual unchanged postimage metadata',case['name'],key)
                assert meta['inputs']==before['inputs']
                names={n.name for n in build.glob('*.o')};previous={n.name for n in parent.glob('*.o')};assert names==previous and names
                objects=[]
                for name in sorted(names):
                    raw=(build/name).read_bytes();assert raw==(parent/name).read_bytes(),('Whole original object differs',case['name'],name)
                    objects.append(dict(file=name,bytes=len(raw),sha256=SHA(raw)))
                q['contexts'].append(dict(case=case,actual_build_root=str(build),actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),original_BUILD_sha256=SHA((parent/'BUILD.json').read_bytes()),original_source=prior['source'],original_archive_sha256=old.record['sha256'],command=cmd,actual_build_wall_seconds=time.perf_counter()-started,objects=objects,model_executions=0));save()
                print('CURRENT_WHOLE_UNCHANGED_IMPLICIT_PLATE_OBJECTS_PASS',case['name'],len(objects),flush=True)
            assert source()[0]==head
        q['status']='EIGHT_CURRENT_UNCHANGED_IMPLICIT_PLATE_COMPLETE_SOURCE_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_CURRENT_UNCHANGED_IMPLICIT_PLATE_POSTIMAGE_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
