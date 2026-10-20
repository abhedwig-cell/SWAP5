"""Native CHARACTER successor on fresh current reader builds and original TTUTIL.

Run unchanged tests/nut-input/run_native_snm.py first in N_NATIVE_RESULT_DIR.
This supplement reuses only that live, hash-verified O0/O2 compiled closure;
every new native test executes. No cross-session cache or physical PASS reuse.
"""
from pathlib import Path
import base64, hashlib, io, json, os, shlex, subprocess, tarfile, time, zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ['N_CHARACTER_RESULT_DIR']).resolve()
OUT.mkdir(exist_ok=False)
NATIVE = Path(os.environ['N_NATIVE_RESULT_DIR']).resolve()
FC = shlex.split(os.environ.get('FC', 'gfortran'))
sha = lambda b: hashlib.sha256(b).hexdigest()
native = json.loads((NATIVE/'result.json').read_text())
assert native['status'] == 'PASS'
for q,h in native['input_sha256'].items():
    assert sha((ROOT/q).read_bytes()) == h
build_events = json.loads((NATIVE/'events.json').read_text())
assert all(e['returncode'] == 0 for e in build_events)
def artifacts():
    return {str(p.relative_to(NATIVE)):sha(p.read_bytes())
            for opt in ['O0','O2'] for p in (NATIVE/opt).iterdir()
            if p.is_file() and (p.suffix in ['.o','.mod'] or p.name=='test')}
before = artifacts()
assert before and all(opt+'/test' in before for opt in ['O0','O2'])
base = (NATIVE/'arrays.snm').read_text()
old = "1*'Mineral ! fertiliser'"
fixtures = {}
def add(name, label=old, extra='', expected=0):
    fixtures[name] = (base.replace(old,label)+extra, expected)
add('concat', "1*'Mineral'//' ! fertiliser'")
add('concat_space', "1*'Mine' // 'ral' // ' ! fertiliser'", 'flCropExt = .FALSE.\n')
add('concat_empty', "1*''//'Mineral ! fertiliser'//''", expected=-1)
add('concat_tab', "1*'Mineral'\t//\t' ! fertiliser' ! comment", expected=-1)
add('false_lower', extra='flCropExt = .false.\n')
add('false_mixed', extra='flCropExt = .FaLsE. ! disabled\n')
add('concat_no_rhs', "1*'Mineral' //", expected=-1)
add('concat_numeric_rhs', "1*'Mineral' // 2", expected=-1)
add('concat_unterminated', "1*'Mineral' //' ! fertiliser", expected=-1)
add('concat_missing_operator', "1*'Mineral' ' ! fertiliser'", expected=-1)
add('concat_overlong', "1*'Mineral'//'1234567890123456789'", expected=-1)
add('true_output', extra='flCropExt = .true.\n', expected=-1)
add('short_false', extra='flCropExt = .f.\n', expected=-1)
add('numeric_false', extra='flCropExt = 0\n', expected=-1)
add('bare_false', extra='flCropExt = false\n', expected=-1)
add('duplicate_false', extra='flCropExt = .false.\nflCropExt = .false.\n', expected=-1)
add('escaped_quote', "1*'Mineral''s fertiliser'", expected=-1)
fixtures['repeat_concat'] = (base.replace('MatNum = 1*1','MatNum = 1 2')
                            .replace(old,"2*'Mineral'//' ! fertiliser'")
                            .replace(' = 1*',' = 2*'), 0)
for name,(text,expected) in fixtures.items():
    (OUT/(name+'.snm')).write_text(text)
