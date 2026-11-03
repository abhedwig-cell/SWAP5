"""Reuse exact compiled native objects after an unrelated link failure."""
import hashlib
import json
from pathlib import Path
import subprocess


def verified_objects(prior,root,ordered,shadow,optimization,compiler):
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    r=json.loads((prior/'RESULT.json').read_text(encoding='utf-8'))
    assert r['optimization']==optimization and r['compiler']==compiler
    # Current Git objects prove that the captured compiler inputs did not change.
    # The Python orchestrator is not a compiled input and may fix the failed link.
    for path,blob in r['source_git_blob'].items():
        if path in ('tests/dataqual15/qualify_nonlinear_native_contact.py','tests/dataqual15/research_native_build_cache.py'):continue
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=root,text=True).strip()==blob,path
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=root),path
    old=[];objects=[]
    for event in r['events']:
        if not event['label'].startswith('compile-') or not event['label'][8:].isdigit():continue
        assert event['returncode']==0
        command=event['command'];assert '-'+optimization in command and '-fcheck=all' in command
        old.append(Path(command[-3]));objects.append(Path(command[-1]))
    assert len(old)==len(ordered)
    entries=[];selected=[]
    for before,after,obj in zip(old,ordered,objects):
        if sha(before)!=sha(after):
            # This external program provides no module used by other objects.
            # Recompile it; no changed physics/provider object may be inherited.
            assert after==shadow['app/solute_project/main_water.f90'], (before,after,'changed compiled input')
            selected.append(None)
        else:selected.append(obj)
        entries.append(dict(source_sha256=sha(before),object=str(obj),object_sha256=sha(obj)))
    certificate=prior/'EXACT_OBJECTS.json'
    if certificate.exists():assert json.loads(certificate.read_text(encoding='utf-8'))==entries
    else:certificate.write_text(json.dumps(entries,indent=2)+'\n',encoding='utf-8')
    # TTUTIL was separately built from pinned original source authorities.
    utility=prior/'original';u=json.loads((utility/'BUILD.json').read_text(encoding='utf-8'))
    assert u['status']=='BUILT' and u['compiler']==compiler and '-'+optimization in u['flags']
    for p,digest in u['authority_sha256'].items():assert sha(root/p)==digest,p
    for p,digest in u['source_sha256'].items():assert sha(utility/p)==digest,p
    for p,digest in u['object_sha256'].items():assert sha(utility/p)==digest,p
    assert sha(utility/'ttobj/libttutil.a')==u['input_archive_sha256']
    return selected,utility,entries
