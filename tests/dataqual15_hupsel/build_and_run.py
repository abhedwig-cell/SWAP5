"""Actual original Hupsel hydrological germination build and model execution."""
import argparse,csv,hashlib,json,re,shutil,subprocess,time,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];W=ROOT.parent;sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--driver',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--reuse',type=Path,help='Optional verified BUILD.json/object baseline; omit for a clean source build');p.add_argument('--ttutil-archive',type=Path,default=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers/ttobj/libttutil.a'),help='Original compiled TTUTIL provider archive');p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--end',type=int,default=365);a=p.parse_args();out=a.output.resolve();out.mkdir();fc=a.compiler.resolve();reuse=a.reuse.resolve()if a.reuse else None;old=None;events=[]
compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0]
archive=a.ttutil_archive.resolve();assert archive.is_file(),archive
if reuse:
 old=json.loads((reuse/'BUILD.json').read_text())
 assert old['compiler']==compiler
 assert '-'+a.optimization in old['flags'];assert all(sha(Path(f))==h for f,h in old['object_sha256'].items())
flags=['-'+a.optimization,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out)]
if reuse:
 for f in reuse.glob('*.mod'):shutil.copyfile(f,out/f.name)
sys.path.insert(0,str(ROOT/'tools/solute'))
from legacy_reader_sources import materialize
original,_=materialize(ROOT,out)
program=a.driver.resolve()if a.driver else ROOT/'app/solute_project/main.f90';mapping={}
for s in list((ROOT/'src').rglob('*.f90'))+list((ROOT/'app/solute_column').glob('*.f90'))+list((ROOT/'app/solute_project').glob('*.f90'))+[original]:
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',s.read_text(),re.M|re.I):mapping[n.lower()]=s
order=[];seen=set();dependencies={}
def visit(s):
 if s in seen:return
 seen.add(s);children=[]
 for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s.read_text(),re.M|re.I):
  n=n.lower()
  if n in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
  assert n in mapping,(n,s)
  if mapping[n]!=s:children.append(mapping[n]);visit(mapping[n])
 dependencies[s]=children;order.append(s)
visit(program);order.remove(program);visit(original);visit(ROOT/'src/legacy/b1_10_port/headcalc.f90');order.append(program)
def key(s):
 s=str(s)
 for token in ['/src/','/app/']:
  if token in s:return token[1:]+s.split(token,1)[1]
 return Path(s).name
prior={}
if old:
 oldobjs=list(old['object_sha256']);prior={key(s):(h,Path(oldobjs[i])) for i,(s,h) in enumerate(old['source_sha256'].items())}
hashes={str(s):sha(s)for s in order};objects=[];changed=set()
def run(cmd,label,cwd=out,timeout=120):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=timeout);i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),label=label,returncode=r.returncode,seconds=time.monotonic()-t));(out/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()+r.stdout.decode();return r
for i,s in enumerate(order):
 if key(s)in prior and prior[key(s)][0]==sha(s)and not set(dependencies[s])&changed:obj=prior[key(s)][1]
 else:
  changed.add(s);obj=out/f'{i}.o';run([fc,*flags,'-c',s,'-o',obj],'compile')
 objects.append(obj)
exe=out/'swap5_hupsel_germination';run([fc,'-fopenmp',*objects,archive,'-o',exe],'link')
reader=out/'read_fallow';run([fc,*flags,ROOT/'src/process/mod_pmdirect_swetr0_process.f90',ROOT/'app/solute_project/read_fallow_project.f90',archive,'-o',reader],'reader')
build=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=compiler,build_mode='verified-reuse'if reuse else'clean-source',reuse_candidate=old['candidate']if old else None,ttutil_archive=str(archive),flags=flags,source_sha256=hashes,executable_sha256=sha(exe),provider_count=len(order),changed=[str(s)for s in changed],object_sha256={str(o):sha(o)for o in objects},archive_sha256=sha(archive))
(out/'BUILD.json').write_text(json.dumps(build,indent=2)+'\n')
case=out/'full';case.mkdir();source=ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'
for n in ['swap.swp','maize.crp','swap.dra']:
 if(source/n).exists():shutil.copyfile(source/n,case/n)
# Resolve original names directly, retain original bytes.
for f in source.glob('*.met'):shutil.copyfile(f,case/f.name)
print('BUILT',len(order),'providers',len(changed),'recompiled',flush=True)
