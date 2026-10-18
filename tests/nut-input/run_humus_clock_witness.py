"""Execute original time-update/soil-clock statements before original rateconstants.

This scoped original-caller witness is separate from new-owner process tests;
it is not an execution of the complete historical hydrological model.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['N_HUMUS_CLOCK_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_HUMUS_CLOCK_AUTHORITY.tar.xz.b64').read_bytes())
assert sha(raw)=='eb2c33d8a93cd46ea175f964d768bc4bcbef04a5b9ff1f0f88cc5882632c3959'
with tarfile.open(fileobj=io.BytesIO(raw))as t:
 clock={m.name:t.extractfile(m).read()for m in t if m.isfile()}
manifest=json.loads(clock['MANIFEST.json'])
for p,h in manifest['files'].items():assert sha(clock[p])==h
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
 original={n:t.extractfile('SWAP/'+n).read()for n in ['management_soil.f90','wofost_soil_declarations.f90','wofost_soil_rateconstants.f90']}
assert sha(original['management_soil.f90'])==manifest['management_identity_sha256']
caller=clock['SWAP/swap.f90'].decode();positions=[caller.lower().index(s.lower())for s in ['call TimeControl(3)','call Soilmanagement(2)','call Soilmanagement(4)']];assert positions==sorted(positions)
update='\n'.join(clock['SWAP/timecontrol.f90'].decode().splitlines()[231:234])+'\n'
soilclock=original['management_soil.f90'].decode().splitlines()[342]+'\n'
assert 't1900 = t1900 + dt'in update and 't1900Soil = t1900'in soilclock
(OUT/'time_update.inc').write_text(update);(OUT/'soil_clock.inc').write_text(soilclock)
(OUT/'original_caller_order.txt').write_text(caller[positions[0]:positions[-1]+len('call Soilmanagement(4)')]+'\n')
events=[];results={}
def run(c,b,category):
 c=list(map(str,c));start=time.perf_counter();r=subprocess.run(c,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:03d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i:03d}.stdout',stderr=f'{i:03d}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir()
 for n,v in original.items():(b/n).write_bytes(v)
 (b/'fixture.f90').write_text('subroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
 driver='''program witness
 use wofost_soil_declarations
 implicit none
 real(8)::tcum,t1900,t,timjan1,dt,expected,internal_end,internal_start
 integer::day
 nf=8;RateconFOM_ref=.01d0;RateconBio_ref=.001d0;RateconHum_ref=.02d0/365.2425d0
 RateconHum_exp=.04d0/365.2425d0;tstartHumexp=3d0
 WFrac_t=.34d0;WFrac_t0=.34d0;WFrac_sat=.45d0;WFPScrit=.6d0;WFPScrit2=.5d0
 Temp=20d0;Temp_ref=20d0;RateConNitrif_ref=.02d0;RateConDenitr_ref=.03d0
 t1900=1d0;tcum=0d0;timjan1=1d0;dt=1d0
 internal_start=tstartHumexp-1d0
 do day=1,3
'''+update+soilclock+'''
  call wofost_soilrateconstants(1)
  expected=RateconHum_ref
  if(day>=2)expected=RateconHum_exp
  if(abs(RateconHum-expected*red_T*red_W)>1d-15)error stop 1
  internal_end=t1900-1d0
  if((t1900Soil>=tstartHumexp).neqv.(internal_end>=internal_start))error stop 2
  if(day==2.and.internal_end-1d0>=internal_start)error stop 3
  print *,day,t1900Soil,internal_end,RateconHum
 end do
 print '(A)','ORIGINAL_HUMUS_ENDPOINT_CLOCK_SWITCH=PASS'
end program
'''
 (b/'witness.f90').write_text(driver);flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
 for i,n in enumerate(['wofost_soil_declarations.f90','wofost_soil_rateconstants.f90','fixture.f90','witness.f90']):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',b/n,'-o',o],b,'compile');objects.append(o)
 exe=b/'witness';run(['gfortran',*flags,*objects,'-o',exe],b,'link');results[opt]=run([exe],b,'native')
assert results['O0']==results['O2']
r=dict(status='ORIGINAL_HUMUS_CALLER_ENDPOINT_CLOCK_O0_O2_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),clock_authority_sha256=sha(raw),original_source_sha256={k:sha(v)for k,v in original.items()},caller_source_sha256=manifest['files'],time_update_sha256=sha(update.encode()),soil_clock_sha256=sha(soilclock.encode()),runner_sha256=sha(Path(__file__).read_bytes()),results=results,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