events = []
def run(command, cwd, category, success=True):
    command = list(map(str,command)); start = time.perf_counter()
    p = subprocess.run(command,cwd=cwd,capture_output=True,input=b'')
    row = dict(command=command,category=category,seconds=time.perf_counter()-start,returncode=p.returncode)
    for stream in ['stdout','stderr']:
        filename = f'{len(events):04d}.{stream}'; data = getattr(p,stream)
        (OUT/filename).write_bytes(data); row[stream]=filename; row[stream+'_sha256']=sha(data)
    events.append(row); (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
    if success:
        assert p.returncode == 0, p.stdout.decode()+p.stderr.decode()
    return p.returncode,p.stdout.decode()

outputs = {}
for opt in ['O0','O2']:
    exe = NATIVE/opt/'test'
    assert any(e['category']=='link' and e['command'][-1]==str(exe) for e in build_events)
    outputs[opt] = {}
    for name,(text,expected) in fixtures.items():
        code,out = run([exe,OUT/(name+'.snm'),expected],OUT,'native')
        outputs[opt][name] = out
assert outputs['O0'] == outputs['O2']

raw = base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
assert sha(raw) == 'ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
zipfile.ZipFile(io.BytesIO(raw)).extractall(OUT/'original')
source = OUT/'original/TTUTIL'
sources = [source/'ttutilprefs.f90',source/'ttutil.f90']+sorted(p for p in source.glob('*.f90') if p.name not in ['ttutilprefs.f90','ttutil.f90'])+sorted(source.glob('*.for'))
soil_archive=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
assert sha(soil_archive)=='18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c'
with tarfile.open(fileobj=io.BytesIO(soil_archive)) as tar:
    management=tar.extractfile('SWAP/management_soil.f90').read()
(OUT/'management_soil.original.f90').write_bytes(management)
text=management.decode();start=text.index('      if (abs(TimeAmend(isme) +1.0d0 - t1900) < 1.d-3) then')
end=text.index('      end if',start)+len('      end if')
gate=text[start:end]
original_driver = '''module original_clock_counter
 integer::count=0
end module
program original
 use original_clock_counter
 implicit none
 character(512)::path,mode
 character(80)::names(20)
 integer::n,isme,day
 logical::flag,rdinqr
 real(8)::clock,TimeAmend(2)
 call get_command_argument(1,path);call get_command_argument(2,mode)
 call rdinit(20,0,trim(path))
 n=1
 if(trim(mode)=='repeat')n=2
 call rdfcha('MatName',names,20,n)
 if(trim(mode)=='name'.or.trim(mode)=='repeat')then
   if(any(names(:n)/='Mineral ! fertiliser'))error stop 'original concatenation'
 end if
 flag=.false.
 if(rdinqr('flCropExt'))call rdslog('flCropExt',flag)
 if(trim(mode)=='false'.and.flag)error stop 'original false'
 if(trim(mode)=='true'.and..not.flag)error stop 'original true'
 if(trim(mode)=='clock')then
   call rdstim('clock',clock)
   if(clock/=366.5d0)error stop 'original fractional clock'
   TimeAmend=[clock,367d0];isme=1;count=0
   do day=367,370
     call literal_daily_gate(TimeAmend,isme,real(day,8))
   end do
   if(isme/=1.or.count/=0)error stop 'original fractional queue stall'
   print '(A)','ORIGINAL_DAILY_FRACTIONAL_EVENT_BLOCKS_QUEUE=PASS'
   TimeAmend=[366d0,367d0];isme=1;count=0
   do day=367,368
     call literal_daily_gate(TimeAmend,isme,real(day,8))
   end do
   if(isme/=3.or.count/=2)error stop 'original daily positive control'
   print '(A)','ORIGINAL_DAILY_INTEGER_EVENT_POSITIVE_CONTROL=PASS'
 end if
 print '(A,A,A,A,A,L1)','ORIGINAL_CHARACTER=',trim(mode),':',trim(names(1)),':FLAG=',flag
 close(20)
end program
subroutine literal_daily_gate(TimeAmend,isme,t1900)
 implicit none
 real(8),intent(in)::TimeAmend(2),t1900
 integer,intent(inout)::isme
'''+gate+'''
end subroutine
subroutine Wofost_SoilAmendents
 use original_clock_counter
 count=count+1
end subroutine
'''
original_results = {}
for opt in ['O0','O2']:
    b = OUT/opt; b.mkdir(); objects=[]
    (b/'original.f90').write_text(original_driver)
    for i,p in enumerate(sources):
        obj=b/f'{i}.o'; objects.append(obj)
        run(FC+['-'+opt,'-std=legacy','-fallow-argument-mismatch','-ffixed-line-length-none','-ffree-line-length-none','-I'+str(source),'-I'+str(b),'-J'+str(b),'-c',p,'-o',obj],b,'original_compile')
    exe=b/'original'
    run(FC+['-'+opt,b/'original.f90',*objects,'-o',exe],b,'original_link')
    original_results[opt]={}
    for name in ['concat','concat_space','concat_empty','concat_tab','false_lower','false_mixed','true_output','short_false','numeric_false','bare_false','escaped_quote','repeat_concat']:
        mode='repeat' if name=='repeat_concat' else ('name' if name.startswith('concat') else ('true' if name=='true_output' else 'false'))
        valid=name not in ['concat_empty','concat_tab','short_false','numeric_false','bare_false','escaped_quote']
        code,out=run([exe,OUT/(name+'.snm'),mode],b,'original_native',valid)
        assert (code==0)==valid
        original_results[opt][name]=out if valid else 'REJECTED_ORIGINAL_SYNTAX_TYPE'
    clock=OUT/'clock.snm'
    clock.write_text(base+'clock = 1901-01-01_12:00:00\n')
    _,out=run([exe,clock,'clock'],b,'original_native');original_results[opt]['clock']=out
assert original_results['O0']==original_results['O2']
assert artifacts()==before, 'live native object/module/executable drift'

result=dict(status='NATIVE_CHARACTER_O0_O2_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={**native['input_sha256'],str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())},fixtures={n:dict(sha256=sha((OUT/(n+'.snm')).read_bytes()),expected=e)for n,(_,e)in fixtures.items()},outputs=outputs,original_results=original_results,original_source_sha256={p.name:sha(p.read_bytes())for p in source.iterdir()if p.is_file()},original_zip_sha256=sha(raw),original_driver_sha256=sha(original_driver.encode()),live_reuse={'native_result_sha256':sha((NATIVE/'result.json').read_bytes()),'native_events_sha256':sha((NATIVE/'events.json').read_bytes()),'artifacts_before_after':before,'executables':{opt:sha((NATIVE/opt/'test').read_bytes())for opt in ['O0','O2']}},cost_seconds={cat:sum(e['seconds']for e in events if e['category']==cat)for cat in ['native','original_compile','original_link','original_native']})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(result['status'])
