"""Seal actual full native executions, all providers and retained failed cases."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
import root_accuracy_production as owner
ROOT=owner.ROOT;sha=owner.sha

def main():
 p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args();w=a.workspace.resolve();f={}
 folders={**{'native-'+o:w/('s5-root-accuracy-'+o)for o in ('O0','O2')},
 **{'runtime-'+o:w/('s5-root-accuracy-runtime-'+o)for o in ('O0','O2')},
 **{'controls-'+o:w/('s5-root-accuracy-controls-'+o)for o in ('O0','O2')},
 'component':w/'s5-root-accuracy-component','thermal-preservation':w/'s5-root-accuracy-thermal-contract',
 'duplicate-prefix':w/'s5-root-accuracy-crc-runtime-O2'}
 def asset(path,pin=None):
  b=Path(path).read_bytes();h=sha(b);assert pin is None or h==pin,path;f.setdefault('assets/'+h,b)
 for label,folder in folders.items():
  assert folder.is_dir(),folder
  for path in folder.rglob('*'):
   if not path.is_file()or path.suffix=='.mod':continue
   if path.suffix in ('.exe','.o','.a'):asset(path)
   else:f[label+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
  if not label.startswith('native-'):continue
  build=json.loads((folder/'BUILD.json').read_text())
  for key in ('source_sha256','object_sha256'):
   for path,pin in build[key].items():asset(path,pin)
  provider=build['publication_provider']
  for key in ('source','object'):asset(provider[key],provider[key+'_sha256'])
  asset(build['ttutil_archive'],build['archive_sha256'])
  exe=folder/'swap5_hupsel_germination.exe';asset(exe,build['executable_sha256'])
 for name in owner.PATHS:f['sources/'+name]=(ROOT/name).read_bytes()
 contract=json.loads(f['thermal-preservation/RESULT.json']);assert contract['status']=='SPRINT03_CURRENT_RUNTIME_AND_THERMAL_TEMPORAL_CONTRACT_PASS'and all(e['returncode']==0 for e in contract['events'])
 for name,pin in contract['source_sha256'].items():asset(name,pin)
 f['RETAINED_FAILURES.json']=json.dumps(dict(validation='Original exact-window helper required crop rows during dormant year boundary. Exact restart bytes already matched; replacement requires the complete exact suffix including correctly empty crop output. Both initial exceptions preserved. Original profile checker date-set assertion was corrected by passing its unchanged required subset; scientific checks unchanged.',duplicate='Unnecessary duplicate full O2 stopped after proving all236 linked source hashes equal to qualified e760 source. Canonical joint crop/soil-N CRC is outside this closure. Prefix, native return, elapsed/CPU and dependency reconciliation retained. Separate full fresh build retained locally; no second full PASS claimed.',build_invocation='First verified O0 reuse passed BUILD.json rather than directory and refused before compilation; corrected path reused all236 verified objects.',science='Oxygen584 remains failed: about2.4467966e-4cm versus5.37184e-7cm.36/37 is not whole-scientific admission.'),indent=2).encode()
 proof=owner.verify(f);proof['actual_data_refusals']=owner.data_controls(f)
 archive=ROOT/'integration/dataqual15_hupsel/ROOT_ACCURACY_PRODUCTION_WINDOWS_20261105.tar.xz'
 manifest=json.dumps({n:sha(b)for n,b in f.items()},sort_keys=True).encode()
 with tarfile.open(archive,'w:xz',preset=3)as t:
  for n,b in sorted({**f,'MANIFEST.json':manifest}.items()):
   info=tarfile.TarInfo(n);info.size=len(b);t.addfile(info,io.BytesIO(b))
 report=dict(archive=archive.relative_to(ROOT).as_posix(),archive_sha256=sha(archive.read_bytes()),bytes=archive.stat().st_size,files=len(f)+1,proof=proof)
 archive.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
