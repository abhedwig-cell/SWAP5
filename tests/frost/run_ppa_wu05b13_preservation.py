#!/usr/bin/env python3
"""Current whole-module preservation, including all B12 analytic families."""
import argparse,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--route',choices=['normal','low_air'],required=True);p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);args=p.parse_args()
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()=='012b2e9df2fa854f19b31c98a1bcd214d8285662'
names=['ppa_wu05b_frost_runtime','ppa_wu05b2_root_frost_runtime','ppa_wu05b3_frost_bottom_runtime','ppa_wu05b4_root_bottom_runtime','ppa_wu05b6_normal_drain_runtime','ppa_wu05b9_response_drain_runtime','ppa_wu05b11_normal_runtime','ppa_wu05b12_normal_runtime']if args.route=='normal'else['ppa_wu05b8_low_air_runtime','ppa_wu05b10_low_air_response_runtime','ppa_wu05b11_low_air_runtime','ppa_wu05b12_low_air_runtime']
for opt in args.opts:
 base=pathlib.Path('/tmp/ppa-wu05b13-'+args.route.replace('_','-')+'-runtime')
 if args.route=='low_air'and opt==2 and not(base/'o2').exists():base=pathlib.Path(str(base)+'-parallel')
 b=base/f'o{opt}';assert(b/'mod_fmr_serialized_reference_backend.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 helper=pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-b12-helper-o{opt}.o')
 subprocess.run(['gfortran',*flags,'-c',str(ROOT/'tests/frost/mod_ppa_wu05b12_analytic_fixture.f90'),'-o',str(helper)],check=True)
 objects=[str(f)for f in sorted(b.glob('*.o'))if not f.name.startswith('test_')]+[str(helper)]
 for name in names:
  out=pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o{opt}')
  subprocess.run(['gfortran',*flags,'-c',str(ROOT/f'tests/frost/test_{name}.f90'),'-o',str(out)+'.o'],check=True)
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(out)+'.o','-o',str(out)],check=True)
  if args.route=='low_air'and name=='ppa_wu05b12_low_air_runtime':
   pieces=[]
   for family in range(1,6):
    so=pathlib.Path(str(out)+f'-family-{family}.log');se=pathlib.Path(str(out)+f'-family-{family}.err')
    with so.open('w')as stdout,se.open('w')as stderr:subprocess.run([str(out),str(family)],stdout=stdout,stderr=stderr,check=True)
    text=so.read_text();assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
    pieces.append(text);print(f'B13_PRESERVE_B12_LOW_AIR_O{opt}_FAMILY_{family}=PASS',flush=True)
   pathlib.Path(str(out)+'.log').write_text(''.join(pieces))
  else:
   with open(str(out)+'.log','w')as so,open(str(out)+'.err','w')as se:subprocess.run([str(out)],stdout=so,stderr=se,check=True)
   assert 'PASS' in pathlib.Path(str(out)+'.log').read_text()
  print(f'B13_CURRENT_{args.route.upper()}_O{opt}_{name}=PASS',flush=True)
if len(args.opts)==2:
 for name in names:
  assert pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o0.log').read_bytes()==pathlib.Path(f'/tmp/frost-b13-preserve-{args.route}-{name}-o2.log').read_bytes()
  print(f'B13_CURRENT_{args.route.upper()}_O0_O2_{name}=PASS',flush=True)

