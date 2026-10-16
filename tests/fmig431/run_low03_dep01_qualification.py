#!/usr/bin/env python3
"""Explicit LOW03 DEP01 semantic successor; historical guards are untouched."""
import base64,gzip,hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
BASE=json.loads((ROOT/'tests/fmig431/low03_dep01_baseline_source.json').read_text())
MANIFEST=json.loads((ROOT/'tests/fmig431/low03_dep01_input_git_blobs.json').read_text())
TESTS=['tests/ross/test_ross13_36_material_production_envelope.f90','tests/ross/test_fross22_admission_all_material.f90','tests/ross/test_ross12_soil_water_solver_adapter.f90','tests/ross/test_ross12_solver_selection_binding.f90','tests/ross/test_ross12_serialized_production_wiring.f90','tests/publication/test_pub_p2e01_solver_seam_paired_pilot.f90','tests/fmig431/test_low03_dep01_defaults.f90']
REQUIRED=['F_ROSS13_36_MATERIAL_PRODUCTION_ENVELOPE PASS','F_ROSS21_MATRIX_GATE=PASS','ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS','ROSS12_SOLVER_SELECTION_BINDING PASS','ROSS12_SERIALIZED_PRODUCTION_WIRING PASS','PUB_P2E01_SOLVER_SEAM_PAIRED_EXTRACTION_READY=PASS','LOW03_DEP01_ROSSFAST_DEFAULTS_FAIL_CLOSED_REPLAY=PASS']
def blob(b):return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
for p,b in MANIFEST['git_blobs'].items():
 if blob((ROOT/p).read_bytes())!=b:raise RuntimeError('input postimage drift: '+p)
for p,m in BASE['files'].items():
 raw=gzip.decompress(base64.b64decode(m['gzip_base64']))
 if blob(raw)!=m['git_blob'] or hashlib.sha256(raw).hexdigest()!=m['sha256']:raise RuntimeError('baseline carrier corrupt: '+p)
FC=shlex.split(os.environ.get('FC','gfortran'));LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
modules={}
for p in list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']+[ROOT/t for t in TESTS]:
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
def visit(p):
 if p in seen:return
 if p in visiting:raise RuntimeError('cycle: '+str(p))
 visiting.add(p)
 for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
  q=modules.get(n.lower())
  if q and q!=p:visit(q)
  elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):raise RuntimeError('unresolved: '+n)
 visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
for t in TESTS:visit(ROOT/t)
testpaths={ROOT/t for t in TESTS};sources=[p for p in ordered if p not in testpaths]
result={'work_unit':'F-MIG431-LOW03-P0-DEP01','scope':'current canonical versus LOW03 shared-contract semantic preservation, not mode3 application or performance admission','tested_postimage':os.environ.get('LOW03_DEP01_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),'baseline':BASE['canonical_baseline'],'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'input_git_blobs':MANIFEST['git_blobs'],'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},'runner_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'runs':{},'canonical_admission':False}
env=dict(os.environ,SWAP5_ROSSFAST_EXPECT_TIERED_WORK='1')
with tempfile.TemporaryDirectory(prefix='low03-dep01-') as folder:
 for variant in ('baseline','candidate'):
  result['runs'][variant]={}
  for opt in ('O0','O2'):
   build=pathlib.Path(folder)/variant/opt;build.mkdir(parents=True)
   flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
   objects=[]
   for p in sources:
    rel=str(p.relative_to(ROOT));actual=p
    if variant=='baseline' and rel in BASE['files']:
     actual=build/p.name;actual.write_bytes(gzip.decompress(base64.b64decode(BASE['files'][rel]['gzip_base64'])))
    obj=build/(p.stem+'.o');objects.append(str(obj))
    subprocess.run(FC+flags+['-c',str(actual),'-o',str(obj)],check=True,capture_output=True,text=True)
   result['runs'][variant][opt]={}
   for idx,t in enumerate(TESTS):
    if variant=='baseline' and idx==6:continue
    p=ROOT/t;obj=build/(p.stem+'.o');exe=build/p.stem
    subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,capture_output=True,text=True)
    subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,capture_output=True,text=True)
    try:out=subprocess.check_output([str(exe),'assets/rossfast/d3r'],cwd=ROOT,env=env,text=True,stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
     print(e.output,flush=True);raise
    if REQUIRED[idx] not in out:raise RuntimeError('missing marker '+t)
    record={'stdout':out,'stdout_sha256':hashlib.sha256(out.encode()).hexdigest()}
    if idx==1:
     raw=build/'matrix.txt';raw.write_text(out);summary=build/'matrix.json'
     subprocess.run(['python3',str(ROOT/'tools/performance/f_ross22_admission_all_material_summary.py'),'--input',str(raw),'--output',str(summary)],check=True,capture_output=True,text=True)
     record['matrix_summary']=json.loads(summary.read_text())
    result['runs'][variant][opt][t]=record
    print(variant+' '+opt+' '+t+' PASS',flush=True)
 for t in TESTS[:6]:
  ref=result['runs']['baseline']['O0'][t]['stdout']
  for variant in ('baseline','candidate'):
   for opt in ('O0','O2'):
    if result['runs'][variant][opt][t]['stdout']!=ref:raise RuntimeError('semantic output differs '+variant+' '+opt+' '+t)
 if result['runs']['candidate']['O0'][TESTS[6]]['stdout']!=result['runs']['candidate']['O2'][TESTS[6]]['stdout']:raise RuntimeError('new fail-closed test optimization drift')
result['status']='SEMANTIC_SUCCESSOR_LOCAL_PASS';result['baseline_candidate_o0_o2_complete_output_identity']=True
pathlib.Path(os.environ.get('LOW03_DEP01_RESULT','low03_dep01_result.json')).write_text(json.dumps(result,indent=2)+'\n')
print('LOW03_DEP01_SHARED_SEMANTIC_PRESERVATION=PASS')
