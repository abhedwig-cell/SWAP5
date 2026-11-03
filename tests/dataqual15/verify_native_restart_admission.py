"""Compose exact predecessor science with the qualified native I/O successor.

No old verifier or manifest is changed. A committed, isolated preservation view
has the exact predecessor production trees. Its verdict stays historical; the
current source delta and native restart proof are checked independently.
"""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
AREAS=['src','app','reference']

def git(*args,cwd=None,env=None):
    return subprocess.check_output(['git',*args],cwd=cwd or ROOT,env=env,text=True).strip()

def blob(ref,path):
    cp=subprocess.run(['git','rev-parse',ref+':'+path],cwd=ROOT,capture_output=True,text=True)
    return cp.stdout.strip()if cp.returncode==0 else None

def guard(record):
    base=record['predecessor']
    changed=set(git('diff','--name-only','--no-renames',base,'HEAD','--',*AREAS).splitlines())
    assert changed==set(record['production_delta']),'unreviewed production paths'
    assert not git('diff','HEAD','--',*AREAS),'uncommitted production source'
    assert not git('ls-files','--others','--exclude-standard','--',*AREAS),'untracked production source'
    for path,pins in record['production_delta'].items():
        assert blob(base,path)==pins['before']and blob('HEAD',path)==pins['after'],path
    for path,pins in record['preservation_restore'].items():
        assert blob(base,path)==pins['before']and blob('HEAD',path)==pins['after'],path
    assert {area:blob(base,area)for area in AREAS}==record['predecessor_production_trees']
    for path,pin in record['gate_source_sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==pin,path

def prepare(record,out):
    view=(out/'predecessor').resolve()
    assert view.parent==out.resolve()and not view.exists()
    index=out/'projection.index';env=dict(os.environ,GIT_INDEX_FILE=str(index))
    git('read-tree','HEAD',env=env)
    for path,pins in record['preservation_restore'].items():
        if pins['before']is None:git('update-index','--force-remove','--',path,env=env)
        else:git('update-index','--add','--cacheinfo','100644,'+pins['before']+','+path,env=env)
    tree=git('write-tree',env=env);index.unlink()
    assert {area:blob(tree,area)for area in AREAS}==record['predecessor_production_trees']
    commit=git('-c','user.name=Codex','-c','user.email=codex@openai.com','commit-tree',tree,'-p',git('rev-parse','HEAD'),'-m','Exact predecessor preservation projection; no current I/O qualification implied')
    subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),commit],cwd=ROOT,check=True,capture_output=True)
    return view,dict(tree=tree,commit=commit,scope='EXACT_PREDECESSOR_PRODUCTION_NOT_CURRENT_NATIVE_EXECUTION')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--prepare-only',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    data=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())
    record=data['native_disk_restart_20261102']['admission']
    guard(record);events=[]
    def run(label,args,cwd):
        cp=subprocess.run([sys.executable,'-B',*args],cwd=cwd,capture_output=True)
        (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
        events.append(dict(label=label,returncode=cp.returncode,args=args))
        assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-2000:])
    run('current-native',['tests/dataqual15/verify_native_restart_evidence.py'],ROOT)
    if record.get('sensible_stock_owner_admission'):
        run('current-sensible-stock',[record['sensible_stock_owner_admission']['verifier']],ROOT)
    view,projection=prepare(record,out)
    if a.prepare_only:
        (out/'PREPARED.json').write_text(json.dumps(projection,indent=2)+'\n')
        print(view);return
    try:
        run('predecessor-grass',['tests/dataqual15/verify_grass_full_evidence.py','--spec','integration/dataqual15/GRASS_UNION_FULL_SPEC.json','--capsule','integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz','--manifest','integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json'],view)
        run('predecessor-stress',['tests/dataqual15/stress_evidence.py'],view)
        # Includes the unchanged SPRINT03 and UNION_C3 validators exactly once.
        run('predecessor-hupsel',['tests/dataqual15_hupsel/uptake_evidence.py'],view)
        guard(record)
        result=dict(status='EXACT_PREDECESSOR_AND_NATIVE_IO_SUCCESSOR_PASS',candidate=git('rev-parse','HEAD'),projection=projection,events=events,
                    full_current1827_execution=False,whole_scientific_qualification=False)
        (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    finally:
        assert view.resolve().parent==out.resolve()
        subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,check=True)
if __name__=='__main__':main()
