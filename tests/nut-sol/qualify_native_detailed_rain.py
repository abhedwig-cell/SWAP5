"""Original detailed-rain/ETpot witnesses and actual atomic native reporting days."""
import argparse,base64,csv,gzip,hashlib,io,json,re,runpy,shutil,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def rows(path):return [{k:float(v)for k,v in r.items()}for r in csv.DictReader(path.open())]
def audit(path):return json.loads(base64.b64decode(''.join(l.split('=',1)[1]for l in path.read_text().splitlines()if l.startswith('! native_project_audit_base64='))))
def rain_oracle():
 raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
 with tarfile.open(fileobj=io.BytesIO(raw))as t:source=t.extractfile('SWAP/MOD_meteo.f90').read()
 text=source.decode('cp1252');start=text.index('   subroutine LoadRainData ()');end=text.index('   end subroutine LoadRainData',start)+len('   end subroutine LoadRainData');body=text[start:end]
 context='''module MOD_swap_base
 integer::iun_min2=10,iun_max2=99,unit_log=77,unit_err=0
 character(200)::pathatm=''
end module
module variables
 real(8)::tstart,tend
end module
module original_rain
 implicit none
 integer::swrainfilall,rain_rec
 character(200)::rainfil
 real(8),allocatable::raintim(:),rainflx(:),arai(:)
contains
'''+body+'''
end module
program witness
 use MOD_swap_base
 use variables
 use original_rain
 implicit none
 integer::i,u
 character(1024)::swp
 logical::rdinqr
 call get_command_argument(1,swp)
 call rdinit(74,0,trim(swp));call rdstim('tstart',tstart);call rdstim('tend',tend)
 call rdscha('rainfil',rainfil);call lowerc(rainfil)
 if(rdinqr('pathatm'))call rdscha('pathatm',pathatm)
 if(len_trim(pathatm)>0)pathatm=trim(pathatm)//'/'
 swrainfilall=0
 if(index(trim(rainfil),'.rain')>0)swrainfilall=1
 close(74)
 open(77,file='original-rain.log',status='replace')
 call LoadRainData()
 open(newunit=u,file='original-rain.csv',status='replace')
 write(u,'(A)')'day,rain_cm'
 do i=1,size(arai)
  write(u,'(I0,A,ES25.16E3)')i,',',arai(i)
 end do
 close(u)
 open(newunit=u,file='original-events.csv',status='replace')
 write(u,'(A)')'end_day,rate_cm_day'
 do i=1,size(raintim)
  if(raintim(i)<=tstart)cycle
  write(u,'(ES25.16E3,A,ES25.16E3)')raintim(i)-tstart,',',rainflx(i)
  if(raintim(i)>=tend+1d0)exit
 end do
 close(u)
end program
subroutine swap_error(where,message)
 character(*)::where,message
 print *,where,message
 error stop 1
end subroutine
'''
 return context,sha(source),sha(body.encode('cp1252'))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--cross-year-fixture',type=Path);ap.add_argument('--limit',type=int);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);bundle=a.bundle.resolve();meta=json.loads((bundle/'bundle.json').read_text());opt=meta['optimization']
 report=dict(status='RUNNING',optimization=opt,candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),events=[],cases={},inputs={p:sha((ROOT/p).read_bytes())for p in ['app/solute_project/main.f90','app/solute_crop/read_swp_project.f90','app/solute_crop/read_swp_crop.f90','tools/solute/run_project.py',str(Path(__file__).relative_to(ROOT))]})
 def save():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=2400);i=len(report['events'])
  for stream in ['stdout','stderr']:(out/f'{i:03}.{stream}').write_bytes(getattr(r,stream))
  report['events'].append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode,expected_success=valid));save()
  if (r.returncode==0)!=valid:raise RuntimeError(str(cmd)+'\n'+r.stderr.decode(errors='replace')[-2000:])
  return r
 b=json.loads((Path(meta['exe']).parent/'build-complete.json').read_text());fc=b['compiler_command'];flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(out)]
 tt=[p for p in b['reused_artifact_sha256']if p.endswith('/libttutil.a')];assert len(tt)==1
 source,mh,bh=rain_oracle();(out/'rain-oracle.f90').write_text(source);report['original_meteo_sha256']=mh;report['whole_LoadRainData_sha256']=bh
 run(fc+flags+[out/'rain-oracle.f90',tt[0],'-o',out/'rain-oracle'],out)
 crop_source,fh=runpy.run_path(str(ROOT/'tests/nut-sol/qualify_native_simple_crop.py'))['oracle']()
 crop_source=crop_source.replace('integer::n,i,j,u,first,last,datea(6)','logical::rdinqr\n integer::n,i,j,u,first,last,datea(6)')
 crop_source=crop_source.replace(" call rdsdor('rds',", " if(rdinqr('swcfbs'))call rdsinr('swcfbs',0,1,swcfbs)\n if(swcfbs==1)call rdsdor('cfbs',0d0,1.5d0,cfbs)\n call rdsdor('rds',")
 (out/'crop-oracle.f90').write_text(crop_source);run(fc+flags+[out/'crop-oracle.f90',tt[0],'-o',out/'crop-oracle'],out)
 old=runpy.run_path(str(ROOT/'integration/audits/verify_root_substep.py'))['capsule']()
 names=['pulse']+(['cross_year']if a.cross_year_fixture else[])
 for name in names:
  case=out/name;case.mkdir();(case/'crop data').mkdir();(case/'weather data').mkdir()
  if name=='pulse':
   swp=old['daily/'+opt+'/dry/input.swp'].decode();crp=old['daily/'+opt+'/dry/crop.crp'];weather=old['daily/'+opt+'/dry/weather.met']
   swp+="\nSWBOTB=2\nSW2=1\nSINAVE=0.\nSINAMP=0.\nSINMAX=1.\nPONDMX=1000.\nRSRO=.001\nRSROEXP=1.\nPATHATM='weather data'\nPATHCROP='crop data'\nRAINFIL='pulse.rain'\n"
   swp=swp.replace('SWRAIN=0','SWRAIN=3').replace('SWCFBS=0','SWCFBS=1\nCFBS=.7')
   (case/'crop data/crop.crp').write_bytes(crp);(case/'weather data/weather.met').write_bytes(weather)
   lines=['Station Day Month Year Time Amount']
   for day,month in [(27,2),(28,2),(29,2),(1,3),(2,3),(3,3),(4,3),(5,3)]:
    for hour,amount in [(0.,0.),(.25,0.),(.5,.001),(.75,.002),(1.,0.)]:
     # Avoid duplicate midnight records between adjacent Gregorian days.
     if hour==0. and len(lines)>1:continue
     lines.append("'s' "+f'{day} {month} 2024 {hour:.5f} {amount:.8f}')
   (case/'weather data/pulse.rain').write_text('\n'.join(lines)+'\n');days=8;split=3
  else:
   src=a.cross_year_fixture.resolve();swp=(src/'full/input.swp').read_text();days=481;split=365
   for folder in ['crop data','weather data']:
    for p in (src/folder.title()).iterdir():shutil.copy2(p,case/folder/p.name)
   swp=swp.replace('SWRAIN=0','SWRAIN=3').replace('SWCFBS=0','SWCFBS=1\nCFBS=.7')+"\nRAINFIL='andelst_rain'\n"
   for ext in ['998','999']:(case/('weather data/andelst_rain.'+ext)).write_bytes(gzip.decompress((ROOT/('tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_rain.'+ext+'.gz')).read_bytes()))
  swp_path=case/'project.swp';swp=swp.replace('Crop Data','crop data').replace('Weather Data','weather data')
  swp_path.write_text(swp)
  common=[sys.executable,ROOT/'tools/solute/run_project.py',swp_path,'--bundle',bundle,'--temporal-tolerance','.001']
  if name=='cross_year':common+=['--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
  n=min(days,a.limit)if a.limit else days;split=min(split,max(1,n//2))if n<days else split
  for target,extra in [('full',['--stop-after',str(n)]),('split',['--stop-after',str(split)]),('resumed',['--stop-after',str(n),'--restart',case/'split'])]:run(common+['--output',case/target]+extra,ROOT)
  for p in ['state.csv','endpoint.csv','restart.bin']:assert(case/'full'/p).read_bytes()==(case/'resumed'/p).read_bytes(),(name,p)
  budget=rows(case/'full/budget.csv');assert len(budget)==n and rows(case/'resumed/budget.csv')==budget[split:]
  info=audit(case/'full/input.nml');run([out/'rain-oracle','project.swp'],case)
  expected=rows(case/'original-events.csv');actual=[{k:float(v)for k,v in r.items()}for r in info['rain_events']];assert actual==expected,'whole original LoadRainData intervals'
  daily=rows(case/'original-rain.csv')
  for i,d in enumerate(budget):
   assert abs(d['rain_supplied_cm']-daily[i]['rain_cm'])<1e-11
   assert d['rain_segments']>=1 and abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
   gross=d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['runoff_cm']+d['actual_transpiration_cm']-d.get('bottom_up_cm',0.)
   assert abs(gross)<1e-10,(name,i,'gross',gross)
  stage=case/'preparation';stage.mkdir();document=(case/'full/input.nml').read_text()
  for key,h in info['original_sources'].items():
   raw=base64.b64decode(''.join(l.split('=',1)[1]for l in document.splitlines()if l.startswith('! '+key+'_base64=')));assert sha(raw)==h
   filename='input.swp'if key=='original_swp'else{'met':'weather-','crop':'crop-','rain':'rain-'}[key.split('_')[0]]+key.split('_')[1]+{'met':'.met','crop':'.crp','rain':'.rain'}[key.split('_')[0]]
   (stage/filename).write_bytes(raw)
  run([meta['project_reader'],'input.swp','prepare'],stage)
  for period in info['prepared_periods']:
   idx=str(period['index']);run([out/'crop-oracle','period-'+idx+'.swp','crop-'+idx+'.crp','weather.met'],stage)
   original=rows(stage/'original.csv');native=[{k:float(v)for k,v in row.items()}for row in period['plan']]
   assert len(original)==len(native)
   for x,y in zip(original,native):
    for k in x:assert abs(x[k]-y[k])<=1e-13*max(1.,abs(x[k])),(name,idx,k,x[k],y[k])
   (stage/'original.csv').rename(stage/('original-'+idx+'.csv'))
  report['cases'][name]=dict(days=n,declared_days=days,full_period=n==days,events=len(actual),restart_exact=True,original_Andelst_model=False,water_max_residual=max(abs(x['water_residual_cm'])for x in budget),solute_max_residual=max(abs(x['solute_residual_mg_cm2'])for x in budget));save()
  # Complete source identity includes future original rain bytes.
  changed=next((case/'weather data').glob('pulse.rain'if name=='pulse'else'andelst_rain.999'));original_bytes=changed.read_bytes();changed.write_bytes(original_bytes+b'\n* changed future source\n')
  run(common+['--output',case/'forbidden-source','--restart',case/'split'],ROOT,False);assert not(case/'forbidden-source').exists();changed.write_bytes(original_bytes)
 report['status']='NATIVE_DETAILED_RAIN_SOIL_FACTOR_COMPOSITION_PASS';save();print(json.dumps(report['cases']))
if __name__=='__main__':main()
