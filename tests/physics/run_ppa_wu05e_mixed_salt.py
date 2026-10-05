#!/usr/bin/env python3
"""Actual typed application and backend replay, not a stubbed runtime seam."""
import hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get('FC','gfortran'))
LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
TESTS=['tests/physics/test_fmr_base_salt_temporal_policy.f90','tests/physics/test_ppa_wu05e_mixed_salt.f90']
FIXTURE=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90'
modules={}
for p in list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
def visit(p):
 if p in seen:return
 if p in visiting:raise RuntimeError('module cycle: '+str(p))
 visiting.add(p)
 for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
  q=modules.get(n.lower())
  if q and q!=p:visit(q)
  elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):
   raise RuntimeError('unresolved module: '+n)
 visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
for test in TESTS:visit(ROOT/test)
sources=[p for p in ordered if str(p.relative_to(ROOT)) not in TESTS]
result={'work_unit':'PPA-WU05-E','compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
 'tested_postimage':os.environ.get('C3A_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),
 'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},'runs':{}}
result['source_sha256'][str(FIXTURE.relative_to(ROOT))]=hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
if os.environ.get('C3A_LIST_SOURCES'):
 print('\n'.join(str(p.relative_to(ROOT)) for p in ordered));raise SystemExit()
with tempfile.TemporaryDirectory(prefix='c3a-application-') as folder:
 for opt in os.environ.get('C3A_OPTS','O0 O2').split():
  build=pathlib.Path(folder)/opt;build.mkdir()
  fixture=FIXTURE.read_text()
  (build/'wu05e_mixed_fixture.inc').write_text(fixture[fixture.index('  subroutine add_root_thermal_oxygen'):fixture.rindex('end program')])
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
   '-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
  objects=[]
  for p in sources:
   obj=build/(p.stem+'.o');objects.append(str(obj))
   strict=['-Wall','-Wextra','-Werror'] if '/physics/oxygen/' in str(p) or p.name in (
    'mod_crop_bartholomeus_input.f90','mod_fmr_bartholomeus_contract.f90') else []
   subprocess.run(FC+flags+strict+['-c',str(p),'-o',str(obj)],check=True,stdout=subprocess.DEVNULL)
  result['runs'][opt]={}
  for test in TESTS:
   p=ROOT/test;obj=build/(p.stem+'.o');exe=build/p.stem
   subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,stdout=subprocess.DEVNULL)
   subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,stdout=subprocess.DEVNULL)
   arguments=[] if 'temporal_policy' in test else ['write',str(build/'restart.bin'),str(build/'expected.bin')]
   completed=subprocess.run([str(exe)]+arguments,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
   output=completed.stdout
   print(output,flush=True)
   completed.check_returncode()
   marker='PPA_WU05E_BASE_SALT_METRIC=PASS_TEST_ONLY' if 'temporal_policy' in test else 'PPA_WU05E_MATRIX_MIXED_STRESS_LIFECYCLE=PASS_TEST_ONLY'
   if marker not in output:raise RuntimeError('missing gate marker: '+marker)
   result['runs'][opt][test]=output.splitlines()
   if 'mixed_salt' in test:
    fresh=subprocess.run([str(exe),'resume',str(build/'restart.bin'),str(build/'resumed.bin')],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    print(fresh.stdout,flush=True);fresh.check_returncode()
    if 'PPA_WU05E_FRESH_PROCESS_RESTART=PASS_TEST_ONLY' not in fresh.stdout:raise RuntimeError('fresh process marker missing')
    if (build/'expected.bin').read_bytes()!=(build/'resumed.bin').read_bytes():raise RuntimeError('separate process physical state differs')
    result['runs'][opt]['fresh_process']=fresh.stdout.splitlines()
    result['runs'][opt]['fresh_process_physical_sha256']=hashlib.sha256((build/'resumed.bin').read_bytes()).hexdigest()
    print('PPA_WU05E_FRESH_PROCESS_PHYSICAL_BYTES=IDENTICAL',flush=True)
if 'O0' in result['runs'] and 'O2' in result['runs']:
 if result['runs']['O0']['fresh_process_physical_sha256']!=result['runs']['O2']['fresh_process_physical_sha256']:
  raise RuntimeError('O0/O2 physical state differs')
 result['o0_o2_physical_bytes']='IDENTICAL'
result['status']='LOCAL_MATRIX_SALT_MIXED_GATES_PASS_NOT_ADMITTED'
pathlib.Path(os.environ.get('C3A_RESULT','wu05e_mixed_salt_result.json')).write_text(json.dumps(result,indent=2)+'\n')
print('PPA_WU05E_MATRIX_LOCAL_GATE=PASS_TEST_ONLY')
