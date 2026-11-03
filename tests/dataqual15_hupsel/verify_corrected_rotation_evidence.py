"""Portable remeasurement of the sealed current corrected diagnostic run."""
import csv,hashlib,io,json,subprocess,sys,tarfile,tempfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from audit_corrected_rotation import audit
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def verify():
 record=json.loads((BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json').read_text())
 assert not record['whole_scientific_admission']
 changed=subprocess.check_output(['git','diff','--name-only',record['baseline'],'HEAD','--','src','app','reference'],cwd=ROOT,text=True)
 assert not changed,'unreviewed production successor'
 for name,pin in record['normalized_repository_dependency_sha256'].items():
  assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==pin,name
 archive=BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz'
 assert sha(archive.read_bytes())==record['archive_sha256']
 with tarfile.open(archive)as t:
  members=t.getmembers();assert len({m.name for m in members})==len(members)
  assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive
             and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
  files={m.name:t.extractfile(m).read()for m in members}
 assert {n:sha(b)for n,b in files.items()}==record['files_sha256']
 for prefix in ('build','build-O0'):
  build=json.loads(files[prefix+'/BUILD.json'])
  assert sha(files[prefix+'/swap5_hupsel_germination.exe'])==build['executable_sha256']
  assert sha(files[prefix+'/ttutil/libttutil.a'])==build['archive_sha256']
  for i,pin in enumerate(build['source_sha256'].values()):
   assert sha(files[prefix+'/compiled-source/'+str(i)+'.f90'])==pin
 assert sys.byteorder=='little','sealed native x86 stream ABI requires little endian'
 with tempfile.TemporaryDirectory(prefix='swap5-rotation-')as folder:
  out=Path(folder).resolve();assert out.parent==Path(tempfile.gettempdir()).resolve()
  for name,raw in files.items():
   if not name.startswith(('case/','build/')):continue
   path=(out/name).resolve();assert path.is_relative_to(out)
   path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
  # Capsule hashes and current normalized dependencies replace unavailable
  # original Windows provider paths. All independent data checks run again.
  measured=audit(out/'case',out/'build',live_providers=False)
 assert measured==json.loads(files['AUDIT.json'])
 continuation=json.loads(files['restart/RESULT.json'])
 assert continuation['status']=='CORRECTED_FINAL_ROTATION_OWN_BUILD_RESTART_O0_O2_PASS'
 for whole,resumed,start in [('case','restart/O2-restart-1058',1058),('case','restart/O2-restart-1077',1077),
                             ('restart/O0-compatible-tail','restart/O0-strict-restart-1077',1077)]:
  assert files[whole+'/checkpoint.bin']==files[resumed+'/checkpoint.bin']
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   rows=lambda prefix:list(csv.DictReader(io.StringIO(files[prefix+'/'+name].decode())))
   assert [r for r in rows(whole)if float(r[clock])>start]==rows(resumed)
 assert len(measured['negative_controls'])==7 and all(c['rejected']for c in measured['negative_controls'])
 print('SEALED_CURRENT1096_DIAGNOSTIC_LEDGER_CANOPY_AND_OWN_BUILD_RESTART_PASS_NOT_WHOLE_SCIENCE')
 return record

if __name__=='__main__':verify()
