"""Preserve completed observations without executing another model.

Archives contain content-addressed raw bytes; FILES.json maps original paths to
assets. Executables/compiler products are excluded, not physical observations.
"""
from pathlib import Path
import argparse,hashlib,json,zipfile

def sha(data):return hashlib.sha256(data).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--windows',type=Path,required=True);p.add_argument('--ubuntu',type=Path,required=True);p.add_argument('--composition',type=Path);p.add_argument('--diagnostics',type=Path);p.add_argument('--destination',type=Path,required=True);a=p.parse_args();dest=a.destination;dest.mkdir(exist_ok=True,parents=True)
 excluded={'.exe','.dll','.so','.o','.mod','.smod','.a','.pyc'};known={};index={};archives=[];archive=None
 def add(label,name,data):
  nonlocal archive
  if Path(name).suffix.lower() in excluded or Path(name).name in {'day_donor','day_kernel','component'}:return
  digest=sha(data);index[label+'/'+name]={'sha256':digest,'bytes':len(data)}
  if digest in known:return
  if archive is None or archive.fp.tell()>48_000_000:
   if archive:archive.close()
   path=dest/('RAW-%02d.zip'%(len(archives)+1));archives.append(path);archive=zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6)
  asset='sha256/'+digest;archive.writestr(asset,data);known[digest]={'archive':archives[-1].name,'member':asset}
 roots=[('windows',a.windows)]+([('composition',a.composition)] if a.composition else [])+([('diagnostics',a.diagnostics)] if a.diagnostics else [])
 for label,root in roots:
  for f in sorted(root.rglob('*')):
   if f.is_file():add(label,f.relative_to(root).as_posix(),f.read_bytes())
 with zipfile.ZipFile(a.ubuntu) as z:
  for n in z.namelist():
   if not n.endswith('/'):add('ubuntu',n,z.read(n))
 if archive:archive.close()
 (dest/'FILES.json').write_text(json.dumps({'format':'CONTENT_ADDRESSED_RAW_V1','files':index,'assets':known},indent=2))
 for label,root in [('WINDOWS',a.windows)]+([('COMPOSITION',a.composition)] if a.composition else []):
  for n in ['RESULT','FINISH','MATCHED_REFERENCE','SATURATION_REFERENCE','UNSELECTED','HEAT_FAILURE','HEAT']:
   f=root/(n+'.json')
   if f.exists():(dest/(label+'_'+n+'.json')).write_bytes(f.read_bytes())
 with zipfile.ZipFile(a.ubuntu) as z:
  for name in ['wetting/RESULT.json','wetting/FINISH.json','component/RESULT.json','wetting/HEAT.json']:
   if name in z.namelist():(dest/('UBUNTU_'+name.replace('/','_'))).write_bytes(z.read(name))
 manifest={'archives':{f.name:{'sha256':sha(f.read_bytes()),'bytes':f.stat().st_size} for f in archives},'files_index_sha256':sha((dest/'FILES.json').read_bytes()),'upstream_ubuntu_artifact_sha256':sha(a.ubuntu.read_bytes()),'preserved_paths':len(index),'unique_assets':len(known)}
 (dest/'SEAL.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
if __name__=='__main__':main()
