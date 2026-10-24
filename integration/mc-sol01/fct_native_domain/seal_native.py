"""Seal successful native generations plus failures and original control builds."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,required=True);a=ap.parse_args();files={}
 for opt in ['o0','o2']:
  build=a.root/('native-fct-current-'+opt);r=json.loads((build/'build.json').read_text());base=r['baseline']
  files['build-'+opt+'/build.json']=(build/'build.json').read_bytes()
  files['build-'+opt+'/commit.raw']=subprocess.check_output(['git','cat-file','commit',base],cwd=ROOT)
  for p,h in r['inputs'].items():
   b=subprocess.check_output(['git','show',base+':'+p],cwd=ROOT);assert sha(b)==h;files['build-'+opt+'/source/'+p]=b
  for p in build.glob('*'):
   if p.is_file() and p.suffix in ['.f90','.stdout','.stderr']:files['build-'+opt+'/'+p.name]=p.read_bytes()
  native=a.root/('native-fct-complete-'+opt)
  for p in native.rglob('*'):
   if p.is_file():files['native-'+opt+'/'+str(p.relative_to(native))]=p.read_bytes()
 # Preserve every launched development result and its prepared inputs/diagnostics.
 retained=[]
 for folder in sorted(a.root.iterdir()):
  if not folder.is_dir() or not folder.name.startswith(('native-fct-','native-reference-','heterogeneous-domain-','signed-domain-')):continue
  if not (folder/'RESULT.json').is_file():continue
  label='development/'+folder.name;retained.append(folder.name)
  result=json.loads((folder/'RESULT.json').read_text());meta=result.get('build',result)
  checkpoint=meta.get('baseline');bindings={}
  if checkpoint:
   files[label+'/commit.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
   for p,h in meta.get('inputs',{}).items():
    b=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(b)==h;files['source_pool/'+h]=b;bindings[p]=h
   files[label+'/source_bindings.json']=json.dumps(bindings).encode()
  if 'generated' in meta:
   build_dir=Path(meta['events'][-1]['command'][-1]).parent
   for p,h in meta['generated'].items():
    b=(build_dir/p).read_bytes();assert sha(b)==h;files['source_pool/'+h]=b
  for p in folder.rglob('*'):
   if p.is_file() and (p.suffix.lower() in ['.json','.nml','.swp','.bin','.csv','.f90']):files[label+'/'+str(p.relative_to(folder))]=p.read_bytes()
 files['DEVELOPMENT_ROUNDS.json']=json.dumps(retained).encode()
 files['PRESERVATION.json']=(a.root/'fct-native-preservation.json').read_bytes()
 old_source=subprocess.check_output(['git','show','2de14588:integration/mc-sol01/fct_sink_restart/verify.py'],cwd=ROOT)
 ns=dict(__file__=str(HERE.parent/'fct_sink_restart/verify.py'),__name__='archived_checkout_failure')
 exec(compile(old_source,'archived_checkout_failure/verify.py','exec'),ns)
 peer=runpy.run_path(str(ROOT/'integration/audits/verify_saturated_picard_current.py'))['capsule']()
 try:ns['assess']({p[5:]:b for p,b in peer.items() if p.startswith('disk/')})
 except AssertionError:
  files['failed_validator/verify.py']=old_source;files['failed_validator/stderr']=traceback.format_exc().encode()
  files['failed_validator/receipt.json']=json.dumps(dict(status='REPRODUCED_ARCHIVED_CHECKOUT_PATH_FAILURE',source='2de14588',physical_source_changed=False,repair='Bind all compiled source suffixes to one archived checkout and generated files to their actual output root.')).encode()
 else:raise AssertionError('archived path failure unexpectedly absent')
 for p in ['verify_native.py','seal_native.py','generate.py','build_native.py','run_native.py']:files['validation/'+p]=(HERE/p).read_bytes()
 v=runpy.run_path(str(HERE/'verify_native.py'));r=v['assess'](files);c=v['controls'](files)
 files['VERIFICATION.json']=json.dumps(r).encode();files['CONTROLS.json']=json.dumps(c).encode()
 files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())}).encode();stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as t:
  for p,b in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=stream.getvalue();(HERE/'NATIVE_EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
 index=dict(sha256=sha(raw),bytes=len(raw),members=len(files),result=r,controls=c,retained_rounds=retained)
 (HERE/'NATIVE_EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n');print(json.dumps(index,indent=2))
if __name__=='__main__':main()
