"""Exact native crop logical successor; old authority executes unmodified."""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
import production_diagnostic_admission as predecessor
import native_crop_opaque as candidate
ROOT=predecessor.ROOT;SOURCE=candidate.SOURCE;ENTRY=predecessor.ENTRY;STATUS=predecessor.STATUS
SCOPE='integration/dataqual15_hupsel/PRODUCTION_CROP_LOGICAL_SCOPE_20261105.json'
KEY='native_crop_logical_successor_20261105';BASELINE='5a4d47df19de2fa529878a7b92a7925f52daf819'
AREAS=('src','app','reference')
CONTROL_BRIDGE=('.github/workflows/hupsel-production-diagnostic.yml','tools/vq/select_grass_sprint.py','tests/dataqual15_hupsel/test_grass_sprint_selection.py')
GATES=('tests/dataqual15_hupsel/production_crop_logical_posix.py',ENTRY,'tests/dataqual15_hupsel/production_crop_logical_admission.py','tests/dataqual15_hupsel/production_crop_logical_native.py','tests/dataqual15_hupsel/production_crop_logical_evidence.py','tests/dataqual15_hupsel/native_crop_bool.py','tests/dataqual15_hupsel/native_crop_opaque.py','tests/dataqual15_hupsel/native_crop_opaque_writer.py','tests/dataqual15_hupsel/native_crop_bool_runtime.py','tests/dataqual15_hupsel/native_crop_adapter_runtime.py','tests/dataqual15_hupsel/native_crop_adapter_fixture.py','tests/dataqual15_hupsel/native_crop_weather_runtime.py','tests/dataqual15_hupsel/production_diagnostic_native.py','tests/dataqual15_hupsel/production_diagnostic_guards.py','tests/dataqual15_hupsel/qualify_rotation_restart_guards.py','tests/dataqual15_hupsel/build_and_run.py','tests/dataqual15_hupsel/test_production_crop_logical.py','.github/workflows/hupsel-production-crop-logical.yml',*CONTROL_BRIDGE)
sha=lambda b:hashlib.sha256(b).hexdigest()
git=predecessor.git;blob=predecessor.blob

def old_source():return subprocess.check_output(['git','show',BASELINE+':'+SOURCE],cwd=ROOT).decode()
def postimage():return candidate.candidate(old_source())
def owned(raw):
    r=json.loads(raw);return {key:r.get(key)for key in ('native_disk_restart_20261102','project_diagnostic_restart_successor_20261104',KEY)}

