"""Seal raw completed experiments without changing their registrations or results."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['study','original','native','analysis','provenance']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();files={}
 for prefix,folder in [('science',a.study),('original',a.original),('native',a.native)]:
  for path in sorted(folder.rglob('*')):
   if path.is_file():files[prefix+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
 files['ANALYSIS.json']=a.analysis.read_bytes();files['PROVENANCE.json']=a.provenance.read_bytes()
 dest=ROOT/'integration/dataqual15_hupsel/SPRINT03_SCIENCE_EVIDENCE.tar.xz'
 with tarfile.open(dest,'w:xz',preset=6)as t:
  for name,raw in sorted(files.items()):
   info=tarfile.TarInfo(name);info.size=len(raw);info.mode=0o644;info.mtime=0;t.addfile(info,io.BytesIO(raw))
 source=['tests/dataqual15_hupsel/'+name for name in ['scientific_followup.py','inspect_profiles.py','diagnose_refinement.py','full_period_analysis.py','package_sprint03.py']]
 result=dict(schema='swap5.hupsel.sprint03.scientific-evidence.v1',status='FULLY_EXECUTED_SCIENTIFIC_QUALIFICATION_OPEN',archive=dest.name,archive_sha256=sha(dest.read_bytes()),archive_bytes=dest.stat().st_size,members={name:sha(raw)for name,raw in sorted(files.items())},source_sha256={name:sha((ROOT/name).read_bytes())for name in source},native_authority='UNION_C3_HUPSEL_RESULT.json',frozen_scientific_gate_pass=False,whole_energy_qualified=False,production_promoted=False)
 dest.with_name('SPRINT03_SCIENCE_MANIFEST.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
 print(json.dumps({k:v for k,v in result.items()if k not in ['members','source_sha256']},indent=2))
if __name__=='__main__':main()
