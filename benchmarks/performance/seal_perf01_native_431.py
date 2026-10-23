"""Retain the actual complete-input experiment, including failed work and build sources."""
import argparse,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True,type=Path);a=ap.parse_args()
 files={};base=Path('/tmp')
 for folder in sorted(base.glob('perf01-native-*')):
  if folder.name=='perf01-native-docs-site':continue
  if not folder.is_dir():
   if folder.is_file():files['raw/'+folder.name]=folder.read_bytes()
   continue
  for p in sorted(folder.rglob('*')):
   if not p.is_file()or p.suffix in ['.o','.a','.mod']or p.name.startswith(('swap431','swap5_')):continue
   if p.stat().st_mode&0o111 and p.suffix not in ['.py','.sh']:continue
   if p.name.startswith('inputrd$'):continue
   files['raw/'+p.relative_to(base).as_posix()]=p.read_bytes()
 for name in ['owner','controls']:
  for stream in ['stdout','stderr']:files['predecessor/'+name+'.'+stream]=(base/('perf01-predecessor710-'+name+'.'+stream)).read_bytes()
 for name in ['owner','controls']:
  for stream in ['stdout','stderr']:files['predecessor-composed/'+name+'.'+stream]=(base/('perf01-predecessor188-'+name+'.'+stream)).read_bytes()
 frozen=Path('/tmp/perf01-predecessor710')
 command=['python','-B','-c',"import json,runpy;print(json.dumps(runpy.run_path('integration/audits/native_project_admission.py')['record']()['frozen_fsi35_successors']))"]
 r=subprocess.run(command,cwd=frozen,capture_output=True,check=True)
 files['predecessor/fsi35.json']=r.stdout
 for build in ['perf01-native-fixed-O0','perf01-native-fixed-O2']:
  metadata=json.loads((base/build/'shared/build-complete.json').read_text())
  for p,h in metadata['input_sha256'].items():
   raw=(ROOT/p).read_bytes();assert sha(raw)==h;files['compiled-current/'+p]=raw
 # Bind executed generation/preparation recipes, not a later undocumented reconstruction.
 for p in sorted((ROOT/'benchmarks/performance').glob('*perf01*native*431*.py')):files['recipes/'+p.name]=p.read_bytes()
 for name in ['qualify_perf01_saturated_flux.py','qualify_perf01_line_search_retry.py','build_perf01_native_iteration_probe.py','build_perf01_original_application.py','prepare_perf01_native_431.py']:
  files['recipes/'+name]=(ROOT/'benchmarks/performance'/name).read_bytes()
 files['MANIFEST.json']=json.dumps({p:sha(v)for p,v in files.items()},sort_keys=True,indent=2).encode()+b'\n'
 buf=io.BytesIO()
 with tarfile.open(fileobj=buf,mode='w:xz',preset=6)as t:
  for p,raw in sorted(files.items()):
   info=tarfile.TarInfo(p);info.size=len(raw);info.mtime=0;info.mode=0o644;t.addfile(info,io.BytesIO(raw))
 raw=buf.getvalue();a.output.write_bytes(raw)
 index=dict(schema=1,path=a.output.name,bytes=len(raw),sha256=sha(raw),members=len(files),member_sha256={p:sha(v)for p,v in files.items()})
 a.output.with_suffix('.index.json').write_text(json.dumps(index,indent=2,sort_keys=True)+'\n')
 print(json.dumps({k:v for k,v in index.items()if k!='member_sha256'}))
if __name__=='__main__':main()
