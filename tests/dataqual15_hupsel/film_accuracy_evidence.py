"""Audit the complete measured film component dossier, without promoting a trajectory."""
import argparse,base64,gzip,io,json,math,tarfile
from pathlib import Path,PurePosixPath
import film_accuracy as f
BASE=f.BASE;STEM='FILM_ACCURACY_WINDOWS_20261104'

def audit(files):
 r=json.loads(files['RESULT.json']);assert r['profiles']==3206 and r['rooted_nodes']==41678
 assert r['input_sha256']=='70232a44072f546f2abde62bda2db52faeaff4df04b72a9442a49afb9fcd8148'
 assert r['status']=='COMPONENT_REFERENCE_ACCURACY_MEASURED_NOT_TRAJECTORY_ADMISSION'
 assert all(r[k]is False for k in ('production_admission','whole_scientific_admission','reference_trajectory_accuracy_qualified'))
 assert f.sha(files['certified-film.dat'])==r['fixture_sha256']
 table=[line.split()for line in files['certified-film.dat'].decode().splitlines()]
 assert len(table)==3206 and all(int(row[0])==i+1 and 1<=int(row[1])<=34 and len(row)==int(row[1])+2 and all(math.isfinite(float(x))and float(x)>=0 for x in row[2:])for i,row in enumerate(table))
 assert sum(int(row[1])for row in table)==41678
 c=json.loads((f.ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(c['gzip_base64']))
 assert f.sha(literal)==r['source_sha256']=='8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87'
 for opt in ('O0','O2'):
  b=r['builds'][opt];assert f.sha(files[opt+'/compare.exe'])==b['executable_sha256']
  assert files[opt+'/oxygen.f90'].decode().replace('\r\n','\n')==f.adapted_source(literal.decode())
  assert files[opt+'/driver.f90'].decode().replace('\r\n','\n')==f.adapted_driver((f.ROOT/'tests/dataqual15_hupsel/original_factor_comparison.f90').read_text())
  assert files[opt+'/fixture.f90'].decode().replace('\r\n','\n')==f.MODULE
  for path,pin in b['source_sha256'].items():
   path=path.replace('\\','/');key=opt+'/'+path if '/'not in path else 'compiled-source/'+path
   assert f.sha(files[key])==pin
   if '/'in path:assert files[key].replace(b'\r\n',b'\n')==(f.ROOT/path).read_bytes().replace(b'\r\n',b'\n')
  rows=[]
  for mode in ('baseline','certified'):
   data=[list(map(float,line.split()))for line in files[opt+'/'+mode+'.stdout'].decode().splitlines()]
   assert len(data)==41678 and all(len(x)==9 and all(math.isfinite(y)for y in x)for x in data)
   assert [(int(x[0]),int(x[1]))for x in data]==[(i+1,j+1)for i,row in enumerate(table)for j in range(int(row[1]))]
   rows.append(data)
  old,new=rows
  assert all(x[:4]==y[:4]and x[5:7]==y[5:7]and x[8]==y[8]for x,y in zip(old,new))
  before=max(abs(x[4]-x[5])for x in old);after=max(abs(x[4]-x[5])for x in new);binding=max(abs(x[4]-x[6])for x in old)
  assert before==b['unchanged_original_typed_max']>1e-4 and after==b['certified_original_typed_max']<=1e-4
  assert binding==b['original_binding_max']<1e-9 and b['inside_unchanged_assembled_bound']is True
  assert {x['name']for x in b['native_refusals']}=={'wrong-record','wrong-node-count','nonfinite','negative','truncated','extra'}
  for x in b['native_refusals']:assert x['returncode']!=0 and f.sha(files[opt+'/'+x['name']+'.stderr'])==x['stderr_sha256']
 return dict(status='COMPLETE_ORIGINAL_STATE_FILM_COMPONENT_DATA_PASS',profiles=3206,rooted_nodes=41678,native_refusals=12,production_admission=False,whole_scientific_admission=False)

def controls(files):
 trials=[]
 for flag in ('production_admission','whole_scientific_admission','reference_trajectory_accuracy_qualified'):
  r=json.loads(files['RESULT.json']);r[flag]=True;trials.append(dict(files,**{'RESULT.json':json.dumps(r).encode()}))
 r=json.loads(files['RESULT.json']);r['builds']['O0']['certified_original_typed_max']=0;trials.append(dict(files,**{'RESULT.json':json.dumps(r).encode()}))
 for key in ('certified-film.dat','O0/certified.stdout','O2/oxygen.f90'):
  changed=dict(files);changed[key]=files[key][:-20];trials.append(changed)
 for changed in trials:
  try:audit(changed)
  except (AssertionError,ValueError,KeyError,IndexError):pass
  else:raise AssertionError('false component authority accepted')
 return len(trials)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
 if a.capture:
  src=a.capture.resolve();files={}
  for name in ('RESULT.json','WITNESSES.json','certified-film.dat'):files[name]=(src/name).read_bytes()
  r=json.loads(files['RESULT.json'])
  for opt in ('O0','O2'):
   for path in (src/opt).iterdir():
    if path.suffix in ('.f90','.stdout','.stderr','.exe'):files[opt+'/'+path.name]=path.read_bytes()
   for path in r['builds'][opt]['source_sha256']:
    path=path.replace('\\','/')
    if '/'in path:files['compiled-source/'+path]=(f.ROOT/path).read_bytes()
  result=audit(files);result['data_refusals']=controls(files)
  archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz',preset=3)as t:
   for name,raw in sorted(files.items()):i=tarfile.TarInfo(name);i.size=len(raw);t.addfile(i,io.BytesIO(raw))
  manifest=dict(result,archive=archive.name,archive_sha256=f.sha(archive.read_bytes()),files_sha256={n:f.sha(raw)for n,raw in files.items()},measured=result)
  (BASE/(STEM+'.json')).write_text(json.dumps(manifest,indent=2)+'\n')
 else:
  r=json.loads((BASE/(STEM+'.json')).read_text());raw=(BASE/r['archive']).read_bytes();assert f.sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   members=t.getmembers();assert len(members)==len(r['files_sha256']) and all(m.isfile()and not PurePosixPath(m.name).is_absolute()and '..'not in PurePosixPath(m.name).parts for m in members)
   files={m.name:t.extractfile(m).read()for m in members}
  assert set(files)==set(r['files_sha256']) and all(f.sha(raw)==r['files_sha256'][n]for n,raw in files.items())
  result=audit(files);result['data_refusals']=controls(files)
 print(json.dumps(result))
if __name__=='__main__':main()
