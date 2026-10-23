"""Seal actual rounds, source checkpoints, streams and composed preservation."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--round-root',type=Path,required=True);a=ap.parse_args();files={};cost={}
    labels=['round1','round2','round3','round4','round5'];files['ROUNDS.json']=json.dumps(labels).encode()
    for label in labels:
        folder=a.round_root/('sinks-'+label);r=json.loads((folder/'execution.json').read_text());checkpoint=r['baseline']
        files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
        for p,h in r['inputs'].items():
            b=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(b)==h;files[label+'/source/'+p]=b
        paths=[folder/'execution.json',*[folder/p for p in r['generated']]]
        paths.extend(folder/e[s] for e in r['events'] for s in ['stdout','stderr'])
        for p in paths:files[label+'/'+str(p.relative_to(folder))]=p.read_bytes()
        cost[label]=sum(e['seconds'] for e in r['events'])
    files['LAUNCH_FAILURES.json']=json.dumps(dict(round1='Compiler wrapper PermissionError before version invocation; no native result, UNKNOWN.',
      round2='Version succeeded; compiler wrapper PermissionError before first build; native result UNKNOWN.',
      round4='Process matrix and24 joint O0 cases complete; new joint O2 binary lost executable mode before invocation. Native remaining outcomes UNKNOWN.',
      recovery='Existing executable GNU13.3 compiler wrapper selected; round3 process complete. Runner now sets execute bit on its own compiled artifacts and captures launch errors. New complete round5 required.',
      original_error_stream='Only interactive tool output; not captured by initial subprocess OSError path. This summary is not an original raw stderr stream.')).encode()
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_single_zero_pool.py'));r=owner['verify']();c=owner['self_test']()
    old=runpy.run_path(str(HERE.parent/'fct_pulse_restart/verify.py'));index=json.loads((HERE.parent/'fct_pulse_restart/EVIDENCE_INDEX.json').read_text())
    prior_files=old['unpack'](HERE.parent/'fct_pulse_restart/EVIDENCE.tar.xz.b64',index['decoded_sha256']);old['assess'](prior_files);prior=old['controls'](prior_files)
    files['PRESERVATION.json']=json.dumps(dict(qualified=r['qualified'],controls=len(c),control_labels=c,result=r,pulse_controls=len(prior),pulse_control_labels=prior),indent=2).encode()
    validation_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    files['validation/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',validation_checkpoint],cwd=ROOT)
    files['validation/identity.json']=json.dumps(dict(commit=validation_checkpoint)).encode()
    for p in ['verify.py','seal.py']:
        b=(HERE/p).read_bytes()
        assert b==subprocess.check_output(['git','show',validation_checkpoint+':'+str((HERE/p).relative_to(ROOT))],cwd=ROOT)
        files['validation/'+p]=b
    v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files);controls=v['controls'](files)
    files['VERIFICATION.json']=json.dumps(result,indent=2).encode();files['CONTROLS.json']=json.dumps(controls,indent=2).encode()
    files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())},indent=2).encode();stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w:xz',preset=6) as t:
        for p,b in sorted(files.items()):
            m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
    raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
    index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=cost,current_owner_controls=len(c),predecessor_pulse_controls=len(prior))
    for name,data in [('EVIDENCE_INDEX.json',index),('MEASUREMENTS.json',result)]:
        (HERE/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(index,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