def guard(r):
    assert r['predecessor']==BASELINE and r['whole_scientific_admission']is False
    assert r['scope']=='NATIVE_CROP_HOST_LOGICAL_WORDS_HUPSEL_WEATHER_STREAM_ONLY'and r['rotation_qualified']is False
    assert r['unit_profile']=='Unformatted STREAM; native endian; recorded compiler cohorts only'
    subprocess.run(['git','merge-base','--is-ancestor',BASELINE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
    assert set(r['production_delta'])=={SOURCE} and set(r['bridge_restore'])=={SOURCE,ENTRY,STATUS,*CONTROL_BRIDGE}
    assert set(r['gate_source_sha256'])==set(GATES)
    assert set(git('diff','--name-only','--no-renames',BASELINE,'HEAD','--',*AREAS).splitlines())=={SOURCE}
    assert not git('diff','HEAD','--',*AREAS) and not git('ls-files','--others','--exclude-standard','--',*AREAS)
    assert {a:blob(BASELINE,a)for a in AREAS}==r['predecessor_production_trees']
    assert {a:blob('HEAD',a)for a in ('app','reference')}==r['unchanged_trees']
    for path,pins in r['bridge_restore'].items():
        assert blob(BASELINE,path)==pins['before'],path
        if path==STATUS:
            before=owned(subprocess.check_output(['git','show',BASELINE+':'+STATUS],cwd=ROOT))
            registered=owned(subprocess.check_output(['git','show',pins['after']],cwd=ROOT))
            assert {k:v for k,v in registered.items()if k!=KEY}=={k:v for k,v in before.items()if k!=KEY}
            assert registered[KEY]=={'scope':SCOPE}
            assert owned((ROOT/STATUS).read_bytes())==owned(subprocess.check_output(['git','show','HEAD:'+STATUS],cwd=ROOT))==registered
        else:
            assert blob('HEAD',path)==pins['after']
            assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT)
    assert r['production_delta'][SOURCE]==r['bridge_restore'][SOURCE]
    body=(ROOT/SOURCE).read_bytes().replace(b'\r\n',b'\n');assert body==postimage().encode() and sha(body)==r['postimage_sha256']
    assert all(sha((ROOT/path).read_bytes().replace(b'\r\n',b'\n'))==digest for path,digest in r['gate_source_sha256'].items())

def prepare(r,out):
    out.mkdir(parents=True,exist_ok=True);view=(out/'predecessor').resolve();assert not view.exists()and view.parent==out.resolve()
    index=out/'predecessor.index';env=dict(os.environ,GIT_INDEX_FILE=str(index.resolve()))
    git('read-tree','HEAD',env=env)
    for path,pins in r['bridge_restore'].items():git('update-index','--add','--cacheinfo','100644,'+pins['before']+','+path,env=env)
    tree=git('write-tree',env=env);index.unlink()
    assert {a:blob(tree,a)for a in AREAS}==r['predecessor_production_trees']
    assert all(blob(tree,path)==pins['before']for path,pins in r['bridge_restore'].items())
    commit=git('-c','user.name=Codex','-c','user.email=codex@users.noreply.github.com','commit-tree',tree,'-p',git('rev-parse','HEAD'),'-m','Exact pre-crop-logical production and unmodified admission authority')
    p=subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),commit],cwd=ROOT,env=predecessor.process_env(),capture_output=True)
    (out/'worktree.stdout').write_bytes(p.stdout);(out/'worktree.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
    return view,dict(commit=commit,tree=tree,scope='EXACT_UNMODIFIED_PREDECESSOR_NOT_CURRENT_RUNTIME_PROOF')

def inherited(view,out):
    events=[];env=predecessor.process_env(dict(os.environ,PYTHONUTF8='1'))
    for label,args in (('old-admission',[ENTRY,'--output',str(out/'old-admission')]),('opaque-proof',['tests/dataqual15_hupsel/native_crop_opaque_evidence.py']),('opaque-posix',['tests/dataqual15_hupsel/native_crop_opaque_posix.py']),('weather-proof',['tests/dataqual15_hupsel/native_crop_weather_evidence.py']),('weather-posix',['tests/dataqual15_hupsel/native_crop_weather_posix.py'])):
        p=subprocess.run([sys.executable,'-B',*args],cwd=view,env=env,capture_output=True)
        (out/(label+'.stdout')).write_bytes(p.stdout);(out/(label+'.stderr')).write_bytes(p.stderr)
        events.append(dict(label=label,returncode=p.returncode));assert p.returncode==0,(label,p.stderr[-3000:])
    return events

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True)
    r=json.loads((ROOT/SCOPE).read_text());guard(r)
    if a.prepare_only:
        view,projection=prepare(r,out);(out/'PREPARED.json').write_text(json.dumps(projection,indent=2)+'\n');print(view);return
    from production_crop_logical_evidence import verify
    proof=verify(r)
    work=Path(tempfile.mkdtemp(prefix='s5l-')).resolve()if os.name=='nt'else out
    view,projection=prepare(r,work)
    try:
        events=inherited(view,work);guard(r)
        for e in events:
            for stream in ('stdout','stderr'):
                path=work/(e['label']+'.'+stream)
                if work!=out:shutil.copyfile(path,out/path.name)
        (out/'RESULT.json').write_text(json.dumps(dict(status='EXACT_CURRENT_CROP_LOGICAL_RUNTIME_AND_UNMODIFIED_PREDECESSOR_PASS',projection=projection,current_runtime=proof,events=events,whole_scientific_admission=False),indent=2)+'\n')
        print('EXACT_CURRENT_CROP_LOGICAL_RUNTIME_AND_UNMODIFIED_PREDECESSOR_PASS')
    finally:
        subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,env=predecessor.process_env(),check=True,capture_output=True)
        if work!=out:
            assert work.parent==Path(tempfile.gettempdir()).resolve()and work.name.startswith('s5l-');shutil.rmtree(work)

if __name__=='__main__':main()
