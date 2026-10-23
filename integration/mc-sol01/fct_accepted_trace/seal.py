"""Generate deterministic sealed proof; source snapshots follow each real checkpoint."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for name in ['water-failed','replay-failed-1','replay-failed-2','water','replay','reference-failed','reference']:ap.add_argument('--'+name,type=Path,required=True)
 a=ap.parse_args();files={};cost={}
 for label,folder in vars(a).items():
  r=json.loads((folder/'execution.json').read_text());checkpoint=r['baseline']
  files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
  for p,h in r['inputs'].items():
   raw=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(raw)==h
   files[label+'/source/'+p]=raw
  paths=[folder/'execution.json',folder/'result.json',folder/'storage_successor.f90']
  paths.extend(folder/e[s] for e in r.get('events',[]) for s in ['stdout','stderr'])
  paths.extend(folder/c['path'] for c in r.get('water_cases',[]))
  for p in paths:
   if p.exists():files[label+'/'+p.name]=p.read_bytes()
  cost[label]=sum(e['seconds'] for e in r.get('events',[]))+sum(e['seconds'] for e in r.get('references',[]))+sum(e['seconds'] for e in r.get('extensions',[]))
 # Retain the rejected prefix output even though it was not a successful case.
 for p in a.water_failed.glob('water-*.txt'):files['water_failed/'+p.name]=p.read_bytes()
 owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'));current=owner['verify']();cc=owner['self_test']()
 preservation=dict(current_qualified=current['qualified'],current_controls=len(cc),current_control_labels=cc)
 for name,digest in [('storage','36764e94f77d3dbdd01f540abba9a672c2437ac4660398f7302a289e15ddc4d2'),('prototype','74c05bfb093073db0b3c7a574443383677795c17596879b17c8b617e0a02196a')]:
  folder=ROOT/('integration/mc-sol01/fct_water_sorption' if name=='storage' else 'integration/mc-sol01/fct_prototype')
  v=runpy.run_path(str(folder/'verify.py'));f=v['unpack'](folder/'EVIDENCE.tar.xz.b64',digest) if name=='storage' else None
  if f is None:
   raw=base64.b64decode((folder/'EVIDENCE.tar.xz.b64').read_bytes());assert sha(raw)==digest
   with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:f={m.name:t.extractfile(m).read() for m in t.getmembers()}
   manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in f.items()}
  v['assess'](f);preservation[name+'_qualified']=True;preservation[name+'_controls']=len(v['controls'](f))
 files['PRESERVATION.json']=json.dumps(preservation,indent=2).encode()
 verifier=runpy.run_path(str(HERE/'verify.py'));result=verifier['assess'](files);files['VERIFICATION.json']=json.dumps(result,indent=2).encode()
 controls=verifier['controls'](files);files['CONTROLS.json']=json.dumps(controls,indent=2).encode()
 files['MANIFEST.json']=json.dumps({p:sha(v) for p,v in sorted(files.items())},indent=2).encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz',preset=9) as t:
  for p,v in sorted(files.items()):
   info=tarfile.TarInfo(p);info.size=len(v);info.mtime=0;t.addfile(info,io.BytesIO(v))
 raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
 index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=cost)
 (HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n');(HERE/'MEASUREMENTS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(index,indent=2))
if __name__=='__main__':main()
