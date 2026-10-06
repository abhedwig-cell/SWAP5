#!/usr/bin/env python3
"""Fresh B19 complete module build; source must be committed before compilation."""
import argparse,os,pathlib,re,shutil,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
source=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
assert subprocess.check_output(['git','diff','--name-only','HEAD','--','src'],cwd=ROOT,text=True).strip()=='' , 'commit source before build'
print('B19_SOURCE_TREE='+source,flush=True)
a=argparse.ArgumentParser();a.add_argument('--route',choices=['normal','low_air'],default='low_air')
a.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);a.add_argument('--build',type=pathlib.Path)
args=a.parse_args()
prefix='ppa-wu05b19-'+args.route.replace('_','-')+'-runtime'
BUILD=args.build or pathlib.Path(os.environ.get('TMPDIR','/tmp'))/prefix
assert BUILD.name.startswith(prefix) and BUILD.is_absolute(),'owned B19 build directory required'
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
ordered += [ROOT/'src/legacy/b1_10_port/headcalc.f90',ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90']
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
 print('B19_BUILD_O'+str(opt)+'=PASS',flush=True)
print('BUILD='+str(BUILD),flush=True)
