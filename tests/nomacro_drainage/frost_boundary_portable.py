"""Actual source-bound original Frost boundary builds and full35/cold science."""
import argparse,hashlib,itertools,json,platform,subprocess,sys,time
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
    a=p.parse_args();assert platform.system()==('Linux' if a.platform=='Ubuntu' else 'Windows')
    head=source();a.output.mkdir(parents=True)
    q=dict(status='RUNNING_ACTUAL_FROST_BOUNDARY_FULL35_NOT_QUALIFIED',source=head,platform=a.platform,
           optimization=a.optimization,contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for bottom,kind,implicit in itertools.product((5,8),('water','cde'),(0,1)):
            assert source()==head
            name=f'{kind}-bottom{bottom}-implicit{implicit}-hys2-initial2'
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
            q['contexts'].append(item);save();result.check_returncode()
            science=json.loads((folder/'science/RESULT.json').read_text())
            assert science['source']==head and science['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+kind.upper()+'_SHORT_PASS_NOT_ADMITTED'
            item['science']=science;save();print('PASS',name,a.optimization,flush=True)
        assert len(q['contexts'])==8 and source()==head
        q['status']='EIGHT_ACTUAL_FROST_BOUNDARY_FULL35_AND_OWN_COLD_PASS_NOT_ADMITTED'
    except Exception as error:
        q.update(status='FAILED_ACTUAL_FROST_BOUNDARY_COHORT_NOT_QUALIFIED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
