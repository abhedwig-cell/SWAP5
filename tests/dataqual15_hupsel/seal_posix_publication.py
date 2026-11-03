"""Seal Linux Actions I/O evidence and check its actual compiled source bytes."""
import argparse,hashlib,io,json,tarfile,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
assert sha(a.input.read_bytes())=='3e3cb274f06621a961b252a84212bada2290240121a3b723af03d541301359ad'
sources={};results=[];files={}
with zipfile.ZipFile(a.input)as z:
 for opt in ('O0','O2'):
  q=json.loads(z.read('publication-'+opt+'/RESULT.json'))
  assert q['status']=='NATIVE_TWO_DAY_PUBLICATION_RESTART_AND_CORRUPTION_PASS'
  for path,digest in q['build']['source_sha256'].items():
   for segment in ('src/','app/'):
    if '/'+segment in path:
     relative=segment+path.split('/'+segment,1)[1]
     assert sha((ROOT/relative).read_bytes().replace(b'\r\n',b'\n'))==digest,relative
     sources[relative]=digest
  provider=q['build']['publication_provider'];relative='app/support/restart_publish.c'
  assert sha((ROOT/relative).read_bytes().replace(b'\r\n',b'\n'))==provider['source_sha256'];sources[relative]=provider['source_sha256']
  results.append(dict(optimization=opt,compiler=q['build']['compiler'],executable_sha256=q['build']['executable_sha256'],checkpoint_sha256=q['checkpoint_sha256'],outer_controls=len(q['decoder']['cases']),crc_cases=len(q['crc']['results'])))
 for name in z.namelist():
  if not name.endswith('/')and(Path(name).suffix in ('.json','.csv','.bin','.nml','.swp','.crp','.met','.dra')or Path(name).name in ('stdout','stderr')):files[name]=z.read(name)
with tarfile.open(a.output,'w:xz')as t:
 for name,raw in sorted(files.items()):
  info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;t.addfile(info,io.BytesIO(raw))
m=dict(status='POSIX_CHECKED_O0_O2_NATIVE_IO_PASS',run_id=41693014543,artifact_id=13258580659,tested_merge='813c8978cc205903e3bd42bee37201f395d577f4',archive_sha256=sha(a.output.read_bytes()),files_sha256={n:sha(r)for n,r in sorted(files.items())},normalized_repository_source_sha256=sources,results=results,whole_scientific_admission=False,physical_correction=False)
a.output.with_suffix('.json').write_text(json.dumps(m,indent=2)+'\n');print(m['status'])
