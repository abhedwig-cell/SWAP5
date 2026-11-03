"""Verify bounded full-column/history counterexample and native transport data."""
import hashlib,json,struct,subprocess,tarfile,zlib
from pathlib import Path
from analyze_transport_donors import analyze
from analyze_native_thermal_receipts import analyze as thermal
ROOT=Path(__file__).resolve().parents[2]
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def verify():
 record=json.loads((ROOT/'integration/dataqual15/COUPLED_CONTACT_WINDOWS_EVIDENCE_20261103.json').read_text(encoding='utf-8'))
 assert not git('diff','4600df4b695269fa1a36d79dbaffde8b7a547eff','HEAD','--','src','app','reference'),'production changed'
 assert not record['full_coupled_step_accepted'] and not record['full_energy_balance_complete'] and not record['history_memory_closure_available']
 wrapper=record['uncompiled_orchestrator_successor'];assert git('rev-parse','HEAD:'+wrapper['path'])==wrapper['current_blob']
 archive=ROOT/record['archive'];assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['archive_sha256']
 with tarfile.open(archive) as t:files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
 manifest=json.loads(files.pop('MANIFEST.json'));assert manifest.keys()==files.keys()
 for name,raw in files.items():assert hashlib.sha256(raw).hexdigest()==manifest[name],name
 for opt in ('O0','O2'):
  r=json.loads(files[opt+'/RESULT.json']);measurement=record['measurements'][opt];assert r['source_git_blob']==measurement['source_git_blob']
  for name,blob in r['source_git_blob'].items():
   assert not git('diff','HEAD','--',name),'uncommitted input'
   if name==wrapper['path']:
    assert git('rev-parse',r['baseline']+':'+name)==blob
    assert hashlib.sha1(b'blob '+str(len(files[opt+'/measurement-orchestrator.py'])).encode()+b'\0'+files[opt+'/measurement-orchestrator.py']).hexdigest()==blob
   else:assert git('rev-parse','HEAD:'+name)==blob,name
  for name,digest in r['rendered_sha256'].items():assert hashlib.sha256(files[opt+'/overlay/'+name]).hexdigest()==digest,name
  assert hashlib.sha256(files[opt+'/build/native.exe']).hexdigest()==r['executable_sha256']
  compiled=json.loads(files[opt+'/COMPILED_INPUTS.json']);assert len(compiled)==202
  for i,e in enumerate(compiled):assert hashlib.sha256(files[opt+'/compiled-source/'+str(i)+'.f90']).hexdigest()==e['source_sha256']
  utilities=json.loads(files[opt+'/TTUTIL_BUILD.json']);assert utilities['status']=='BUILT'
  for name,digest in utilities['source_sha256'].items():assert hashlib.sha256(files[opt+'/ttutil-source/'+name.replace('\\','/')]).hexdigest()==digest
  rows=files[opt+'/contact-1/coupled-contact.csv'].decode().splitlines()
  trials=[row.split(',') for row in rows if row.startswith('COUPLED,')];assert len(trials)==5 and [x[2] for x in trials]==['T','T','T','F','F']
  assert max(float(x[-2]) for x in trials[:3])<1e-10 and all(abs(float(x[-1]))<1e-11 for x in trials[:3])
  for tag in ['MACRO_STORAGE','MACRO_VERTICAL']:
   rr=[x.split(',') for x in rows if x.startswith(tag+',')];assert len(rr)==3 and all(x[2]=='T' and abs(float(x[3]))<1e-10 for x in rr)
  histories=[x.split(',') for x in rows if x.startswith('HISTORY_BRANCHES,')];assert len(histories)==3 and all(x[2:5]==['T','T','F'] and float(x[5])>0 for x in histories)
  nodes=[x.split(',') for x in rows if x.startswith('NODE,')];assert len(nodes)==336
  for case in ['contact-0/origin.bin','contact-0/diagnostic-rejected.bin','contact-1/diagnostic-rejected.bin','actual-prefix/restart.bin']:
   raw=files[opt+'/'+case];assert raw[:8]==b'S5WM0001' and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
  assert files[opt+'/contact-0/origin.bin']==files[opt+'/contact-0/diagnostic-rejected.bin']==files[opt+'/contact-1/diagnostic-rejected.bin']
  analysis,cases=analyze(files[opt+'/actual-prefix/actual-thermal.csv'],files[opt+'/actual-prefix/actual-transport.csv']);assert analysis['intervals']==194 and not analysis['full_energy_balance_complete']
  assert thermal(files[opt+'/actual-prefix/actual-thermal.csv'])['intervals']==194
 for name in ['contact-1/coupled-contact.csv','actual-prefix/actual-thermal.csv','actual-prefix/actual-transport.csv']:assert files['O0/'+name]==files['O2/'+name]
 assert files['O0/actual-prefix/restart.bin'][72:-4]==files['O2/actual-prefix/restart.bin'][72:-4]
 donors=json.loads(files['donors/RESULT.json']);assert donors==record['actual_transport_analysis'] and set(donors['corrupt_actual_data_controls'].values())=={'REJECTED'}
 assert donors['builds']['O0']['stdout']==donors['builds']['O2']['stdout']
 for opt in ['O0','O2']:
  assert files['donors/'+opt+'/run.stdout'].decode()==donors['builds'][opt]['stdout']
  assert hashlib.sha256(files['donors/'+opt+'/donor.exe']).hexdigest()==donors['builds'][opt]['executable_sha256']
 print('FULL112_NONLINEAR_STORAGE_VERTICAL_VERIFIED_HISTORY_NONUNIQUE_REFUSED; ACTUAL_TRANSPORT_VERIFIED_FULL_ENERGY_OPEN')
 return record
if __name__=='__main__':verify()
