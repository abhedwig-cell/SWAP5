"""Default coupled preservation using the verified current runtime build."""
from pathlib import Path
import argparse,json,subprocess,os,hashlib,io,tarfile,base64,struct
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--providers',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();w=a.providers.resolve();out=a.output.resolve();out.mkdir(exist_ok=False);sha=lambda b:hashlib.sha256(b).hexdigest();r=json.loads((w/'result.json').read_bytes());events=json.loads((w/'events.json').read_bytes());fc=os.environ.get('FC','gfortran')
for path,h in r['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h
source=(w/'driver.f90').read_text();start=source.index(' subroutine crop_depletion_joint()');end=source.index(' subroutine require(ok,label)');source=source[:start]+(ROOT/'tests/nut-crop/crop_depletion_joint.inc').read_text()+source[end:];driver=out/'driver.f90';driver.write_text(source)
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/crop_only_depletion/COMPOSITION.tar.xz.b64').read_bytes())))as t:prior=json.load(t.extractfile('joint/result.json'))['results']
assert all(e['returncode']==0 for e in events);results={};records=[];bindings={}
def run(cmd):
 e=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True);row=dict(command=list(map(str,cmd)),returncode=e.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(records):04d}.{k}';(out/name).write_bytes(getattr(e,k));row[k]=name
 records.append(row);(out/'events.json').write_text(json.dumps(records,indent=2));assert e.returncode==0,(row,e.stdout.decode(),e.stderr.decode())
for opt in ['O0','O2']:
 b=out/opt;b.mkdir();link=next(e['command']for e in events if e['category']=='link'and '-'+opt in e['command']);objects=[Path(v)for v in link if v.endswith('.o')][:-1];flags=link[1:link.index(str(objects[0]))];provider_files=objects+list((w/opt).glob('*.mod'));bound={str(f):sha(f.read_bytes())for f in provider_files};bindings.update(bound)
 obj=b/'driver.o';exe=b/'default';run([fc,*flags,'-c',driver,'-o',obj]);run([fc,*flags,*objects,obj,'-o',exe])
 for case in [k.split('/')[1]for k in prior if k.startswith(opt+'/')]:
  checkpoint=b/(case+'.restart');endpoint=b/(case+'.endpoint');run([exe,'write',checkpoint,endpoint,case]);row=prior[opt+'/'+case];assert sha(endpoint.read_bytes())==row['endpoint_sha256']and sha(Path(str(endpoint)+'.ledger').read_bytes())==row['ledger_sha256']
  for day in [1,4]:
   fresh=b/(case+'.fresh-'+str(day));run([exe,'resume',str(checkpoint)+'.'+str(day),fresh,case,str(day)])
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes()
  for day in [2,5]:
   before=Path(str(checkpoint)+'.before-'+str(day)).read_bytes()
   for kind in ['exhaust','stale','water']:assert before==Path(str(checkpoint)+'.'+kind+'-reject-'+str(day)).read_bytes()
  results[opt+'/'+case]=row
 for f,h in bound.items():assert sha(Path(f).read_bytes())==h
result=dict(status='DEFAULT_COUPLED_30_RUNS_60_RESTARTS_BYTE_EXACT_PASS',results=results,provider_source_sha256=r['input_sha256'],provider_objects_and_modules=bindings,provider_result_sha256=sha((w/'result.json').read_bytes()),generated_driver_sha256=sha(driver.read_bytes()),canonically_admitted=False);(out/'result.json').write_text(json.dumps(result,indent=2));print(result['status'])
