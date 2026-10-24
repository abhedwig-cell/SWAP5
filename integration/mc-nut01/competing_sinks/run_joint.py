"""Explicit current Richards/crop/N partition with independent process restart."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,re,resource,subprocess,tarfile,time,struct
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);out=p.parse_args().output.resolve();out.mkdir(exist_ok=False);fc=os.environ.get('FC','gfortran');events=[];inputs={};sha=lambda b:hashlib.sha256(b).hexdigest()
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
def run(cmd,kind,cwd):
 start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True);e=dict(command=list(map(str,cmd)),category=kind,seconds=time.monotonic()-start,returncode=r.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(out/name).write_bytes(getattr(r,k));e[k]=name
 events.append(e);(out/'events.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,(e,r.stdout.decode(),r.stderr.decode());return r.stdout
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/crop_only_depletion/COMPOSITION.tar.xz.b64').read_bytes())))as t:
 archived={n:t.extractfile('hist/O0/'+n).read()for n in ['matrix_fixture.inc','reactive_grid_stubs.f90']}
source=(ROOT/'tests/nut-crop/test_b112_retained_joint.f90').read_text();prefix=source[:source.index(" if(trim(selected)=='source-profile'")].replace(' use literal_reproductive,only:literal_n=>literal\n','')
body=(ROOT/'tests/nut-crop/crop_depletion_joint.inc').read_text().replace('sp%mineral%c_top=0d0','sp%mineral%c_top=[.002d0,.005d0]')
body=body.replace('nondepleting_top=.true.)','nondepleting_top=.true.,proportional_constant_sinks=.true.)')
body=body.replace("   call require(all(r%chemical%soil%top_unmet==0d0),'nondepleting top has no unmet extraction')", "   call require(all(r%chemical%soil%top_unmet>=0d0),'partition unmet nonnegative')")
body=body.replace("   call require(all(r%chemical%soil%top_actual==r%chemical%soil%top_requested),'all requested top extraction realised')", "   call require(maxval(abs(r%chemical%soil%top_actual-r%chemical%soil%top_unmet-r%chemical%soil%top_requested))<1d-12,'actual and unmet top receipt close request')")
require=source[source.index(' subroutine require(ok,label)'):source.index(" include 'crop_fixture.inc'")]
driver=out/'driver.f90';driver.write_text(prefix+' call crop_depletion_joint()\ncontains\n'+body+require+" include 'crop_fixture.inc'\n include 'material_fixture.inc'\n include 'matrix_fixture.inc'\nend program\nsubroutine swap_error(origin,message)\n character(*)::origin,message\n print *,origin,message\n error stop 1\nend subroutine\n")
for path in ['tests/nut-crop/test_b112_retained_joint.f90','tests/nut-crop/crop_depletion_joint.inc','tests/nut-crop/crop_fixture.inc','tests/nut-material/material_fixture.inc',str(Path(__file__).relative_to(ROOT))]:inputs[path]=sha((ROOT/path).read_bytes())
results={}
for opt in ['O0','O2']:
 b=out/opt;b.mkdir()
 for n,data in archived.items():(b/n).write_bytes(data)
 providers={}
 for f in list((ROOT/'src').rglob('*.f90'))+[b/'reactive_grid_stubs.f90']:
  for m in re.findall(r'^\s*module\s+(\w+)\s*$',f.read_text(),re.M|re.I):providers[m.lower()]=f
 ordered=[];seen=set()
 def visit(f):
  if f in seen:return
  seen.add(f)
  for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',f.read_text(),re.M|re.I):
   m=m.lower()
   if m in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
   assert m in providers,('unresolved',m)
   if providers[m]!=f:visit(providers[m])
  ordered.append(f)
 visit(driver);ordered.remove(driver);ordered +=[ROOT/'src/legacy/b1_10_port/headcalc.f90',driver]
 flags=['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),'-I'+str(ROOT/'tests/nut-crop'),'-I'+str(ROOT/'tests/nut-material')];objects=[]
 for i,f in enumerate(ordered):
  obj=b/(str(i)+'.o');run([fc,*flags,'-c',f,'-o',obj],'compile',b);objects.append(obj)
  if f.is_relative_to(ROOT):inputs[str(f.relative_to(ROOT))]=sha(f.read_bytes())
 exe=b/'joint';run([fc,*flags,*objects,'-o',exe],'link',b)
 for case in ['crop_nh4','crop_both']:
  checkpoint=b/(case+'.restart');endpoint=b/(case+'.endpoint');run([exe,'write',checkpoint,endpoint,case],'native',b)
  for day in [1,4]:
   fresh=b/(case+'.fresh-'+str(day));run([exe,'resume',str(checkpoint)+'.'+str(day),fresh,case,str(day)],'restart_native',b)
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(fresh)+suffix).read_bytes()
  for day in [2,5]:
   before=Path(str(checkpoint)+'.before-'+str(day)).read_bytes()
   for kind in ['exhaust','stale','water']:assert before==Path(str(checkpoint)+'.'+kind+'-reject-'+str(day)).read_bytes()
  ledger=struct.unpack('14d',Path(str(endpoint)+'.ledger').read_bytes());assert ledger[3]>0 and sum(ledger[9:11])>0 and sum(ledger[7:9])<0 and abs(ledger[0]+ledger[1]-ledger[2]-ledger[13])<1e-12
  if opt=='O2':
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(out/'O0'/(case+'.endpoint'))+suffix).read_bytes()
  results[opt+'/'+case]=dict(endpoint_sha256=sha(endpoint.read_bytes()),ledger=ledger)
r=dict(status='ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS',runs=4,restarts=8,days=8,results=results,input_sha256=inputs,canonically_admitted=False);(out/'result.json').write_text(json.dumps(r,indent=2));print(r['status'])
