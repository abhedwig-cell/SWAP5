"""Verify actual corrected native accept/rollback/disk evidence without promoting legacy scope."""
import hashlib,json,math,struct,subprocess,tarfile,zlib
from pathlib import Path
from audit_native_donors import audit
ROOT=Path(__file__).resolve().parents[2]
def verify():
 git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
 assert not git('diff','c1ce8808bdfc042577295811b5acccbd7608ebea','HEAD','--','src','app','reference')
 record=json.loads((ROOT/'integration/dataqual15/NATIVE_COUPLED_WINDOWS_EVIDENCE_20261103.json').read_text(encoding='utf-8'))
 path=ROOT/record['archive'];digest=lambda data:hashlib.sha256(data).hexdigest()
 assert digest(path.read_bytes())==record['archive_sha256']
 with tarfile.open(path) as t:files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
 manifest=json.loads(files.pop('MANIFEST.json'));assert manifest.keys()==files.keys()
 for name,h in manifest.items():assert digest(files[name])==h,name
 assert json.loads(files['historical-donors.json'])==audit()
 for folder in ['native-o0','native-o2','component-o0','component-o2']:
  r=json.loads(files[folder+'/RESULT.json'])
  for name,blob in r.get('source_git_blob',r.get('sources',{})).items():
   assert git('rev-parse','HEAD:'+name)==blob,name
   assert not git('diff','HEAD','--',name),name
  if folder.startswith('component'):
   assert r['status']=='PASS' and r['compile_closure']==11
   assert digest(files[folder+'/component.exe'])==r['executable_sha256']
   stdout=files[folder+'/execute.stdout'].decode().replace('\r\n','\n')
   for marker in ['NATIVE_FEEDBACK_TRANSACTION_COMPONENT_PASS','TYPED_RESTART_BINDING_CRC_ROUNDTRIP_PASS',
                  'ADAPTIVE_COMPLETE_WINDOW_AND_LATE_FAILURE_ROLLBACK_PASS']:assert marker in stdout
   continue
  assert r['owned_native_substep_accepted'] and not r['original_outer_interval_accepted'] and not r['full_energy_balance_complete']
  assert digest(files[folder+'/build/native.exe'])==r['executable_sha256']
  for name,h in r['rendered_sha256'].items():assert digest(files[folder+'/overlay/'+name])==h
  cert=json.loads(files[folder+'/COMPILED_INPUTS.json']);assert len(cert)==207
  for i,e in enumerate(cert):assert digest(files[folder+'/compiled-source/'+str(i)+'.f90'])==e['source_sha256']
  assert files[folder+'/contact-0/origin.bin']==files[folder+'/contact-0/diagnostic-rejected.bin']==files[folder+'/contact-1/diagnostic-rejected.bin']
  rows=files[folder+'/contact-1/native-coupled-transaction.csv'].decode().splitlines()
  transactions=[row.split(',') for row in rows if row.startswith('TRANSACTION,')]
  assert len(transactions)==4
  for row in transactions[:2]:
   assert int(row[2])==0 and int(row[3])==1 and int(row[4])>=1 and int(row[5])>=2 and int(row[6])==int(row[4])+int(row[5])
   assert max(abs(float(row[8])),abs(float(row[9])))<=1e-10 and 0<=float(row[10])<=1e-6
   assert float(row[11])<=1e-9 and float(row[12])>0
  for row in transactions[2:]:assert int(row[2])!=0 and int(row[3])==0
  revisions=[row.split(',') for row in rows if row.startswith('REVISION,')];assert [int(x[2]) for x in revisions]==[1,1,0,0]
  for kind in [0,1]:
   assert 'NATIVE_TYPED_DISK_RESTART_EXACT,'+str(kind) in rows
   data=files[folder+f'/contact-1/native-coupled-accepted-{kind}.bin']
   assert data[:8]==b'S5NC0001' and zlib.crc32(data[:-4])==struct.unpack('=I',data[-4:])[0]
   assert data[72:136].rstrip()==b'ANDELST_ACTION_NATIVE_FEEDBACK_V1'
   assert struct.unpack('=i',data[144:148])[0]==kind
   assert struct.unpack('=q',data[148:156])[0]==1
  windows=[row.split(',') for row in rows if row.startswith('WINDOW,')]
  for row in windows[:2]:
   assert int(row[2])>=2 and int(row[3])>=1 and float(row[4])>1e-6 and abs(float(row[5]))<=1e-10
  assert sum(row.startswith('ACCEPTED_NODE,') for row in rows)==224
 assert not record['original_outer_interval_accepted'] and not record['full_physical_energy_complete']
 return 'CORRECTED_NATIVE_FULL_WINDOW_FEEDBACK_HISTORY_AND_DISK_VERIFIED; ORIGINAL_OUTER_FULL_ENERGY_OPEN'
if __name__=='__main__':print(verify())
