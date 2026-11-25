"""Actual source-bound original Frost boundary builds and full35/cold science."""
import argparse,hashlib,itertools,json,platform,shutil,subprocess,sys,time
from pathlib import Path
from frost_boundary_inputs import prepare
R=Path(__file__).resolve().parents[2]


def source():
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    q=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_BOUNDARY03_CONTRACT_V1.json').read_text())
    base=q['dependency_candidate']
    assert set(git('diff','--name-only',base,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(q['files'])
    for path,item in q['files'].items():
        raw=(R/path).read_bytes().replace(b'\r\n',b'\n')
        assert raw==git('show','HEAD:'+path) and hashlib.sha256(raw).hexdigest()==item['proposed_lf_sha256']
        if item['added']:continue
        old=git('show',base+':'+path);assert hashlib.sha256(old).hexdigest()==item['before_lf_sha256']
        text=old.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert text[edit['base_start']:edit['base_end']]==edit['before']
            parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==raw
    return git('rev-parse','HEAD').decode().strip()


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--platform',choices=('Ubuntu','Windows'),required=True)
    p.add_argument('--previous-proof',type=Path)
    a=p.parse_args();assert platform.system()==('Linux' if a.platform=='Ubuntu' else 'Windows')
    head=source();a.output.mkdir(parents=True)
    q=dict(status='RUNNING_ACTUAL_FROST_BOUNDARY_FULL35_NOT_QUALIFIED',source=head,platform=a.platform,
           optimization=a.optimization,contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def compiled_controls(profile,folder):
        logs=folder/'compiled-controls-controller';logs.mkdir()
        command=[sys.executable,'-B','tests/nomacro_drainage/frost_boundary_controls.py',
                 '--profile',str(profile),'--reference-work',str(a.reference_work),'--output',str(folder/'controls')]
        with (logs/'stdout.bin').open('xb') as stdout,(logs/'stderr.bin').open('xb') as stderr:
            result=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=600)
        observed=dict(returncode=result.returncode,actual_controller_source=head)
        record=folder/'controls/RESULT.json'
        if record.is_file():observed['result']=json.loads(record.read_text())
        return observed
    save()
    try:
        if a.previous_proof is not None:
            # Reuse the actual completed first context only after a fresh complete
            # generated/compiled postimage comparison. Never repeat its full days
            # for this private-owner dispatch repair.
            old=json.loads((a.previous_proof/'current/RESULT.json').read_text())
            assert old['source']=='6049f82bcf265ef17de2ff86a69b4ef4c33f768f'
            completed=[x for x in old['contexts'] if x.get('compiled_controls',{}).get('returncode')==0]
            assert len(completed)==5
            for prior in completed:
                name=prior['case'];parts=name.split('-');kind=parts[0];bottom=int(parts[1][-1]);implicit=int(parts[2][-1])
                assert bottom in (5,8) and kind in ('water','cde') and not (bottom==8 and implicit)
                profile=a.previous_proof/'current'/name/'science'
                science=json.loads((profile/'RESULT.json').read_text())
                assert science['source'] in ('16988131766408867b0c1fa94a3a45cabe68b6fe','6049f82bcf265ef17de2ff86a69b4ef4c33f768f')
                assert science['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+kind.upper()+'_SHORT_PASS_NOT_ADMITTED'
                folder=a.output/'preservation'/name;folder.mkdir(parents=True);inputs=folder/'inputs';prepare(kind,implicit,bottom,inputs)
                inventory=lambda root:{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
                assert inventory(inputs)==inventory(a.previous_proof/'current'/name/'inputs')==science['inventory']
                projection=json.loads((a.previous_proof/'COMPILED_PROJECTION_V1.json').read_text())
                original=a.previous_proof/projection[science['build_root']]['archive_prefix']
                assert hashlib.sha256((original/'BUILD.json').read_bytes()).hexdigest()==projection[science['build_root']]['actual_BUILD_sha256']
                build=a.build_root/'current-preservation'/name
                command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER',
                         '--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',
                         'original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),
                         '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                with (folder/'build.stdout.bin').open('xb') as stdout,(folder/'build.stderr.bin').open('xb') as stderr:
                    result=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=300)
                result.check_returncode()
                from frost_history_state_central import generated,compiled
                comparison=dict(generated=generated(original,build),compiled=compiled(original,build))
                record=dict(case=name,source=science['source'],actual_current_compiler=head,
                            original_science=science,current_generated_compiled=comparison,
                            compiled_controls=prior['compiled_controls'],
                            completed_full35_reused_without_model_replay=True,model_executions=0)
                (folder/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
                q['contexts'].append(record);save()
        for bottom,kind,implicit in itertools.product((5,8),('water','cde'),(0,1)):
            if bottom==8 and implicit:continue
            assert source()==head
            name=f'{kind}-bottom{bottom}-implicit{implicit}-hys2-initial2'
            if name in {x['case'] for x in q['contexts']}:continue
            folder=a.output/name;folder.mkdir();inputs=folder/'inputs';prepare(kind,implicit,bottom,inputs)
            build=a.build_root/name;logs=folder/'controller';logs.mkdir()
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_cde_drainage_runtime.py',
                     '--reference-work',str(a.reference_work),'--build-root',str(build),
                     '--output',str(folder/'science'),'--kind',kind,'--optimization',a.optimization,
                     '--phase','short','--existing-input',str(inputs)]
            start=time.perf_counter()
            with (logs/'stdout.bin').open('xb') as stdout,(logs/'stderr.bin').open('xb') as stderr:
                result=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=600)
            item=dict(case=name,bottom=bottom,kind=kind,implicit=implicit,returncode=result.returncode,
                      seconds=time.perf_counter()-start,actual_controller_source=head)
            q['contexts'].append(item);save()
            if result.returncode:
                item['status']='FAILED_ACTUAL_INDEPENDENT_CONTEXT_RETAINED_NOT_QUALIFIED';save()
                continue
            science=json.loads((folder/'science/RESULT.json').read_text())
            assert science['source']==head and science['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+kind.upper()+'_SHORT_PASS_NOT_ADMITTED'
            item['science']=science;save()
            item['compiled_controls']=compiled_controls(folder/'science',folder);save()
            print('FULL35_AND_CONTROLS',name,a.optimization,item['compiled_controls']['returncode'],flush=True)
        assert len(q['contexts'])==6 and source()==head
        assert not any(item.get('returncode',0) for item in q['contexts']),'Actual failed contexts retained; whole cohort not qualified'
        assert all(item['compiled_controls']['returncode']==0 for item in q['contexts']),'Actual compiled native/transaction controls failed'
        q['status']='SIX_ACTUAL_BOUNDED_FROST_BOUNDARY_FULL35_COLD_COMPILED_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:
        q.update(status='FAILED_ACTUAL_FROST_BOUNDARY_COHORT_NOT_QUALIFIED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
