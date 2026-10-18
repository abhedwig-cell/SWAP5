"""Execute the unmodified archived TTUTIL reader against candidate fixtures.

This is an independent syntax/type/array oracle, not a legacy SoilManagement
full-run oracle. TTUTIL day 1 is mapped to SWAP5 internal Gregorian day 0.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,time,zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['TTUTIL_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
FIXTURES=Path(os.environ['N_NATIVE_RESULT_DIR']).resolve()
raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
assert hashlib.sha256(raw).hexdigest()=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
source=OUT/'source';zipfile.ZipFile(io.BytesIO(raw)).extractall(source);source=source/'TTUTIL'
events=[];results={}
def run(args,b,category,success=True):
 args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=b,input=b'',capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=args,seconds=time.perf_counter()-t,category=category,returncode=p.returncode))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if success and p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.returncode,p.stdout.decode()
oracle='''program oracle
 implicit none
 character(512)::path
 character(80)::names(20)
 logical::rdinqr
 integer::mat(20),ids(1000),nm,ne,i
 real(8)::dose(1000),dates(1000),x,v(20),humrate,humstart
 character(8)::key
 call get_command_argument(1,path)
 call rdinit(20,0,trim(path))
 call rdainr('MatNum',1,20,mat,20,nm)
 call rdfcha('MatName',names,20,nm)
 if(nm/=1.or.mat(1)/=1)error stop 1
 if(trim(names(1))/='Mineral ! fertiliser'.and.trim(names(1))/='mineral ! fertiliser')error stop 1
 call rdfdor('AppAge',0d0,5000d0,v,20,nm)
 if(v(1)/=0d0)error stop 2
 call rdfdor('NH4NFrac',0d0,1d0,v,20,nm)
 if(abs(v(1)-.21d0)>1d-14)error stop 3
 call rdatim('smedate',dates,1000,ne)
 call rdfinr('iMat',1,1000,ids,1000,ne)
 call rdfdor('Dosagekgha',0d0,500000d0,dose,1000,ne)
 if(ne/=3.or.any(ids(:ne)/=1))error stop 4
 if(any(dose(:ne)/=[100d0,50d0,25d0]))error stop 5
 if(any(dates(:ne)-1d0/=[363d0,365d0,365d0]))error stop 6
 do i=1,8
  write(key,'(A,I1,A)')'FOM',i,'_t'
  call rdsdor(trim(key),0d0,1000d0,x)
  if(x/=1d0)error stop 7
 end do
 call rdsdor('Hum_t',0d0,1000d0,x)
 if(x/=40d0)error stop 8
 call rdsdor('RateConNitrif_ref',0d0,1000d0,x)
 if(abs(x-.02d0)>1d-14)error stop 9
 if(rdinqr('RateconHum_exp'))then
  call rdsdor('RateconHum_exp',0d0,100d0,humrate)
  call rdstim('tstartHumexp',humstart)
  if(abs(humrate-.1d0)>1d-14.and.humrate/=0d0.and.abs(humrate-.0001d0)>1d-14)error stop 10
  if(humstart-1d0/=365d0)error stop 11
  print '(A)','ORIGINAL_TTUTIL_OPTIONAL_HUMUS_RATE_DATE=PASS'
 end if
 close(20)
 print '(A)','ORIGINAL_TTUTIL_TYPED_ARRAY_TABLE_DATE_INTERPRETATION=PASS'
end program
'''
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();(b/'oracle.f90').write_text(oracle)
 sources=[source/'ttutilprefs.f90',source/'ttutil.f90']+sorted(p for p in source.glob('*.f90')if p.name not in ['ttutilprefs.f90','ttutil.f90'])+sorted(source.glob('*.for'))
 objects=[]
 for i,p in enumerate(sources):
  o=b/f'{i}.o';objects.append(o)
  run(['gfortran','-'+opt,'-std=legacy','-fallow-argument-mismatch','-ffixed-line-length-none','-ffree-line-length-none','-I'+str(source),'-I'+str(b),'-J'+str(b),'-c',p,'-o',o],b,'compile')
 exe=b/'oracle';run(['gfortran','-'+opt,b/'oracle.f90',*objects,'-o',exe],b,'link')
 results[opt]={}
 for name in ['arrays','table','continuation','case_comments','hum_experiment','hum_zero','hum_small']:
  (b/(name+'.snm')).write_bytes((FIXTURES/(name+'.snm')).read_bytes())
  _,output=run([exe,name+'.snm'],b,'native');assert 'ORIGINAL_TTUTIL_TYPED_ARRAY_TABLE_DATE_INTERPRETATION=PASS'in output
  results[opt][name]=output
 # Prove that the historical library really discriminates the original defect.
 (b/'scalar.snm').write_text((FIXTURES/'arrays.snm').read_text().replace('MatNum = 1*1','MatNum = 1'))
 code,output=run([exe,'scalar.snm'],b,'negative_native',False)
 assert code!=0 and 'variable is scalar'in output
 results[opt]['scalar_material']='REJECTED_SOURCE_SCALAR_NOT_ARRAY'
assert results['O0']==results['O2']
r=dict(status='ORIGINAL_TTUTIL_O0_O2_PASS',authority_zip_sha256=hashlib.sha256(raw).hexdigest(),results=results,source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in source.iterdir()if p.is_file()},fixture_sha256={n:hashlib.sha256((FIXTURES/(n+'.snm')).read_bytes()).hexdigest()for n in ['arrays','table','continuation','case_comments','hum_experiment','hum_zero','hum_small']},runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native','negative_native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
