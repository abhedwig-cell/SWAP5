"""Compare the production grass-start candidate with the original compiled routine."""
import csv,json,subprocess,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT.parent/'dq13-grass-qualification-final';out.mkdir(exist_ok=False)
ref=ROOT.parent/'dq13-reference431/providers';original=(ref/'selected/wofost.f90').read_text();needle='   private\n';assert original.count(needle)==1
oracle=original.replace(needle,needle+'   public :: update_dvs_rate, dtsum, dvr, fl_tsum\n',1);(out/'wofost.f90').write_text(oracle)
driver='''program original_grass
use iso_fortran_env,only:real64
use wofost_module,only:update_dvs_rate,dtsum,dvr,fl_tsum,sw_wofost,p_grs,t_tsumcum,nodtsum
use atmosphere_interface,only:tav
use plant_interface,only:tsum
use MOD_SoilTemperature,only:tsoil
implicit none
integer::mode,warm,delay,required,ios
real(real64)::soil
nodtsum=1;sw_wofost=3
 do
 read(*,*,iostat=ios)mode,tsum,tav,soil,warm,delay,required
 if(ios/=0)exit
 p_grs%sw_tsum=mode;p_grs%temptsum=5d0;p_grs%t_temptsum=required
 t_tsumcum=warm;tsoil(1)=soil
 call update_dvs_rate()
 write(*,'(2(es25.16e3,1x),l1,1x,i0)')dtsum,dvr,fl_tsum,t_tsumcum
 end do
end program
'''
# Original module name is read from the authoritative provider, never guessed.
import re
module=re.search(r'^module\s+(\w+)',original,re.M|re.I)[1];driver=driver.replace('wofost_module',module);(out/'oracle.f90').write_text(driver)
weather=list(csv.DictReader(l for l in (ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/260.met').read_text().splitlines()if l.strip()and not l.startswith('*')))
fixtures=[];tsum=0.;year=None
for r in weather:
 if year!=r['YYYY']:tsum=0.;year=r['YYYY']
 tav=(float(r['Tmin'])+float(r['Tmax']))/2;fixtures.append(f'1 {tsum:.17g} {tav:.17g} 0 0 0 1');tsum+=max(0,tav)
for mode in [0,1,2]:
 for t in [199.,200.,201.]:
  for air in [-5.,0.,1.,2.]:
   for soil in [4.,5.,6.]:
    for warm in [0,1,2]:
     for delay in [0,1,2]:fixtures.append(f'{mode} {t} {air} {soil} {warm} {delay} 2')
data=('\n'.join(fixtures)+'\n').encode();(out/'fixtures.txt').write_bytes(data);events=[]
def run(cmd,**kw):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,**kw);events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode));(out/f'{len(events)}.stderr').write_bytes(r.stderr)
 if r.returncode:raise RuntimeError(r.stderr.decode())
 return r.stdout
fc='/usr/bin/x86_64-linux-gnu-gfortran-13'
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-J'+str(folder),'-I'+str(folder)]
 run([fc,*flags,ROOT/'src/crop/mod_wofost_grass_development.f90',ROOT/'tests/dataqual13/grass_development_driver.f90','-o',folder/'candidate'])
 run([fc,*flags,'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj'),'-c',out/'wofost.f90','-o',folder/'wofost.o'])
 objects=[p for p in (ref/'swobj').glob('*.o')if p.name.lower()!='wofost.o']
 run([fc,*flags,'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj'),out/'oracle.f90',folder/'wofost.o',*objects,ref/'ttobj/libttutil.a','-o',folder/'oracle'])
 actual=run([folder/'candidate'],input=data);expected=run([folder/'oracle'],input=data);(folder/'candidate.stdout').write_bytes(actual);(folder/'oracle.stdout').write_bytes(expected)
 a=[r.split()for r in actual.splitlines()];e=[r.split()for r in expected.splitlines()];assert len(a)==len(e)==len(fixtures)
 for x,y in zip(a,e):assert x[:3]+[x[4]]==y,(x,y)
 print(opt,'ORIGINAL_GRASS_DEVELOPMENT_PASS',len(fixtures),flush=True)
(out/'RESULT.json').write_text(json.dumps(dict(status='GRASS_DEVELOPMENT_COMPONENT_PASS_NOT_MODEL_EXECUTION',fixtures=len(fixtures),original_weather_days=len(weather),events=events,source_sha256=hashlib.sha256(original.encode()).hexdigest()),indent=2))
