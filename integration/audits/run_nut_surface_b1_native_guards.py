"""Real enabled Richards/crop native restarts and CRC-valid corruptions.

Wet qualification is default; the separately recorded dry gross/E trial remains
an explicit research selection and must not be reported as qualified.
"""
from pathlib import Path
import hashlib,json,os,struct,subprocess,time,zlib
ROOT=Path(__file__).resolve().parents[2];BASE=Path(os.environ['N_SURFACE_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_NATIVE_DIR']).resolve();OUT.mkdir(exist_ok=False)
KIND=os.environ.get('N_SURFACE_NATIVE_KIND','wet');assert KIND in ['wet','dry']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();self_sha=sha(Path(__file__))
prior=json.loads((BASE/'result.json').read_text());assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(BASE/'generated_driver.f90')==prior['generated_driver_sha256']
origin=json.loads((BASE/'events.json').read_text());assert all(e['returncode']==0 for e in origin)
text=(BASE/'generated_driver.f90').read_text()
# Retain the discriminating positive-surface-stock wet fixture even when the
# byte-verified current production providers were built with the field driver.
# This changes only generated test input; no provider is replaced or inherited.
if prior.get('hydrology','clay')=='field-loam':
 old='  cfg%tiles(1)%initial_state%ponding_depth=0d0';assert text.count(old)==1
 added='  cfg%tiles(1)%initial_state%ponding_depth=.2d0\n'
 for i in [3,10,12]:added+=f'  cfg%tiles(1)%parameters%cofgen({i},:)=cfg%tiles(1)%parameters%cofgen({i},:)*1d-3\n'
 text=text.replace(old,added.rstrip())
 old='     forcing%pond_input%rain_rate_cm_day=merge(.5d0,.05d0,mod(d,7)==6)*(1d0+.4d0*season)';assert text.count(old)==1
 text=text.replace(old,'     forcing%pond_input%rain_rate_cm_day=.05d0*(1d0+.4d0*season)')

changes={'initial_state%ponding_depth=.2d0':'initial_state%ponding_depth=0d0','rain_rate_cm_day=.05d0*(1d0+.4d0*season)':'rain_rate_cm_day=.4d0','irrigation_rate_cm_day=.005d0':'irrigation_rate_cm_day=0d0','runon_rate_cm_day=.01d0':'runon_rate_cm_day=0d0','potential_pond_evaporation_cm_day=.01d0*(1d0+.4d0*season)':'potential_pond_evaporation_cm_day=.4d0'}
if KIND=='dry':
 for a,b in changes.items():assert text.count(a)==1,a;text=text.replace(a,b)
