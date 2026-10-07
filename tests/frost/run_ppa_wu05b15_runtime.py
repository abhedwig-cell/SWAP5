#!/usr/bin/env python3
"""Fresh whole-module B15 runtime; one full configuration per process."""
import argparse,os,pathlib,re,shutil,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--route',choices=['normal','low_air'],required=True)
a.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);a.add_argument('--build',type=pathlib.Path)
a.add_argument('--micro-successor',action='store_true',help='Require the exact MICRO02-06 successor source tree')
args=a.parse_args()
source='ac822aafd5403547a2c7ffad5c3ba02c9fa36496' if args.micro_successor else 'ab1849e155cfe4aadb838075c3e402985bc4e0f5'
assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source
prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')
BUILD=args.build or pathlib.Path(os.environ.get('TMPDIR','/tmp'))/prefix
assert BUILD.name.startswith(prefix) and BUILD.is_absolute(),'owned B15 build directory required'
BUILD.mkdir(parents=True,exist_ok=True)
stub=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90'
if args.route=='low_air':
 old=b'  real(8), parameter :: disnod(numnod+1) = 1.0d0'
 new=b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
 b=stub.read_bytes();assert b.count(old)==1
 stub=BUILD/'consistent_grid_stubs.f90';stub.write_bytes(b.replace(old,new))
modules={}
for p in [*ROOT.joinpath('src').rglob('*.f90'),stub]:
 m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',p.read_text(),re.I|re.M)
 if m:modules[m[1].lower()]=p
ordered=[];seen=set();visiting=[]
def visit(name):
 if name in seen or name not in modules:return
 assert name not in visiting,visiting+[name]
 p=modules[name];visiting.append(name)
 for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.I|re.M):visit(n.lower())
 visiting.pop();seen.add(name);ordered.append(p)
for name in ['mod_fmr_serialized_multiswap_runtime','mod_fmr_committed_restart','mod_fmr_production_application_bootstrap']:visit(name)
ordered += [ROOT/'src/legacy/b1_10_port/headcalc.f90',ROOT/'tests/frost/mod_ppa_wu05b15_extended_fixture.f90',ROOT/f'tests/frost/test_ppa_wu05b15_{args.route}_runtime.f90']
(BUILD/'sources').write_text('\n'.join(map(str,ordered))+'\n')
for opt in args.opts:
 out=BUILD/f'o{opt}'
 if out.exists():shutil.rmtree(out)
 out.mkdir()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(out),'-I',str(out)]
 objects=[]
 for p in ordered:
  obj=out/(p.stem+'.o');subprocess.run(['gfortran',*flags,'-c',str(p),'-o',str(obj)],check=True);objects.append(str(obj))
 subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,'-o',str(out/'test')],check=True)
 output=[]
 for configuration in range(1,7):
  stdout=out/f'configuration-{configuration}.txt';stderr=out/f'configuration-{configuration}.err'
  with stdout.open('w')as so,stderr.open('w')as se:
   subprocess.run([str(out/'test'),str(configuration)],stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'},check=True)
  text=stdout.read_text();assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
  assert 'PPA_WU05B15_EXTENDED_APPLICATION=PASS' in text and 'PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS' in text
  output.append(text);print(f'PPA_WU05B15_{args.route.upper()}_O{opt}_CONFIGURATION_{configuration}_FRESH_PROCESS=PASS',flush=True)
 (out/'output.txt').write_text(''.join(output))
 print(f'PPA_WU05B15_{args.route.upper()}_RUNTIME_O{opt}=PASS',flush=True)
if all((BUILD/f'o{o}'/'output.txt').exists()for o in [0,2]):
 assert (BUILD/'o0/output.txt').read_bytes()==(BUILD/'o2/output.txt').read_bytes()
 print(f'PPA_WU05B15_{args.route.upper()}_O0_O2_IDENTITY=PASS',flush=True)
print('BUILD='+str(BUILD),flush=True)
