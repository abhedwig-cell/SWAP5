#!/usr/bin/env python3
"""Execute unchanged B0 grouping defect, then one-line R2 B1 correction."""
from pathlib import Path
import os,json,hashlib,base64,io,tarfile,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['CALENDAR_REFERENCE_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'events.json').exists(),'fresh output required'
events=[]
def sha(b):return hashlib.sha256(b).hexdigest()
def run(args,cwd,category):
 t=time.perf_counter();r=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:03d}.{stream}').write_bytes(getattr(r,stream))
 events.append({'command':list(map(str,args)),'category':category,'returncode':r.returncode,'seconds':time.perf_counter()-t,**{stream+'_file':f'{i:03d}.{stream}'for stream in ['stdout','stderr']},**{stream+'_sha256':sha(getattr(r,stream))for stream in ['stdout','stderr']}})
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stderr.decode()
 return r.stdout.decode()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as a:raw=a.extractfile('SWAP/management_soil.f90').read()
assert sha(raw)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
source=raw.decode();a=source.index('!     Converting kg/ha -> kg/m2');b=source.index('! -   open file with soil nutrient parameters',a)
group=source[a:b];a=source.index('      if (abs(TimeAmend(isme)');b=source.index('      return',a);trigger=source[a:b]
old='smedate(isme)-smedate(isme-1) < 0.d-3';new='smedate(isme)-smedate(isme-1) < 1.d-3';assert group.count(old)==1
events_source='''module observed_events
 implicit none
 integer::calls=0,seen(8)=0,isme,NuAmend(8),iAmend(8,8)
 real(8)::Amend(8),delivered=0d0
contains
 subroutine Wofost_SoilAmendents
 integer::k
 do k=1,NuAmend(isme)
 calls=calls+1;seen(calls)=iAmend(isme,k);delivered=delivered+Amend(iAmend(isme,k))
 end do
 end subroutine
end module
'''
r={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'authority_sha256':sha(raw),'correction':{'old':old,'new':new},'compiler':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],'runs':{}}
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir();(build/'management_soil.f90').write_bytes(raw)
 for label in ['B0','B1_R2']:
  selected=group if label=='B0'else group.replace(old,new)
  body=events_source+'''program reference_calendar
 use observed_events
 implicit none
 integer,parameter::nsme=4
 integer::i,j,day,previous_calls
 real(8)::smedate(8),MatAmount(8),TimeAmend(8),t1900
 smedate=1d8;MatAmount=0d0;TimeAmend=1d8;NuAmend=0;iAmend=0
 smedate(1:4)=[0d0,0d0,1d0,3d0];MatAmount(1:4)=[100d0,200d0,300d0,400d0]
'''+selected+'''
 isme=1
 do day=0,3
 t1900=real(day+1,8);previous_calls=calls
'''+trigger+'''
 write(*,'(A,I1,A,I1,A,8I3)')'SELECT_DAY=',day,' COUNT=',calls-previous_calls,' INDICES=',seen(previous_calls+1:calls)
 end do
'''+(''' if(calls/=1.or.seen(1)/=1.or.isme/=2.or.delivered/=.01d0)error stop 1
 print '(A)','B0_SAME_DATE_STALLS_ALL_LATER_AMENDMENTS=PASS'
'''if label=='B0'else''' if(calls/=4.or.any(seen(1:4)/=[1,2,3,4]).or.isme/=4.or.abs(delivered-.1d0)>1d-15)error stop 1
 print '(A)','B1_R2_SAME_DATE_SOURCE_ORDER_LATER_DATES_MASS=PASS'
''')+'''end program
'''
  p=build/(label+'.f90');p.write_text(body);exe=build/label
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build)]
  run(['gfortran',*flags,p,'-o',exe],build,'compile_link');output=run([exe],build,'native')
  r['runs'][opt+'/'+label]={'source_sha256':sha(p.read_bytes()),'stdout':output}
r.update(status='B0_DEFECT_B1_R2_PASS',cost_seconds={category:sum(e['seconds']for e in events if e['category']==category)for category in ['compile_link','native']},input_sha256={str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
