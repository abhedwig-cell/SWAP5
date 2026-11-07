"""Execute unchanged Reference census/sweeps with the missing current provider.

Build repair qualification is not numerical or production admission.
"""
import argparse,hashlib,json,os,re,shlex,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='af758371e796978f542a7f091419ff4089dfe618'
SCRIPTS={name:'tests/publication/run_pub_p2e04_reference_'+name+'.sh'for name in('failure_census','bc_sweeps')}
PROVIDER='src/process/mod_drainage_dramet3_response.f90'
ANCHOR='  src/runtime/mod_fmr_drainage_response_binding.f90\n'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def raw(ref,path):return subprocess.check_output(['git','show',ref+':'+path],cwd=ROOT)
def normalized(b):return b.replace(b'\r\n',b'\n')
def postimage(path):
 b=raw(BASE,path);assert b.count(ANCHOR.encode())==1 and PROVIDER.encode()not in b
 return b.replace(ANCHOR.encode(),('  '+PROVIDER+'\n'+ANCHOR).encode())
def guard():
 for area in('src','app','reference'):
  assert git('rev-parse','HEAD:'+area)==git('rev-parse',BASE+':'+area)
  assert not git('diff','HEAD','--',area)and not git('ls-files','--others','--exclude-standard','--',area)
 for path in SCRIPTS.values():assert normalized((ROOT/path).read_bytes())==raw('HEAD',path)==postimage(path)
 return {a:git('rev-parse','HEAD:'+a)for a in('src','app','reference')}
def recipe(case):
 path=SCRIPTS[case];text=postimage(path).decode();sources=re.findall(r'^\s*(\S+\.f90)\s*$',re.search(r'MODULE_SRC=\((.*?)\n\)',text,re.S).group(1),re.M)
 assert len(sources)==47 and sources.count(PROVIDER)==1 and sources.index(PROVIDER)+1==sources.index('src/runtime/mod_fmr_drainage_response_binding.f90')
 flags=shlex.split(re.search(r'^COMMON=\((.*?)\)$',text,re.M).group(1));test=re.search(r'^TEST=(\S+)',text,re.M).group(1)
 assert normalized((ROOT/test).read_bytes())==raw(BASE,test)==raw('HEAD',test)
 assert normalized((ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90').read_bytes())==raw(BASE,'tests/fsi/fsi04_real_headcalc_stubs.f90')
 assert not any('/mod_rossfast_d3r_'+name+'.f90'in source for source in sources for name in('table_kernel','table_provider','soil_water_solver'))
 return sources,flags,test
def validate_output(case,b):
 text=b.decode();markers=['PUB_P2E04_ROSSFAST_SOLVER_EXECUTED=FALSE']
 if case=='failure_census':markers+=['PUB_P2E04_CASE_COUNT=162','PUB_P2E04_FAILURE_CENSUS=PASS']
 else:
  markers+=['PUB_P2E04_PRODUCTION_TOLERANCE_CHANGED=FALSE','PUB_P2E04_ROSSFAST_THRESHOLD_FROZEN=FALSE','PUB_P2E04_STAGE_BC_SWEEPS=PASS']
  for prefix,count in [('PUB_P2E04_TARGET_BEGIN=',5),('PUB_P2E04_STAGE_B|',20),('PUB_P2E04_STAGE_C|',35)]:assert sum(line.startswith(prefix)for line in text.splitlines())==count
 assert all(m in text for m in markers)
def execute(out,compiler):
 trees=guard();out.mkdir(parents=True,exist_ok=False);events=[];results={};start=time.monotonic()
 def run(command,label):
  command=list(map(str,command));cp=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=300);stem=str(len(events)).zfill(4)
  for stream in('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=label,command=command,returncode=cp.returncode,stdout=stem+'.stdout',stderr=stem+'.stderr'))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');return cp
 for case in SCRIPTS:
  sources,flags,test=recipe(case);rows={}
  for opt in('O0','O2'):
   build=out/(case+'-'+opt);build.mkdir();objects=[];compiled=[]
   for source in sources:
    obj=build/(Path(source).stem+'.o');extra=['-Wno-error=unused-dummy-argument']if source=='src/solver/mod_soil_water_solver_contract.f90'else[]
    cp=run([compiler,*flags,*extra,'-'+opt,'-J',build,'-I',build,'-c',ROOT/source,'-o',obj],'provider')
    assert cp.returncode==0,cp.stderr[-4000:];objects.append(obj);compiled.append(dict(source=source,sha256=sha((ROOT/source).read_bytes()),object=obj.relative_to(out).as_posix(),object_sha256=sha(obj.read_bytes())))
   obj=build/'test.o';cp=run([compiler,*flags,'-'+opt,'-J',build,'-I',build,'-c',ROOT/test,'-o',obj],'driver');assert cp.returncode==0,cp.stderr[-4000:]
   exe=build/('test.exe'if os.name=='nt'else'test');cp=run([compiler,'-fopenmp','-'+opt,*objects,obj,'-o',exe],'link');assert cp.returncode==0,cp.stderr[-4000:]
   cp=run([exe],'original-test');valid=False
   marker_failure=None
   if cp.returncode==0:
    try:validate_output(case,cp.stdout);valid=True
    except AssertionError as error:marker_failure=str(error)or'Original marker/count criterion failed'
   rows[opt]=dict(provider_count=len(compiled),providers=compiled,driver=test,driver_sha256=sha((ROOT/test).read_bytes()),executable=exe.relative_to(out).as_posix(),executable_sha256=sha(exe.read_bytes()),returncode=cp.returncode,markers_pass=valid,stdout_sha256=sha(cp.stdout),stdout=events[-1]['stdout'])
  results[case]=dict(optimizations=rows,outputs_equal=rows['O0']['stdout_sha256']==rows['O2']['stdout_sha256'])
 status='BUILD_REPAIRED_ORIGINAL_GATES_PASS'if all(case['outputs_equal']and all(x['markers_pass']for x in case['optimizations'].values())for case in results.values())else'BUILD_REPAIRED_ORIGINAL_NUMERICAL_FAILURE_RETAINED'
 assert trees==guard();result=dict(status=status,baseline=BASE,head=git('rev-parse','HEAD'),production_trees=trees,platform='WINDOWS'if os.name=='nt'else'POSIX',compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],seconds=time.monotonic()-start,script_sha256={p:sha(raw('HEAD',p))for p in SCRIPTS.values()},results=results,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(status,flush=True)
 if status!='BUILD_REPAIRED_ORIGINAL_GATES_PASS':raise SystemExit(1)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',default=shutil.which('gfortran'));a=p.parse_args();os.environ['OMP_NUM_THREADS']='1';execute(a.output.resolve(),str(Path(a.compiler).resolve()))
