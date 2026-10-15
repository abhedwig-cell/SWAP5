#!/usr/bin/env python3
"""Tiny actual constructor/selector plus unchanged original management blocks."""
from pathlib import Path
import base64,hashlib,io,json,os,shlex,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['CALENDAR_RESULT_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));sha=lambda b:hashlib.sha256(b).hexdigest();events=[]
def run(args,cwd,category,expected=0):
 args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
 e=dict(command=args,category=category,returncode=p.returncode,expected_returncode=expected,seconds=time.perf_counter()-t)
 for stream in ['stdout','stderr']:e.update({stream+'_file':f'{i:04d}.{stream}',stream+'_sha256':sha(getattr(p,stream))})
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode!=expected:raise RuntimeError(str(e))
 return p.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as a:raw=a.extractfile('SWAP/management_soil.f90').read()
assert sha(raw)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
s=raw.decode();a=s.index('      ! check time of application');b=s.index('!     Converting kg/ha',a);sort=s[a:b]
a=s.index('      do i=1,nsme',b);b=s.index('! -   open file with soil nutrient parameters',a);conversion_group=s[a:b]
a=s.index('      if (abs(TimeAmend(isme) +1.0d0 - t1900)');b=s.index('      return',a);trigger=s[a:b]
# The original body is compiled verbatim; only its external amendment effect is replaced
# by a selection observation, independently of production calendar/chemistry.
oracle='''subroutine literal_calendar(source,amount,n,evaluation,expected,due,groups)
 use iso_fortran_env,only:real64
 implicit none
 integer,intent(in)::n
 real(real64),intent(in)::source(n),amount(n),evaluation
 real(real64),intent(out)::expected(n)
 logical,intent(out)::due(n)
 integer,intent(out)::groups
 real(real64)::smedate(n),MatAmount(n),amend(n),TimeAmend(n),t1900
 integer::i,j,isme,nsme,NuAmend(n),iAmend(n,n),observed
 character(11)::datedum
 character(200)::message
 smedate=source;MatAmount=amount;nsme=n;t1900=evaluation
'''+sort+conversion_group+''' groups=j;expected=amend;due=.false.
 do observed=1,n
  isme=observed
'''+trigger.replace('call Wofost_SoilAmendents','due(observed)=.true.')+''' end do
end subroutine
subroutine dtdpst(form,t,date)
 character(*),intent(in)::form
 real(8),intent(in)::t
 character(*),intent(out)::date
 date='literal'
end subroutine
subroutine swap_error(origin,message)
 character(*),intent(in)::origin,message
 print '(A)','LEGACY_UNSORTED_CALENDAR_REJECT=PASS'
 error stop 7
end subroutine
'''
providers=['src/process/mod_soil_n_pool_state.f90','src/process/mod_b111_soil_n_addition.f90','src/process/mod_b111_amendment_calendar.f90']
driver=ROOT/'tests/nut-calendar/test_calendar_contract.f90';inputs={p:sha((ROOT/p).read_bytes())for p in providers}
inputs[str(driver.relative_to(ROOT))]=sha(driver.read_bytes());inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes());results={}
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir();(build/'management_soil.f90').write_bytes(raw);(build/'literal_calendar.f90').write_text(oracle)
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
 objects=[]
 for i,p in enumerate([ROOT/x for x in providers]+[build/'literal_calendar.f90']):
  obj=build/f'{i}.o';run(FC+flags+['-c',p,'-o',obj],build,'compile');objects.append(obj)
 obj=build/'driver.o';exe=build/'test_calendar_contract';run(FC+flags+['-c',driver,'-o',obj],build,'driver_compile');run(FC+flags+objects+[obj,'-o',exe],build,'link')
 out=run([exe],build,'native');negative=run([exe,'legacy-unsorted'],build,'reference_reject',7)
 assert 'CALENDAR_LITERAL_TRIGGER_CASES=241'in out and 'CALENDAR_REAL_UNITS_INDEX_SORT_DOMAIN_15_INVALID_EMPTY=PASS'in out and 'LEGACY_UNSORTED_CALENDAR_REJECT=PASS'in negative
 results[opt]=dict(stdout=out,source_rejection=negative,production_providers=3)
r=dict(status='PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),input_sha256=inputs,compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],authority_sha256=sha(raw),extracted_blocks_sha256=sha((sort+conversion_group+trigger).encode()),oracle_sha256=sha(oracle.encode()),runs=results,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k]for k in ['status','cost_seconds']}))
