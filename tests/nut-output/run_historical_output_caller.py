"""Fresh real application dispatch over pinned incumbent O0/O2 providers.

No physical oracle/assertion is replaced. The incumbent preparation and complete
native/restart/crash matrix are reused verbatim; only application call sites are
changed and additional dispatch/startup assertions are inserted.
"""
from pathlib import Path
import argparse,hashlib,json,os,resource,runpy,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',required=True,type=Path);p.add_argument('--calendar',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
a=p.parse_args();COLD=a.cold.resolve();CALENDAR=a.calendar.resolve();OUT=a.output.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
previous=json.loads((CALENDAR/'result.json').read_text())
assert previous['status']=='COLD_HEAT_SAVED_CALENDAR_HARVEST_FALLOW_O0_O2_FRESH_PASS'
for path,h in previous['input_sha256'].items():assert sha(ROOT/path)==h,path
for path,h in previous['pinned_artifacts'].items():assert sha(Path(path))==h,path
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
recipe=ROOT/'tests/nut-output/run_saved_calendar_output.py'
prepare,execute=recipe.read_text().split('events=[];pinned={};results={}',1)
# Preserve the exact incumbent preparation and its source/capsule binding.
prepare=prepare[prepare.index('sha=lambda'):]
scope=dict(__file__=str(recipe),ROOT=ROOT,COLD=COLD,OUT=OUT)
OUT.mkdir(exist_ok=False)
exec(compile('from pathlib import Path\nimport base64,hashlib,json,os,resource,runpy,signal,subprocess,time\n'+prepare,str(recipe),'exec'),scope)
def once(text,old,new):
 assert text.count(old)==1,(old,text.count(old))
 return text.replace(old,new,1)
import re
for kind in ['cold','heat']:
 d=OUT/kind;s=(d/'cycle_proof.inc').read_text()
 s=once(s,'  type(senescence_joint_result_t)::r,manual','  type(historical_output_result_t)::dispatch\n  type(senescence_joint_result_t)::r,manual')
 def day(match):
  owner,body=match.group(1),match.group(2);fallow='fallow'in owner
  body=body.replace('plan,split,o,s','plan,split,senescence,o,s').replace('plan,split,vo,vs','plan,split,senescence,vo,vs') if fallow else body
  result='fallow'if fallow else'r';field='fallow'if fallow else'active'
  body=body.replace(','+result+',code',',dispatch,code')
  return 'call advance_historical_saved_output('+body+')\n   '+result+'=dispatch%'+field+'\n'
 s=re.sub(r'call (run_crop_soil_n_saved_calendar_(?:fallow_)?day)\((.*?)\)\n',day,s,flags=re.S)
 def boundary(match):
  body=match.group(1);path=body.split(',n,column,',1)[0]
  return "call advance_historical_saved_output("+path+",'',.false.,670001_int64,backend,column, &\n     cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,6d0,6d0, &\n     plan,split,senescence,o,s,dates,rows,dispatch,code,observation=observation)\n    h=dispatch%boundary\n    call require(dispatch%action==n+1,'restart-derived exact harvest action')\n"
 s=re.sub(r'call run_crop_soil_n_saved_cycle_harvest\((.*?)\)\n',boundary,s,flags=re.S)
 assert 'call run_crop_soil_n_saved_calendar_'not in s and 'call run_crop_soil_n_saved_cycle_harvest'not in s
 anchor="    call saved_write(prefix//'.before-phase-'//tag,w,c,o,s,dates,rows)"
 trial="""
    call advance_historical_saved_output(prefix//'.unexpected', '',.false.,670001_int64,backend,column, &
     cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,6d0,7d0, &
     plan,split,senescence,o,s,dates,rows,dispatch,code)
    call require(code==OUTPUT_DAY_INVALID,'boundary cannot advance a day or consume a gift')
    if(n==3)then
     call advance_historical_saved_output(prefix//'.unexpected', '',.false.,670001_int64,backend,column, &
      cfg%tiles(1)%template,cfg%tiles(1)%parameters,w,forcing,cfg%numerical,c,weather,6d0,6d0, &
      plan,split,senescence,o,s,dates,rows,dispatch,code)
     call require(code==OUTPUT_DAY_INVALID,'retirement cannot fabricate an observation')
    end if
    call saved_write(prefix//'.rejected-dispatch-phase-'//tag,w,c,o,s,dates,rows)
"""
 s=once(s,anchor,anchor+trial)
 (d/'cycle_proof.inc').write_text(s)
 driver=(d/'driver.f90').read_text().replace(' implicit none',' use mod_crop_soil_n_historical_output_application\n implicit none',1)
 (d/'driver.f90').write_text(driver)
 for path in d.iterdir():scope['generated'][path.relative_to(OUT).as_posix()]=sha(path)
