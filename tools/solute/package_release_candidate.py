"""Package tracked standalone sources at an exact Git commit; no model or release publication."""
import argparse,hashlib,io,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--ref',default='HEAD');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
if a.output.exists():raise FileExistsError(a.output)
sha=subprocess.check_output(['git','rev-parse',a.ref+'^{commit}'],cwd=ROOT,text=True).strip()
paths=['app','src','tools/solute','tools/vq','reference/swap-4.3.1/projects','reference/swap-4.3.1/source-archives','docs/getting-started.md','docs/science/RC2_USER_GUIDE.md','README.md']
raw=subprocess.check_output(['git','archive','--format=zip',sha,*paths],cwd=ROOT)
files={}
with zipfile.ZipFile(io.BytesIO(raw)) as source:
 for n in source.namelist():
  if not n.endswith('/'):files[n]=source.read(n)
manifest=dict(release_candidate='SWAP5-NOMACRO-RC2-20261116',source_commit=sha,scope=['Grassgrowth1827','Hupsel1096','SaltFarm04dS1461'],science='NOT_QUALIFIED whole equivalence; retained scientific limitations',files={n:hashlib.sha256(v).hexdigest() for n,v in sorted(files.items())})
files['RELEASE_MANIFEST.json']=(json.dumps(manifest,indent=2)+'\n').encode()
a.output.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(a.output,'w',compression=zipfile.ZIP_DEFLATED) as dest:
 for n,v in sorted(files.items()):
  info=zipfile.ZipInfo(n,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;dest.writestr(info,v)
with zipfile.ZipFile(a.output) as z:
 for n,v in files.items():assert z.read(n)==v,n
receipt=dict(status='EXACT_TRACKED_SOURCE_PACKAGE_VERIFIED',source_commit=sha,archive=a.output.name,sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),bytes=a.output.stat().st_size,members=len(files),manifest_sha256=hashlib.sha256(files['RELEASE_MANIFEST.json']).hexdigest())
a.output.with_suffix('.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(json.dumps(receipt))
