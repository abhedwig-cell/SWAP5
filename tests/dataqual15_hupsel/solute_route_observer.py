"""Output-only copied-source observer for real accepted solute suffixes."""
import argparse,csv,hashlib,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ROUTE='src/runtime/mod_fmr_b111_pond_solute_route.f90'
MAIN='app/solute_project/main.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

RAW='''
    block
      integer,save::observer_unit=0
      if(observer_unit==0)open(newunit=observer_unit,file='solute_trials.dat',status='replace',action='write')
      write(observer_unit,'(*(es25.17e3,1x))')t%t0,t%t1,r%mass_before_mg_cm2,r%mass_after_mg_cm2, &
        r%external_input_mg_cm2+pond_receipt%dry_input,r%external_output_mg_cm2, &
        r%decay_output_mg_cm2,r%root_output_mg_cm2,r%drain_output_mg_cm2,r%bottom_output_mg_cm2, &
        r%runoff_output_mg_cm2,r%bottom_input_mg_cm2,r%drain_input_mg_cm2,f%dt_day, &
        sum(max(f%qdra_cm_day,0d0))*f%dt_day,max(-f%q_face_up_cm_day(n+1),0d0)*f%dt_day, &
        sum(f%root_sink_cm_day)*f%dt_day, &
        sum(max(f%qdra_cm_day,0d0)*spread(mobile%concentration_mg_cm3,1,size(f%qdra_cm_day,1)))*f%dt_day, &
        max(-f%q_face_up_cm_day(n+1),0d0)*mobile%concentration_mg_cm3(n)*f%dt_day, &
        f%tscf*sum(f%root_sink_cm_day*mobile%concentration_mg_cm3)*f%dt_day, &
        real(f%transport_scheme,real64),f%tscf,mobile%concentration_mg_cm3(n), &
        next_mobile%concentration_mg_cm3(n),f%q_face_up_cm_day(n+1),amount%pond_mass,next_amount%pond_mass, &
        pond_receipt%dry_input
    end block
'''
ACCEPTED='''
        block
          integer,save::observer_unit=0
          if(observer_unit==0)open(newunit=observer_unit,file='solute_accepted.dat',status='replace',action='write')
          write(observer_unit,'(*(es25.17e3,1x))')s%t0,s%t1,s%chemical_mass_before,s%chemical_mass_after, &
            s%chemical_external_in,s%chemical_external_out,s%chemical_decay_out,s%chemical_residual, &
            merge(1d0,0d0,s%reactive_chemical_available)
        end block
'''

def instrument(route,main):
 anchor='    if(r%status/=B111_REACTIVE_OK)return\n'
 assert route.count(anchor)==1
 changed_route=route.replace(anchor,anchor+RAW)
 anchor2='      associate(s=>observation%accepted_water_flux_substeps(k))\n'
 assert main.count(anchor2)==1
 changed_main=main.replace(anchor2,anchor2+ACCEPTED)
 assert changed_route.replace(RAW,'')==route and changed_main.replace(ACCEPTED,'')==main
 return changed_route,changed_main

def build(bundle,out,fc):
 bundle=bundle.resolve();out.mkdir();record=json.loads((bundle/'BUILD.json').read_text())
 assert subprocess.check_output([fc,'--version'],text=True).splitlines()[0]==record['compiler']
 assert all(sha(Path(n))==h for n,h in record['source_sha256'].items())
 assert all(sha(Path(n))==h for n,h in record['object_sha256'].items())
 assert sha(Path(record['ttutil_archive']))==record['archive_sha256']
 pub=record['publication_provider'];assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(pub['object']))==pub['object_sha256']
 for f in bundle.glob('*.mod'):shutil.copyfile(f,out/f.name)
 route,main=instrument((ROOT/ROUTE).read_text(),(ROOT/MAIN).read_text())
 replacements={ROUTE:route,MAIN:main};objects=list(map(Path,record['object_sha256']));events=[];patches={}
 flags=[f for f in record['flags'] if not f.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
 def run(cmd):
  t=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180)
  i=len(events);(out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-t))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr
 for i,n in enumerate(record['source_sha256']):
  path=Path(n)
  if path.is_relative_to(ROOT) and path.relative_to(ROOT).as_posix() in replacements:
   relative=path.relative_to(ROOT).as_posix();source=out/path.name;source.write_text(replacements[relative],encoding='utf-8',newline='\n')
   obj=out/(str(i)+'.o');run([fc,*flags,'-c',source,'-o',obj]);objects[i]=obj
   patches[relative]=dict(before=record['source_sha256'][n],after=sha(source),postimage=source.name)
 assert set(patches)=={ROUTE,MAIN}
 exe=out/'observed.exe';run([fc,'-fopenmp','-Wl,--stack,16777216',*objects,pub['object'],record['ttutil_archive'],'-o',exe])
 result=dict(baseline_build=record,source_patches=patches,executable_sha256=sha(exe),
             object_sha256={str(p):sha(p) for p in objects},observer_source_sha256=sha(Path(__file__)),events=events)
 (out/'BUILD.json').write_text(json.dumps(result,indent=2)+'\n');return exe

def qualify(opt,bundle,seed,basecase,baseline_outputs,out,fc):
 exe=build(bundle,out/'build',fc);events=[]
 def run(name,checkpoint,compat,capture=None):
  folder=out/name
  cmd=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/run_canopy_observation.py'),'--exe',str(exe),
       '--predecessor',str(basecase),'--strict-restart',str(checkpoint),'--output',str(folder),'--end','1096','--timeout','600']
  if compat:cmd+=['--compatibility-control']
  if capture:cmd+=['--capture',str(capture)]
  cp=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=660)
  (out/(name+'.stdout')).write_bytes(cp.stdout);(out/(name+'.stderr')).write_bytes(cp.stderr)
  events.append(dict(command=cmd,returncode=cp.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  assert cp.returncode==0,(cp.stdout,cp.stderr)
  r=json.loads((folder/'RESULT.json').read_text());assert r['returncode']==0
  return folder
 whole=run('whole',seed,True,1088);tail=run('strict-own-1088',whole/'checkpoint-1088.bin',False)
 assert (whole/'checkpoint.bin').read_bytes()==(baseline_outputs/'checkpoint.bin').read_bytes()
 assert (whole/'checkpoint.bin').read_bytes()==(tail/'checkpoint.bin').read_bytes()
 for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
  read=lambda p:list(csv.DictReader(p.open()))
  prior=read(baseline_outputs/name);w=read(whole/name);r=read(tail/name)
  assert w==[x for x in prior if float(x[clock])>1077]
  assert r==[x for x in w if float(x[clock])>1088]
 report=dict(optimization=opt,baseline_bundle=str(bundle),strict_own_restart=True,
             exact_unobserved_endpoint=True,exact_daily_budget_crop=True,first_seed_scope='Explicit prior-build input-bound compatibility, not strict own-build restart',
             whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('o0','o2','case','o0-tail','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 for opt,bundle,seed,baseline in [('O2',a.o2,a.case/'checkpoint-1077.bin',a.case),
                                 ('O0',a.o0,a.o0_tail/'checkpoint-1077.bin',a.o0_tail)]:
  folder=out/opt;folder.mkdir()
  qualify(opt,bundle.resolve(),seed.resolve(),a.case.resolve(),baseline.resolve(),folder,a.compiler.resolve())