a=text.index(' subroutine rotation_continuation(');b=text.index(' subroutine report_water_state(',a);body=text[a:b]
needle="   if(trim(mode)=='resume')then\n    read(arg,*)first";assert body.count(needle)==1
body=body.replace(needle,"""   if(trim(mode)=='check'.or.trim(mode)=='reject')then
    water=kernel_committed_state_t();state=crop_soil_state_t()
    call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template, &
      670001_int64,9001_int64,9101_int64,sp,cp,water,state,code)
    if(trim(mode)=='check')then
     call require(code==0.and.water%ready().and.state%ready(),'positive enabled native decode')
    else
     call require(code/=0.and..not.water%ready().and..not.state%ready(),'corrupt enabled native rejects atomically')
    endif
    print *,'SURFACE_NATIVE_CHECK',trim(mode)
    stop
   endif
"""+needle)
needle="   print *,'ROTATION_POOLS'";assert body.count(needle)==1
body=body.replace(needle,"   print *,'SURFACE_NATIVE_STOCK',ps%surface_n_kg_m2\n"+needle)
text=text[:a]+body+text[b:];driver=OUT/'dry_native.f90';driver.write_text(text)
events=[];runs={};artifacts={}
def run(c,b,kind):
 c=list(map(str,c));t=time.perf_counter();r=subprocess.run(c,cwd=b,capture_output=True,env={**os.environ,'OMP_NUM_THREADS':'1'});i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=kind,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==0,(kind,r.stdout.decode(),r.stderr.decode());return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();base=BASE/opt;ce=[e for e in origin if e['category']=='compile'and '-'+opt in e['command']]
 flags=ce[-1]['command'][1:ce[-1]['command'].index('-c')];flags=[('-J'+str(b)if x.startswith('-J')else x)for x in flags]+['-I'+str(b)]
 objects=[Path(e['command'][-1])for e in ce[:-1]]
 for p in objects+list(base.glob('*.mod')):artifacts[str(p)]=sha(p)
 obj=b/'driver.o';exe=b/'dry_native';run(['gfortran',*flags,'-c',driver,'-o',obj],b,'driver_compile');run(['gfortran',*flags,*objects,obj,'-o',exe],b,'link')
 restart=b/'restart';end=b/'endpoint';fresh=b/'fresh'
 stdout=run([exe,'write',restart,end,'surface-profile','0','2'],b,'native')
 run([exe,'resume',Path(str(restart)+'.1'),fresh,'surface-profile','1','2'],b,'fresh_native')
 assert end.read_bytes()==fresh.read_bytes(),'dry fresh-process endpoint drift'
 fields=next(line.split()[1:]for line in stdout.splitlines()if line.strip().startswith('SURFACE_NATIVE_STOCK'))
 values=[float(x.replace('D','E'))for x in fields];assert len(values)==2 and min(values)>0,'dry stocks absent'
 raw=end.read_bytes();pattern=struct.pack('<2d',*values);offset=raw.find(pattern);assert offset>=0 and raw.find(pattern,offset+1)<0,'ambiguous dry surface payload'
 run([exe,'check',end,'unused','surface-profile','0','2'],b,'positive_decode')
 mutants={}
 def changed(label,at,fmt,value):
  d=bytearray(raw);struct.pack_into(fmt,d,at,value);d[-4:]=struct.pack('<I',zlib.crc32(d[:-4]));mutants[label]=bytes(d)
 for species in [0,1]:
  for label,value in [('negative',-1.),('nan',float('nan')),('inf',float('inf')),('above_bound',100.1)]:changed(f'{label}_{species}',offset+8*species,'d',value)
 for label,payload in [('missing_surface',raw[:offset]+raw[offset+16:-4]),('missing_one_species',raw[:offset]+raw[offset+8:-4]),('duplicate_surface',raw[:offset]+raw[offset:offset+16]+raw[offset:-4])]:mutants[label]=payload+struct.pack('<I',zlib.crc32(payload))
 marker=raw.find(struct.pack('<d',-81006.));assert marker>=0;changed('mode_marker',marker,'d',-999.)
 mutants['crc']=raw[:-1]+bytes([raw[-1]^1]);mutants['truncated']=raw[:120];mutants['trailing']=raw+b'x'
 for label,data in mutants.items():
  p=b/(label+'.bin');p.write_bytes(data);out=run([exe,'reject',p,'unused','surface-profile','0','2'],b,'negative_decode');assert 'SURFACE_NATIVE_CHECKreject'in out.replace(' ','')
 runs[opt]=dict(stdout=stdout,endpoint_sha256=sha(end),restart_sha256=sha(Path(str(restart)+'.1')),stocks=values,mutants=list(mutants))
assert runs['O0']==runs['O2']
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in prior['input_sha256'].items():assert sha(ROOT/p)==h,p
assert sha(Path(__file__))==self_sha
r=dict(status='SURFACE_N_B1_'+KIND.upper()+'_PHYSICAL_NATIVE_AND_CORRUPTIONS_PASS_NOT_ADMITTED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={**prior['input_sha256'],str(Path(__file__).relative_to(ROOT)):self_sha},provider_result_sha256=sha(BASE/'result.json'),generated_driver_sha256=sha(driver),artifacts=artifacts,runs=runs,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['driver_compile','link','native','fresh_native','positive_decode','negative_decode']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
