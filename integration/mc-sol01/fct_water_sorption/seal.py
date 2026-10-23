"""Create generated source/raw evidence, retaining the observed oracle failure."""
import argparse,base64,hashlib,io,json,os,runpy,subprocess,sys,tarfile,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--failed',type=Path,required=True);ap.add_argument('--qualified',type=Path,required=True);a=ap.parse_args()
 files={}
 for label,out in [('oracle_failed',a.failed),('qualified',a.qualified)]:
  r=json.loads((out/'execution.json').read_text());checkpoint=r['baseline']
  files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
  for p,h in r['inputs'].items():
   raw=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(raw)==h
   files[label+'/source/'+p]=raw
  for p in [out/'execution.json',out/'result.json',*(out/e[s] for e in r['events'] for s in ['stdout','stderr'])]:
   if p.exists():files[label+'/'+p.name]=p.read_bytes()
 # Reproduce the already observed failure using its unchanged original oracle
 # against original streams and source snapshots; this is not a new native run.
 with tempfile.TemporaryDirectory() as name:
  base=Path(name)
  for p,v in files.items():
   if p.startswith('oracle_failed/source/'):
    q=base/p[len('oracle_failed/source/'):];q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
  cp=subprocess.run([sys.executable,'-B',str(base/'integration/mc-sol01/fct_water_sorption/run.py'),'--verify-only','--output',str(a.failed.resolve())],capture_output=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
  assert cp.returncode!=0 and b'Failed to converge after 100 iterations' in cp.stderr
  files['oracle_failed/assessment-reproduced.stdout']=cp.stdout;files['oracle_failed/assessment-reproduced.stderr']=cp.stderr
  files['ORACLE_FAILURE.json']=json.dumps(dict(status='ASSESSMENT_FAILED_NATIVE_192_PASSED',observed='Original assessment RuntimeError after100 Brent iterations on near-zero sharp-tail concentration. No Fortran failure. Original terminal stream was not file-captured; separate unchanged-oracle reproduction retained here.',reproduction_returncode=cp.returncode,reproduction_command=cp.args)).encode()
 owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'))
 current=owner['verify']();current_controls=owner['self_test']()
 previous=runpy.run_path(str(ROOT/'integration/mc-sol01/fct_prototype/verify.py'))
 raw=base64.b64decode((ROOT/'integration/mc-sol01/fct_prototype/EVIDENCE.tar.xz.b64').read_bytes())
 assert sha(raw)=='74c05bfb093073db0b3c7a574443383677795c17596879b17c8b617e0a02196a'
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:old={m.name:t.extractfile(m).read() for m in t.getmembers()}
 old.pop('MANIFEST.json');prototype=previous['assess'](old);prototype_controls=previous['controls'](old)
 files['PRESERVATION.json']=json.dumps(dict(current_owner=current,current_controls=len(current_controls),current_control_labels=current_controls,prototype_qualified=True,prototype_result=prototype,prototype_controls=len(prototype_controls)),indent=2).encode()
 verifier=runpy.run_path(str(HERE/'verify.py'));result=verifier['assess'](files);files['VERIFICATION.json']=json.dumps(result,indent=2).encode()
 controls=verifier['controls'](files);files['CONTROLS.json']=json.dumps(controls).encode()
 files['MANIFEST.json']=json.dumps({p:sha(v) for p,v in sorted(files.items())},indent=2).encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz') as t:
  for p,v in sorted(files.items()):
   info=tarfile.TarInfo(p);info.size=len(v);info.mtime=0;t.addfile(info,io.BytesIO(v))
 raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
 index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=sum(e['seconds'] for e in json.loads(files['qualified/execution.json'])['events']))
 (HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n')
 (HERE/'MEASUREMENTS.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(index,indent=2))
if __name__=='__main__':main()
