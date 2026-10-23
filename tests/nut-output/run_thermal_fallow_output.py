"""Actual accepted-heat retired/fallow output with unchanged physical providers.

The full cold proof remains source-bound. Generate a thermal version of the
admitted saved-output driver, preserving its scientific assertions; explicit
substitutions select heat owners and independently sampled original temperature.
"""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,resource,signal,struct,subprocess,sys,tarfile,time,zlib
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--thermal',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
COLD=a.cold.resolve();THERMAL=a.thermal.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((COLD/'result.json').read_text());th=json.loads((THERMAL/'result.json').read_text())
assert c['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
assert th['status']=='THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS'
for path,h in {**c['input_sha256'],**th['input_sha256']}.items():assert sha(ROOT/path)==h,path
assert th['cold_proof_sha256']==sha(COLD/'result.json')
old_events=json.loads((COLD/'events.json').read_text());assert all(e['returncode']==0 for e in old_events)
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
helper=(ROOT/'tests/nut-output/saved_output_proof.inc').read_text()
helper=helper.replace('type(soil_n_material_input_t)::none(0)','type(soil_n_material_input_t)::none(2),invalid_material(2)')
helper=helper.replace('  forcing=cfg%tiles(1)%base_forcing;','  call materials(none,split)\n  forcing=cfg%tiles(1)%base_forcing;')
for old,new in [('run_crop_soil_n_saved_harvest','run_crop_soil_n_thermal_saved_harvest'),('run_crop_soil_n_saved_fallow_day','run_crop_soil_n_thermal_saved_fallow_day'),('capture_crop_soil_n_saved_harvest','capture_crop_soil_n_thermal_saved_harvest')]:helper=helper.replace(old,new)
# The output interface explicitly rejects a competing prescribed environment.
helper=helper.replace('r,code,e)', 'r,code)').replace('r,code,e,csv_path=', 'r,code,csv_path=')
old="""    call run_crop_soil_n_material_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters, &
     mw,forcing,cfg%numerical,mc,weather,t,t+1d0,none,split,manual,e,fallow=.true.)"""
assert helper.count(old)==1
helper=helper.replace(old,'    call manual_thermal_fallow(second,mw,mc,forcing,t,t+1d0,none,manual)')
old="    9101_int64,sp,cp,water,state,o,s,dates,rows,code)"
assert helper.count(old)==1
helper=helper.replace(old,old[:-1]+',cfg%tiles(1)%parameters)')
old="""  call read_crop_n_saved_generation(trim(path),column,cfg%tiles(1)%template,wid,9001_int64, &
   9101_int64,sp,cp,water,state,o,s,dates,rows,code)"""
assert helper.count(old)==1
helper=helper.replace('  integer(int64)::wid','  integer(int64)::wid\n  type(fmr_b110_physical_parameters_t)::heat')
helper=helper.replace(old,"""  heat=cfg%tiles(1)%parameters
  if(action=='wrong-heat')heat%z(1)=heat%z(1)-.01d0
  if(action=='missing-heat')then
"""+old+"""
  else
"""+old[:-1]+",heat)\n  end if")
old="   call saved_write(prefix//'.bad-roots-'//tag,w,c,o,s,dates,rows)"
assert helper.count(old)==1
helper=helper.replace(old,old+"""
   call run_crop_soil_n_thermal_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code,environment=e)
   call require(code==OUTPUT_DAY_INVALID.and.r%status/=JOINT_OK,'competing thermal environment rejects')
   call saved_write(prefix//'.environment-day-'//tag,w,c,o,s,dates,rows)
   invalid_material=none;invalid_material(2)%kind=999
   call run_crop_soil_n_thermal_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,t,t+1d0, &
    invalid_material,split,o,s,dates,rows,r,code)
   call require(code/=0.and.r%status/=JOINT_OK,'invalid thermal fallow material batch rejects atomically')
   call saved_write(prefix//'.material-day-'//tag,w,c,o,s,dates,rows)
   badforcing=forcing;deallocate(badforcing%root_extraction_sink)
   call run_crop_soil_n_thermal_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,badforcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code)
   call require(code/=0.and.r%status/=JOINT_OK,'missing root forcing rejects atomically')
   call saved_write(prefix//'.absent-roots-day-'//tag,w,c,o,s,dates,rows)
   badforcing=forcing;deallocate(badforcing%soil_temperature)
   call run_crop_soil_n_thermal_saved_fallow_day(prefix//'.invalid',date,emit,670001_int64,backend,column, &
    cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,badforcing,cfg%numerical,c,weather,t,t+1d0, &
    none,split,o,s,dates,rows,r,code)
   call require(code/=0.and.r%status/=JOINT_OK,'missing heat forcing rejects atomically')
   call saved_write(prefix//'.absent-heat-day-'//tag,w,c,o,s,dates,rows)
""")
old="   call saved_physical(prefix//'.actual-day-'//tag,w,c)"
assert helper.count(old)==1
helper=helper.replace(old,"""   call require(r%joint%diagnostics%max_abs_step_mass_residual<=HARD_MASS_GATE,'thermal fallow hard water gate')
   call require(r%materials%gross_n>0d0.and.r%materials%volatilized_n>0d0.and.abs(r%materials%residual)<=1d-12, &
    'actual amended thermal fallow hard whole N gate')
   call require(r%joint%chemical%soil%temperature_used_c==accepted_literal_temperature(w,t,t+1d0), &
    'thermal fallow temperature equals original accepted profile reduction')
"""+old)
helper+='\n'+(ROOT/'tests/nut-output/thermal_fallow_manual.inc').read_text()
(OUT/'thermal_fallow_proof.inc').write_text(helper)
s=(THERMAL/'driver.f90').read_text()
imports=' use mod_crop_ext_saved_residue\n use mod_crop_n_saved_generation\n use mod_crop_soil_n_thermal_saved_output\n use mod_crop_soil_n_output_harvest\n'
s=s.replace(' implicit none',imports+' implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'thermal_fallow_proof.inc'\n",1)
anchor=" if(trim(mode)=='reject')then";assert s.count(anchor)==1
s=s.replace(anchor," if(trim(mode)=='saved-resume'.or.trim(mode)=='saved-reject'.or.trim(mode)=='saved-reject-live')then\n  call saved_resume_mode()\n  stop\n end if\n"+anchor,1)
anchor="  call require(r%joint%joint%chemical%soil%external_in>0d0.and.abs(r%joint%joint%chemical%whole_n_residual)<=1d-12,'inflow whole soil crop N')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+"\n  call saved_output_proof(trim(endpoint)//'.stages.saved',automatic_water,automatic_soil,.false.)\n  call saved_output_proof(trim(endpoint)//'.stages.deferred',automatic_water,automatic_soil,.true.)",1)
(OUT/'driver.f90').write_text(s)
# Reuse the admitted controller's actual programs and byte/state assertions.
recipe=ROOT/'tests/nut-output/run_saved_output.py';text=recipe.read_text()
prep=text[text.index("archive=ROOT/"):text.index('resource.setrlimit')]
exec(compile(prep,str(recipe),'exec'),globals())
text=text[text.index('events=[];pinned='):]
old="providers=['mod_crop_ext_saved_residue','mod_crop_soil_n_saved_harvest','mod_crop_n_saved_generation','mod_crop_soil_n_output_harvest','mod_crop_soil_n_saved_output']"
assert text.count(old)==1
providers=['src/adapter/mod_crop_ext_saved_residue.f90','src/adapter/mod_crop_n_saved_generation.f90','src/adapter/mod_crop_soil_n_output_harvest.f90','src/runtime/mod_fmr_crop_soil_n_thermal_fallow.f90','src/adapter/mod_crop_soil_n_thermal_saved_output.f90']
text=text.replace(old,'providers='+repr(providers))
text=text.replace("flags+=['-I'+str(old),'-I'+str(OUT),'-I'+str(ROOT/'tests/nut-output')]","flags+=['-I'+str(old),'-I'+str(OUT),'-I'+str(THERMAL/'profile'),'-I'+str(ROOT/'tests/nut-output')]")
text=text.replace("obj=b/(provider+'.o')","obj=b/(Path(provider).stem+'.o')").replace("ROOT/('src/adapter/'+provider+'.f90')","ROOT/provider")
text=text.replace("(old/'default.endpoint').read_bytes()","(THERMAL/opt/'output.endpoint').read_bytes()")
text=text.replace("['failed-day-','bad-roots-','nan-day-']","['failed-day-','bad-roots-','nan-day-','environment-day-','material-day-','absent-roots-day-','absent-heat-day-']")
old="  run([exe,'saved-reject',Path(str(prefix)+'.phase-3'),b/'unused','','wrong-water'],b,'invalid_identity')"
assert text.count(old)==1
text=text.replace(old,old+"\n  for option in ['missing-heat','wrong-heat']:\n   run([exe,'saved-reject',Path(str(prefix)+'.phase-3'),b/'unused','',option],b,'invalid_heat_identity')")
text=text.replace("inputs=['src/adapter/'+p+'.f90'for p in providers]+",'inputs=providers+')
text=text.replace("str(archive.relative_to(ROOT))]","str(archive.relative_to(ROOT)),'tests/nut-output/thermal_fallow_manual.inc','tests/nut-output/run_thermal_fallow_output.py']")
text=text.replace("c['results'][opt]['default_endpoint']","th['results'][opt]['physical']")
text=text.replace("thermal_selected=False","thermal_selected=True,thermal_input_sha256=th['input_sha256'],thermal_proof_sha256=sha(THERMAL/'result.json'),generated_helper_sha256=sha(OUT/'thermal_fallow_proof.inc')")
text=text.replace('SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS','THERMAL_SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS')
exec(compile(text,str(recipe),'exec'),globals())
