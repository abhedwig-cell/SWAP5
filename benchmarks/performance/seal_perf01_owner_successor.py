"""Bind fresh current owner runs, original assertions and explicit source projections."""
import hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023'
STATUS=ROOT/(PREFIX+'_STATUS.json');BASE='ef2110c6b0f1aa315eabb00c3672705b6d51a3bf'
sha=lambda b:hashlib.sha256(b).hexdigest()
f={}
def add(group,folder):
 folder=Path(folder)
 for p in sorted(folder.rglob('*')):
  if p.is_file()and not p.is_symlink()and p.suffix not in ['.o','.mod','.a','.pyc','.tmp']:
   b=p.read_bytes()
   if not b.startswith(b'\x7fELF'):f[group+'/'+str(p.relative_to(folder))]=b
def main():
 for group,folder in [('nut-hist','nut-hist-v2'),('nut-joint','nut-joint'),('fct','fct-joint')]:add(group,'/tmp/perf01-owner-'+folder)
 for opt in ['O0','O2']:
  for group,folder in [('native-drain','native-drain'),('native-boesten','native-boesten'),('joint-drain-plain','drain-plain'),('joint-drain-boesten','drain-boesten'),('research','research')]:add(group+'-'+opt,'/tmp/perf01-owner-'+folder+'-'+opt)
  for group,pattern in [('wet','wet.pending-*'),('failed470','rejected.pending-*')]:
   folder=Path('/tmp/perf01-owner-'+group+'-'+opt)
   for name in ['result.json','events.json','stdout','stderr']:
    if(folder/name).exists():f[group+'-'+opt+'/'+name]=(folder/name).read_bytes()
   if group=='wet':add('wet-'+opt+'/prefix',folder/'prefix')
   pending=list(folder.glob(pattern));assert len(pending)==1;add(group+'-'+opt+'/rejected',pending[0])
  folder=Path('/tmp/perf01-typed-composed-'+opt)
  for name in ['bundle.json','events.json']:f['build-'+opt+'/'+name]=(folder/name).read_bytes()
  for name in ['column','read_project','read_crop','read_root']:f['build-'+opt+'/'+name+'/build-complete.json']=(folder/name/'build-complete.json').read_bytes()
  meta=json.loads((folder/'column/build-complete.json').read_text())
  for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p).read_bytes())==h
  for p,h in meta['input_sha256'].items():
   raw=(ROOT/p).read_bytes();assert sha(raw)==h;f['source/'+p]=raw
 for report,key in [('nut-hist/result.json','input_sha256'),('nut-joint/result.json','input_sha256'),('fct/execution.json','inputs')]:
  r=json.loads(f[report])
  for p,h in r[key].items():
   raw=(ROOT/p).read_bytes();assert sha(raw)==h;f['source/'+p]=raw
 for p in ['nut-hist/result.json','nut-joint/result.json']:
  for opt in ['O0','O2']:
   if p.startswith('nut-joint'):
    for path,h in json.loads(f[p])['builds'][opt]['objects_and_modules'].items():assert sha(Path(path).read_bytes())==h
 for p in json.loads(f['fct/execution.json'])['inputs']:f['fct/source/'+p]=(ROOT/p).read_bytes()
 ref=json.loads(f['fct/execution.json'])['baseline'];f['fct/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',ref],cwd=ROOT)
 f['predecessor/source.py']=subprocess.check_output(['git','show',BASE+':integration/audits/verify_nut_single_zero_pool.py'],cwd=ROOT)
 f['predecessor/owner.json']=Path('/tmp/perf01-owner-baseline-controls.json').read_bytes()
 f['predecessor/controls.json']=Path('/tmp/perf01-owner-baseline-controls-actual.json').read_bytes();controls=json.loads(f['predecessor/controls.json']);assert len(controls)==134
 r=json.loads(STATUS.read_text());previous_keys=set(r.get('owner_postimages',{}));previous_aliases=r.get('owner_archived_source_aliases',{});r['owner_baseline']=BASE
 science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
 delta=subprocess.check_output(['git','diff','--name-status',BASE,'--',*science],cwd=ROOT,text=True).splitlines()
 r['owner_scientific_delta']={l.split('\t')[1]:l.split('\t')[0]for l in delta}
 paths={p.split('source ',1)[1]for p in controls if'source 'in p}|set(r['owner_scientific_delta'])
 paths|={'integration/mc-sol01/fct_joint_acceptance/verify.py','docs/science/PERF01_WATER_FLUX_TEMPORAL_POLICY.md',
  'benchmarks/performance/reconcile_perf01_typed_hist.py','benchmarks/performance/check_perf01_owner_failed_day.py',str(Path(__file__).relative_to(ROOT))}
 r['owner_postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
 refs=[BASE,'c459429a','57e1b3f2','779224e5','3461a520','4beca656','4689d335','d80cb933']
 aliases=previous_aliases if previous_keys==paths else{}
 for p in sorted(paths):
  if p in aliases:continue
  if subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode:continue
  hashes=[]
  for ref in refs:
   cp=subprocess.run(['git','show',ref+':'+p],cwd=ROOT,capture_output=True)
   if cp.returncode==0:hashes.append(sha(cp.stdout))
  aliases[p]=sorted(set(hashes))
 r['owner_archived_source_aliases']=aliases
 # Immutable predecessor capsules remain checksum-bound repository inputs.
 for p in sorted(paths):
  if not p.endswith('.b64'):f['current-source/'+p]=(ROOT/p).read_bytes()
 f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
 path=ROOT/(PREFIX+'_OWNER_EVIDENCE.tar.xz')
 with tarfile.open(path,'w:xz')as t:
  for p,b in sorted(f.items()):m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
 r['owner_evidence']=dict(path=str(path.relative_to(ROOT)),sha256=sha(path.read_bytes()),bytes=path.stat().st_size,members=len(f))
 STATUS.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['owner_evidence']))
if __name__=='__main__':main()
