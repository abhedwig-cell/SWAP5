"""Reconstruct original providers from the pinned B1.11 and TTUTIL authorities."""
import argparse,base64,hashlib,io,json,subprocess,sys,tarfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/vq'))
from b0_source_runner import SWAP_ORDER,select_dec_branches
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def build_original(output,compiler,optimization,utilities_only=False):
 out=Path(output).resolve();out.mkdir(parents=True,exist_ok=False)
 fc=str(Path(compiler).resolve());events=[]
 authority=ROOT/'integration/audits/evidence'
 source=out/'source';source.mkdir()
 model=authority/'SWAP431_B111_AUTHORITY.tar.gz.b64'
 utilities=authority/'SWAP431_TTUTIL_AUTHORITY.zip.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(model.read_bytes())))as archive:
  archive.extractall(source,filter='data')
 with zipfile.ZipFile(io.BytesIO(base64.b64decode(utilities.read_bytes())))as archive:
  archive.extractall(source)
 selected=out/'selected';selected.mkdir();tt=source/'TTUTIL'
 hashes={};manifests={}
 for name,folder,flat in [('B1.11-source-manifest.sha256',source/'SWAP',True),('TTUTIL-source-manifest.sha256',tt,False)]:
  manifest=ROOT/'tests/data/ppa_wu05_migmac01'/name;manifests[str(manifest.relative_to(ROOT))]=sha(manifest)
  for row in manifest.read_text().splitlines():
   digest,size,relative=row.split();path=folder/(Path(relative).name if flat else relative)
   assert path.stat().st_size==int(size)and sha(path)==digest,('source identity',path)
   hashes[str(path.relative_to(out))]=digest
 for path in (source/'SWAP').glob('*.f90'):
  (selected/path.name).write_bytes(select_dec_branches(path.read_bytes().decode('cp1252')).encode('cp1252'))
 flags=['-'+optimization,'-finit-local-zero','-fallow-argument-mismatch']
 if optimization=='O0':flags+=['-fcheck=all','-ffpe-trap=invalid,zero,overflow']
 report=dict(status='BUILDING',compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],flags=flags,source_sha256=hashes,authority_sha256={str(p.relative_to(ROOT)):sha(p)for p in [model,utilities]},manifest_sha256=manifests,events=events)
 def save():(out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120)
  index=len(events);(out/f'{index}.stdout').write_bytes(r.stdout);(out/f'{index}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode));save()
  assert r.returncode==0,r.stderr.decode(errors='replace')
 bt=out/'ttobj';bt.mkdir();bs=out/'swobj';bs.mkdir()
 first=['ttutilprefs.f90','ttutil.f90','outdat.f90','rdmodulettutil.f90'];objects=[]
 for path in [tt/n for n in first]+[p for p in sorted(tt.glob('*.f90'))+sorted(tt.glob('*.for'))if p.name not in first]:
  obj=bt/(path.stem+'.o');run([fc,*flags,'-ffree-line-length-none'if path.suffix=='.f90'else'-ffixed-line-length-none','-I'+str(tt),'-I'+str(bt),'-J'+str(bt),'-c',path,'-o',obj],bt)
  assert obj.stat().st_size>0;objects.append(obj)
 # gfortran locates the matching archiver without a host-specific path.
 archiver=subprocess.check_output([fc,'-print-prog-name=ar'],text=True).strip()
 library=bt/'libttutil.a';run([archiver,'rcs',library,*objects],bt)
 if not utilities_only:
  for name in SWAP_ORDER:
   if name=='swap_main.f90':continue
   obj=bs/(Path(name).stem+'.o');run([fc,*flags,'-cpp','-Dlinux','-ffree-line-length-none','-I'+str(bt),'-I'+str(bs),'-J'+str(bs),'-c',selected/name,'-o',obj],bs)
   assert obj.stat().st_size>0
 assert all(sha(out/n)==h for n,h in hashes.items()),'original sources changed during build'
 report.update(status='BUILT',selected_sha256={str(p.relative_to(out)):sha(p)for p in selected.glob('*.f90')},object_sha256={str(p.relative_to(out)):sha(p)for folder in [bt,bs]for p in folder.glob('*.o')},input_archive_sha256=sha(library));save()
 return out

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--utilities-only',action='store_true');a=p.parse_args()
 print(build_original(a.output,a.compiler,a.optimization,a.utilities_only)/'ttobj/libttutil.a')
