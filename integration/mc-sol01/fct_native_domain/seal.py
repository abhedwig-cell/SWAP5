"""Retain source-bound small-process development rounds, not native admission."""
import argparse,base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('rounds',type=Path,nargs='+');a=ap.parse_args();files={};results=[]
 helpers=['integration/mc-sol01/fct_native_domain/generate.py','integration/mc-sol01/fct_native_domain/run.py',
  'integration/mc-sol01/fct_sinks/generate.py','integration/mc-sol01/fct_sinks/process_driver.f90',
  'integration/mc-sol01/fct_reactive/generate.py','integration/mc-sol01/fct_accepted_trace/qualify_replay.py',
  'integration/mc-sol01/fct_water_sorption/mod_research_storage_fct.f90']
 for i,folder in enumerate(a.rounds):
  r=json.loads((folder/'RESULT.json').read_text());assert r['status']=='PROCESS_EXTENSION_PASS_NOT_NATIVE_ACTIVATION' and r['cases']==96
  label='round'+str(i+1);results.append({k:v for k,v in r.items() if k not in ['events','inputs','closure']})
  files[label+'/RESULT.json']=(folder/'RESULT.json').read_bytes()
  files[label+'/commit.raw']=subprocess.check_output(['git','cat-file','commit',r['baseline']],cwd=ROOT)
  for p in sorted(set(helpers)|set(r['inputs'])):
   b=subprocess.check_output(['git','show',r['baseline']+':'+p],cwd=ROOT)
   if p in r['inputs']:assert sha(b)==r['inputs'][p]
   files[label+'/source/'+p]=b
  for p in folder.glob('*.f90'):files[label+'/generated/'+p.name]=p.read_bytes()
 files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())}).encode();stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as t:
  for p,b in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
 raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
 index=dict(sha256=sha(raw),bytes=len(raw),members=len(files),rounds=results,native_qualification=False,production_activated=False)
 (HERE/'EVIDENCE_INDEX.json').write_text(json.dumps(index,indent=2)+'\n');print(json.dumps(index,indent=2))
if __name__=='__main__':main()
