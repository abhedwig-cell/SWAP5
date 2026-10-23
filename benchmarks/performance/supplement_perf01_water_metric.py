"""Daily state observations and active empirical root-stress discriminator."""
import argparse,csv,hashlib,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='src/process/mod_pond_water_temporal_difference.f90'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
def rows(p):return list(csv.DictReader(p.open()))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--study',type=Path,required=True)
 ap.add_argument('--bundle-prefix',type=Path,required=True);ap.add_argument('--compiler',required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 r=dict(status='RUNNING',script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),events=[],cases={},criteria=dict(daily_water_mm=1e-9,daily_runoff_mm=.01,season_runoff_mm=.05,daily_storage_mm=.01,daily_transpiration_mm=.01,season_transpiration_mm=.05,daily_total_evaporation_mm=.01),production_changed=False)
 def save():(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
 def run(cmd,cwd,label):
  cmd=list(map(str,cmd));t=time.perf_counter()
  try:x=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  except subprocess.TimeoutExpired as e:x=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
  for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(x,s))
  r['events'].append(dict(label=label,command=cmd,seconds=time.perf_counter()-t,returncode=x.returncode));save();return x
 fc=['sh',a.compiler];core=min(os.sched_getaffinity(0));r['core']=core
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());m=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text())
  for p,h in m['input_sha256'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,p
  for p,h in m['reused_artifact_sha256'].items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
  folder=out/opt;folder.mkdir();flags=[x for x in m['flags']if not x.startswith('-J')]
  objects=[e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')];assert len(objects)==193
  archive=next(p for p in m['reused_artifact_sha256']if p.endswith('/libttutil.a'))
  for arm in ['ordinary','water']:
   driver=ROOT/'app/solute_project/main.f90'if arm=='ordinary'else a.study/opt/'main.f90';raw=driver.read_text()
   anchor='  integer :: nodes=4';assert raw.count(anchor)==1;raw=raw.replace(anchor,'  integer::pd_unit,pd_node\n'+anchor)
   anchor='  do j=first,stop_after';assert raw.count(anchor)==1;raw=raw.replace(anchor,"  open(newunit=pd_unit,file='daily_physical.csv',status='new')\n  write(pd_unit,'(A)')'day,node,head_cm,theta'\n"+anchor)
   anchor='    clock=t1';assert raw.count(anchor)==1;raw=raw.replace(anchor,'''    call water%snapshot(physical,ok)
    call require(ok,'daily research snapshot')
    select type(pd=>physical)
    type is(fmr_b110_physical_state_t)
      do pd_node=1,numnod
        write(pd_unit,'(I0,A,I0,2(A,ES25.17E3))')j,',',pd_node,',',pd%pressure_head(pd_node),',',pd%water_content(pd_node)
      end do
    class default
      error stop 'unexpected research snapshot type'
    end select
'''+anchor)
   anchor="  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'";assert raw.count(anchor)==1;raw=raw.replace(anchor,'  close(pd_unit)\n'+anchor)
   p=folder/(arm+'.f90');p.write_text(raw);obj=list(objects);extra=[];includes=[]
   if arm=='water':
    wd=a.study/opt;includes=['-I'+str(wd)];extra=[wd/'geometry.o']
    old=next(e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+SOURCE));obj[obj.index(old)]=str(wd/'difference.o')
   binary=folder/arm;x=run([*fc,*includes,*flags,'-J'+str(folder),p,*obj,*extra,archive,'-o',binary],folder,opt+'-'+arm+'-link');x.check_returncode()
   for rain in [1,4]:
    previous=a.study/f'{opt}-{rain}x-{arm}-0'
    for fixture in ['base','stress']:
     label=f'{opt}-{rain}x-{fixture}-{arm}';case=out/label;case.mkdir();text=(previous/'input.nml').read_text()
     if fixture=='stress':
      text='\n'.join(l for l in text.splitlines()if not l.startswith('! native_project_audit_base64='))+'\n'
      assert text.count('&crop\n')==1;text=text.replace('&crop\n','&crop\n substep_root_stress=.true.\n')
      for field,value in [('HLIM3L','-25d0'),('HLIM3H','-50d0'),('HLIM4','-400d0'),('HLIM2U','-10d0'),('HLIM2L','-10d0'),('EMPIRICAL_OXYGEN_ENABLED','T')]:
       text,n=re.subn(r'(?m)^(\s*PROFILES\(1\)%PARAMETERS%'+field+r'=)[^\n]*',lambda x:x[1]+' '+value+',',text);assert n==1,field
     (case/'input.nml').write_text(text);(case/'input.swp').write_bytes((previous/'input.swp').read_bytes())
     x=run(['taskset','-c',core,binary,'input.nml','-','97','input.swp'],case,label)
     if x.returncode:r['cases'][label]=dict(status='REJECTED',returncode=x.returncode);save();continue
     if fixture=='base':
      for n in FILES:assert (case/n).read_bytes()==(previous/n).read_bytes(),(label,n)
     data=rows(case/'budget.csv');assert len(data)==97
     assert max(abs(float(d['water_residual_cm']))for d in data)<1e-10
     if fixture=='stress':
      for part in ['half','resume']:
       part_label=label+'-'+part;p=out/part_label;p.mkdir()
       for n in ['input.nml','input.swp']:(p/n).write_bytes((case/n).read_bytes())
       x=run(['taskset','-c',core,binary,'input.nml',out/(label+'-half')/'restart.bin'if part=='resume'else'-','48'if part=='half'else'97','input.swp'],p,part_label);x.check_returncode()
       if part=='resume':
        for n in FILES[1:]:assert (p/n).read_bytes()==(case/n).read_bytes()
        assert rows(p/'budget.csv')==data[48:]
     r['cases'][label]=dict(status='COMPLETE',drought_days=sum(float(d['drought_reduction_cm'])>1e-12 for d in data),oxygen_days=sum(float(d['oxygen_reduction_cm'])>1e-12 for d in data));save()
  for rain in [1,4]:
   for fixture in ['base','stress']:
    name=f'{opt}-{rain}x-{fixture}';plain=out/(name+'-ordinary');water=out/(name+'-water')
    if any(r['cases'][name+'-'+arm]['status']!='COMPLETE'for arm in ['ordinary','water']):continue
    left=rows(plain/'daily_physical.csv');right=rows(water/'daily_physical.csv');assert len(left)==len(right)==388
    a0=rows(plain/'budget.csv');a1=rows(water/'budget.csv')
    diff={k:dict(max_mm=10*max(abs(float(d[k])-float(s[k]))for d,s in zip(a1,a0)),sum_mm=10*sum(float(d[k])-float(s[k])for d,s in zip(a1,a0)))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm']}
    c=r['criteria'];criteria=dict(daily_runoff=diff['runoff_cm']['max_mm']<c['daily_runoff_mm'],season_runoff=abs(diff['runoff_cm']['sum_mm'])<c['season_runoff_mm'],storage=diff['water_end_cm']['max_mm']<c['daily_storage_mm'],daily_transpiration=diff['actual_transpiration_cm']['max_mm']<c['daily_transpiration_mm'],season_transpiration=abs(diff['actual_transpiration_cm']['sum_mm'])<c['season_transpiration_mm'],total_evaporation=10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for d,s in zip(a1,a0))<c['daily_total_evaporation_mm'])
    r['cases'][name]=dict(max_daily_head_cm=max(abs(float(d['head_cm'])-float(s['head_cm']))for d,s in zip(left,right)),max_daily_theta=max(abs(float(d['theta'])-float(s['theta']))for d,s in zip(left,right)),differences=diff,criteria=criteria);save()
 for rain in [1,4]:
  for fixture in ['base','stress']:
   for arm in ['ordinary','water']:
    label=f'O0-{rain}x-{fixture}-{arm}';other=f'O2-{rain}x-{fixture}-{arm}'
    if r['cases'][label]['status']==r['cases'][other]['status']=='COMPLETE':
     for n in [*FILES,'daily_physical.csv']:assert (out/label/n).read_bytes()==(out/other/n).read_bytes(),(label,n)
 r['status']='DAILY_STATE_AND_ACTIVE_ROOT_STRESS_DISCRIMINATOR_COMPLETE';save();print(json.dumps(r['cases'],indent=2))
if __name__=='__main__':main()
