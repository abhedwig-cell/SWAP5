#!/usr/bin/env python3
"""Local O0/O2 LOW05-A qualification with explicit legacy support fixture."""
import base64,gzip,hashlib,json,os,pathlib,re,shlex,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
TESTS=['tests/fmig431/test_low05a_application.f90','tests/fmig431/test_low05a_progress.f90','tests/fapp/test_ppa_low02_time_application_admission.f90','tests/fapp/test_ppa_wu01_production_application_bootstrap.f90','tests/fmig431/test_fmig431_low01a_qgwl_binding.f90','tests/fmig431/test_fmig431_low01a_transaction_contract.f90']
frozen_authority=json.loads((ROOT/'tests/fmig431/low05a_frozen_authority_sha256.json').read_text())
for path,expected in frozen_authority['sha256'].items():
 if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=expected:raise RuntimeError('shared authority drift: '+path)
FC=shlex.split(os.environ.get('FC','gfortran'))
LINK=shlex.split(os.environ.get('FMR_FC_LINK_FLAGS',''))
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
  elif not q and n.lower() not in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib'):raise RuntimeError('unresolved module: '+n)
 visiting.remove(p);seen.add(p);ordered.append(p)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
for test in TESTS:visit(ROOT/test)
testpaths={ROOT/p for p in TESTS};sources=[p for p in ordered if p not in testpaths]
result={'work_unit':'F-MIG431-LOW05-A','scope':'bounded ordinary Reference application, existing FSI04 support fixture','compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},'runs':{},'progress_counts':{},'tested_postimage':os.environ.get('LOW05A_TESTED_SHA',os.environ.get('GITHUB_SHA','not-specified')),'canonical_admission':False,'shared_authority_drift_check':'PASS','shared_authority_baseline':frozen_authority['baseline']}
result['runner_sha256']=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='low05a-') as folder:
 for opt in ('O0','O2'):
  build=pathlib.Path(folder)/opt;build.mkdir()
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
  carrier=json.loads((ROOT/'integration/audits/F-MIG431_LOWER_BOUNDARY_B111_SOURCE.json').read_text())
  member=next(m for m in carrier['members'] if m['path']=='SWAP/functions.f90')
  raw=gzip.decompress(base64.b64decode(member['gzip_base64']))
  if hashlib.sha256(raw).hexdigest()!=member['sha256']:raise RuntimeError('frozen source hash mismatch')
  text=raw.decode()
  match=re.search(r'^\s*real\(8\) function afgen .*?^\s*end function afgen',text,re.M|re.S|re.I)
  if not match:raise RuntimeError('AFGEN extraction failed')
  frozen=build/'frozen_b111_afgen.f90';frozen.write_text(re.sub(r'\bafgen\b','low05_b111_afgen',match.group(0),flags=re.I)+'\n')
  frozen_obj=build/'frozen_b111_afgen.o'
  subprocess.run(FC+flags+['-c',str(frozen),'-o',str(frozen_obj)],check=True,text=True,stdout=subprocess.DEVNULL)
  result['frozen_functions_sha256']=member['sha256']
  objects=[str(frozen_obj)]
  for p in sources:
   obj=build/(p.stem+'.o');objects.append(str(obj))
   subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,text=True,stdout=subprocess.DEVNULL)
  result['runs'][opt]={}
  for test in TESTS:
   p=ROOT/test;obj=build/(p.stem+'.o');exe=build/p.stem
   subprocess.run(FC+flags+['-c',str(p),'-o',str(obj)],check=True,text=True,stdout=subprocess.DEVNULL)
   subprocess.run(FC+LINK+flags+objects+[str(obj),'-o',str(exe)],check=True,text=True,stdout=subprocess.DEVNULL)
   output=subprocess.check_output([str(exe)],text=True,stderr=subprocess.STDOUT)
   markers=[line for line in output.splitlines() if 'PASS' in line]
   if not markers:raise RuntimeError('no PASS markers: '+test)
   result['runs'][opt][test]=markers
   if test.endswith('test_low05a_progress.f90'):
    counts=re.search(r'LOW05A_PROGRESS_COUNTS steps=(\d+) retries=(\d+)',output)
    if not counts:raise RuntimeError('missing progress counters')
    result['progress_counts'][opt]={'accepted_substeps':int(counts[1]),'retries':int(counts[2])}
   print(opt+' '+test+' PASS',flush=True)
if result['runs']['O0']!=result['runs']['O2']:raise RuntimeError('O0/O2 markers differ')
if result['progress_counts']['O0']!=result['progress_counts']['O2']:raise RuntimeError('O0/O2 progress counters differ')
result['status']='LOCAL_BOUNDED_GATES_PASS';result['o0_o2_marker_identity']=True
output=pathlib.Path(os.environ.get('LOW05A_RESULT','low05a_qualification_result.json'))
output.write_text(json.dumps(result,indent=2)+'\n')
print('LOW05A_LOCAL_QUALIFICATION=PASS')
