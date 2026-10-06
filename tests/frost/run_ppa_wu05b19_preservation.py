#!/usr/bin/env python3
"""Fresh B19 whole-module preservation of original B1 through B15 runtime programs."""
import argparse,concurrent.futures,contextlib,fcntl,gzip,hashlib,json,os,pathlib,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--route',choices=['normal','low_air'],required=True);p.add_argument('--build',type=pathlib.Path,required=True)
p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--workers',type=int,choices=range(1,9),default=1)
p.add_argument('--resume',action='store_true');p.add_argument('--global-workers',type=int,choices=range(1,5));args=p.parse_args()
RESULTS=args.build/'preservation';RESULTS.mkdir(exist_ok=True)
@contextlib.contextmanager
def process_slot():
 if args.global_workers is None:
  yield;return
 slots=args.build/'process-slots';slots.mkdir(exist_ok=True)
 files=[(slots/f'slot-{i}').open('a+')for i in range(args.global_workers)];locked=False
 try:
  while not locked:
   for f in files:
    try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:continue
    locked=True;break
   if not locked:time.sleep(.1)
  yield
 finally:
  for f in files:f.close()
source=json.loads((ROOT/'integration/audits/PPA_WU05B19_PREREGISTRATION.json').read_text())['candidate_source']
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==source
names=['ppa_wu05b_frost_runtime','ppa_wu05b2_root_frost_runtime','ppa_wu05b3_frost_bottom_runtime','ppa_wu05b4_root_bottom_runtime','ppa_wu05b6_normal_drain_runtime','ppa_wu05b9_response_drain_runtime','ppa_wu05b11_normal_runtime','ppa_wu05b12_normal_runtime','ppa_wu05b13_normal_runtime','ppa_wu05b14_normal_runtime','ppa_wu05b15_normal_runtime']if args.route=='normal'else['ppa_wu05b8_low_air_runtime','ppa_wu05b10_low_air_response_runtime','ppa_wu05b11_low_air_runtime','ppa_wu05b12_low_air_runtime','ppa_wu05b13_low_air_runtime','ppa_wu05b14_low_air_runtime','ppa_wu05b15_low_air_runtime']
authority=json.loads(gzip.decompress((ROOT/'docs/audits/evidence/PPA_WU05B15_LOCAL_REPLAY.json.gz').read_bytes()))
for opt in args.opts:
 b=args.build/f'o{opt}';assert(b/'mod_fmr_serialized_reference_backend.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 support=[]
 for name in ['mod_ppa_wu05b12_analytic_fixture','mod_ppa_wu05b13_empirical_fixture','mod_ppa_wu05b14_extended_fixture','mod_ppa_wu05b15_extended_fixture']:
  obj=str(RESULTS/f'frost-b19-preserve-{args.route}-{name}-o{opt}.o')
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/{name}.f90'),'-o',obj],check=True);support.append(obj)
 objects=[str(f)for f in sorted(b.glob('*.o'))if not f.name.startswith('test_')]+support
 tasks=[];programs={};families={}
 for name in names:
  out=RESULTS/f'frost-b19-preserve-{args.route}-{name}-o{opt}';programs[name]=out
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/test_{name}.f90'),'-o',str(out)+'.o'],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(out)+'.o','-o',str(out)],check=True)
  count=6 if name in ['ppa_wu05b15_normal_runtime','ppa_wu05b15_low_air_runtime']else 5 if args.route=='low_air'and name=='ppa_wu05b12_low_air_runtime'else 6 if args.route=='low_air'and name=='ppa_wu05b13_low_air_runtime'else 4 if args.route=='low_air'and name=='ppa_wu05b14_low_air_runtime'else 0
  families[name]=count
  for family in (range(1,count+1)if count else[None]):
   stem=str(out)+(f'-family-{family}'if family else '')
   tasks.append((name,out,family,pathlib.Path(stem+'.log'),pathlib.Path(stem+'.err')))
 def execute(task):
  name,out,family,so,se=task
  receipt=pathlib.Path(str(so)+'.receipt.json')
  if args.resume and receipt.exists():
   r=json.loads(receipt.read_text())
   assert r['production_source_tree']==source and r['process_exit_code']==0 and r['complete_case']
   assert r['source_sha256']==hashlib.sha256((ROOT/f'tests/frost/test_{name}.f90').read_bytes()).hexdigest()
   assert r['program_sha256']==hashlib.sha256(out.read_bytes()).hexdigest()
   assert r['stdout_sha256']==hashlib.sha256(so.read_bytes()).hexdigest()
   return f'B19_VERIFIED_EXISTING_{name}_O{opt}_FAMILY_{family}=PASS'
  out.chmod(out.stat().st_mode | 0o100)
  with process_slot(),so.open('w')as stdout,se.open('w')as stderr:cp=subprocess.run([str(out)]+([str(family)]if family else []),stdout=stdout,stderr=stderr,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
  if cp.returncode!=0:
   failure={'production_source_tree':source,'route':args.route,'optimization':opt,'program':name,'family':family,'process_exit_code':cp.returncode,'complete_case':False,'stdout_sha256':hashlib.sha256(so.read_bytes()).hexdigest(),'stderr_sha256':hashlib.sha256(se.read_bytes()).hexdigest()}
   pathlib.Path(str(so)+'.failure.json').write_text(json.dumps(failure,indent=2)+'\n')
   print(f'B19_PRESERVATION_PROCESS_FAILED={name} O{opt} family={family} exit={cp.returncode}',flush=True)
   raise subprocess.CalledProcessError(cp.returncode,[str(out)])
  text=so.read_text();assert ('FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'if name=='ppa_wu05b_frost_runtime'else'RUNTIME=PASS')in text
  if family:assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
  oldkey=f'frost-b15-preserve-{args.route}-{name}-o{opt}'+(f'-family-{family}'if family else '')+'.log'
  if oldkey in authority['logs']:assert text==authority['logs'][oldkey],oldkey
  r={'production_source_tree':source,'route':args.route,'optimization':opt,'program':name,'family':family,'program_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((ROOT/f'tests/frost/test_{name}.f90').read_bytes()).hexdigest(),'stdout_sha256':hashlib.sha256(so.read_bytes()).hexdigest(),'process_exit_code':0,'complete_case':True}
  receipt.write_text(json.dumps(r,indent=2)+'\n')
  return f'B19_PRESERVE_{name}_O{opt}_FAMILY_{family}=PASS'if family else f'B19_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS'
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)as pool:
  for f in concurrent.futures.as_completed([pool.submit(execute,t)for t in tasks]):print(f.result(),flush=True)
 for name,count in families.items():
  if not count:continue
  out=programs[name];pieces=[pathlib.Path(str(out)+f'-family-{i}.log').read_text()for i in range(1,count+1)]
  assert all(s.count('_RUNTIME=PASS')==1 and s.count('FINE_COMPARISON')==6 for s in pieces)
  combined=''.join(pieces)
  if name in ['ppa_wu05b15_normal_runtime','ppa_wu05b15_low_air_runtime']:
   assert combined==authority['runtime_output_snapshots'][args.route+'_O'+str(opt)]
  pathlib.Path(str(out)+'.log').write_text(combined);print(f'B19_CURRENT_LOW_AIR_O{opt}_{name}=PASS',flush=True)
if len(args.opts)==2:
 for name in names:
  assert (RESULTS/f'frost-b19-preserve-{args.route}-{name}-o0.log').read_bytes()==(RESULTS/f'frost-b19-preserve-{args.route}-{name}-o2.log').read_bytes()
  print(f'B19_CURRENT_{args.route.upper()}_O0_O2_{name}=PASS',flush=True)