# Reuse unchanged output objects only after source and artifact checks above.
execute=execute[:execute.index("for path in providers+")]
start=execute.index(' for path in providers:');end=execute.index(" for kind in ['cold','heat']:",start)
execute=execute[:start]+""" for path in providers:
  obj=CALENDAR/opt/(Path(path).stem+'.o');assert obj.is_file();extras.append(obj);pinned[str(obj)]=sha(obj)
 flags+=['-I'+str(CALENDAR/opt)]
 obj=b/'historical.o';run([fc,*flags,'-c',ROOT/PRODUCTION,'-o',obj],b,'provider_compile');extras.append(obj)
"""+execute[end:]
scope.update(CALENDAR=CALENDAR,PRODUCTION='src/adapter/mod_crop_soil_n_historical_output_application.f90')
exec(compile('events=[];pinned={};results={}\n'+execute,str(recipe),'exec'),scope)
events=scope['events'];run=scope['run'];pinned=scope['pinned']
# Native SNM TRUE startup now enters the same complete-generation caller.
native=(ROOT/'tests/nut-output/native_output_project.inc').read_text()
native=once(native,'  type(soil_n_day_environment_t)::environment','  type(crop_ext_saved_residue_t)::saved_memory\n  type(historical_output_result_t)::dispatch\n  type(soil_n_day_environment_t)::environment')
native=once(native,'  aw=water;ow=water;ordinary=state','  ow=water;ordinary=state')
old='call initialize_historical_crop_soil_output_owner('
def startup(match):
 body=match.group(1)
 body=body.replace("'1900-12-30',", "'1900-12-30',trim(endpoint)//'.startup',column,cfg%tiles(1)%template,670001_int64,water,")
 body=body.replace('diagnostic,','diagnostic,saved_memory,')
 return 'call initialize_historical_saved_output('+body+')'
native=re.sub(r'call initialize_historical_crop_soil_output_owner\((.*?)\)',startup,native,flags=re.S) if False else native
# Parentheses inside arguments require the closing call/newline boundary.
native=re.sub(r'call initialize_historical_crop_soil_output_owner\((.*?)\)\n',lambda m:startup(m)+'\n',native,flags=re.S)
native=once(native,"  call initialize_historical_saved_output(selection,sp,cp,crop,9001_int64,9101_int64, &\n   base_day,water_fraction,'native-output.snm'", "  aw=water\n  call initialize_historical_saved_output(selection,sp,cp,crop,9001_int64,9101_int64, &\n   base_day,water_fraction,'native-output.snm'")
native=native.replace('read_crop_n_output_generation','read_crop_n_saved_generation').replace('write_crop_n_output_generation','write_crop_n_saved_generation')
native=native.replace('actual,diagnostic,dates,rows','actual,diagnostic,saved_memory,dates,rows')
native=native.replace('run_crop_soil_n_output_day','advance_historical_saved_output').replace('batch,split,policy1,diagnostic,dates,rows,r,code','plan1,split,policy1,diagnostic,saved_memory,dates,rows,dispatch,code')
native=once(native,"   if(code/=0)print *,'native output day failed'", "   r=dispatch%active\n   call require(dispatch%action==HIST_ACTIVE,'native application chooses active route')\n   if(code/=0)print *,'native output day failed'")
(OUT/'native_output_project.inc').write_text(native)
source=(COLD/'driver.f90').read_text().replace(' implicit none',' use mod_crop_soil_n_historical_output_application\n implicit none',1)
(OUT/'native_driver.f90').write_text(source)
native_results={}
for opt in ['O0','O2']:
 b=OUT/opt;old=COLD/opt;es=json.loads((COLD/'events.json').read_text())
 link=next(e['command']for e in es if e['category']=='link'and e['command'][-1]==str(old/'hist'));objects=[v for v in link if v.endswith('.o')][:-1]
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]+['-I'+str(OUT),'-I'+str(old),'-I'+str(CALENDAR/opt)]
 extras=[CALENDAR/opt/(Path(path).stem+'.o')for path in scope['providers']]+[b/'historical.o']
 case=b/'native';case.mkdir();obj=case/'driver.o';exe=case/'caller'
 run([fc,*flags,'-c',OUT/'native_driver.f90','-o',obj],case,'native_driver_compile');run([fc,*flags,*objects,*extras,obj,'-o',exe],case,'native_link')
 run([exe,'native-output',case/'restart',case/'endpoint','source-profile'],case,'native_startup')
 run([exe,'native-output-resume',str(case/'restart')+'.day1',case/'fresh','source-profile'],case,'native_restart')
 for suffix in ['', '.csv','.true','.false']:
  assert Path(str(case/'endpoint')+suffix).read_bytes()==Path(str(case/'fresh')+suffix).read_bytes(),suffix
 for suffix in ['.true','.false','.initial-true','.initial-false']:
  assert Path(str(case/'endpoint')+suffix).read_bytes()==Path(str(COLD/opt/'native.endpoint')+suffix).read_bytes(),('native physics changed',suffix)
 native_results[opt]={suffix:sha(Path(str(case/'endpoint')+suffix))for suffix in ['','.csv','.true','.false']}
assert native_results['O0']==native_results['O2']
for opt in ['O0','O2']:
 for kind in ['cold','heat']:
  for before in (OUT/opt/kind).glob('*.before-phase-*'):
   prefix,tag=str(before).rsplit('.before-phase-',1)
   assert before.read_bytes()==Path(prefix+'.rejected-dispatch-phase-'+tag).read_bytes()
  assert scope['results'][kind+'-'+opt]==previous['results'][kind+'-'+opt],'incumbent complete generation drift'
inputs=scope['inputs'];inputs[scope['PRODUCTION']]=sha(ROOT/scope['PRODUCTION']);inputs['tests/nut-output/run_historical_output_caller.py']=sha(Path(__file__))
generated=scope['generated']
for name in ['native_output_project.inc','native_driver.f90']:generated[name]=sha(OUT/name)
for path,h in {**previous['pinned_artifacts'],**pinned}.items():assert sha(Path(path))==h,path
r=dict(status='HISTORICAL_SAVED_OUTPUT_CALLER_O0_O2_PASS',results=scope['results'],native=native_results,events=events,input_sha256=inputs,generated=generated,pinned_artifacts={**previous['pinned_artifacts'],**pinned},calendar_result_sha256=sha(CALENDAR/'result.json'),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})},full_mc_nut01_closed=False)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
