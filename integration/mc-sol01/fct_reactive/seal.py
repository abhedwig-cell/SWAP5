"""Source snapshots and raw streams from actual executions, sealed deterministically."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--round-root',type=Path,required=True);a=ap.parse_args();files={};cost={}
    labels=['round1','round2'];files['ROUNDS.json']=json.dumps(labels).encode()
    for label in labels:
        folder=a.round_root/('reactive-'+label);r=json.loads((folder/'execution.json').read_text());checkpoint=r['baseline']
        files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
        for p,h in r['inputs'].items():
            b=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(b)==h;files[label+'/source/'+p]=b
        paths=[folder/'execution.json',*[folder/p for p in r['generated']]]
        paths.extend(folder/e[s] for e in r['events'] for s in ['stdout','stderr'])
        for p in paths:files[label+'/'+p.name]=p.read_bytes()
        cost[label]=sum(e['seconds'] for e in r['events'])
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_single_zero_pool.py'));result=owner['verify']();controls=owner['self_test']()
    files['PRESERVATION.json']=json.dumps(dict(qualified=result['qualified'],controls=len(controls),result=result,control_labels=controls),indent=2).encode()
    v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files);controls=v['controls'](files)
    files['VERIFICATION.json']=json.dumps(result,indent=2).encode();files['CONTROLS.json']=json.dumps(controls,indent=2).encode()
    files['validator.py']=Path(HERE/'verify.py').read_bytes();files['sealer.py']=Path(__file__).read_bytes()
    files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())},indent=2).encode();stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w:xz',preset=6) as t:
        for p,b in sorted(files.items()):
            m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
    raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
    index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=cost,current_owner_controls=len(json.loads(files['PRESERVATION.json'])['control_labels']))
    for name,data in [('EVIDENCE_INDEX.json',index),('MEASUREMENTS.json',result)]:
        (HERE/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(index,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
