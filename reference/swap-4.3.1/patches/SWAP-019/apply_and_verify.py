"""Exact, byte-safe B1.11 -> B1.12 leaf-residue correction."""
from pathlib import Path
import hashlib, shutil, subprocess, tempfile
PATCH_SHA256='763e44540692971a8d2bb491a1ff47bb5682a5f3dcf0f6d8ca72838adc353070'
PREDECESSOR_MANIFEST='24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2'
SOURCE_MANIFEST='5bab54598c3519c1b1f2f313431ba0947f39c9673eb1fbc7eec719477f9f2d0e'
TARGETS={
 'wofost.f90':('3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b','2d1f9962f2423f94209784cf92e295ddbd18d103a052312be0f3da3e330bac38'),
 'wofostnut.f90':('071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2','f64dbc7a58bc7508fd25aa277fa09f70a9ed9206aab684ad094ef1dc61d3e346')}
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,label):
 if not ok:raise ValueError(label)
def manifest(data):
 return ''.join(f'{sha(v)}  {len(v):8d}  SWAP/{k}\n'for k,v in sorted(data.items())).encode('ascii')
def apply_tree(source_root,patch_path=None):
 source_root=Path(source_root);patch_path=Path(patch_path or Path(__file__).with_name('fix.patch'))
 patch=patch_path.read_bytes();require(sha(patch)==PATCH_SHA256,'stored patch identity')
 before={p.name:p.read_bytes()for p in source_root.iterdir()if p.is_file()}
 require(len(before)==63 and sha(manifest(before))==PREDECESSOR_MANIFEST,'ordered B1.11 source identity')
 for n,(a,b)in TARGETS.items():require(sha(before[n])==a,'canonical B0/ordered preimage '+n)
 with tempfile.TemporaryDirectory(prefix='swap019-')as tmp:
  parent=Path(tmp);target=parent/'SWAP';target.mkdir()
  for n,b in before.items():(target/n).write_bytes(b)
  cp=subprocess.run(['patch','--binary','--batch','--forward','--fuzz=0','-p1'],input=patch,cwd=parent,capture_output=True)
  require(cp.returncode==0,'exact binary patch application '+cp.stderr.decode(errors='replace'))
  after={p.name:p.read_bytes()for p in target.iterdir()if p.is_file()}
 require(set(after)==set(before),'patch member drift')
 require({n for n in before if before[n]!=after[n]}==set(TARGETS),'patch changed foreign member')
 for n,(a,b)in TARGETS.items():
  require(sha(after[n])==b,'corrected postimage '+n)
  require(after[n].count(b'\n')==after[n].count(b'\r\n'),'CRLF normalization '+n)
 require(sha(manifest(after))==SOURCE_MANIFEST and sum(map(len,after.values()))==1886750,'B1.12 source identity')
 for n in TARGETS:(source_root/n).write_bytes(after[n])
 return {n:{'before':a,'after':b}for n,(a,b)in TARGETS.items()}
