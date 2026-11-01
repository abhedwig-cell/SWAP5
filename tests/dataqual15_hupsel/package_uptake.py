"""Seal completed actual-state experiments, including failed literal gates."""
import argparse,hashlib,json,shutil,tarfile
from pathlib import Path
from uptake_evidence import inspect,file_sha,ROOT,DIRECTORY

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['capture','paired','precision','failed','local','raw-trials','raw-metadata','selected','witness','provenance','first-observer','staging']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();stage=a.staging.resolve();stage.mkdir(parents=True,exist_ok=False)
 for label,folder in [('capture',a.capture),('paired',a.paired),('precision',a.precision),('failed_prepare',a.failed),('local_selected',a.local)]:
  for source in sorted(folder.rglob('*')):
   if not source.is_file()or source.name=='uptake-trials.dat':continue
   target=stage/label/source.relative_to(folder);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
 for label,path in [('raw-trials.dat.xz',a.raw_trials),('RAW_TRIALS.json',a.raw_metadata),('selected-cases.dat',a.selected),('WATERFILM_HIGH_PRECISION.json',a.witness),('PROVENANCE.json',a.provenance),('first_observer.py',a.first_observer)]:shutil.copyfile(path,stage/label)
 analysis=inspect(stage);(stage/'ANALYSIS.json').write_text(json.dumps(analysis,indent=2)+'\n',newline='\n')
 files={p.relative_to(stage).as_posix():p for p in sorted(stage.rglob('*'))if p.is_file()and'regenerated-observer'not in p.relative_to(stage).parts and p.name!='recomputed-inputs.dat'}
 cap=DIRECTORY/'UPTAKE_EVIDENCE.tar.xz'
 with tarfile.open(cap,'w:xz',preset=3)as archive:
  for name,path in files.items():
   info=tarfile.TarInfo(name);info.size=path.stat().st_size;info.mode=0o644;info.mtime=0
   with path.open('rb')as source:archive.addfile(info,source)
 sources=['tests/dataqual15_hupsel/'+name for name in ['observe_uptake.py','uptake_observation.inc','paired_uptake.f90','replay_uptake.py','inspect_uptake_case.py','refine_oxygen_owner.py','waterfilm_high_precision.py','requirements-science.txt','uptake_evidence.py','package_uptake.py']]+['integration/dataqual15_hupsel/UPTAKE_DIAGNOSIS_PREREGISTRATION.json']
 parts=[]
 with cap.open('rb')as stream:
  index=0
  while chunk:=stream.read(32*1024*1024):
   index+=1;part=cap.with_name(cap.name+'.part'+str(index).zfill(3));part.write_bytes(chunk);parts.append(dict(path=part.name,bytes=len(chunk),sha256=file_sha(part)))
 manifest=dict(schema='swap5.hupsel.actual-uptake-evidence.v1',status='ACTUAL_INPUT_DIAGNOSIS_QUALIFIED_WITH_LITERAL_FAILURES_RETAINED',archive=cap.name,archive_parts=parts,archive_sha256=file_sha(cap),archive_bytes=cap.stat().st_size,members={name:file_sha(path)for name,path in files.items()},source_sha256={name:file_sha(ROOT/name)for name in sources},literal_component_gates_pass=False,full_scientific_qualification=False,production_promoted=False,production_changed=False)
 (DIRECTORY/'UPTAKE_EVIDENCE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',newline='\n');print(json.dumps({k:v for k,v in manifest.items()if k not in ['members','source_sha256']},indent=2))
if __name__=='__main__':main()
