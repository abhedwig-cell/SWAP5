"""Real calendar/saved-crop/harvest/fallow composition on fresh current providers."""
from pathlib import Path
import argparse,base64,hashlib,json,os,resource,runpy,signal,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();COLD=a.cold.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
cold=json.loads((COLD/'result.json').read_text());assert cold['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
inputs=dict(cold['input_sha256'])
for path,h in inputs.items():assert sha(ROOT/path)==h,path
owner=runpy.run_path(str(ROOT/'integration/audits/native_project_admission.py'))
capsule=ROOT/owner['record']()['evidence']['path'];raw=base64.b64decode(capsule.read_bytes())
assert hashlib.sha256(raw).hexdigest()==owner['record']()['evidence']['decoded_sha256']
f=owner['unpack'](raw);incumbent=json.loads(f['nut-current/cycle/result.json'])
assert cold['results']==json.loads(f['nut-current/cold/result.json'])['results'],'fresh current cold baseline drift'
for path,h in incumbent['input_sha256'].items():assert sha(ROOT/path)==h,path;inputs[path]=h
profile=OUT/'profile';profile.mkdir()
(profile/'literal_profile.inc').write_bytes(f['nut-current/thermal/profile/literal_profile.inc'])
generated={'profile/literal_profile.inc':sha(profile/'literal_profile.inc')}
for name in ['original_harvest_dm.inc','original_harvest_n.inc']:
 (profile/name).write_bytes(f['nut-current/saved/'+name]);generated['profile/'+name]=sha(profile/name)
def replace_once(text,old,new):
 assert text.count(old)==1,(old,text.count(old))
 return text.replace(old,new,1)
for kind in ['cold','heat']:
 thermal=kind=='heat';d=OUT/kind;d.mkdir()
 for name in ['driver.f90','cycle_base.inc']:(d/name).write_bytes(f['nut-current/cycle/'+kind+'/'+name])
 driver=(d/'driver.f90').read_text().replace(' implicit none',' use mod_crop_soil_n_saved_calendar_output\n use mod_soil_n_amendment_calendar\n implicit none',1)
 (d/'driver.f90').write_text(driver)
 s=(ROOT/'tests/nut-output/cycle_output_proof.inc').read_text()
 s=replace_once(s,'type(soil_n_material_input_t)::batch(2),invalid(2)','type(soil_n_material_input_t),allocatable::batch(:)\n  type(soil_n_amendment_calendar_t)::plan,invalid_plan')
 s=replace_once(s,'type(fmr_b110_physical_forcing_t)::forcing','type(fmr_b110_physical_forcing_t)::forcing,badforcing')
 s=replace_once(s,'call cycle_config(p);call materials(batch,split)','call cycle_config(p);call saved_calendar_plan(plan)')
 s=replace_once(s,'\n    tag=achar(49+t)','\n    call saved_calendar_manual_batch(t,batch)\n    tag=achar(49+t)')
 s=replace_once(s,'\n   tag=achar(49+t)','\n   call saved_calendar_manual_batch(t,batch)\n   tag=achar(49+t)')
 s=s.replace('run_crop_soil_n_saved_cycle_day','run_crop_soil_n_saved_calendar_day').replace('batch,split,senescence','plan,split,senescence')
 first=s.index('    call run_crop_soil_n_saved_calendar_day(');end=s.index('\n    call require',first)
 active=s[first:end].replace("'absent-cycle-dir/file'","prefix//'.invalid'")
 start=s.index('    invalid=batch;');end=s.index('    mw=w;mc=c;',start)
 negatives=active.replace('plan,split,senescence','invalid_plan,split,senescence')+"\n    call require(code==OUTPUT_DAY_INVALID,'invalid active calendar rejects')\n    call saved_write(prefix//'.invalid-day-'//tag,w,c,o,s,dates,rows)\n"
 negatives+=active.replace('real(t,real64),real(t+1,real64)','real(t,real64)+.5d0,real(t+1,real64)+.5d0')+"\n    call require(code==OUTPUT_DAY_INVALID,'off-grid active calendar rejects')\n    call saved_write(prefix//'.offgrid-day-'//tag,w,c,o,s,dates,rows)\n"
 negatives+='    badforcing=forcing;badforcing%root_extraction_sink=-1d0\n'+active.replace('w,forcing,','w,badforcing,')+"\n    call require(code/=OUTPUT_DAY_OK,'physical active rejection retains calendar gift')\n    call saved_write(prefix//'.physical-reject-day-'//tag,w,c,o,s,dates,rows)\n"
 if thermal:
  negatives+=active.replace('code,CYCLE_ENVIRONMENT)','code,environment=e)')+"\n    call require(code==OUTPUT_DAY_INVALID,'active calendar cannot override accepted heat')\n    call saved_write(prefix//'.environment-day-'//tag,w,c,o,s,dates,rows)\n"
 s=s[:start]+negatives+s[end:]
 anchor="    call saved_write(prefix//'.manual-day-'//tag,mw,mc,mo,ms,md,mr)"
 s=replace_once(s,anchor,anchor+'\n'+active+"\n    call require(code==OUTPUT_DAY_INVALID,'active calendar replay rejects duplicate gift')\n    call saved_write(prefix//'.replay-day-'//tag,w,c,o,s,dates,rows)")
 s=s.replace('CYCLE_FALLOW_OWNER','run_crop_soil_n_saved_calendar_fallow_day').replace('batch,split,o,s','plan,split,o,s')
 first=s.index('   call run_crop_soil_n_saved_calendar_fallow_day(');end=s.index('\n   call require',first)
 fallow=s[first:end];trial=fallow.replace("prefix//'.day-'//tag","prefix//'.invalid'")
 negatives="   call saved_write(prefix//'.before-day-'//tag,w,c,o,s,dates,rows)\n"
 for label,call,check in [
  ('invalid-day',trial.replace('plan,split,o,s','invalid_plan,split,o,s'),'code==OUTPUT_DAY_INVALID'),
  ('offgrid-day',trial.replace('real(t,real64),real(t+1,real64)','real(t,real64)+.5d0,real(t+1,real64)+.5d0'),'code==OUTPUT_DAY_INVALID'),
  ('failed-day',trial.replace("prefix//'.invalid'","'absent-cycle-dir/file'"),'code==OUTPUT_DAY_SAVE_FAILED')]:
  negatives+=call+"\n   call require("+check+",'fallow calendar "+label+"')\n   call saved_write(prefix//'."+label+"-'//tag,w,c,o,s,dates,rows)\n"
 negatives+='   badforcing=forcing;badforcing%root_extraction_sink=1d-4\n'+trial.replace('w,forcing,','w,badforcing,')+"\n   call require(code/=OUTPUT_DAY_OK,'fallow calendar rejects active roots')\n   call saved_write(prefix//'.physical-reject-day-'//tag,w,c,o,s,dates,rows)\n"
 if thermal:
  negatives+=trial.replace('code,CYCLE_ENVIRONMENT)','code,environment=e)')+"\n   call require(code==OUTPUT_DAY_INVALID,'fallow calendar cannot override accepted heat')\n   call saved_write(prefix//'.environment-day-'//tag,w,c,o,s,dates,rows)\n"
 s=replace_once(s,'   CYCLE_MANUAL_FALLOW',negatives+'   CYCLE_MANUAL_FALLOW')
 view=trial.replace("prefix//'.invalid'","prefix//'.view-day-'//tag").replace('parameters,w,forcing','parameters,vw,forcing').replace('cfg%numerical,c,weather','cfg%numerical,vc,weather').replace('split,o,s,dates,rows','split,vo,vs,vd,vr').replace('code,CYCLE_ENVIRONMENT)',"code,CYCLE_ENVIRONMENT,csv_path='absent-cycle-dir/view.csv')")
 s=replace_once(s,fallow,"   vw=w;vc=c;vo=o;vs=s;vd=dates;vr=rows\n"+view+"\n   call require(code==OUTPUT_DAY_VIEW_FAILED,'fallow calendar CSV failure keeps generation')\n   call saved_write(prefix//'.view-memory-'//tag,vw,vc,vo,vs,vd,vr)\n"+fallow)
 anchor="\n   call saved_write(prefix//'.manual-day-'//tag,mw,mc,mo,ms,md,mr)"
 s=replace_once(s,anchor,anchor+'\n'+trial+"\n   call require(code==OUTPUT_DAY_INVALID,'fallow calendar replay rejects duplicate gift')\n   call saved_write(prefix//'.replay-day-'//tag,w,c,o,s,dates,rows)")
 s=replace_once(s,"  if(action=='roundtrip')then","  if(action=='physical')then\n   call saved_physical(trim(endpoint),water,state)\n  else if(action=='roundtrip')then")
 s=s.replace('CYCLE_HEAT_PARAMETERS','cfg%tiles(1)%parameters')
 s=s.replace(',code,CYCLE_ENVIRONMENT)',',code)'if thermal else',code,e)').replace(',code,CYCLE_ENVIRONMENT,csv_path=',',code,csv_path='if thermal else',code,e,csv_path=')
 s=s.replace('CYCLE_MANUAL_ACTIVE',('call run_crop_soil_n_thermal_interval'if thermal else'call run_crop_soil_n_senescence_interval')+'(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,mw,forcing,cfg%numerical,mc,weather,real(t,real64),real(t+1,real64),batch,split,senescence,manual'+(')'if thermal else',e)'))
 s=s.replace('CYCLE_MANUAL_FALLOW','call manual_thermal_fallow(second,mw,mc,forcing,real(t,real64),real(t+1,real64),batch,mf)'if thermal else'call run_crop_soil_n_material_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,mw,forcing,cfg%numerical,mc,weather,real(t,real64),real(t+1,real64),batch,split,mf,e,fallow=.true.)')
 s+="\n include 'saved_calendar_fixture.inc'\n";assert'CYCLE_'not in s.replace('CYCLE_FRESH_GENERATION_PASS','').replace('CYCLE_ACTUAL_TWO_CROPS_SEED_ACTIVE_HARVEST_FALLOW_PASS','')
 (d/'cycle_proof.inc').write_text(s)
 for path in d.iterdir():generated[path.relative_to(OUT).as_posix()]=sha(path)
events=[];pinned={};results={}
def run(command,cwd,category):
 command=list(map(str,command));start=time.perf_counter();r=subprocess.run(command,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=command,category=category,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(i)+' '+r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
fc=os.environ.get('FC','gfortran');version=run([fc,'--version'],OUT,'compiler')
assert '13.3.0'in version
preload=OUT/'rename-stop.so';run(['cc','-shared','-fPIC',ROOT/'tests/nut-output/rename_stop.c','-ldl','-o',preload],OUT,'hook_build')
providers=['src/adapter/'+n+'.f90'for n in ['mod_crop_ext_saved_residue','mod_crop_soil_n_saved_harvest','mod_crop_n_saved_generation','mod_crop_soil_n_output_harvest','mod_crop_soil_n_saved_output']]+['src/runtime/mod_fmr_crop_soil_n_thermal_fallow.f90']+['src/adapter/'+n+'.f90'for n in ['mod_crop_soil_n_thermal_saved_output','mod_crop_soil_n_saved_cycle_output','mod_crop_soil_n_saved_calendar_output']]
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=COLD/opt;es=json.loads((COLD/'events.json').read_text())
 link=next(e['command']for e in es if e['category']=='link'and e['command'][-1]==str(old/'hist'));objects=[v for v in link if v.endswith('.o')][:-1];assert len(objects)==331
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]+['-I'+str(old),'-I'+str(profile),'-I'+str(ROOT/'tests/nut-output')]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 extras=[]
 for path in providers:
  obj=b/(Path(path).stem+'.o');run([fc,*flags,'-c',ROOT/path,'-o',obj],b,'provider_compile');extras.append(obj)
 for kind in ['cold','heat']:
  d=OUT/kind;case=b/kind;case.mkdir();obj=case/'driver.o';exe=case/'calendar'
  run([fc,*flags,'-I'+str(d),'-c',d/'driver.f90','-o',obj],case,'driver_compile');run([fc,*flags,*objects,*extras,obj,'-o',exe],case,'link')
  run([exe,'write',case/'original.restart',case/'endpoint'],case,'actual_native')
  seeds=sorted(p for p in case.glob('*.cycle.seed')if'.opaque-stages.'not in p.name);assert len(seeds)==2
  report={}
  for seed in seeds:
   prefix=Path(str(seed).removesuffix('.seed'));delayed='deferred'in str(seed);schedule='deferred'if delayed else'saved'
   for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']:
    actual=Path(str(prefix)+'.'+label);assert actual.read_bytes()==Path(str(prefix)+'.manual-'+label).read_bytes(),('manual',kind,opt,label)
    copy=case/(prefix.name+'-rt-'+label);run([exe,'cycle-resume',actual,copy,'','roundtrip'],case,'roundtrip');assert copy.read_bytes()==actual.read_bytes()
    run([exe,'cycle-resume',actual,case/'unused','','old-identity'],case,'old_identity')
    fresh=case/(prefix.name+'-fresh-'+label);run([exe,'cycle-resume',actual,fresh,'','delayed'if delayed else'continue'],case,'fresh')
    if label!='day-8':assert Path(str(fresh)+'.day-8').read_bytes()==Path(str(prefix)+'.day-8').read_bytes(),('fresh',kind,opt,label)
   for before,after in [('before-seed','bad-seed'),('before-seed','failed-seed')]+[(a+'-'+tag,c+'-'+tag)for tag in ['1','2','3']for a,c in [('before-phase','failed-phase')]]:
    assert Path(str(prefix)+'.'+before).read_bytes()==Path(str(prefix)+'.'+after).read_bytes()
   for tag in ['5','6','7','8']:
    for label in ['failed-day','invalid-day','offgrid-day','physical-reject-day']+(['environment-day']if kind=='heat'else[]):assert Path(str(prefix)+'.before-day-'+tag).read_bytes()==Path(str(prefix)+'.'+label+'-'+tag).read_bytes(),(label,tag)
    assert Path(str(prefix)+'.day-'+tag).read_bytes()==Path(str(prefix)+'.replay-day-'+tag).read_bytes()==Path(str(prefix)+'.view-day-'+tag).read_bytes()==Path(str(prefix)+'.view-memory-'+tag).read_bytes()
   physical=case/(schedule+'.physical');run([exe,'cycle-resume',str(prefix)+'.day-8',physical,'','physical'],case,'physical_endpoint')
   report[schedule]={label:sha(Path(str(prefix)+'.'+label))for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']};report[schedule]['physical']=sha(physical)
  assert report['saved']['physical']==report['deferred']['physical'],'report schedule changes calendar physics'
  prefix=Path(str(seeds[0]).removesuffix('.seed'));delayed='deferred'in str(prefix);crashes={}
  for point,before,after in [('active','seed','day-5'),('fallow','phase-3','day-7')]:
   for phase in ['before','after']:
    crash=case/('crash-'+point+'-'+phase);crash.mkdir();out=crash/'run';target=Path(str(out)+'.'+after);target.write_bytes(Path(str(prefix)+'.'+before).read_bytes())
    env={**os.environ,'LD_PRELOAD':str(preload),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'1'}
    started=time.perf_counter()
    with(crash/'stdout').open('wb')as stdout,(crash/'stderr').open('wb')as stderr:
     child=subprocess.Popen([str(exe),'cycle-resume',str(prefix)+'.'+before,str(out),'','delayed'if delayed else'continue'],cwd=crash,env=env,stdout=stdout,stderr=stderr)
     _,status=os.waitpid(child.pid,os.WUNTRACED);assert os.WIFSTOPPED(status)and os.WSTOPSIG(status)==signal.SIGSTOP,(crash,(crash/'stderr').read_text())
     child.kill();child.wait();assert child.returncode==-signal.SIGKILL
    wanted=before if phase=='before'else after;assert target.read_bytes()==Path(str(prefix)+'.'+wanted).read_bytes()
    recovered=crash/'recovered';run([exe,'cycle-resume',target,recovered,'','delayed'if delayed else'continue'],crash,'crash_fresh');assert Path(str(recovered)+'.day-8').read_bytes()==Path(str(prefix)+'.day-8').read_bytes()
    receipt=dict(returncode=-9,complete=True,sha256=sha(target),process_wall_seconds=time.perf_counter()-started);(crash/'result.json').write_text(json.dumps(receipt)+'\n');crashes[point+'-'+phase]={k:v for k,v in receipt.items()if k!='process_wall_seconds'}
  report['crashes']=crashes;results[kind+'-'+opt]=report
assert results['cold-O0']==results['cold-O2']and results['heat-O0']==results['heat-O2']
rejected_trials=0;replay_rejections=0
for before in OUT.glob('O*/**/*.before-day-[5678]'):
 prefix,tag=str(before).rsplit('.before-day-',1)
 labels=['failed-day','invalid-day','offgrid-day','physical-reject-day']+(['environment-day']if'/heat/'in str(before)else[])
 for label in labels:
  assert before.read_bytes()==Path(prefix+'.'+label+'-'+tag).read_bytes(),('fresh rejected state',before,label)
  rejected_trials+=1
 replay=Path(prefix+'.replay-day-'+tag)
 if replay.exists():
  actual=Path(prefix+'.day-'+tag)
  assert actual.read_bytes()==replay.read_bytes()==Path(prefix+'.manual-day-'+tag).read_bytes()==Path(prefix+'.view-day-'+tag).read_bytes()==Path(prefix+'.view-memory-'+tag).read_bytes(),('fresh manual/replay/view state',actual)
  replay_rejections+=1
assert all(sha(Path(path))==h for path,h in pinned.items()),'base providers changed'
for path in providers+['tests/nut-output/run_saved_calendar_output.py','tests/nut-output/saved_calendar_fixture.inc','tests/nut-output/cycle_output_proof.inc','tests/nut-output/rename_stop.c']:inputs[path]=sha(ROOT/path)
r=dict(status='COLD_HEAT_SAVED_CALENDAR_HARVEST_FALLOW_O0_O2_FRESH_PASS',results=results,events=events,input_sha256=inputs,pinned_artifacts=pinned,generated=generated,base_providers=331,additional_providers=9,cold_result_sha256=sha(COLD/'result.json'),cold_results=cold['results'],rejected_trials=rejected_trials,replay_rejections=replay_rejections,immutable_fixture_capsule_sha256=hashlib.sha256(raw).hexdigest(),compiler=version.splitlines()[0],full_mc_nut01_closed=False,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
