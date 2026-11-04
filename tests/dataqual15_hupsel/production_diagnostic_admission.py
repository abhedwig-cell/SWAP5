"""Exact current app postimage plus unmodified committed predecessor authority."""
import argparse, hashlib, json, os, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = 'app/solute_project/hupsel_rotation_restart.f90'
ENTRY = 'tests/dataqual15/verify_current_native_admission.py'
STATUS = 'integration/dataqual15/STATUS.json'
SCOPE = 'integration/dataqual15_hupsel/PRODUCTION_DIAGNOSTIC_SCOPE_20261104.json'
AREAS = ('src','app','reference')
GATES = (ENTRY,'tests/dataqual15_hupsel/production_diagnostic_admission.py',
         'tests/dataqual15_hupsel/production_diagnostic_evidence.py',
         'tests/dataqual15_hupsel/production_diagnostic_native.py',
         'tests/dataqual15_hupsel/production_diagnostic_guards.py',
         'tests/dataqual15_hupsel/production_diagnostic_posix.py',
         'tests/dataqual15_hupsel/qualify_rotation_restart_guards.py',
         'tests/dataqual15_hupsel/build_and_run.py',
         'tests/dataqual15_hupsel/test_production_diagnostic_admission.py',
         '.github/workflows/hupsel-production-diagnostic.yml')


def git(*args, env=None, cwd=None):
    return subprocess.check_output(['git',*args],cwd=cwd or ROOT,env=env,text=True).strip()


def blob(ref,path):
    p=subprocess.run(['git','rev-parse',ref+':'+path],cwd=ROOT,capture_output=True,text=True)
    return p.stdout.strip() if p.returncode==0 else None


def owned_status(raw):
    value=json.loads(raw)
    return {key:value.get(key) for key in ('native_disk_restart_20261102','project_diagnostic_restart_successor_20261104')}


def current_guard(record):
    base=record['predecessor']
    subprocess.run(['git','merge-base','--is-ancestor',base,'HEAD'],cwd=ROOT,check=True,capture_output=True)
    assert set(record['production_delta'])=={APP}
    assert set(record['bridge_restore'])=={APP,ENTRY,STATUS}
    assert set(record['gate_source_sha256'])==set(GATES)
    changed=set(git('diff','--name-only','--no-renames',base,'HEAD','--',*AREAS).splitlines())
    assert changed=={APP},'unreviewed production paths'
    assert not git('diff','HEAD','--',*AREAS),'uncommitted production source'
    assert not git('ls-files','--others','--exclude-standard','--',*AREAS),'untracked production source'
    for path,pins in record['bridge_restore'].items():
        assert blob(base,path)==pins['before'],path
        if path==STATUS:
            registered=owned_status(subprocess.check_output(['git','show',pins['after']],cwd=ROOT))
            before=owned_status(subprocess.check_output(['git','show',base+':'+STATUS],cwd=ROOT))
            assert registered['native_disk_restart_20261102']==before['native_disk_restart_20261102'],'old native authority drift'
            assert registered['project_diagnostic_restart_successor_20261104']=={'scope':SCOPE},'unreviewed successor route'
            assert owned_status(subprocess.check_output(['git','show','HEAD:'+STATUS],cwd=ROOT))==registered,'native status drift'
            assert owned_status((ROOT/STATUS).read_bytes())==registered,'dirty native status'
        else:
            assert blob('HEAD',path)==pins['after'],path
            assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT),path
    assert record['production_delta'][APP]==record['bridge_restore'][APP]
    assert {area:blob(base,area) for area in AREAS}==record['predecessor_production_trees']
    for area,pin in record['unchanged_trees'].items():assert blob('HEAD',area)==pin,area
    assert hashlib.sha256((ROOT/APP).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==record['compiled_app_postimage_sha256']
    for path,pin in record['gate_source_sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==pin,path


def prepare(record,out):
    view=(out/'predecessor').resolve();assert not view.exists() and view.parent==out.resolve()
    index=out/'predecessor.index';env=dict(os.environ,GIT_INDEX_FILE=str(index.resolve()))
    git('read-tree','HEAD',env=env)
    for path,pins in record['bridge_restore'].items():
        git('update-index','--add','--cacheinfo','100644,'+pins['before']+','+path,env=env)
    tree=git('write-tree',env=env);index.unlink()
    assert {area:blob(tree,area) for area in AREAS}==record['predecessor_production_trees']
    # The exact old entrypoint and STATUS suppress the new delegation naturally;
    # no diagnostic override or weakened old source validator is installed.
    assert blob(tree,ENTRY)==record['bridge_restore'][ENTRY]['before']
    assert blob(tree,STATUS)==record['bridge_restore'][STATUS]['before']
    commit=git('-c','user.name=Codex','-c','user.email=codex@users.noreply.github.com',
               'commit-tree',tree,'-p',git('rev-parse','HEAD'),'-m','Exact pre-S5HR4 predecessor authority; not current runtime evidence')
    subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),commit],cwd=ROOT,check=True,capture_output=True)
    return view,dict(tree=tree,commit=commit,scope='EXACT_PREDECESSOR_PRODUCTION_AND_UNMODIFIED_ADMISSION_AUTHORITY')


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--prepare-only',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True)
    record=json.loads((ROOT/SCOPE).read_text());current_guard(record)
    from production_diagnostic_evidence import verify
    proof=verify(record);view,projection=prepare(record,out);events=[]
    if a.prepare_only:
        (out/'PREPARED.json').write_text(json.dumps(projection,indent=2)+'\n');print(view);return
    def run(label,args):
        r=subprocess.run([sys.executable,'-B',*args],cwd=view,capture_output=True,env=dict(os.environ,PYTHONUTF8='1'))
        (out/(label+'.stdout')).write_bytes(r.stdout);(out/(label+'.stderr')).write_bytes(r.stderr)
        events.append(dict(label=label,args=args,returncode=r.returncode));assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-2000:])
    try:
        run('unmodified-predecessor-admission',[ENTRY,'--output',str(out/'old-admission')])
        run('qualified-default-runtime',['tests/dataqual15_hupsel/default_diagnostic_evidence.py'])
        current_guard(record)
        result=dict(status='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS',
                    current=git('rev-parse','HEAD'),projection=projection,current_native=proof,events=events,
                    whole_scientific_admission=False,oxygen_reference_correction=False)
        (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
    finally:
        assert view.resolve().parent==out.resolve()
        subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,check=True,capture_output=True)


if __name__=='__main__':main()
