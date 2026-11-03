"""Seal completed source-bound Windows measurements, including failed development probes."""
import argparse, hashlib, io, json, subprocess, tarfile
from pathlib import Path
from audit_native_donors import audit
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser()
 for name in ['native-o0','native-o2','component-o0','component-o2']:p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 files={};reports={};digest=lambda data:hashlib.sha256(data).hexdigest()
 for name in ['native-o0','native-o2','component-o0','component-o2']:
  folder=getattr(a,name.replace('-','_')).resolve();r=json.loads((folder/'RESULT.json').read_text(encoding='utf-8'));reports[name]=r
  assert r.get('owned_native_substep_accepted') if name.startswith('native') else r['status']=='PASS'
  for path,blob in r.get('source_git_blob',r.get('sources',{})).items():
   assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==blob,path
  for path in folder.rglob('*'):
   if not path.is_file():continue
   rel=path.relative_to(folder).as_posix()
   if '/original/' in '/'+rel or rel.endswith(('.o','.mod','.tmp')):continue
   if rel.startswith('build/') and rel!='build/native.exe':continue
   files[name+'/'+rel]=path.read_bytes()
  if name.startswith('native'):
   for i,entry in enumerate(json.loads((folder/'COMPILED_INPUTS.json').read_text(encoding='utf-8'))):
    data=Path(entry['source']).read_bytes();assert digest(data)==entry['source_sha256']
    files[name+'/compiled-source/'+str(i)+'.f90']=data
 files['historical-donors.json']=(json.dumps(audit(),indent=2)+'\n').encode()
 for folder in sorted(ROOT.parent.glob('native-coupled-O*-0*')):
  if folder in [a.native_o0.resolve(),a.native_o2.resolve()]:continue
  for rel in ['RESULT.json','contact-1/native-coupled-context.csv','contact-1/native-coupled-transaction.csv','compile-205.stderr']:
   if (folder/rel).is_file():files['failed-development/'+folder.name+'/'+rel]=(folder/rel).read_bytes()
 manifest={name:digest(data) for name,data in files.items()};files['MANIFEST.json']=(json.dumps(manifest,indent=2)+'\n').encode()
 archive=a.output.with_suffix('.tar.xz');archive.parent.mkdir(parents=True,exist_ok=True)
 with tarfile.open(archive,'w:xz') as t:
  for name,data in sorted(files.items()):
   item=tarfile.TarInfo(name);item.size=len(data);t.addfile(item,io.BytesIO(data))
 record=dict(archive=archive.resolve().relative_to(ROOT).as_posix(),archive_sha256=digest(archive.read_bytes()),
  baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),platform='Windows',
  status='CORRECTED_NATIVE_SUBSTEP_ACCEPTED_ORIGINAL_OUTER_AND_FULL_ENERGY_OPEN',
  native={name:dict(optimization=r['optimization'],baseline=r['baseline'],events=r['events'],
   transaction_rows=[x for x in r['native_transaction_rows'] if x.startswith(('TRANSACTION','WINDOW','REVISION'))]) for name,r in reports.items() if name.startswith('native')},
  component_closure=11,original_outer_interval_accepted=False,full_physical_energy_complete=False,
  independent_historical_water_donor_temperatures=False)
 a.output.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8');print(archive,archive.stat().st_size)
if __name__=='__main__':main()
