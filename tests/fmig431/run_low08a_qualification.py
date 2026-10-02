#!/usr/bin/env python3
"""Bounded O0/O2 compile and application qualification for F-MIG431-LOW08-A."""
import base64,gzip,hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
TESTS=[
 'tests/fmig431/test_low08a_application.f90',
 'tests/fmig431/test_low08_p0_typed_solver.f90',
 'tests/fmig431/test_low03a_application.f90',
 'tests/fmig431/test_low05a_application.f90',
 'tests/fmig431/test_fmig431_low01a_qgwl_binding.f90',
 'tests/fapp/test_ppa_low02_time_application_admission.f90',
 'tests/fapp/test_ppa_wu01_production_application_bootstrap.f90'
]
FC=shlex.split(os.environ.get('FC','gfortran'))
LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
modules={}
for p in list((ROOT/'src').rglob('*.f90'))+[ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90']:
    for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):
        modules[n.lower()]=p
ordered=[];seen=set();visiting=set()
def visit(p):
    if p in seen:return
    if p in visiting:raise RuntimeError('module cycle: '+str(p))
    visiting.add(p)
    for n in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',p.read_text(),re.M|re.I):
        q=modules.get(n.lower())
        if q and q!=p:visit(q)
        elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):
            raise RuntimeError('unresolved module: '+n+' from '+str(p))
    visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
for t in TESTS:visit(ROOT/t)
testpaths={ROOT/p for p in TESTS};sources=[p for p in ordered if p not in testpaths]
result={
 'work_unit':'F-MIG431-LOW08-A',
 'scope':'ordinary non-groundwater-owned SWBOTB8 lysimeter application, Reference SWKIMPL0 homogeneous bare profile',
 'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],
 'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},
 'runs':{},'tested_postimage':os.environ.get('LOW08A_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),
 'canonical_admission':False
}
result['runner_sha256']=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='low03a-') as folder:
  for opt in ('O0','O2'):
    build=pathlib.Path(folder)/opt;build.mkdir()
    flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
    carrier=json.loads((ROOT/'integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json').read_text())
  member=next(m for m in carrier['members'] if m['path']=='SWAP/functions.f90')
  raw=gzip.decompress(base64.b64decode(member['gzip_base64']))
  if hashlib.sha256(raw).hexdigest()!=member['sha256']:raise RuntimeError('frozen source hash mismatch')
  match=re.search(r'^\s*real\(8\) function afgen .*?^\s*end function afgen',raw.decode(),re.M|re.S|re.I)
  if not match:raise RuntimeError('AFGEN extraction failed')
  frozen=build/'frozen_b111_afgen.f90';frozen.write_text(re.sub(r'\bafgen\b','low05_b111_afgen',match.group(0),flags=re.I)+'\n')
  frozen_obj=build/'frozen_b111_afgen.o'
  subprocess.run(FC+flags+['-c',str(frozen),'-o',str(frozen_obj)],check=True,text=True,stdout=subprocess.DEVNULL)
  objects=[str(frozen_obj)]
    for p in sources:
      obj=build/(p.stem+'.o');objects.append(str(obj))
      subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,text=True)
    result['runs'][opt]={}
    for test in TESTS:
      p=ROOT/test;obj=build/(p.stem+'.o');exe=build/p.stem
      subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,text=True)
      subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,text=True)
      try:
        output=subprocess.check_output([str(exe)],text=True,stderr=subprocess.STDOUT)
      except subprocess.CalledProcessError as exc:
        print(exc.output,flush=True)
        raise
      markers=[line for line in output.splitlines() if 'PASS' in line]
      if not markers:raise RuntimeError('no PASS markers: '+test)
      result['runs'][opt][test]=markers
      print(opt+' '+test+' PASS',flush=True)
if result['runs']['O0']!=result['runs']['O2']:raise RuntimeError('O0/O2 PASS markers differ')
result['o0_o2_marker_identity']=True
result['status']='BOUNDED_APPLICATION_GATES_PASS'
out=pathlib.Path(os.environ.get('LOW08A_RESULT','low08a_qualification_result.json'))
out.write_text(json.dumps(result,indent=2)+'\n')
print('LOW08A_LOCAL_QUALIFICATION=PASS')
