"""Seal actual original chronology artifacts as small SHA-bound transport parts."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
from original_chronology_evidence import ROOT,BASE,STEM,sha,norm
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--archive',type=Path,required=True);p.add_argument('--reuse-archive',action='store_true');a=p.parse_args()
 root=a.capture.resolve();assert (root/'AUDIT.json').exists() and (root/'COLLECTED.json').exists()
 files={}
 for f in sorted(root.rglob('*')):
  if not f.is_file() or f.suffix=='.mod':continue
  name=f.relative_to(root).as_posix()
  if name.startswith('cold-factor-') and f.name=='original_factor_inputs.dat':continue
  files[name]=f.read_bytes()
 config=json.loads(files['COLLECTION.json'])
 tests=['original_chronology_evidence.py','original_chronology_audit.py','original_micro_comparison.py','original_micro_comparison.f90',
  'original_oxygen_reference_gate.py','original_oxygen_chronology.py','original_oxygen_forcing.py','original_micro_forcing.py',
  'original_oxygen_conductivity.py','original_oxygen_k_jacobian.py','original_k_jacobian_check.py','original_reference_balance_control.py',
  'original_oxygen_self_convergence.py','original_oxygen_quadrature.py','pressure_oxygen_temporal.py','oxygen_frozen_k_runtime.py',
  'micro_pressure_runtime.py','micro_pressure_probe.py','matched_oxygen_owners.f90','original_factor_comparison.f90',
  'collect_original_chronology.py','seal_original_chronology.py']
 dependencies=[*[ROOT/'tests/dataqual15_hupsel'/n for n in tests],*[ROOT/n for n in config['factor_repository_order']],
  ROOT/'src/process/mod_root_micro_matric_flux_table.f90',ROOT/'src/process/mod_root_micro_de_willigen_process.f90',
  ROOT/'tests/dataqual15/original_sources.py',ROOT/'tests/dataqual15_hupsel/scientific_followup.py',ROOT/'tools/vq/b0_source_runner.py',
  ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json',
  ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
  BASE/'SPRINT03_SCIENCE_MANIFEST.json',BASE/'PRESSURE_OXYGEN_EVIDENCE_20261104.json',BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json']
 build=json.loads(files['native-frozen-k/build-O2/BUILD.json'])
 dependencies.extend(Path(n) for n in build['baseline']['source_sha256'] if Path(n).is_relative_to(ROOT))
 normalized={p.relative_to(ROOT).as_posix():norm(p) for p in dependencies}
 if a.reuse_archive:
  with tarfile.open(a.archive.resolve()) as t:
   names=t.getnames();assert len(names)==len(set(names)) and set(names)==set(files)
   for n in names:assert t.extractfile(n).read()==files[n],n
 else:
  with tarfile.open(a.archive.resolve(),'w:xz',preset=6) as t:
   for name,raw in files.items():
    info=tarfile.TarInfo(name);info.size=len(raw);info.mtime=0;t.addfile(info,io.BytesIO(raw))
 raw=a.archive.read_bytes();parts=[]
 for i,start in enumerate(range(0,len(raw),4*1024*1024)):
  name=STEM+'.tar.xz.part'+str(i).zfill(2);chunk=raw[start:start+4*1024*1024];(BASE/name).write_bytes(chunk)
  parts.append(dict(name=name,bytes=len(chunk),sha256=sha(chunk)))
 record=dict(status='QUALIFIED_ORIGINAL_CHRONOLOGY_REFERENCE_UNDERRESOLVED_NOT_PHYSICAL_ADMISSION',
  archive_sha256=sha(raw),archive_bytes=len(raw),archive_parts=parts,files_sha256={n:sha(b) for n,b in files.items()},
  normalized_repository_dependency_sha256=normalized,
  factor_repository_order=config['factor_repository_order'],production_admission=False,whole_scientific_admission=False,
  frozen_predecessor_gates_unchanged=True,additional_reference_gate='REFERENCE_UNDERRESOLVED',
  scope='Windows actual unmodified original full controls and refined584 prefix, actual native584 copied-source control; cold O0/O2 typed MICRO and original/typed oxygen replay. Not full native POSIX runtime or production correction qualification.')
 (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps(dict(archive_bytes=len(raw),parts=len(parts),files=len(files)),indent=2))
