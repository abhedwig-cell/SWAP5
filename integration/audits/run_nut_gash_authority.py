"""Literal archived Gash/AFGEN, preimage counterexample and current owner gates."""
from pathlib import Path
import base64,hashlib,io,json,os,shlex,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_GASH_AUTHORITY_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];results={}
sha=lambda b:hashlib.sha256(b).hexdigest()
raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
assert sha(raw)=='18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c'
with tarfile.open(fileobj=io.BytesIO(raw))as tar:
 originals={n:tar.extractfile('SWAP/'+n+'.f90').read()for n in ['MOD_meteo','functions','management_soil','integral']}
for n,b in originals.items():(OUT/(n+'.original.f90')).write_bytes(b)
def extract(name,a,b):
 s=originals[name].decode();start=s.index(a);end=s.index(b,start)+len(b);return s[start:end]
gash=extract('MOD_meteo','   subroutine Gash ()','   end subroutine Gash')
afgen=extract('functions','   real(8) function afgen (','   end function afgen')
literal='''module MOD_arrays
 integer,parameter::macroptb=4
end module
module plant_interface
 real(8)::pfreetb(4),pstemtb(4),scanopytb(4),avevaptb(4),avprectb(4)
end module
module MOD_irrigation
 real(8)::gird
 integer::isua
end module
module variables
 real(8)::t
end module
module literal_gash
 real(8)::grai,aintc
 contains
'''+gash+'''
end module
'''+afgen
(OUT/'literal.f90').write_text(literal)
driver='''program authority
 use mod_gash_interception_process
 use literal_gash,only:grai,aintc,original_gash=>Gash
 use MOD_irrigation,only:gird,isua
 use plant_interface
 use variables,only:t
 implicit none
 type(gash_source_window_input_t)::x
 type(gash_source_window_result_t)::r
 real(8)::rain(3)=[0d0,.1d0,2d0],irrig(3)=[0d0,.2d0,.4d0],times(3)=[-1d0,5d0,11d0]
 real(8)::err,maxerr
 integer::i,j,k,flag,status,bad,total,expected
 character(8)::arg
 call get_command_argument(1,arg);read(arg,*)expected
 pfreetb=[0d0,.2d0,10d0,.4d0];pstemtb=[0d0,.1d0,10d0,.1d0]
 scanopytb=[0d0,.14d0,10d0,.21d0];avevaptb=[0d0,.2d0,10d0,.4d0]
 avprectb=[0d0,2d0,10d0,4d0]
 call table(x%free_throughfall,pfreetb);call table(x%stemflow,pstemtb)
 call table(x%canopy_storage_cm,scanopytb);call table(x%average_precipitation,avprectb)
 call table(x%average_evaporation,avevaptb)
 bad=0;total=0;maxerr=0d0
 do k=1,3
 do i=1,3
 do j=1,3
 do flag=0,1
  grai=rain(i);gird=irrig(j);t=times(k);isua=flag
  x%source_time=t;x%gross_rain_cm=grai;x%surface_irrigation_cm=gird
  x%surface_irrigation_is_intercepted=flag==0
  call original_gash()
  call evaluate_gash_source_window(x,r,status)
  if(status/=GASH_OK)error stop 'current valid Gash rejected'
  err=abs(aintc-r%interception_cm);maxerr=max(maxerr,err);total=total+1
  if(err>1d-14)bad=bad+1
 end do
 end do
 end do
 end do
 print '(A,I0,A,I0,A,ES25.16)','ORIGINAL_GASH_CASES=',total,':MISMATCHES=',bad,':MAX_ABS_CM=',maxerr
 if(expected==0.and.bad/=0)error stop 'original Gash disagreement'
 if(expected==1.and.bad==0)error stop 'missing preimage irrigation branch counterexample'
 print '(A)','LITERAL_GASH_SOURCE_BRANCH_CONTROL=PASS'
contains
 subroutine table(t,a)
 type(gash_table_t),intent(out)::t
 real(8),intent(in)::a(4)
 allocate(t%time(2),t%value(2));t%time=a([1,3]);t%value=a([2,4])
 end subroutine
end program
'''
(OUT/'authority.f90').write_text(driver)
preimage=subprocess.check_output(['git','show','5ce0f1115a5ea89be54aacaae02ed61ab2ca2696:src/process/mod_gash_interception_process.f90'],cwd=ROOT)
(OUT/'preimage.f90').write_bytes(preimage)
def run(command,cwd,category):
 command=list(map(str,command));start=time.perf_counter();p=subprocess.run(command,cwd=cwd,capture_output=True)
 e=dict(command=command,category=category,seconds=time.perf_counter()-start,returncode=p.returncode)
 for stream in ['stdout','stderr']:
  n=f'{len(events):04d}.{stream}';data=getattr(p,stream);(OUT/n).write_bytes(data);e[stream]=n;e[stream+'_sha256']=sha(data)
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
current=ROOT/'src/process/mod_gash_interception_process.f90'
inputs={str(current.relative_to(ROOT)):sha(current.read_bytes()),str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())}
gates=[('tests/fpm/test_f_mig431_int12_d_gash.f90',[current]),('tests/fvq/test_fvq_int12d_gash_independent.f90',[current]),('tests/fpm/test_f_mig431_int12_d_p0.f90',[current,ROOT/'src/runtime/mod_interception_source_window_runtime.f90',ROOT/'src/runtime/mod_gash_source_window_binding.f90']),('tests/fpm/test_f_mig431_int12_d_daily.f90',[ROOT/'src/process/mod_gash_daily_application.f90'])]
for opt in ['O0','O2']:
 results[opt]={}
 for version,source in [('current',current),('preimage',OUT/'preimage.f90')]:
  b=OUT/(opt+'-'+version);b.mkdir()
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
  exe=b/'authority';run(FC+flags+[source,OUT/'literal.f90',OUT/'authority.f90','-o',exe],b,'compile_link')
  results[opt][version]=run([exe,int(version=='preimage')],b,'native')
 b=OUT/(opt+'-gates');b.mkdir();flags=['-'+opt,'-std=f2008','-pedantic-errors','-ffree-line-length-none','-Wall','-Wextra','-Werror','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 for index,(test,sources)in enumerate(gates):
  for p in [*sources,ROOT/test]:inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
  exe=b/str(index);run(FC+flags+[*sources,ROOT/test,'-o',exe],b,'owner_compile_link');results[opt][test]=run([exe],b,'owner_native')
assert results['O0']==results['O2']
result=dict(status='ORIGINAL_GASH_54_CASES_AND_OWNERS_O0_O2_PASS',results=results,input_sha256=inputs,archive_sha256=sha(raw),original_source_sha256={n:sha(b)for n,b in originals.items()},literal_sha256=sha(literal.encode()),driver_sha256=sha(driver.encode()),preimage_sha256=sha(preimage),cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['compile_link','native','owner_compile_link','owner_native']})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
