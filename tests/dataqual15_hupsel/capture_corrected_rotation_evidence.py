"""Seal completed actual rotation outputs and current dependency bytes."""
import argparse,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
for name in ('case','restart','o0','o2'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();files={};dependencies={}
audit=json.loads((a.case/'AUDIT.json').read_text());restart=json.loads((a.restart/'RESULT.json').read_text())
assert audit['status']=='COMPLETE_CORRECTED_CURRENT_DIAGNOSTIC_ROTATION_LEDGER_AND_CANOPY_PASS'
assert restart['status']=='CORRECTED_FINAL_ROTATION_OWN_BUILD_RESTART_O0_O2_PASS'
assert not audit['whole_scientific_admission']and not restart['whole_scientific_admission']
for prefix,folder in [('case',a.case),('restart',a.restart)]:
 for path in folder.rglob('*'):
  if path.is_file():files[prefix+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
files['AUDIT.json']=(a.case/'AUDIT.json').read_bytes()
for opt,folder in [('O0',a.o0),('O2',a.o2)]:
 folder=folder.resolve();build=json.loads((folder/'BUILD.json').read_text())
 assert all(sha(Path(n).read_bytes())==pin for n,pin in build['source_sha256'].items())
 assert all(sha(Path(n).read_bytes())==pin for n,pin in build['object_sha256'].items())
 publisher=build['publication_provider']
 assert sha(Path(publisher['source']).read_bytes())==publisher['source_sha256']
 assert sha(Path(publisher['object']).read_bytes())==publisher['object_sha256']
 archive=Path(build['ttutil_archive']);assert sha(archive.read_bytes())==build['archive_sha256']
 exe=folder/'swap5_hupsel_germination.exe';assert sha(exe.read_bytes())==build['executable_sha256']
 prefix='build'if opt=='O2'else'build-O0'
 for name in ('BUILD.json','EVENTS.json',exe.name):files[prefix+'/'+name]=(folder/name).read_bytes()
 files[prefix+'/ttutil/libttutil.a']=archive.read_bytes()
 source=Path(publisher['source']);dependencies[source.relative_to(ROOT).as_posix()]=sha(source.read_bytes().replace(b'\r\n',b'\n'))
 for i,name in enumerate(build['source_sha256']):
  path=Path(name)
  files[prefix+'/compiled-source/'+str(i)+'.f90']=path.read_bytes()
  if path.is_relative_to(ROOT):
   relative=path.relative_to(ROOT).as_posix();dependencies[relative]=sha(path.read_bytes().replace(b'\r\n',b'\n'))
for name in ['tests/dataqual15_hupsel/audit_corrected_rotation.py',
             'tests/dataqual15_hupsel/qualify_corrected_rotation_restarts.py',
             'tests/dataqual15_hupsel/verify_corrected_rotation_evidence.py',
             'tests/dataqual15_hupsel/capture_corrected_rotation_evidence.py',
             'tests/dataqual15_hupsel/run_canopy_observation.py',
             'tests/dataqual15_hupsel/inspect_profiles.py',
             'tests/dataqual15_hupsel/scientific_followup.py',
             'integration/dataqual15_hupsel/CORRECTED_ROTATION_PREREGISTRATION_20261103.json']:
 dependencies[name]=sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))
baseline='baada36c4f717ca40057b6db663e20f60b9d2a62'
assert not subprocess.check_output(['git','diff','--name-only',baseline,'HEAD','--','src','app','reference'],cwd=ROOT)
base=ROOT/'integration/dataqual15_hupsel';archive=base/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz'
with tarfile.open(archive,'w:xz')as t:
 for name,raw in sorted(files.items()):
  entry=tarfile.TarInfo(name);entry.size=len(raw);entry.mtime=0;t.addfile(entry,io.BytesIO(raw))
record=dict(status='QUALIFIED_WINDOWS_CURRENT1096_DIAGNOSTIC_LEDGER_AND_O0_O2_FINAL_CONTINUATION',
            baseline=baseline,candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},
            normalized_repository_dependency_sha256=dependencies,water_frozen_error=audit['assessment']['water_global'],
            frozen_selected_metrics_inside=sum(v['inside_frozen_bound']for v in audit['assessment'].values()),
            frozen_selected_metrics_outside=[k for k,v in audit['assessment'].items()if not v['inside_frozen_bound']],
            original_full_profile_schedule_qualified=False,whole_scientific_admission=False,canonical_admission=False)
(base/'CORRECTED_ROTATION_EVIDENCE_20261103.json').write_text(json.dumps(record,indent=2)+'\n')
print('SEALED',len(files),'files',archive.stat().st_size,'bytes')
