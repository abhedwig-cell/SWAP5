"""Verify the integrated OPEN scientific dossier; never turn its failed gate green."""
import hashlib,json,subprocess,sys,tarfile,tempfile
from pathlib import Path,PurePosixPath
from full_period_analysis import analyze
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def verify():
 # Closed current-production inventory and retained actual native decoder controls.
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/verify_union_c3_hupsel.py')],check=True,cwd=ROOT)
 directory=ROOT/'integration/dataqual15_hupsel';m=json.loads((directory/'SPRINT03_SCIENCE_MANIFEST.json').read_text())
 assert m['status']=='FULLY_EXECUTED_SCIENTIFIC_QUALIFICATION_OPEN'
 for name,pin in m['source_sha256'].items():assert sha((ROOT/name).read_bytes())==pin,name
 cap=directory/m['archive'];assert sha(cap.read_bytes())==m['archive_sha256']and cap.stat().st_size==m['archive_bytes']
 with tempfile.TemporaryDirectory(prefix='hupsel-sprint03-')as tmp,tarfile.open(cap)as t:
  tmp=Path(tmp);names=t.getnames();assert len(names)==len(set(names))and set(names)==set(m['members'])
  for member in t.getmembers():
   path=PurePosixPath(member.name);assert member.isfile()and not path.is_absolute()and '..'not in path.parts and '\\'not in member.name and ':'not in member.name
   raw=t.extractfile(member).read();assert sha(raw)==m['members'][member.name],member.name
   dest=tmp.joinpath(*path.parts);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
  for folder in ['science','original','native']:
   r=json.loads((tmp/folder/'RESULT.json').read_text())
   for name,pin in r.get('source_sha256',{}).items():assert sha((ROOT/name).read_bytes())==pin,name
  result=analyze(tmp/'science',tmp/'original',tmp/'native');assert result==json.loads((tmp/'ANALYSIS.json').read_text())
  assert result['original_frozen_gate_pass']is False and m['frozen_scientific_gate_pass']is False
  assert m['whole_energy_qualified']is False and m['production_promoted']is False
  provenance=json.loads((tmp/'PROVENANCE.json').read_text());assert provenance['literal_native_source_unchanged']is True
 print('SPRINT03_DOSSIER_INTEGRITY=PASS; FULL1096=PASS; FROZEN_SCIENTIFIC_GATE=FAIL_RETAINED; SCIENCE=OPEN')
if __name__=='__main__':verify()
