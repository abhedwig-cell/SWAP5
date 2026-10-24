"""Nonjuvenile Richards/crop/N using bound current providers and one private-body recompile."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,re,resource,subprocess,tarfile,time,struct
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--providers',type=Path,required=True);args=p.parse_args();provider=args.providers.resolve();out=args.output.resolve();out.mkdir(exist_ok=False);fc=os.environ.get('FC','gfortran');events=[];inputs={};sha=lambda b:hashlib.sha256(b).hexdigest()
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
body=body.replace('cp%lai_crit_nupt=20d0','cp%lai_crit_nupt=0d0')
body=body.replace('nondepleting_top=.true.)','nondepleting_top=.true.,proportional_constant_sinks=.true.)')
body=body.replace("   call require(all(r%chemical%soil%top_unmet==0d0),'nondepleting top has no unmet extraction')", "   call require(all(r%chemical%soil%top_unmet>=0d0),'partition unmet nonnegative')")
body=body.replace("   call require(all(r%chemical%soil%top_actual==r%chemical%soil%top_requested),'all requested top extraction realised')", "   call require(maxval(abs(r%chemical%soil%top_actual-r%chemical%soil%top_unmet-r%chemical%soil%top_requested))<1d-12,'actual and unmet top receipt close request')")
require=source[source.index(' subroutine require(ok,label)'):source.index(" include 'crop_fixture.inc'")]
driver=out/'driver.f90';driver.write_text(prefix+' call crop_depletion_joint()\ncontains\n'+body+require+" include 'crop_fixture.inc'\n include 'material_fixture.inc'\n include 'matrix_fixture.inc'\nend program\nsubroutine swap_error(origin,message)\n character(*)::origin,message\n print *,origin,message\n error stop 1\nend subroutine\n")
for path in ['tests/nut-crop/test_b112_retained_joint.f90','tests/nut-crop/crop_depletion_joint.inc','tests/nut-crop/crop_fixture.inc','tests/nut-material/material_fixture.inc',str(Path(__file__).relative_to(ROOT))]:inputs[path]=sha((ROOT/path).read_bytes())
results={}
provider_result=json.loads((provider/'result.json').read_bytes());provider_events=json.loads((provider/'events.json').read_bytes())
changed='src/process/mod_b111_soil_n_daily_exchange.f90'
for p,h in provider_result['input_sha256'].items():
 if p!=changed:assert sha((ROOT/p).read_bytes())==h,('unqualified reuse drift',p)
inputs.update({p:sha((ROOT/p).read_bytes())for p in provider_result['input_sha256']})
bindings={}
for opt in ['O0','O2']:
 b=out/opt;b.mkdir();(b/'matrix_fixture.inc').write_bytes(archived['matrix_fixture.inc'])
 link=next(e['command']for e in provider_events if e['category']=='link'and '-'+opt in e['command']);objects=[Path(x)for x in link if x.endswith('.o')][:-1];flags=link[1:link.index(str(objects[0]))]
 flags=[('-J'+str(b))if x.startswith('-J')else x for x in flags]
 old_event=next(e for e in provider_events if e['category']=='compile'and '-'+opt in e['command']and str(ROOT/changed)in e['command']);oldobj=Path(old_event['command'][-1]);assert oldobj in objects
 bound={str(p):sha(p.read_bytes())for p in objects+list((provider/opt).glob('*.mod'))};bindings.update(bound)
 obj=b/'exchange.o';run([fc,*flags,'-c',ROOT/changed,'-o',obj],'changed_compile',b)
 module='mod_b111_soil_n_daily_exchange.mod';assert (b/module).read_bytes()==(provider/opt/module).read_bytes(),'public compiler module interface changed'
 objects=[obj if p==oldobj else p for p in objects]
 driver_obj=b/'driver.o';run([fc,*flags,'-c',driver,'-o',driver_obj],'driver_compile',b);exe=b/'joint';run([fc,*flags,*objects,driver_obj,'-o',exe],'link',b)
 for p,h in bound.items():assert sha(Path(p).read_bytes())==h,'provider objects or modules mutated'
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
r=dict(status='NONJUVENILE_ACTUAL_PARTITION_CROP_RICHARDS_O0_O2_PASS',provider_result_sha256=sha((provider/'result.json').read_bytes()),provider_objects_and_modules=bindings,runs=4,restarts=8,days=8,results=results,input_sha256=inputs,canonically_admitted=False);(out/'result.json').write_text(json.dumps(r,indent=2));print(r['status'])
