"""Fresh original TTUTIL and real native reader fractional-clock comparison."""
from pathlib import Path
import argparse,ast,base64,datetime,hashlib,io,json,os,re,shlex,subprocess,time,zipfile
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
OUT=ap.parse_args().output.resolve();OUT.mkdir(exist_ok=False)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={}
sha=lambda b:hashlib.sha256(b).hexdigest()
def run(c,cwd,category,success=True):
 c=list(map(str,c));exe=Path(c[0])
 if exe.is_file()and exe.is_relative_to(OUT)and exe.read_bytes()[:4]==b'\x7fELF':exe.chmod(0o755)
 t=time.perf_counter();r=subprocess.run(c,cwd=cwd,capture_output=True)
 e=dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-t)
 for key in ['stdout','stderr']:
  name=f'{len(events):04d}.{key}';raw=getattr(r,key);(OUT/name).write_bytes(raw);e[key]=name;e[key+'_sha256']=sha(raw)
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if success and r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r
raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
assert sha(raw)=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
zipfile.ZipFile(io.BytesIO(raw)).extractall(OUT/'tt');tt=OUT/'tt/TTUTIL'
recipe=ROOT/'tests/nut-input/run_native_snm.py';tree=ast.parse(recipe.read_text());ns={}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id in ['array','params']for t in n.targets)],type_ignores=[]),str(recipe),'exec'),ns)
base=ns['array']+ns['params']+'RateconHum_exp = .1\ntstartHumexp = '
valid=['1901-01-01','01-JAN-1901','1901-01-01_00:00','01-Jan-1901_12:00','1901-01-01_01:30',
 '1901-01-01_23:59:59','1901-01-01_23:59:59.25','1901-01-01_12:34:56.123456789','2000-02-29_12:00',
 '1901-01-01_24:00','1901-01-01_99:59:59','1901-01-01_12:00:00.']
invalid=['1901-01-01_12:60','1901-01-01_12:00:60','1901-01-01_12',
 '1901-01-01_12:00:-1','1901-01-01__12:00','1901-01-01_aa:bb',
 '1901-01-01_12:00:00.2x','1900-02-29_12:00','1901-01-01.5']
for i,s in enumerate(valid+invalid):(OUT/f'{i}.snm').write_text(base+s+'\n')
oracle='''program oracle
 implicit none
 character(512)::path
 real(8)::clock
 call get_command_argument(1,path)
 call rdinit(20,0,trim(path))
 call rdstim('tstartHumexp',clock)
 print '(A,ES26.17)','CLOCK=',clock-1d0
 close(20)
end program
'''
modules={}
for p in (ROOT/'src').rglob('*.f90'):
 for m in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.I|re.M):modules[m.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.I|re.M):
  if m.lower()in modules:visit(modules[m.lower()])
 ordered.append(p)
visit(ROOT/'tests/nut-input/test_humus_timestamp.f90')
results={}
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();(b/'oracle.f90').write_text(oracle);objects=[]
 flags=['-'+opt,'-ffree-line-length-none','-ffixed-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 sources=[tt/'ttutilprefs.f90',tt/'ttutil.f90']+sorted(p for p in tt.glob('*.f90')if p.name not in ['ttutilprefs.f90','ttutil.f90'])+sorted(tt.glob('*.for'))
 for i,p in enumerate(sources):
  obj=b/f'tt-{i}.o';run([*FC,*flags,'-std=legacy','-fallow-argument-mismatch','-I'+str(tt),'-c',p,'-o',obj],b,'original_compile');objects.append(obj)
 old=b/'oracle';run([*FC,*flags,b/'oracle.f90',*objects,'-o',old],b,'original_link');objects=[]
 for i,p in enumerate(ordered):
  obj=b/f'native-{i}.o';run([*FC,*flags,'-std=f2008','-c',p,'-o',obj],b,'production_compile');objects.append(obj)
  inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
 exe=b/'native';run([*FC,*flags,*objects,'-o',exe],b,'production_link');results[opt]={}
 for i,s in enumerate(valid+invalid):
  path=OUT/f'{i}.snm';r=run([old,path],b,'original_native',False)
  if i<len(valid):
   assert r.returncode==0 and b'CLOCK='in r.stdout,(s,r.stdout,r.stderr)
   clock=float(r.stdout.decode().split('CLOCK=')[1].split()[0]);p=run([exe,path,str(clock)],b,'production_native')
   actual=float(p.stdout.decode().split('CLOCK=')[1].split()[0]);assert abs(actual-clock)<=4*__import__('math').ulp(max(1.,clock))
   results[opt][s]=dict(original=clock,current=actual)
  else:
   # Some original syntax-error paths terminate through STOP without nonzero exit.
   assert r.returncode!=0 or b'CLOCK='not in r.stdout,(s,r.stdout)
   p=run([exe,path,'-1'],b,'production_negative');assert b'TIMESTAMP_ATOMIC_INVALID=PASS'in p.stdout
   results[opt][s]='BOTH_REJECTED'
assert results['O0']==results['O2']
inputs[str(recipe.relative_to(ROOT))]=sha(recipe.read_bytes());inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes())
r=dict(status='ORIGINAL_TTUTIL_AND_NATIVE_HUMUS_TIMESTAMP_O0_O2_PASS',results=results,valid=len(valid),invalid=len(invalid),input_sha256=inputs,original_zip_sha256=sha(raw),cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
