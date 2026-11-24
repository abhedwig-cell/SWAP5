"""Complete the bounded explicit Frost state matrix without replaying saved runs."""
import argparse,hashlib,itertools,json,os,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface')]
import frost_cde_drainage_runtime as runtime
from original_output_baseline import assignment
from experimental_project import inventory
import frost_history_state_model_forensics as science
BASE='e0461f005b95b9f68bc70d4d4698eff903bc04ed'
CLEANUP=Path('C:/Users/Veldh012/OneDrive - Wageningen University & Research/Documents/ChatGPT/SWAP5-finaliseren/tools/storage/cleanup.py')
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'


def source():
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    q=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_HYSTERESIS_STATE01_CONTRACT_V1.json').read_text())
    assert set(git('diff','--name-only',BASE,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(q['files'])|{q['added_file']['path']}
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    for path,item in q['files'].items():
        old=git('show',BASE+':'+path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert sha(old)==item['before_lf_sha256'] and sha(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
        text=old.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            lo,hi=edit['base_start'],edit['base_end'];assert cursor<=lo<=hi and text[lo:hi]==edit['before'];parts.extend((text[cursor:lo],edit['after']));cursor=hi
        parts.append(text[cursor:]);assert ''.join(parts).encode()==actual
    path=q['added_file']['path'];actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert sha(actual)==q['added_file']['sha256'] and actual==git('show','HEAD:'+path)
    return git('rev-parse','HEAD').decode().strip()


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','output','reference-work'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();head=source();a.output.mkdir();q=dict(status='RUNNING_BOUNDED_EXPLICIT_FROST_MATRIX_NOT_ADMITTED',source=head,contexts=[],canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def storage(*args):
        r=subprocess.run([sys.executable,'-B',str(CLEANUP),*args],cwd=CLEANUP.parents[2],capture_output=True,check=True);return json.loads(r.stdout)
    save()
    try:
        q['space_preflight']=storage('check-space','--large-job');save()
        for kind,hys,initial,opt in itertools.product(('water','cde'),(0,1),(1,2),('O0','O2')):
            assert source()==head
            stem='frost-history-state01-explicit-'+kind+'-hys'+str(hys)+'-initial'+str(initial)
            inputs=a.evidence/(stem+'-input-v1');label=stem+'-'+opt+'-v1';profile=a.evidence/label
            if not inputs.exists():
                runtime.thermal.fixture(inputs,'water-frost-drained',3);path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
                for key,value in dict(SWSOLU=int(kind=='cde'),SWHYST=hys,SWINCO=initial).items():text=assignment(text,key,value)
                if kind=='cde':text=assignment(text,'CPRE','0.01')
                path.write_text(text,encoding='cp1252');path=inputs/'swap.dra';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWDIVD',1),encoding='cp1252')
            reused=profile.exists()
            if reused:
                assert (kind,hys,initial,opt) in {('water',0,1,'O0'),('cde',1,2,'O0'),('cde',1,2,'O2')}
                original=json.loads((profile/'RESULT.json').read_text());assert original['status'].endswith('PASS_NOT_ADMITTED')
                assert not subprocess.check_output(['git','diff',original['source'],head,'--','app','src','tools','reference'],cwd=R)
            else:
                allocated=storage('allocate','--task',TASK,'--kind','build','--name',label,'--variant',opt,'--source-ref',head,'--recipe','Actual existing Frost model1 hys'+str(hys)+' initial'+str(initial)+' '+kind+' '+opt+' original35days and3exactcold; unchanged owning1e-10 guards')
                command=[sys.executable,'-B','tests/nomacro_drainage/frost_cde_drainage_runtime.py','--reference-work',str(a.reference_work),'--build-root',allocated['path'],'--output',str(profile),'--kind',kind,'--optimization',opt,'--phase','short','--existing-input',str(inputs)]
                with (a.output/(label+'.stdout')).open('xb') as out,(a.output/(label+'.stderr')).open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=600)
                assert source()==head;r.check_returncode()
            independent=science.audit(profile,a.reference_work)
            (a.output/(label+'-independent.json')).write_text(json.dumps(independent,indent=2)+'\n')
            q['contexts'].append(dict(kind=kind,hysteresis=hys,initial=initial,optimization=opt,profile=str(profile),input_inventory=inventory(inputs),existing_original_period_reused_without_rerun=reused,independent=independent));save()
            print('PASS',kind,hys,initial,opt,'reused' if reused else 'new',len(q['contexts']),flush=True)
        assert len(q['contexts'])==16 and source()==head
        q.update(status='SIXTEEN_WINDOWS_EXPLICIT_FROST_STATE_CONTEXTS_35DAY_AND_48_COLD_INDEPENDENT_PASS_NOT_ADMITTED',original_completed_periods_reused=3,new_periods_executed=13)
    except Exception as error:q.update(status='FAILED_BOUNDED_FROST_MATRIX_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
