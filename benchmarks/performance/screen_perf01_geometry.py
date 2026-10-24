"""Research-only geometry screen; production guards and sources stay intact."""
import csv,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ROUTE=os.environ.get('PERF01_RESEARCH_ROUTE','geometry');assert ROUTE in ['geometry','boesten','combined'];OUT=Path('/tmp/perf01-'+ROUTE+'-'+os.environ.get('PERF01_SCREEN_TAG','screen-v7'));OUT.mkdir()
BASE=Path(os.environ.get('PERF01_SCREEN_BUNDLE','/tmp/perf01-complete-O2'));sys.path.insert(0,str(ROOT/'tools/solute'));import run_project
sha=lambda b:hashlib.sha256(b).hexdigest()
meta=json.loads((BASE/'shared/build-complete.json').read_text());bundle=json.loads((BASE/'bundle.json').read_text())
assert all(sha((ROOT/p).read_bytes())==h for p,h in meta['input_sha256'].items())
r=dict(status='RUNNING',scope='GENERATED_GEOMETRY_RESEARCH_ONLY',route=ROUTE,optimization=bundle['optimization'],production_qualified=False,events=[],cases={})
def save():(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
def run(cmd,cwd,label,required=True):
 start=time.perf_counter();p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120);i=len(r['events'])
 for k in ['stdout','stderr']:(OUT/(str(i)+'.'+k)).write_bytes(getattr(p,k))
 r['events'].append(dict(command=list(map(str,cmd)),label=label,returncode=p.returncode,seconds=time.perf_counter()-start));save()
 if required:assert p.returncode==0,p.stderr.decode()
 return p
source='src/runtime/mod_fmr_serialized_reference_backend.f90';text=(ROOT/source).read_text();start=text.index('  logical function water_flux_trial_admitted(');end=text.index('  end function',start)
old=text[start:end];new=old.replace('p%active_nodes/=4','(p%active_nodes<2.or.p%active_nodes>64)').replace('size(p%dz)/=4','size(p%dz)/=p%active_nodes').replace('if(abs(sum(p%dz)-30.0_real64)>1.e-12_real64)return','if(sum(p%dz)>200.0_real64)return')
assert new!=old and new.count('if(')==old.count('if(')
if ROUTE in ['boesten','combined']:new=new.replace('p%boesten_evaporation_active.or.p%black_evaporation_active','p%black_evaporation_active').replace('t%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.or. &','(t%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BASE.and.t%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION).or. &')
if ROUTE=='combined':new=new.replace('p%picard_conductivity_iteration.or.p%soil_temperature_active','p%soil_temperature_active')
if ROUTE in ['boesten','combined']:
 new=new.replace('    if(.not.allocated(f%pond_input))return\n    if(f%pond_input%implicit_pond_evaporation)return', '    if(p%boesten_evaporation_active)then\n      if(.not.allocated(f%boesten_evaporation))return\n    else\n      if(.not.allocated(f%pond_input))return\n      if(f%pond_input%implicit_pond_evaporation)return\n    end if')
text=text[:start]+new+text[end:]
if ROUTE in ['boesten','combined']:
 at=text.index('  real(real64) function fmr_water_flux_temporal_assessment(');stop=text.index('  end function',at);body=text[at:stop].replace('type is(fmr_b110_physical_state_t)','class is(fmr_b110_physical_state_t)')
 body+='''    if(self%boesten_evaporation_active)then
      select type(bfull=>full_state)
      type is(fmr_b110_boesten_evaporation_state_t)
        select type(bhalf=>half_state)
        type is(fmr_b110_boesten_evaporation_state_t)
          if(.not.all(ieee_is_finite([bfull%boesten_evaporation%spev,bfull%boesten_evaporation%saev,bhalf%boesten_evaporation%spev,bhalf%boesten_evaporation%saev])))then
            value=huge(0d0);return
          end if
          value=max(value,abs(bfull%boesten_evaporation%spev-bhalf%boesten_evaporation%spev),abs(bfull%boesten_evaporation%saev-bhalf%boesten_evaporation%saev))
        class default
          value=huge(0d0)
        end select
      class default
        value=huge(0d0)
      end select
    end if
'''
 text=text[:at]+body+text[stop:]
