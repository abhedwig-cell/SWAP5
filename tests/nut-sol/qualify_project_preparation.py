"""Check native historical project preparation independently of physical execution.

Constructed supported fixtures, authentic Andelst weather, complete original
fixed.f90/ETpot oracle. This is NOT an annual transport qualification.
"""
import argparse,base64,csv,gzip,hashlib,json,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/solute'))
from run_project import prepare,native
def sha(raw):return hashlib.sha256(raw).hexdigest()
def rows(path):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(path.open())]
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--annual-fixture',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 source,source_sha=runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_simple_crop.py'))['oracle']()
 inputs=['tests/nut-sol/qualify_project_preparation.py','tests/nut-sol/qualify_native_simple_crop.py',
  'tools/solute/run_project.py','tools/solute/run_crop_daily.py',
  'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
  'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.998.gz',
  'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz']
 report=dict(status='RUNNING',scope='PREPARATION_ONLY_NOT_ANNUAL_PHYSICAL',
  inputs={p:sha((ROOT/p).read_bytes())for p in inputs},original_fixed_sha256=source_sha,
  cases={},events=[],original_exact_values=0,invalid_inputs=0)
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=120)
  n=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{n:04d}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),cwd=str(cwd),returncode=r.returncode,seconds=time.perf_counter()-start))
  if r.returncode:report['status']='FAILED'
  save();assert r.returncode==0,(cmd,r.stderr[-3000:])
 for opt in ['O0','O2']:
  bundle=json.loads((getattr(a,'bundle_'+opt)/'bundle.json').read_text());folder=out/opt;folder.mkdir()
  build=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
  assert bundle['optimization']==opt
  archive=[p for p in build['reused_artifact_sha256']if p.endswith('/libttutil.a')];assert len(archive)==1
  assert sha(Path(archive[0]).read_bytes())==build['reused_artifact_sha256'][archive[0]]
  (folder/'original.f90').write_text(source);original=folder/'original'
  run(build['compiler_command']+['-'+opt,'-std=legacy','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
   '-ffpe-trap=invalid,zero,overflow','-J'+str(folder),folder/'original.f90',archive[0],'-o',original],folder)
  for name,days,periods in [('annual1998',365,2),('cross_year',481,3)]:
   case=folder/name;case.mkdir()
   for sub in ['Crop Data','Weather Data']:
    (case/sub).mkdir()
    for p in (a.annual_fixture/sub).iterdir():
     if p.is_file():(case/sub/p.name).write_bytes(p.read_bytes())
   swp=(a.annual_fixture/'Project.SWP').read_text()
   if name=='cross_year':
    swp=swp.replace('TEND=31-dec-1998','TEND=26-apr-1999').replace("01-sep-1998 30-nov-1998 'second' 1", "01-sep-1998 30-nov-1998 'second' 1\n01-feb-1999 26-apr-1999 'first' 1")
    met=ROOT/inputs[-1];(case/'Weather Data/History.999').write_bytes(gzip.decompress(met.read_bytes()))
   (case/'Project.SWP').write_text(swp)
   document,snapshot,audit,_=prepare(bundle,case/'Project.SWP',1e-4)
   assert audit['days']==days and audit['periods']==periods
   assert max(audit['profile_index'])==periods and 0 in audit['profile_index']
   (case/'input.nml').write_text(document);(case/'audit.json').write_text(json.dumps(audit,indent=2)+'\n')
   stage=case/'oracle';stage.mkdir()
   for key,h in audit['original_sources'].items():
    raw=base64.b64decode(''.join(l.split('=',1)[1]for l in document.splitlines()if l.startswith('! '+key+'_base64=')))
    assert sha(raw)==h
    filename='input.swp'if key=='original_swp'else('weather-'if key.startswith('met_')else'crop-')+key.split('_')[1]+('.met'if key.startswith('met_')else'.crp')
    (stage/filename).write_bytes(raw)
   native(Path(bundle['project_reader']),['input.swp','prepare'],stage,b'SWP_NATIVE_PROJECT_PREPARED')
   values=0
   for p in audit['prepared_periods']:
    index=str(p['index']);run([original,'period-'+index+'.swp','crop-'+index+'.crp','weather.met'],stage)
    expected=rows(stage/'original.csv');actual=[{k:float(v)for k,v in r.items()}for r in p['plan']]
    assert len(expected)==days and actual==expected,(opt,name,index,'original daily preparation differs')
    values+=days*9;(stage/'original.csv').rename(stage/('original-'+index+'.csv'))
   for i,index in enumerate(audit['profile_index']):
    active=[p['index']for p in audit['prepared_periods']if float(p['plan'][i]['active'])==1]
    assert active==([]if index==0 else[index]),(name,i,index,active)
   report['cases'][opt+'-'+name]=dict(days=days,periods=periods,original_exact_values=values,
    source_sha256=audit['original_sources'],profile_index=audit['profile_index'],original_Andelst_model=False)
   report['original_exact_values']+=values;save()
   # Missing future inputs and a malformed late crop must fail preparation too.
   for label,path in [('late_crop',case/'Crop Data/Second.CRP'),('weather',case/'Weather Data/History.998')]:
    raw=path.read_bytes();path.unlink()
    try:
     try:prepare(bundle,case/'Project.SWP',1e-4)
     except (ValueError,FileNotFoundError):pass
     else:raise AssertionError('missing input accepted: '+label)
    finally:path.write_bytes(raw)
    report['invalid_inputs']+=1
   last=case/'Crop Data/Second.CRP';raw=last.read_bytes();last.write_text('SWIRRF=1\n')
   try:
    try:prepare(bundle,case/'Project.SWP',1e-4)
    except ValueError:pass
    else:raise AssertionError('unsupported future crop accepted')
   finally:last.write_bytes(raw)
   report['invalid_inputs']+=1;save()
 assert report['original_exact_values']==39114 and report['invalid_inputs']==12
 assert report['inputs']=={p:sha((ROOT/p).read_bytes())for p in inputs}
 report['status']='NATIVE_PROJECT_HISTORICAL_PREPARATION_ONLY_O0_O2_PASS';save()
 print(json.dumps({k:v for k,v in report.items()if k not in ['cases','events','inputs']}))
if __name__=='__main__':main()
