"""Seal raw six-case observations, failed wet pilot and immutable build bindings."""
import base64,hashlib,io,json,runpy,tarfile
from pathlib import Path
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 root=HERE.parents[2];scratch=root.parent;files={}
 for label,folder in [('runs',scratch/'consistent-dry'),('failed_wet_pilot',scratch/'consistent-native')]:
  files.update({label+'/'+str(p.relative_to(folder)):p.read_bytes() for p in folder.rglob('*') if p.is_file()})
 for p in ['run.py','verify.py','seal.py']:files['validation/'+p]=(HERE/p).read_bytes()
 files['OWNER.json']=(scratch/'consistent-owner.json').read_bytes()
 predecessor=HERE.parent/'fct_native_refinement/EVIDENCE_INDEX.json';files['BUILD_AUTHORITY.json']=predecessor.read_bytes()
 v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files);controls=[]
 for p in ['runs/o0-1/state.csv','runs/o2-4/budget.csv','validation/run.py']:
  f=dict(files);f.pop(p)
  try:v['assess'](f)
  except (AssertionError,KeyError):controls.append('missing '+p);continue
  raise AssertionError(p)
 f=dict(files);p='runs/o2-4/project.swp';f[p]=f[p].replace(b'-8.,.2',b'-7.,.2')
 try:v['assess'](f)
 except AssertionError:controls.append('changed shared initial ramp')
 else:raise AssertionError('accepted ramp')
 files['VERIFICATION.json']=json.dumps(result).encode();files['CONTROLS.json']=json.dumps(controls).encode()
 files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in files.items()}).encode();s=io.BytesIO()
 with tarfile.open(fileobj=s,mode='w:xz') as t:
  for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=s.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw));(HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(dict(sha256=sha(raw),bytes=len(raw),members=len(files),result=result,controls=controls),indent=2)+'\n')
 print(json.dumps(result,indent=2))
if __name__=='__main__':main()
