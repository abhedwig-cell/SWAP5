"""Small real-provider closure; checked O0/O2, independent real128/FD oracles."""
import argparse,json,os,re,shlex,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
mapping={}
for source in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',source.read_text(),re.M|re.I):mapping[name.lower()]=source
ordered=[];seen=set()
def visit(source):
 if source in seen:return
 seen.add(source)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',source.read_text(),re.M|re.I):
  if name.lower()in mapping:visit(mapping[name.lower()])
 ordered.append(source)
driver=ROOT/'integration/dataqual05/test_power_runoff.f90';visit(driver);report=[]
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir();objects=[];flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),'-I'+str(folder)];fc=shlex.split(os.environ.get('FC','gfortran'));start=time.monotonic()
 for i,src in enumerate(ordered):
  obj=folder/f'{i}.o';subprocess.run(fc+flags+['-c',str(src),'-o',str(obj)],cwd=folder,check=True,capture_output=True);objects.append(str(obj))
 exe=folder/'probe';subprocess.run(fc+flags+objects+['-o',str(exe)],check=True,capture_output=True)
 cp=subprocess.run([str(exe)],capture_output=True);(folder/'stdout').write_bytes(cp.stdout);(folder/'stderr').write_bytes(cp.stderr);cp.check_returncode()
 linear=subprocess.check_output([str(exe),'linear']);(folder/'linear.stdout').write_bytes(linear)
 # Compile literal predecessor provider only; same immutable dependency objects.
 old=folder/'predecessor.f90';old.write_bytes(subprocess.check_output(['git','show','5a0b0fcd4461d651c141919da09a8ddcb9ff25e2:src/solver/mod_b110_dynamic_top_boundary_provider.f90'],cwd=ROOT))
 index=next(i for i,s in enumerate(ordered)if s.name=='mod_b110_dynamic_top_boundary_provider.f90');obj=folder/'predecessor.o'
 subprocess.run(fc+flags+['-c',str(old),'-o',str(obj)],check=True,capture_output=True);previous=objects.copy();previous[index]=str(obj);exe=folder/'previous';subprocess.run(fc+flags+previous+['-o',str(exe)],check=True,capture_output=True)
 before=subprocess.check_output([str(exe),'linear']);(folder/'previous.stdout').write_bytes(before);assert before==linear
 report.append(dict(optimization=opt,providers=len(ordered)-1,seconds=time.monotonic()-start,linear_predecessor_exact=True,result=cp.stdout.decode()))
assert(out/'O0/stdout').read_bytes()==(out/'O2/stdout').read_bytes()
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