generated=OUT/Path(source).name;generated.write_text(text);r['source_sha256']=meta['input_sha256'];r['generated_sha256']=sha(generated.read_bytes())
compile=next(e['command']for e in meta['events']if '-c'in e['command']and str(ROOT/source)in e['command']);oldobj=compile[-1];obj=OUT/'backend.o'
cmd=[str(generated)if x==str(ROOT/source)else str(obj)if x==oldobj else '-J'+str(OUT)if x.startswith('-J')else x for x in compile];run(cmd,OUT,'backend-build')
assert(OUT/'mod_fmr_serialized_reference_backend.mod').read_bytes()==(BASE/'shared/mod_fmr_serialized_reference_backend.mod').read_bytes(),'changed public interface'
project=json.loads((BASE/'column/build-complete.json').read_text());link=next(e['command']for e in project['events']if e['category']=='project_compile_link');exe=OUT/'project'
if ROUTE in ['boesten','combined']:
 main=ROOT/'app/solute_project/main.f90';original=main.read_text();changed=original.replace('.not.dynamic_temperature.and..not.implicit_pond_evaporation.and. &\n      .not.retain_accepted_step_proposal','.not.dynamic_temperature.and..not.implicit_pond_evaporation',1).replace('(retain_accepted_step_proposal.and..not.boesten_evaporation)','retain_accepted_step_proposal',1)
 assert changed!=original;generated_main=OUT/'main.f90';generated_main.write_text(changed);link=[str(generated_main)if x==str(main)else x for x in link]
 if ROUTE=='combined':generated_main.write_text(changed.replace('(.not.picard_conductivity_iteration.and. &','(.true..and. &',1))
cmd=[str(obj)if x==oldobj else str(exe)if x==link[-1]else '-J'+str(OUT)if x.startswith('-J')else x for x in link];run(cmd,OUT,'project-build')
for cells in map(int,os.environ.get('PERF01_SCREEN_CELLS','8,24').split(',')):
 assert cells in [8,24]
 for rain in [1,4]:
  case=OUT/f'{cells}-{rain}';case.mkdir();original=Path('/tmp/perf01-complete-measure')/f'{rain}x-input'
  swp=(original/'swap.swp').read_text().replace('1 1 10.0 2',f'1 1 40.0 {cells//2}').replace('2 1 20.0 2',f'2 1 80.0 {cells//2}').replace('HTB=0.,-75.,-30.,-75.','HTB=0.,-75.,-120.,-75.')
  (case/'swap.swp').write_text(swp)
  for n in ['crop.crp','weather.999']:(case/n).write_bytes((original/n).read_bytes())
  outcomes={}
  for arm,on in [('head',False),('flux',True)]:
   d=case/arm;d.mkdir();doc,snapshot,audit,_=run_project.prepare(bundle,case/'swap.swp',.001,surface_exfiltration='historical_zero',retain_step_proposal=True,water_flux_temporal=on)
   (d/'input.nml').write_text(doc);(d/'input.swp').write_bytes(snapshot)
   if ROUTE in ['boesten','combined']:(d/'input.nml').write_text(doc.replace('&column','&column\n boesten_evaporation=.true.,boesten_cofred=.79'+(',picard_conductivity_iteration=.true.'if ROUTE=='combined'else''),1))
   p=run([exe,'input.nml','-','97','input.swp'],d,f'{cells}-{rain}-{arm}',False)
   outcomes[arm]=dict(returncode=p.returncode,seconds=r['events'][-1]['seconds'])
   if p.returncode==0:
    data=list(csv.DictReader((d/'budget.csv').open()));assert len(data)==97
    outcomes[arm]['max_water_residual_cm']=max(abs(float(v['water_residual_cm']))for v in data);assert outcomes[arm]['max_water_residual_cm']<1e-10
  if all(v['returncode']==0 for v in outcomes.values()):
   rows=lambda a:list(csv.DictReader((case/a/'budget.csv').open()));a,b=rows('head'),rows('flux')
   outcomes['max_daily_difference_mm']={k:10*max(abs(float(x[k])-float(y[k]))for x,y in zip(a,b))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']}
   outcomes['physical_screen_pass']=outcomes['max_daily_difference_mm']['runoff_cm']<.01 and outcomes['max_daily_difference_mm']['water_end_cm']<.01 and outcomes['max_daily_difference_mm']['actual_transpiration_cm']<.01
  r['cases'][f'{cells}-{rain}']=outcomes;save()
r['status']='GEOMETRY_RESEARCH_SCREEN_COMPLETED';save();print(json.dumps(r['cases'],indent=2))
