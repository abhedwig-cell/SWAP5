"""Recover exact research inputs/providers, never current no-macro model code."""
import argparse,hashlib,io,json,subprocess,tarfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args();r=a.workspace;r.mkdir(exist_ok=False)
old=ROOT/'research/hybrid-water01';sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha((old/'original-macro-481-evidence.zip').read_bytes())=='c7b4cb52b86b07cf08a116603590e597c0ab6bd89780afc000e7d03e07512463'
provider=old/'hybrid-hupsel-linux-20261111.tar.xz'
assert sha(provider.read_bytes())=='feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'
with tarfile.open(provider) as t:
 for m in t:
  if m.isfile() and (m.name.startswith('generic-reference/') or m.name=='PROOF_INDEX.json'):
   d=r/'provider'/m.name;d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(t.extractfile(m).read())
with zipfile.ZipFile(old/'original-macro-481-evidence.zip') as z:
 z.extractall(r/'proof')
 with zipfile.ZipFile(io.BytesIO(z.read('qualified/artifact.zip'))) as q:
  for n in q.namelist():
   if n.startswith('O2/build/') and not n.endswith('/'):
    d=r/n;d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(q.read(n))
  (r/'native4.zip').write_bytes(q.read('O2/fresh/accepted-column-1-day-4.zip'))
 with zipfile.ZipFile(io.BytesIO(z.read('segments/4/artifact.zip'))) as q:(r/'native432.zip').write_bytes(q.read('resume-304-to-481/accepted-column-1-day-432.zip'))
ref='84e297af23b2b6e90c927b958fecb5e24228b975'
# Source identities validated by the original frozen host, not rebound to HEAD.
paths=subprocess.check_output(['git','ls-tree','-r','--name-only',ref,'app/hybrid_water','app/support'],cwd=ROOT,text=True).splitlines()
m=json.loads((r/'O2/build/BUILD.json').read_text());paths+=list(n for n,d in m['identity']['kernel_sources'])
for n in paths:
 d=r/'frozen'/n;d.parent.mkdir(parents=True,exist_ok=True);d.write_bytes(subprocess.check_output(['git','show',ref+':'+n],cwd=ROOT))
for name,digest in m['identity']['donor_objects'].items():assert sha((r/'provider/generic-reference/build/swap-obj'/name).read_bytes())==digest
assert sha((r/'provider/generic-reference/build/ttutil-obj/libttutil.a').read_bytes())==m['identity']['ttutil_library']
for n in ['day_donor','day_kernel']:(r/'O2/build'/n).chmod(0o755)
(r/'PREPARED.json').write_text(json.dumps({'frozen_host_ref':ref,'original_BUILD':m},indent=2))
print(r)
