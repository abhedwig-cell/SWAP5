#!/usr/bin/env python3
"""Fresh B14 whole-module relinks, one full incumbent configuration per process."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--route',choices=['normal','low_air'],required=True)
p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--workers',type=int,choices=[1,2],default=1);args=p.parse_args()
source='f1f8351c6cb7ccd2d1a78e79bebb79dce8076c4d'
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==source
names=['ppa_wu05b_frost_runtime','ppa_wu05b2_root_frost_runtime','ppa_wu05b3_frost_bottom_runtime','ppa_wu05b4_root_bottom_runtime','ppa_wu05b6_normal_drain_runtime','ppa_wu05b9_response_drain_runtime','ppa_wu05b11_normal_runtime','ppa_wu05b12_normal_runtime','ppa_wu05b13_normal_runtime']if args.route=='normal'else['ppa_wu05b8_low_air_runtime','ppa_wu05b10_low_air_response_runtime','ppa_wu05b11_low_air_runtime','ppa_wu05b12_low_air_runtime','ppa_wu05b13_low_air_runtime']
for opt in args.opts:
 base=pathlib.Path('/tmp/ppa-wu05b14-'+args.route.replace('_','-')+'-runtime')
 if args.route=='low_air'and opt==2 and not(base/'o2').exists():base=pathlib.Path(str(base)+'-parallel')
 b=base/f'o{opt}';assert(b/'mod_fmr_serialized_reference_backend.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 support=[]
 for name in ['mod_ppa_wu05b12_analytic_fixture','mod_ppa_wu05b13_empirical_fixture']:
  obj=f'/tmp/frost-b14-preserve-{args.route}-{name}-o{opt}.o'
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/{name}.f90'),'-o',obj],check=True);support.append(obj)
 objects=[str(f)for f in sorted(b.glob('*.o'))if not f.name.startswith('test_')]+support
 tasks=[];programs={};families={}
 for name in names:
  out=pathlib.Path(f'/tmp/frost-b14-preserve-{args.route}-{name}-o{opt}');programs[name]=out
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/test_{name}.f90'),'-o',str(out)+'.o'],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(out)+'.o','-o',str(out)],check=True)
  count=5 if args.route=='low_air'and name=='ppa_wu05b12_low_air_runtime'else 6 if args.route=='low_air'and name=='ppa_wu05b13_low_air_runtime'else 0
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
  pathlib.Path(str(so)+'.receipt.json').write_text(json.dumps(r,indent=2)+'\n')
  return f'B14_PRESERVE_{name}_O{opt}_FAMILY_{family}=PASS'if family else f'B14_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS'
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)as pool:
  for f in concurrent.futures.as_completed([pool.submit(execute,t)for t in tasks]):print(f.result(),flush=True)
 for name,count in families.items():
  if not count:continue
  out=programs[name];pieces=[pathlib.Path(str(out)+f'-family-{i}.log').read_text()for i in range(1,count+1)]
  assert all(s.count('_RUNTIME=PASS')==1 and s.count('FINE_COMPARISON')==6 for s in pieces)
  pathlib.Path(str(out)+'.log').write_text(''.join(pieces));print(f'B14_CURRENT_LOW_AIR_O{opt}_{name}=PASS',flush=True)
if len(args.opts)==2:
 for name in names:
  assert pathlib.Path(f'/tmp/frost-b14-preserve-{args.route}-{name}-o0.log').read_bytes()==pathlib.Path(f'/tmp/frost-b14-preserve-{args.route}-{name}-o2.log').read_bytes()
  print(f'B14_CURRENT_{args.route.upper()}_O0_O2_{name}=PASS',flush=True)

