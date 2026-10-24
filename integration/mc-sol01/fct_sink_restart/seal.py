"""Preserve actual fresh processes, physical states, and current owner proof."""
import base64,hashlib,io,json,runpy,subprocess,tarfile,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();folder=a.output
 r=json.loads((folder/'execution.json').read_text());files={'ROUNDS.json':b'["round1"]'}
 files['round1/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
 for p,h in r['inputs'].items():
  b=subprocess.check_output(['git','show',r['baseline']+':'+p],cwd=ROOT);assert sha(b)==h;files['round1/source/'+p]=b
 for p in ['execution.json',*r['generated'],*r['artifacts'],*[e[s] for e in r['events'] for s in ['stdout','stderr']]]:files['round1/'+p]=(folder/p).read_bytes()
 owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_single_zero_pool.py'));result=owner['verify']();controls=owner['self_test']()
 files['PRESERVATION.json']=json.dumps(dict(qualified=result['qualified'],controls=len(controls),result=result,control_labels=controls)).encode()
 v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files);checks=v['controls'](files)
 files['VERIFICATION.json']=json.dumps(result).encode();files['CONTROLS.json']=json.dumps(checks).encode()
 for p in ['verify.py','seal.py']:files['validation/'+p]=(HERE/p).read_bytes()
 files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())}).encode();stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz') as t:
  for p,b in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
 index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=checks,current_owner_controls=len(controls),measured_seconds=sum(e['seconds'] for e in r['events']))
 (HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n');(HERE/'MEASUREMENTS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(index));print(json.dumps(result))
if __name__=='__main__':main()
