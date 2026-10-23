"""Retain raw successful, failed and censored native research and source versions."""
import argparse,base64,io,json,platform,subprocess,tarfile
from pathlib import Path
from verify_sol_day65_continuation import validate,sha,scope_successor
ROOT=Path(__file__).resolve().parents[2]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 proof=a.proof.resolve();files={};postimages={};costs={}
 for p in sorted(proof.rglob('*')):
  if not p.is_file()or p.is_symlink()or p.suffix.lower()in ['.o','.mod','.smod','.a','.so','.tmp','.pyc']:continue
  raw=p.read_bytes()
  if raw.startswith(b'\x7fELF'):continue
  files['proof/'+str(p.relative_to(proof))]=raw
 for p in sorted(proof.parent.glob('day65-*.log')):
  files['operational-logs/'+p.name]=p.read_bytes()
 # Bind all current compiled inputs and actual executed test/adapter inputs.
 for p in proof.glob('composite-*/result.json'):
  r=json.loads(p.read_text())
  if p.parent.name in ['composite-nut-cold','composite-nut-current']:continue
  for mapping in ['inputs','input_sha256','cold_input_sha256']:
   for name,h in r.get(mapping,{}).items():
    current=(ROOT/name).read_bytes()
    if sha(current)!=h:
     assert name=='tests/nut-sol/qualify_native_project.py',(p,name)
     old=subprocess.check_output(['git','show','5e60f181:'+name],cwd=ROOT)
     assert sha(old)==h and scope_successor(old,current),(p,'unreviewed validation-only delta')
     files['execution-sources/'+h]=old
    postimages[name]=sha(current)
  es=r.get('events')
  if es is None and(p.parent/'events.json').exists():es=json.loads((p.parent/'events.json').read_text())
  costs[p.parent.name]={category:sum(e['seconds']for e in es or []if e.get('category','subprocess')==category)
   for category in sorted({e.get('category','subprocess')for e in es or []})}
 for opt in ['O0','O2']:
  b=json.loads((proof/('composite-'+opt)/'shared/build-complete.json').read_text())
  for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h;postimages[p]=h
 changed=subprocess.check_output(['git','diff','--name-only','801e78ee','HEAD'],cwd=ROOT,text=True).splitlines()
 changed=[p for p in changed if Path(p).suffix in ['.py','.f90','.md','.json']and not p.startswith('integration/audits/evidence/')]
 own=['integration/audits/seal_sol_day65_continuation.py','integration/audits/verify_sol_day65_continuation.py',
      'tests/nut-sol/validate_native_project_prefix.py']
 for p in own:postimages[p]=sha((ROOT/p).read_bytes())
 for p in set(changed)|set(postimages):
  if (ROOT/p).is_file():files['source/'+p]=(ROOT/p).read_bytes()
 for rev in subprocess.check_output(['git','rev-list','801e78ee..HEAD'],cwd=ROOT,text=True).splitlines():
  for p in changed:
   cp=subprocess.run(['git','show',rev+':'+p],cwd=ROOT,capture_output=True)
   if cp.returncode==0:files['source-versions/'+sha(cp.stdout)]=cp.stdout
 current=dict(status='BOUNDED_COMPOSITE_RESEARCH_CHECKPOINT',canonically_admitted=False,full_historical_migration=False,
  full_refined_year_qualified=False,source_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  postimages=postimages,measured_subprocess_seconds=costs,historical_dispositions={'annual-coarse-O2':'FAILED_DAY257_AFTER256_ACCEPTED_DAYS',
   'annual-refined-O2':'CENSORED_SUPERSEDED_CURVE_ONLY_NOT_PHYSICAL_FAILURE'},
  unselected=['full moving F-CI','highest low-air','RossFast expansion','complete refined year'])
 coarse=json.loads(files['proof/composite-coarse/result.json'])['cases']['O2-annual1998']['budget'][:98]
 refined=json.loads(files['proof/composite-refined98/prefix-validation.json'])['cases']['O2-annual1998']['budget']
 current['grid_comparison_first98_days']={key:max(abs(x[key]-y[key])for x,y in zip(coarse,refined))
  for key in ['water_end_cm','solute_end_mg_cm2','actual_transpiration_cm']}
 current['grid_comparison_is_convergence_proof']=False
 files['CURRENT.json']=(json.dumps(current,indent=2)+'\n').encode()
 manifest=json.loads((proof/'cache-manifest.json').read_text())
 compiler=Path(manifest['compiler'][0]);toolchain=compiler.parent
 receipt=dict(platform=platform.platform(),compiler_version=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
  compiler_wrapper=str(compiler),compiler_wrapper_sha256=sha(compiler.read_bytes()),
  packages={p.name:dict(bytes=p.stat().st_size,sha256=sha(p.read_bytes()))for p in(toolchain/'packages').glob('*.deb')})
 assert receipt['compiler_version']==manifest['compiler_version']
 files['TOOLCHAIN.json']=(json.dumps(receipt,indent=2)+'\n').encode()
 for p in [compiler,toolchain/'gfortran-cached']:
  if p.exists():files['toolchain-wrappers/'+p.name]=p.read_bytes()
 result=validate(files)
 files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as archive:
  for p,raw in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;archive.addfile(m,io.BytesIO(raw))
 raw=stream.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 print(json.dumps(dict(path=str(a.output),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files),verification=result)))
if __name__=='__main__':main()
