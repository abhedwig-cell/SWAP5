"""Verify explicit corrected contact memory and independent macro thermal evidence."""
import hashlib,json,subprocess,tarfile,zlib,struct,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def verify():
 r=json.loads((ROOT/'integration/dataqual15/CONTACT_MEMORY_WINDOWS_EVIDENCE_20261103.json').read_text(encoding='utf-8'))
 assert not git('diff','65d881cc9678ec8c6d7b0cb7c92207f3ed5f7043','HEAD','--','src','app','reference')
 p=ROOT/r['archive'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['archive_sha256']
 with tarfile.open(p) as t:files={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
 m=json.loads(files.pop('MANIFEST.json'));assert m.keys()==files.keys()
 for name,h in m.items():assert hashlib.sha256(files[name]).hexdigest()==h,name
 for folder in ['native-O0','native-O2','components','thermal']:
  report=json.loads(files[folder+'/RESULT.json'])
  for name,blob in report['source_git_blob'].items():
   assert git('rev-parse','HEAD:'+name)==blob,name
   assert not git('diff','HEAD','--',name),'uncommitted input'
  if folder.startswith('native'):
   assert report['private_coupled_candidate_history_complete'] and report['contact_memory_closure_available'] and not report['full_coupled_step_accepted']
   assert report['policy']=='EXPLICIT_CORRECTED_ACTION_CLOCK_NOT_ORIGINAL_BINARY_MODEL'
   assert hashlib.sha256(files[folder+'/build/native.exe']).hexdigest()==report['executable_sha256']
   for name,h in report['rendered_sha256'].items():assert hashlib.sha256(files[folder+'/overlay/'+name]).hexdigest()==h
   cert=json.loads(files[folder+'/COMPILED_INPUTS.json']);assert len(cert)==203
   for i,e in enumerate(cert):assert hashlib.sha256(files[folder+'/compiled-source/'+str(i)+'.f90']).hexdigest()==e['source_sha256']
   rows=files[folder+'/contact-1/coupled-contact.csv'].decode().splitlines();trials=[x.split(',') for x in rows if x.startswith('COUPLED,')];assert len(trials)==5 and [x[2] for x in trials]==['T','T','T','F','F']
   actions=[x.split(',') for x in rows if x.startswith('ACTION_HISTORY,')];assert len(actions)==3 and all(x[2:4]==['T','T'] and float(x[5])>0 for x in actions)
   old=[x.split(',') for x in rows if x.startswith('HISTORY_BRANCHES,')];assert len(old)==3 and all(x[2:5]==['T','T','F'] for x in old)
   assert files[folder+'/contact-0/origin.bin']==files[folder+'/contact-0/diagnostic-rejected.bin']==files[folder+'/contact-1/diagnostic-rejected.bin']
   for name in ['contact-0/origin.bin','actual-prefix/restart.bin']:
    raw=files[folder+'/'+name];assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
  else:
   for opt in ['O0','O2']:
    if folder=='components':
     for name,test in report['builds'][opt]['tests'].items():
      assert hashlib.sha256(files[folder+'/'+opt+'/'+name+'.exe']).hexdigest()==test['executable_sha256']
      assert files[folder+'/'+opt+'/'+name+'.stdout'].decode().replace('\r\n','\n')==test['stdout']
    else:
     assert not report['model']['full_physical_energy_complete']
     assert hashlib.sha256(files[folder+'/'+opt+'/replay.exe']).hexdigest()==report['builds'][opt]['executable_sha256']
     assert files[folder+'/'+opt+'/run.stdout'].decode().replace('\r\n','\n')==report['builds'][opt]['stdout']
     totals=[]
     for steps in [1,4,16,64]:
      raw=files[folder+'/'+opt+'/macro-ledger-'+str(steps)+'.csv'];rows=[list(map(float,line.rstrip(',').split(','))) for line in raw.decode().splitlines()];assert len(rows)==194
      for row in rows:assert len(row)==7 and abs(row[2]+row[4]-row[3]-row[5])<1e-11
      assert max(abs(row[5]) for row in rows)<1e-10;totals.append(sum(row[4] for row in rows))
     assert abs(totals[3]-totals[2])<abs(totals[2]-totals[1])<abs(totals[1]-totals[0])
     assert report['builds'][opt]['files_sha256']==report['builds']['O0']['files_sha256']
     for name,h in report['builds'][opt]['files_sha256'].items():assert hashlib.sha256(files[folder+'/'+opt+'/'+name]).hexdigest()==h
 for name in ['contact-1/coupled-contact.csv','actual-prefix/actual-thermal.csv','actual-prefix/actual-transport.csv']:assert files['native-O0/'+name]==files['native-O2/'+name]
 assert files['native-O0/actual-prefix/restart.bin'][72:-4]==files['native-O2/actual-prefix/restart.bin'][72:-4]
 print('EXPLICIT_ACTION_MEMORY_NATIVE_CANDIDATE_AND_REFINED_INDEPENDENT_MACRO_TEMPERATURE_VERIFIED; ORIGINAL_COMMIT_FULL_PHYSICAL_ENERGY_OPEN')
 return r
if __name__=='__main__':verify()
