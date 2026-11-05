"""Seal actual completed native results and their exact compiled providers."""
import argparse,hashlib,io,json,subprocess,tarfile
from pathlib import Path
import thermal_profile_production as owner
ROOT=owner.ROOT;sha=owner.sha

def main():
 p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args();w=a.workspace.resolve()
 folders={n:w/('s5-events-'+suffix)for n,suffix in {
  'thermal-contract':'thermal-contract','grass-O0':'grass-O0','grass-O2':'grass-O2','grass-default-O2':'grass-default-O2',
  'thermal-disk-O0':'thermal-disk-O0','thermal-disk-O2':'thermal-disk-O2','grass-367':'grass-367',
  'grass-year-restart':'grass-year-restart','default-140':'default-140','incumbent-140':'incumbent-140',
  'incumbent-grass-O2':'incumbent-grass-O2','andelst-O0':'andelst-O0','andelst-O2':'andelst-linked-O2',
  'andelst-original-O2':'andelst-original-O2','andelst-continue-O2':'andelst-continue-O2',
  'andelst-own-O0':'andelst-own-exact-O0','andelst-own-O2':'andelst-own-exact-O2',
  'andelst-prefix-O0':'andelst-prefix-exact-O0','andelst-prefix-O2':'andelst-prefix-exact-O2',
  'andelst-day1-O0':'andelst-day1-O0','gate-observer':'gate-observer','gate-bracket':'gate-bracket','gate-residual':'gate-residual',
  'andelst-codec':'andelst-codec',
  'failed-project-builder':'native-O2','failed-native-link':'andelst-O2',
  'refused-rounded-event-O0':'andelst-own-O0','refused-rounded-event-O2':'andelst-own-O2',
  'refused-rounded-prefix-O0':'andelst-prefix-O0','refused-rounded-prefix-O2':'andelst-prefix-O2'}.items()}
 files={};source_map={};source_hashes={};artifacts={};builds=[]
 def binary(path):
  path=Path(path);raw=path.read_bytes();name='artifacts/'+sha(raw);files.setdefault(name,raw);artifacts[str(path)]=name;return name
 def source(path,pin):
  path=Path(path);raw=path.read_bytes();assert sha(raw)==pin,path
  name='sources/'+path.relative_to(ROOT).as_posix()if path.is_relative_to(ROOT)else'source-snapshots/'+pin
  files[name]=raw;source_map[str(path)]=name;source_hashes[str(path)]=pin
 for label,folder in folders.items():
  assert folder.is_dir(),folder
  for path in folder.rglob('*'):
   if not path.is_file():continue
   if path.suffix in ('.o','.a','.exe','.mod'):binary(path);continue
   if path.suffix in ('.json','.csv','.bin','.nml','.swp','.bbc','.dra','.met','.crp','.stdout','.stderr','.args','.log')or path.name in ('stdout','stderr'):
    files[label+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
  meta=folder/'BUILD.json'
  if meta.exists():
   data=json.loads(meta.read_text())
   if data.get('status')not in ('BUILT','ORIGINAL_INTERVAL_COMPLETED'):continue
   if 'source_sha256'not in data:continue
   for name,pin in data['source_sha256'].items():source(name,pin)
   for name,pin in data.get('object_sha256',{}).items():assert sha(Path(name).read_bytes())==pin;binary(name)
   exe=folder/data.get('executable','swap5_hupsel_germination.exe')
   assert sha(exe.read_bytes())==data['executable_sha256']
   builds.append(dict(metadata=label+'/BUILD.json',executable=binary(exe)))
 # The real shared-runtime tests use generated hydraulic stubs, not archived model binaries.
 for name,pin in json.loads(files['thermal-contract/RESULT.json'])['source_sha256'].items():source(name,pin)
 for name in owner.PATHS:files['sources/'+name]=(ROOT/name).read_bytes()
 old_ref=subprocess.check_output(['git','rev-parse','origin/codex/grassgrowth-sprint03'],cwd=ROOT,text=True).strip()
 raw=subprocess.check_output(['git','show',old_ref+':integration/dataqual15/SPRINT03_EVIDENCE.tar.xz'],cwd=ROOT)
 assert sha(raw)=='19f6f3f6dc45a115bf161ad7efff22006336ded20dbec047ad7abd859974ff2d'
 with tarfile.open(fileobj=io.BytesIO(raw))as t:
  historical=json.loads(t.extractfile('NATIVE_RESULT.json').read())
  assert historical['full_days']==1827 and historical['original_gate_pass']is False
  files['historical/NATIVE_RESULT.json']=t.extractfile('NATIVE_RESULT.json').read()
  files['historical/PREREGISTRATION.json']=t.extractfile('PREREGISTRATION.json').read()
  files['historical/RESULT.json']=t.extractfile('RESULT.json').read()
  for name in ('budget.csv','crop.csv'):files['historical/adaptive-O2/'+name]=t.extractfile('adaptive-O2/'+name).read()
  for name in ('MANIFEST.json','TRAJECTORY_SUMMARY.json'):files['historical/'+name]=t.extractfile(name).read()
 files['HISTORICAL_THERMAL_REUSE.json']=json.dumps(dict(ref=old_ref,archive_sha256=sha(raw),days=1827,
  original_gate_remains_failed=True,whole_scientific_admission=False,
  scope='Historical complete registered numerical-profile execution, not a new current1827-day or whole-energy claim. Current native selection, default preservation and own year restart are separately measured.',
  dependency_reconciliation='Current native physical process/crop/heat owners match the historical profile. Canonical endpoint-event additions are unused by Grassgrowth; thermal receipt additions are read-only. Current publication uses the separately qualified C publisher; current exact own restart is freshly measured.'),indent=2).encode()
 files['SOURCE_MAP.json']=json.dumps(source_map,indent=2).encode();files['SOURCE_HASHES.json']=json.dumps(source_hashes,indent=2).encode()
 files['ARTIFACT_MAP.json']=json.dumps(artifacts,indent=2).encode();files['BUILDS.json']=json.dumps(builds,indent=2).encode()
 files['RETAINED_FAILURES.json']=json.dumps(dict(andelst='90s original prefix and600s strict-own continuation censored at1.958; not a natural terminal solver failure or original481-day PASS',
  builder='Original native project build linked successfully but Windows suffix lookup failed; alternate native builder then failed POSIX fsync link. Both retained; native provider objects reused with codec and caller recompiled.',
  rounded_event='Unquoted PowerShell double literal lost source-event digits and was correctly refused. Exact quoted original event used for successful own restart controls.',
  gate_observer='Read-only intentional observation stops; not accepted trajectories or qualified cross-executable restarts.'),indent=2).encode()
 archive=ROOT/'integration/dataqual15/THERMAL_PROFILE_PRODUCTION_WINDOWS_20261105.tar.xz'
 owner.verify({},files)
 manifest=json.dumps({n:sha(b)for n,b in files.items()},sort_keys=True).encode()
 with tarfile.open(archive,'w:xz',preset=3)as t:
  for n,b in sorted({**files,'MANIFEST.json':manifest}.items()):
   info=tarfile.TarInfo(n);info.size=len(b);t.addfile(info,io.BytesIO(b))
 report=dict(archive=archive.relative_to(ROOT).as_posix(),archive_sha256=sha(archive.read_bytes()),files=len(files)+1,bytes=archive.stat().st_size,proof=owner.verify({},files))
 (archive.with_suffix('.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':main()
