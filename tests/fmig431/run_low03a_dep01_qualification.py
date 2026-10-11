#!/usr/bin/env python3
"""F-MIG431-LOW03-A-DEP01 paired current-canonical preservation."""
import hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
BASELINE=ROOT/'tests/fmig431/support/low03a_dep01_baseline_serialized_context_binding.txt'
CONTEXT='src/adapter/mod_b110_serialized_context_binding.f90'
BASE_BLOB='58fa665b16851448d3901bb9a46cc23c74797d3a'
BASE_CANONICAL='3869ec27a7314375fd7919debb6abe7c6450f261'
TESTS=[
 'tests/ross/test_ross13_36_material_production_envelope.f90',
 'tests/ross/test_fross22_admission_all_material.f90',
 'tests/ross/test_ross12_soil_water_solver_adapter.f90',
 'tests/ross/test_ross12_solver_selection_binding.f90',
 'tests/ross/test_ross12_serialized_production_wiring.f90',
 'tests/publication/test_pub_p2e01_solver_seam_paired_pilot.f90',
 'tests/fmig431/test_low03_dep01_defaults.f90']
REQUIRED=[
 'F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE PASS','F_ROSS21_MATRIX_GATE=PASS',
 'ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS','ROSS12_SOLVER_SELECTION_BINDING PASS',
 'ROSS12_SERIALIZED_PRODUCTION_WIRING PASS','PUB_P2E01_SOLVER_SEAM_PAIRED_EXTRACTION_READY=PASS',
 'LOW03_DEP01_ROSSFAST_DEFAULTS_FAIL_CLOSED_REPLAY=PASS']
FOCUSED='tests/fmig431/test_low03a_dep01_serialized_context.f90'
def gitblob(data):
 return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
raw=BASELINE.read_bytes()
if gitblob(raw)!=BASE_BLOB:raise RuntimeError('current-canonical context baseline drift')
FC=shlex.split(os.environ.get('FC','gfortran')); LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
modules={}
all_files=list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']+[ROOT/t for t in TESTS]+[ROOT/FOCUSED]
for p in all_files:
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
def visit(p):
 if p in seen:return
 if p in visiting:raise RuntimeError('module cycle '+str(p))
 visiting.add(p)
 for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
  q=modules.get(n.lower())
  if q and q!=p:visit(q)
  elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):
   raise RuntimeError('unresolved module '+n+' from '+str(p))
 visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
for t in TESTS+[FOCUSED]:visit(ROOT/t)
programs={ROOT/t for t in TESTS+[FOCUSED]}
sources=[p for p in ordered if p not in programs]
result={
 'work_unit':'F-MIG431-LOW03-A-DEP01','baseline':BASE_CANONICAL,
 'scope':'one-line serialized Reference legacy-context mode3 carrier prerequisite; no mode3 physics/application admission',
 'tested_postimage':os.environ.get('LOW03A_DEP01_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),
 'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
 'baseline_context_git_blob':BASE_BLOB,
 'candidate_context_sha256':hashlib.sha256((ROOT/CONTEXT).read_bytes()).hexdigest(),
 'runner_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
 'runs':{},'canonical_admission':False}
env=dict(os.environ,SWAP5_ROSSFAST_EXPECT_TIERED_WORK='1')
with tempfile.TemporaryDirectory(prefix='low03a-dep01-') as folder:
 for variant in ('baseline','candidate'):
  result['runs'][variant]={}
  for opt in ('O0','O2'):
   build=pathlib.Path(folder)/variant/opt;build.mkdir(parents=True)
   flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
   objects=[]
   for p in sources:
    rel=str(p.relative_to(ROOT)); actual=p
    if variant=='baseline' and rel==CONTEXT:
     actual=build/'mod_b110_serialized_context_binding.f90';actual.write_bytes(raw)
    obj=build/(p.stem+'.o');objects.append(str(obj))
    subprocess.run(FC+flags+['-c',str(actual),'-o',str(obj)],check=True,capture_output=True,text=True)
   result['runs'][variant][opt]={}
   for idx,t in enumerate(TESTS):
    p=ROOT/t;obj=build/(p.stem+'.o');exe=build/p.stem
    subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,capture_output=True,text=True)
    subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,capture_output=True,text=True)
    try:out=subprocess.check_output([str(exe),'assets/rossfast/d3r'],cwd=ROOT,env=env,text=True,stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:print(e.output,flush=True);raise
    if REQUIRED[idx] not in out:raise RuntimeError('missing marker '+t)
    result['runs'][variant][opt][t]={'stdout_sha256':hashlib.sha256(out.encode()).hexdigest()}
    print(variant+' '+opt+' '+t+' PASS',flush=True)
   if variant=='candidate':
    p=ROOT/FOCUSED;obj=build/(p.stem+'.o');exe=build/p.stem
    subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,capture_output=True,text=True)
    subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,capture_output=True,text=True)
    try:out=subprocess.check_output([str(exe)],text=True,stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:print(e.output,flush=True);raise
    if 'LOW03A_DEP01_SERIALIZED_CONTEXT_GATE=PASS' not in out:raise RuntimeError('focused gate marker missing')
    result['runs'][variant][opt][FOCUSED]={'stdout':out,'stdout_sha256':hashlib.sha256(out.encode()).hexdigest()}
    print(variant+' '+opt+' '+FOCUSED+' PASS',flush=True)
 for t in TESTS:
  ref=result['runs']['baseline']['O0'][t]['stdout_sha256']
  for variant in ('baseline','candidate'):
   for opt in ('O0','O2'):
    if result['runs'][variant][opt][t]['stdout_sha256']!=ref:
     raise RuntimeError('shared semantic output drift '+variant+' '+opt+' '+t)
 if result['runs']['candidate']['O0'][FOCUSED]['stdout']!=result['runs']['candidate']['O2'][FOCUSED]['stdout']:
  raise RuntimeError('focused O0/O2 output drift')
result['baseline_candidate_existing_output_identity']=True
result['status']='QUALIFIED_PREREQUISITE_CANDIDATE'
pathlib.Path(os.environ.get('LOW03A_DEP01_RESULT','low03a_dep01_result.json')).write_text(json.dumps(result,indent=2)+'\n')
print('LOW03A_DEP01_PAIRED_SHARED_PRESERVATION=PASS')
