#!/usr/bin/env python3
"""Fresh B19 whole-module incumbent relinks, one full incumbent configuration per process."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--route',choices=['normal','low_air'],required=True)
p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--workers',type=int,choices=[1,2],default=1);args=p.parse_args()
source='636e782080abdd2c0366f96317c4f59e8170dc53'
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==source
names=['ppa_wu05b_frost_runtime','ppa_wu05b2_root_frost_runtime','ppa_wu05b3_frost_bottom_runtime','ppa_wu05b4_root_bottom_runtime','ppa_wu05b6_normal_drain_runtime','ppa_wu05b9_response_drain_runtime','ppa_wu05b11_normal_runtime','ppa_wu05b12_normal_runtime','ppa_wu05b13_normal_runtime','ppa_wu05b14_normal_runtime','ppa_wu05b15_normal_runtime']if args.route=='normal'else['ppa_wu05b8_low_air_runtime','ppa_wu05b10_low_air_response_runtime','ppa_wu05b11_low_air_runtime','ppa_wu05b12_low_air_runtime','ppa_wu05b13_low_air_runtime','ppa_wu05b14_low_air_runtime','ppa_wu05b15_low_air_runtime']
BUILD=pathlib.Path(__import__('tempfile').mkdtemp(prefix='ppa-wu05b19-incumbent-'+args.route+'-'))
modules={};ordered=[];seen=set()
stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
if args.route=='low_air':
 data=stub.read_bytes();old=b'  real(8), parameter :: disnod(numnod+1) = 1.0d0';new=b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
 assert data.count(old)==1;stub=BUILD/'consistent_stubs.f90';stub.write_bytes(data.replace(old,new))
for f in [*ROOT.joinpath('src').rglob('*.f90'),stub]:
 for m in __import__('re').finditer(r'^\s*module\s+(?!procedure\b)(\w+)',f.read_text(),__import__('re').I|__import__('re').M):modules[m[1].lower()]=f
def visit(name):
 if name in seen or name not in modules:return
 seen.add(name);p=modules[name]
 for n in __import__('re').findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),__import__('re').I|__import__('re').M):visit(n.lower())
 if p not in ordered:ordered.append(p)
for n in ['mod_fmr_serialized_multiswap_runtime','mod_fmr_committed_restart','mod_fmr_production_application_bootstrap']:visit(n)
ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
(BUILD/'sources').write_text('\n'.join(map(str,ordered))+'\n')
receipts={}
for name in names:
 f='tests/frost/test_'+name+'.f90'
 assert subprocess.check_output(['git','show','ca856e88e582d468a6f40971ce1f2a75e5089c40:'+f],cwd=ROOT)==(ROOT/f).read_bytes(),f
for opt in args.opts:
 b=BUILD/f'o{opt}';b.mkdir()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 for p in ordered:subprocess.run(['gfortran',*flags,'-c',str(p),'-o',str(b/(p.stem+'.o'))],check=True)
 print(f'B19_INCUMBENT_{args.route}_O{opt}_WHOLE_MODULE_COMPILE=PASS sources={len(ordered)}',flush=True)
 support=[]
 for name in ['mod_ppa_wu05b12_analytic_fixture','mod_ppa_wu05b13_empirical_fixture','mod_ppa_wu05b14_extended_fixture','mod_ppa_wu05b15_extended_fixture']:
  obj=f'/tmp/frost-b19-preserve-{args.route}-{name}-o{opt}.o'
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/{name}.f90'),'-o',obj],check=True);support.append(obj)
 objects=[str(f)for f in sorted(b.glob('*.o'))if not f.name.startswith('test_')]+support
 tasks=[];programs={};families={}
 for name in names:
  out=pathlib.Path(f'/tmp/frost-b19-preserve-{args.route}-{name}-o{opt}');programs[name]=out
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/test_{name}.f90'),'-o',str(out)+'.o'],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(out)+'.o','-o',str(out)],check=True)
  count=6 if name=='ppa_wu05b15_low_air_runtime'else 6 if name=='ppa_wu05b15_normal_runtime'else 5 if args.route=='low_air'and name=='ppa_wu05b12_low_air_runtime'else 6 if args.route=='low_air'and name=='ppa_wu05b13_low_air_runtime'else 4 if args.route=='low_air'and name=='ppa_wu05b14_low_air_runtime'else 0
  families[name]=count
  for family in (range(1,count+1)if count else[None]):
   stem=str(out)+(f'-family-{family}'if family else '')
   tasks.append((name,out,family,pathlib.Path(stem+'.log'),pathlib.Path(stem+'.err')))
 def execute(task):
  name,out,family,so,se=task
  with so.open('w')as stdout,se.open('w')as stderr:subprocess.run([str(out)]+([str(family)]if family else []),stdout=stdout,stderr=stderr,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'},check=True)
  text=so.read_text();assert ('FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'if name=='ppa_wu05b_frost_runtime'else'RUNTIME=PASS')in text
  if family:assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
  r={'production_source_tree':source,'route':args.route,'optimization':opt,'program':name,'family':family,'program_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((ROOT/f'tests/frost/test_{name}.f90').read_bytes()).hexdigest(),'stdout_sha256':hashlib.sha256(so.read_bytes()).hexdigest(),'process_exit_code':0,'complete_case':True}
  receipts[f'{name}/o{opt}/family-{family}']=r
  pathlib.Path(str(so)+'.receipt.json').write_text(json.dumps(r,indent=2)+'\n')
  return f'B15_PRESERVE_{name}_O{opt}_FAMILY_{family}=PASS'if family else f'B15_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS'
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)as pool:
  for f in concurrent.futures.as_completed([pool.submit(execute,t)for t in tasks]):print(f.result(),flush=True)
 for name,count in families.items():
  if not count:continue
  out=programs[name];pieces=[pathlib.Path(str(out)+f'-family-{i}.log').read_text()for i in range(1,count+1)]
  assert all(s.count('_RUNTIME=PASS')==1 and s.count('FINE_COMPARISON')==6 for s in pieces)
  pathlib.Path(str(out)+'.log').write_text(''.join(pieces));print(f'B15_CURRENT_LOW_AIR_O{opt}_{name}=PASS',flush=True)
if len(args.opts)==2:
 for name in names:
  assert pathlib.Path(f'/tmp/frost-b19-preserve-{args.route}-{name}-o0.log').read_bytes()==pathlib.Path(f'/tmp/frost-b19-preserve-{args.route}-{name}-o2.log').read_bytes()
  print(f'B15_CURRENT_{args.route.upper()}_O0_O2_{name}=PASS',flush=True)


for n in [12,13,14,15]:
 name=f'ppa_wu05b{n}_{args.route}_runtime'
 for opt in args.opts:
  original=pathlib.Path(f'/tmp/ppa-wu05b{n}-'+args.route.replace('_','-')+f'-runtime/o{opt}/output.txt')
  if not original.exists():original=pathlib.Path(f'/tmp/ppa-wu05b{n}-'+args.route.replace('_','-')+f'-runtime-parallel/o{opt}/output.txt')
  assert original.exists()and pathlib.Path(f'/tmp/frost-b19-preserve-{args.route}-{name}-o{opt}.log').read_bytes()==original.read_bytes(),str(original)
  print(f'B19_INCUMBENT_{name}_O{opt}_ORIGINAL_BYTE_IDENTITY=PASS',flush=True)
record=dict(work_unit='PPA-WU05B19',status='LOCAL_COMPLETE_INCUMBENT_PRESERVATION_PASS_NOT_ADMITTED',production_source=source,route=args.route,build=str(BUILD),whole_module_sources=len(ordered),source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered},receipts=receipts)
pathlib.Path('/tmp/frost-b19-incumbent-'+args.route+'.json').write_text(json.dumps(record,indent=2)+'\n')
print('B19_INCUMBENT_COMPLETE=PASS BUILD='+str(BUILD),flush=True)
