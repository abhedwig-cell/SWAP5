"""Exact lineage and rejected reconstruction controls; no numerical recompilation."""
from pathlib import Path
import base64,importlib.util,io,json,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[5]
sys.path.insert(0,str(ROOT/'tools/vq'))
import b1_12_reconstruct as new
h=new.helper();count=0
raw=base64.b64decode(new.AUTHORITY.read_bytes())
with tarfile.open(fileobj=io.BytesIO(raw))as a:original={Path(m.name).name:a.extractfile(m).read()for m in a.getmembers()if m.isfile()and m.name.startswith('SWAP/')}
# B0 and ordered B1.11 target identities coincide; published evidence is unchanged.
manifest=(ROOT/'reference/swap-4.3.1/b0/file-manifest.sha256').read_text()
for name,(pre,post)in h.TARGETS.items():
 assert any(line.startswith(pre)and line.endswith('SWAP/'+name)for line in manifest.splitlines())
 assert h.sha(original[name])==pre
with tempfile.TemporaryDirectory(prefix='swap019-tests-')as t:
 root=Path(t);valid=root/'valid';r=new.from_authority(valid)
 assert r['source_tree']['manifest_sha256']==h.SOURCE_MANIFEST and not r['B0_full_archive_replay_this_run']
 for kind in ['patch','preimage','missing','foreign','line-endings','already-corrected']:
  p=root/kind;p.mkdir();data=dict(original);patch=Path(h.__file__).with_name('fix.patch')
  if kind=='patch':patch=root/'bad.patch';patch.write_bytes(Path(h.__file__).with_name('fix.patch').read_bytes()+b' ')
  if kind=='preimage':data['wofost.f90']+=b'!drift'
  if kind=='missing':data.pop('wofost.f90')
  if kind=='foreign':data['foreign.f90']=b'foreign'
  if kind=='line-endings':data['wofost.f90']=data['wofost.f90'].replace(b'\r\n',b'\n')
  if kind=='already-corrected':data={x.name:x.read_bytes()for x in valid.iterdir()if x.is_file()}
  for n,b in data.items():(p/n).write_bytes(b)
  try:h.apply_tree(p,patch)
  except ValueError:count+=1
  else:raise AssertionError('invalid reference accepted '+kind)
  assert {x.name:x.read_bytes()for x in p.iterdir()if x.is_file()}==data
print(json.dumps({'reference_controls':count,'B0_and_ordered_preimages':'PASS','reconstruction':'PASS','rejection_preserves_inputs':'PASS','snapshot':'B1.12'},indent=2))
