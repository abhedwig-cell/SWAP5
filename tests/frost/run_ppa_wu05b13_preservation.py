#!/usr/bin/env python3
"""Whole-module preservation with independent complete test processes."""
import argparse,concurrent.futures,gzip,hashlib,json,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--route',choices=['normal','low_air'],required=True)
p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--workers',type=int,choices=[1,2],default=1);p.add_argument('--resume-log',type=pathlib.Path);args=p.parse_args()
source='012b2e9df2fa854f19b31c98a1bcd214d8285662'
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==source
names=['ppa_wu05b_frost_runtime','ppa_wu05b2_root_frost_runtime','ppa_wu05b3_frost_bottom_runtime','ppa_wu05b4_root_bottom_runtime','ppa_wu05b6_normal_drain_runtime','ppa_wu05b9_response_drain_runtime','ppa_wu05b11_normal_runtime','ppa_wu05b12_normal_runtime']if args.route=='normal'else['ppa_wu05b8_low_air_runtime','ppa_wu05b10_low_air_response_runtime','ppa_wu05b11_low_air_runtime','ppa_wu05b12_low_air_runtime']
resume=args.resume_log.read_text()if args.resume_log else ''
if resume:
 assert len(args.opts)==1 and args.route=='low_air'
 recovery=json.loads(gzip.decompress((ROOT/'docs/audits/evidence/PPA_WU05B13_PARTIAL_RECOVERY.json.gz').read_bytes()));assert recovery['production_source_tree']==source
for opt in args.opts:
 base=pathlib.Path('/tmp/ppa-wu05b13-'+args.route.replace('_','-')+'-runtime')
 if args.route=='low_air'and opt==2 and not(base/'o2').exists():base=pathlib.Path(str(base)+'-parallel')
 b=base/f'o{opt}';assert(b/'mod_fmr_serialized_reference_backend.o').exists()
 if resume:
  proof=json.loads(pathlib.Path('/tmp/frost-b13-current-whole-module-source-proof.json').read_text());assert proof['production_source_tree']==source and proof['current_all_used_source_bytes_identical']
  for f,d in proof['builds'][args.route+'_O'+str(opt)].items():
   path=base/'consistent_grid_stubs.f90'if f=='owned_consistent_grid_stubs'else ROOT/f
   assert hashlib.sha256(path.read_bytes()).hexdigest()==d,f
  for f,d in recovery['build_artifact_sha256'].items():
   if pathlib.Path(f).parent==b and f.endswith('.o'):assert hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()==d,f
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 helper=pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-b12-helper-o{opt}.o')
 subprocess.run(['gfortran',*flags,'-c',str(ROOT/'tests/frost/mod_ppa_wu05b12_analytic_fixture.f90'),'-o',str(helper)],check=True)
 objects=[str(f)for f in sorted(b.glob('*.o'))if not f.name.startswith('test_')]+[str(helper)]
 tasks=[];programs={}
 for name in names:
  out=pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o{opt}');programs[name]=out
  marker=f'B13_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS'
  if marker in resume:
   assert 'RUNTIME=PASS'in pathlib.Path(str(out)+'.log').read_text();print(marker,flush=True);continue
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/test_{name}.f90'),'-o',str(out)+'.o'],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(out)+'.o','-o',str(out)],check=True)
  for family in (range(1,6)if args.route=='low_air'and name=='ppa_wu05b12_low_air_runtime'else[None]):
   stem=str(out)+(f'-family-{family}'if family else '')
   so=pathlib.Path(stem+'.log');se=pathlib.Path(stem+'.err')
   marker=f'B13_PRESERVE_B12_LOW_AIR_O{opt}_FAMILY_{family}=PASS'
   if family and marker in resume:
    text=so.read_text();assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6;print(marker,flush=True);continue
   tasks.append((name,out,family,so,se))
 def execute(task):
  name,out,family,so,se=task
  with so.open('w')as stdout,se.open('w')as stderr:subprocess.run([str(out)]+([str(family)]if family else []),stdout=stdout,stderr=stderr,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'},check=True)
  text=so.read_text();assert 'RUNTIME=PASS'in text
  if family:assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
  receipt={'production_source_tree':source,'route':args.route,'optimization':opt,'program':name,'family':family,'program_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'stdout_sha256':hashlib.sha256(so.read_bytes()).hexdigest(),'process_exit_code':0,'complete_case':True}
  pathlib.Path(str(so)+'.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
  return f'B13_PRESERVE_B12_LOW_AIR_O{opt}_FAMILY_{family}=PASS'if family else f'B13_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS'
 with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)as pool:
  for future in concurrent.futures.as_completed([pool.submit(execute,t)for t in tasks]):print(future.result(),flush=True)
 if args.route=='low_air':
  out=programs['ppa_wu05b12_low_air_runtime'];pieces=[pathlib.Path(str(out)+f'-family-{i}.log').read_text()for i in range(1,6)]
  assert all(s.count('_RUNTIME=PASS')==1 and s.count('FINE_COMPARISON')==6 for s in pieces)
  pathlib.Path(str(out)+'.log').write_text(''.join(pieces));print(f'B13_CURRENT_LOW_AIR_O{opt}_ppa_wu05b12_low_air_runtime=PASS',flush=True)
if len(args.opts)==2:
 for name in names:
  assert pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o0.log').read_bytes()==pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o2.log').read_bytes()
  print(f'B13_CURRENT_{args.route.upper()}_O0_O2_{name}=PASS',flush=True)

