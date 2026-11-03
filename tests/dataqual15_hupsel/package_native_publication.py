"""Seal measured native publication evidence, without compiled-provider admission."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--qualification',type=Path,nargs=2,required=True)
p.add_argument('--decoder',type=Path,nargs=2,required=True)
p.add_argument('--measurement',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();files={};summaries=[];sources={}
for opt,q,d in zip(('O0','O2'),a.qualification,a.decoder):
 result=json.loads((q/'RESULT.json').read_text());nested=json.loads((d/'RESULT.json').read_text())
 assert result['status']=='NATIVE_TWO_DAY_PUBLICATION_RESTART_AND_CORRUPTION_PASS'
 assert all(e['status']=='PASS'for e in nested['events'])
 for name,digest in result['build']['source_sha256'].items():
  source=Path(name)
  try:relative=source.relative_to(ROOT).as_posix()
  except ValueError:continue
  assert sha(source.read_bytes())==digest
  sources[relative]=digest
 provider=result['build']['publication_provider'];assert sha(Path(provider['source']).read_bytes())==provider['source_sha256']
 sources[Path(provider['source']).relative_to(ROOT).as_posix()]=provider['source_sha256']
 summaries.append(dict(optimization=opt,compiler=result['build']['compiler'],executable_sha256=result['build']['executable_sha256'],checkpoint_sha256=result['checkpoint_sha256'],outer_controls=len(result['decoder']['cases']),nested_controls=len(nested['events']),crc_cases=len(result['crc']['results'])))
 for label,folder in [('qualification',q),('nested-decoder',d)]:
  for f in folder.rglob('*'):
   if f.is_file()and (f.suffix in ('.json','.csv','.bin','.nml','.swp','.crp','.met','.dra')or f.name in ('stdout','stderr')):
    files[opt+'/'+label+'/'+f.relative_to(folder).as_posix()]=f.read_bytes()
measurement=json.loads((a.measurement/'RESULT.json').read_text());assert measurement['returncode']==0
for f in a.measurement.iterdir():
 if f.is_file()and(f.suffix in ('.json','.csv','.bin','.nml','.swp','.crp','.met','.dra')or f.name in ('stdout','stderr')):
  files['measurement/'+f.name]=f.read_bytes()
with tarfile.open(a.output,'w:xz')as t:
 for name,raw in sorted(files.items()):
  info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;t.addfile(info,io.BytesIO(raw))
manifest=dict(status='WINDOWS_NATIVE_IO_QUALIFIED_PHYSICAL_CORRECTION_OPEN',archive_sha256=sha(a.output.read_bytes()),files_sha256={n:sha(r)for n,r in sorted(files.items())},repository_source_sha256=sources,results=summaries,measurement_scope=measurement['scope'],measurement_seconds=measurement['seconds'],scientific_admission=False,canonical_admission=False,posix='PENDING_PR1496',physical_correction=False)
a.output.with_suffix('.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(summaries))
