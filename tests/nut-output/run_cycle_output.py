"""Actual two-crop saved-output composition using exact current provider artifacts."""
from pathlib import Path
import argparse,hashlib,json,os,resource,signal,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--build-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();W=a.build_root.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
proofs={k:json.loads((W/k/'result.json').read_text())for k in ['cold','thermal','saved','thermal-saved']}
inputs={}
for k,r in proofs.items():
 for name in ['input_sha256','cold_input_sha256','thermal_input_sha256']:
  for path,h in r.get(name,{}).items():assert sha(ROOT/path)==h,(k,path);inputs[path]=h
 assert sha(W/k/'driver.f90')==r['generated_driver_sha256']
events=[];pinned={};results={};generated={}
def run(cmd,cwd,category):
 cmd=list(map(str,cmd));started=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,returncode=r.returncode,category=category,seconds=time.perf_counter()-started,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(i)+' '+r.stdout.decode()+r.stderr.decode())
 return r
for kind,folder in [('cold','saved'),('heat','thermal-saved')]:
 d=OUT/kind;d.mkdir();thermal=kind=='heat';s=(W/folder/'driver.f90').read_text();s=s.replace(' implicit none',' use mod_crop_soil_n_saved_cycle_output\n implicit none',1)
 basehelper=(ROOT/'tests/nut-output/saved_output_proof.inc').read_text()if not thermal else(W/folder/'thermal_fallow_proof.inc').read_text()
 anchor='  call saved_fallow_proof(prefix,actual_water,actual,o,s,dates,rows,delayed,manual_water,manual)';assert basehelper.count(anchor)==1
 basehelper=basehelper.replace(anchor,anchor+"\n  call cycle_run(prefix//'.cycle',actual_water,actual,o,s,dates,rows,delayed,.true.)")
 helper=(ROOT/'tests/nut-output/cycle_output_proof.inc').read_text()
 helper=helper.replace('CYCLE_HEAT_PARAMETERS',"cfg%tiles(1)%parameters"if thermal else"cfg%tiles(1)%parameters")
 helper=helper.replace(',code,CYCLE_ENVIRONMENT)',',code)'if thermal else',code,e)')
 helper=helper.replace(',code,CYCLE_ENVIRONMENT,csv_path=',',code,csv_path='if thermal else',code,e,csv_path=')
 helper=helper.replace('CYCLE_MANUAL_ACTIVE',('call run_crop_soil_n_thermal_interval'if thermal else'call run_crop_soil_n_senescence_interval')+'(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,mw,forcing,cfg%numerical,mc,weather,real(t,real64),real(t+1,real64),batch,split,senescence,manual'+(')'if thermal else',e)'))
 helper=helper.replace('CYCLE_MANUAL_FALLOW','call manual_thermal_fallow(second,mw,mc,forcing,real(t,real64),real(t+1,real64),batch,mf)'if thermal else'call run_crop_soil_n_material_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,mw,forcing,cfg%numerical,mc,weather,real(t,real64),real(t+1,real64),batch,split,mf,e,fallow=.true.)')
 helper=helper.replace('CYCLE_FALLOW_OWNER','run_crop_soil_n_thermal_saved_fallow_day'if thermal else'run_crop_soil_n_saved_fallow_day')
 (d/'cycle_base.inc').write_text(basehelper);(d/'cycle_proof.inc').write_text(helper)
 old=" include 'thermal_fallow_proof.inc'"if thermal else" include 'saved_output_proof.inc'";assert s.count(old)==1;s=s.replace(old," include 'cycle_base.inc'\n include 'cycle_proof.inc'",1)
 anchor=" if(trim(mode)=='saved-resume'";at=s.index(anchor);s=s[:at]+" if(index(trim(mode),'cycle-')==1)then\n  call cycle_resume_mode()\n  stop\n end if\n"+s[at:];(d/'driver.f90').write_text(s)
 for f in d.glob('*'):generated[str(f.relative_to(OUT))]=sha(f)
 for opt in ['O0','O2']:
  b=d/opt;b.mkdir();old=W/'cold'/opt;es=json.loads((W/'cold/events.json').read_text());link=next(e['command']for e in es if e['category']=='link'and e['command'][-1]==str(old/'hist'));objects=[v for v in link if v.endswith('.o')][:-1]
  flags=[('-J'+str(b))if x.startswith('-J')else x for x in link[1:link.index(objects[0])]]
  flags+=['-I'+str(W/'saved'/opt),'-I'+str(W/'thermal-saved'/opt),'-I'+str(W/'thermal/profile'),'-I'+str(W/folder),'-I'+str(d),'-I'+str(ROOT/'tests/nut-output')]
  extra={}
  for name in ['saved','thermal-saved']:
   es=json.loads((W/name/'events.json').read_text());cmd=next(e['command']for e in es if e['category']=='link'and e['command'][-1]==str(W/name/opt/'saved'))
   for obj in [v for v in cmd if v.endswith('.o')][:-1]:
    if obj not in objects:extra[Path(obj).name]=obj
  objects+=list(extra.values())
  for obj in objects:pinned[obj]=sha(Path(obj))
  for name in ['cold','saved','thermal-saved']:
   for mod in (W/name/opt).glob('*.mod'):pinned[str(mod)]=sha(mod)
  fc=os.environ.get('FC','gfortran');obj=b/'cycle.o';driver=b/'driver.o';exe=b/'cycle'
  run([fc,*flags,'-c',ROOT/'src/adapter/mod_crop_soil_n_saved_cycle_output.f90','-o',obj],b,'provider_compile')
  run([fc,*flags,'-c',d/'driver.f90','-o',driver],b,'driver_compile')
  run([fc,*flags,*objects,obj,driver,'-o',exe],b,'link')
  run([exe,'write',b/'original.restart',b/'endpoint'],b,'actual_native')
  seeds=sorted(p for p in b.glob('*.cycle.seed')if '.opaque-stages.'not in p.name);assert len(seeds)==2,(kind,opt,seeds)
  report={}
  for seed in seeds:
   prefix=Path(str(seed).removesuffix('.seed'));delayed='deferred'in str(seed)
   for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']:
    actual=Path(str(prefix)+'.'+label);manual=Path(str(prefix)+'.manual-'+label)
    assert actual.read_bytes()==manual.read_bytes(),('manual drift',kind,opt,label)
    rd=b/(prefix.name+'-rt-'+label);run([exe,'cycle-resume',actual,rd,'','roundtrip'],b,'cycle_roundtrip');assert rd.read_bytes()==actual.read_bytes()
    run([exe,'cycle-resume',actual,b/'unused','','old-identity'],b,'old_identity')
    fresh=b/(prefix.name+'-fresh-'+label);run([exe,'cycle-resume',actual,fresh,'','delayed'if delayed else'continue'],b,'cycle_fresh')
    if label!='day-8':assert Path(str(fresh)+'.day-8').read_bytes()==Path(str(prefix)+'.day-8').read_bytes(),('fresh drift',kind,opt,label)
   for before,after in [('before-seed','bad-seed'),('before-seed','failed-seed')]+[(a+'-'+tag,b+'-'+tag)for tag in ['5','6']for a,b in [('before-day','failed-day'),('before-day','invalid-day')]]+[(a+'-'+tag,b+'-'+tag)for tag in ['1','2','3']for a,b in [('before-phase','failed-phase')]]:
    assert Path(str(prefix)+'.'+before).read_bytes()==Path(str(prefix)+'.'+after).read_bytes(),('failed mutation',kind,opt,before,after)
   for tag in ['5','6']:
    assert Path(str(prefix)+'.view-day-'+tag).read_bytes()==Path(str(prefix)+'.view-memory-'+tag).read_bytes()==Path(str(prefix)+'.day-'+tag).read_bytes(),'CSV-only cycle view drift'
   report['deferred'if delayed else'saved']={label:sha(Path(str(prefix)+'.'+label))for label in ['seed','day-5','day-6','phase-1','phase-2','phase-3','day-7','day-8']}
  crashes={}
  for phase in ['before','after']:
   case=b/('crash-'+phase);case.mkdir();target=case/'generation'
   prefix=Path(str(seeds[0]).removesuffix('.seed'));before=Path(str(prefix)+'.seed');after=Path(str(prefix)+'.day-5');target.write_bytes(before.read_bytes())
   env={**os.environ,'LD_PRELOAD':str(W/'saved/rename-stop.so'),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'1'}
   with(case/'stdout').open('wb')as out,(case/'stderr').open('wb')as err:
    child=subprocess.Popen([str(exe),'cycle-resume',str(after),str(target),'','roundtrip'],cwd=case,env=env,stdout=out,stderr=err)
    _,state=os.waitpid(child.pid,os.WUNTRACED);assert os.WIFSTOPPED(state)and os.WSTOPSIG(state)==signal.SIGSTOP
    child.kill();child.wait();assert child.returncode==-signal.SIGKILL
   wanted=before if phase=='before'else after;assert target.read_bytes()==wanted.read_bytes(),'cycle crash partial generation'
   recovered=case/'recovered';run([exe,'cycle-resume',target,recovered,'','roundtrip'],case,'crash_reconstruction');assert recovered.read_bytes()==target.read_bytes()
   crashes[phase]=dict(returncode=child.returncode,complete=True,sha256=sha(target));(case/'result.json').write_text(json.dumps(crashes[phase])+'\n')
  report['crashes']=crashes
  results[kind+'-'+opt]=report
assert results['cold-O0']==results['cold-O2']and results['heat-O0']==results['heat-O2']
assert all(sha(Path(p))==h for p,h in pinned.items()),'provider artifacts drift'
for p in ['src/adapter/mod_crop_soil_n_saved_cycle_output.f90','tests/nut-output/run_cycle_output.py','tests/nut-output/cycle_output_proof.inc']:inputs[p]=sha(ROOT/p)
r=dict(status='COLD_HEAT_TWO_CROP_SAVED_OUTPUT_O0_O2_FRESH_PASS',results=results,events=events,input_sha256=inputs,pinned_artifacts=pinned,generated=generated,shared_base_provider_count=331,additive_provider_count=1,full_mc_nut01_closed=False,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
