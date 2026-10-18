"""Focused HIST candidate: actual shared production closure, no inherited native PASS.

The closure is large because the existing production bootstrap owns Richards.
Every provider is compiled fresh, with isolated O0/O2 artifacts and strict flags.
"""
from pathlib import Path
import ast,base64,hashlib,io,json,os,re,shutil,subprocess,tarfile,time
from prepare_oracle import prepare
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_HIST_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
LITERAL=Path(os.environ['REPRODUCTIVE_LITERAL_FILE']).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
events=[];inputs={};results={}
for helper in ['tests/nut-crop/prepare_oracle.py','tests/nut-reactive/reactive_oracle.inc','tests/nut-crop/crop_oracle.inc','tests/nut-crop/senescence_oracle.inc']:
 if (ROOT/helper).exists():inputs[helper]=sha(ROOT/helper)
def run(args,b,category):
 args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=args,category=category,returncode=p.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(str(i)+' '+p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:
 raws={n:t.extractfile('SWAP/'+n).read()for n in ['wofost_soil_declarations.f90','management_soil.f90','wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90']}
assert hashlib.sha256(raws['management_soil.f90']).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
legacy=ROOT/'tests/nut-senescence/run_senescence.py'
node=next(n for n in ast.parse(legacy.read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='oracle'for t in n.targets))
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir()
 for name,raw in raws.items():(b/name).write_bytes(raw)
 old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio'
 new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
 assert raws['wofost_soil_orgmatn.f90'].count(old)==1
 (b/'wofost_soil_orgmatn.f90').write_bytes(raws['wofost_soil_orgmatn.f90'].replace(old,new))
 prepare(ROOT,b,raws['management_soil.f90'])
 (b/'material_oracle.inc').write_text(ast.literal_eval(node.value))
 (b/'oracle_fixture.f90').write_text('module MOD_texture_orgmat\n use iso_fortran_env,only:real64\n real(real64)::bdens(1)\nend module\nsubroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
 text=(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text().replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 (b/'reactive_grid_stubs.f90').write_text(text[:text.index('subroutine swap_error(origin, message)')])
 text=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text();a=text.index('  subroutine initialize_application_config');z=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 (b/'matrix_fixture.inc').write_text(text[a:z]+'\n')
 providers={}
 for p in list((ROOT/'src').rglob('*.f90'))+[b/'wofost_soil_declarations.f90',b/'oracle_fixture.f90',b/'reactive_grid_stubs.f90',LITERAL]:
  for m in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[m.lower()]=p
 ordered=[];seen=set()
 def visit(p):
  if p in seen:return
  seen.add(p)
  for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   m=m.lower()
   if m in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
   if m not in providers:raise RuntimeError('unresolved '+m)
   if providers[m]!=p:visit(providers[m])
  ordered.append(p)
 driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';visit(driver);ordered.remove(driver)
 for p in [b/'wofost_soil_declarations.f90',b/'oracle_fixture.f90']:
  if p not in ordered:ordered.append(p)
 ordered += [b/n for n in ['wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90','literal_crop_exchange.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90']]
 ordered += [ROOT/'src/legacy/b1_10_port/headcalc.f90',driver]
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-g','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 for folder in ['nut-crop','nut-reactive','nut-sol','nut-material']:flags+=['-I'+str(ROOT/'tests'/folder)]
 objects=[]
 for i,p in enumerate(ordered):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',o],b,'compile');objects.append(o)
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
 exe=b/'hist';run(['gfortran',*flags,*objects,'-o',exe],b,'link')
 # Original two-day owner has independent historical chemistry/N assertions,
 # harvest, annual chemical fallow and successor preservation inside the driver.
 default_restart=b/'default.restart';default_endpoint=b/'default.endpoint';default_fresh=b/'default.fresh'
 default_out=run([exe,'write',default_restart,default_endpoint],b,'native')
 run([exe,'resume',default_restart,default_fresh],b,'native')
 assert default_endpoint.read_bytes()==default_fresh.read_bytes()==Path(str(default_endpoint)+'.opaque').read_bytes()
 # Original composition and its fresh-process endpoint stay selected.
 outputs={}
 for profile in ['source-profile','rotation-profile','atmospheric-profile','humus-profile']:
  restart=b/(profile+'.restart');endpoint=b/(profile+'.endpoint')
  outputs[profile]=run([exe,'write',restart,endpoint,profile],b,'native')
  if profile=='source-profile':
   fresh=b/(profile+'.fresh');run([exe,'resume',restart,fresh,profile],b,'native');assert endpoint.read_bytes()==fresh.read_bytes()
  else:
   for day in [120,366]:
    if profile in ['atmospheric-profile','humus-profile']:assert Path(str(restart)+'.clean-reject-'+str(day)).read_bytes()==Path(str(restart)+'.reject-before-'+str(day)).read_bytes(),'clean-only route leaked state'
    assert Path(str(restart)+'.reject-before-'+str(day)).read_bytes()==Path(str(restart)+'.reject-after-'+str(day)).read_bytes(),'rejected rotation day leaked state'
   for day in [1,120,121,365,366,500]:
    fresh=b/(profile+'-fresh-'+str(day));run([exe,'resume',str(restart)+'.'+str(day),fresh,profile,str(day)],b,'restart_native')
    assert endpoint.read_bytes()==fresh.read_bytes(),('fresh rotation drift',day)
 results[opt]=dict(default_endpoint=sha(default_endpoint),default_stdout=default_out,endpoint={p:sha(b/(p+'.endpoint'))for p in ['source-profile','rotation-profile','atmospheric-profile','humus-profile']},stdout=outputs,providers=len(ordered)-1)
 assert all(sha(ROOT/p)==v for p,v in inputs.items()),'source changed during execution'
assert results['O0']==results['O2'],'O0/O2 endpoint or observable mismatch'
inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__))
r=dict(status='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,results=results,compiler=run(['gfortran','--version'],OUT,'compiler').splitlines()[0],literal_sha256=sha(LITERAL),authority_sha256={n:hashlib.sha256(v).hexdigest()for n,v in raws.items()},cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native','restart_native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
