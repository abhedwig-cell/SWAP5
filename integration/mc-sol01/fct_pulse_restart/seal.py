"""Retain actual initial pulse, current pulse/disk executions and all state bytes."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--round-root',type=Path,required=True);a=ap.parse_args();files={};cost={}
    labels=['round1','round2'];files['ROUNDS.json']=json.dumps(labels).encode()
    for label in labels:
        folder=a.round_root/('pulse-disk-'+label);r=json.loads((folder/'execution.json').read_text());checkpoint=r['baseline']
        files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
        for p,h in r['inputs'].items():
            b=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(b)==h;files[label+'/source/'+p]=b
        paths=[folder/'execution.json',*[folder/p for p in r['generated']],*[folder/p for p in r['artifacts']]]
        paths.extend(folder/e[s] for e in r['events'] for s in ['stdout','stderr'])
        for p in paths:files[label+'/'+str(p.relative_to(folder))]=p.read_bytes()
        cost[label]=sum(e['seconds'] for e in r['events'])
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_single_zero_pool.py'));r=owner['verify']();c=owner['self_test']()
    old=runpy.run_path(str(HERE.parent/'fct_reactive/verify.py'));index=json.loads((HERE.parent/'fct_reactive/EVIDENCE_INDEX.json').read_text())
    f=old['unpack'](HERE.parent/'fct_reactive/EVIDENCE.tar.xz.b64',index['decoded_sha256']);old['assess'](f);prior=old['controls'](f)
    files['PRESERVATION.json']=json.dumps(dict(qualified=r['qualified'],controls=len(c),control_labels=c,result=r,reactive_controls=len(prior),reactive_control_labels=prior),indent=2).encode()
    # Preserve and reproduce the original validator path-classification failure.
    old_source=subprocess.check_output(['git','show','05d0e5e2:integration/mc-sol01/fct_pulse_restart/verify.py'],cwd=ROOT)
    ns=dict(__file__=str(HERE/'verify.py'),__name__='failed_validation')
    exec(compile(old_source,'failed_validation/verify.py','exec'),ns)
    try:ns['assess'](files)
    except AssertionError:
        files['failed_validation/verify.py']=old_source
        files['failed_validation/stderr']=traceback.format_exc().encode()
        files['failed_validation/receipt.json']=json.dumps(dict(status='REPRODUCED_VALIDATOR_FAILURE',
            cause='Output root name pulse-disk matched substring pulse- for disk builds. Fixed by selecting the immediate build-directory name.',
            original_source_checkpoint='05d0e5e2',native_numerics_changed=False)).encode()
    else:raise AssertionError('expected original validation failure absent')
    v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files);controls=v['controls'](files)
    files['VERIFICATION.json']=json.dumps(result,indent=2).encode();files['CONTROLS.json']=json.dumps(controls,indent=2).encode()
    for p in ['verify.py','accuracy.py','seal.py']:files['validation/'+p]=(HERE/p).read_bytes()
    files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())},indent=2).encode();stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w:xz',preset=6) as t:
        for p,b in sorted(files.items()):
            m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
    raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
    index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=cost,current_owner_controls=len(c),predecessor_reactive_controls=len(prior))
    for name,data in [('EVIDENCE_INDEX.json',index),('MEASUREMENTS.json',result)]:
        (HERE/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(index,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
