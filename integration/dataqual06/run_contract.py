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
driver=ROOT/'integration/dataqual06/test_surface_conductivity.f90';visit(driver);report=[]
for opt in ['O0','O2']:
 folder=out/opt;folder.mkdir();objects=[];flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),'-I'+str(folder)];fc=shlex.split(os.environ.get('FC','gfortran'));start=time.monotonic()
 for i,src in enumerate(ordered):
  obj=folder/f'{i}.o';subprocess.run(fc+flags+['-c',str(src),'-o',str(obj)],cwd=folder,check=True,capture_output=True);objects.append(str(obj))
 exe=folder/'probe';subprocess.run(fc+flags+objects+['-o',str(exe)],check=True,capture_output=True)
 cp=subprocess.run([str(exe)],capture_output=True);(folder/'stdout').write_bytes(cp.stdout);(folder/'stderr').write_bytes(cp.stderr);cp.check_returncode()
 report.append(dict(optimization=opt,providers=len(ordered)-1,seconds=time.monotonic()-start,result=cp.stdout.decode()))
assert(out/'O0/stdout').read_bytes()==(out/'O2/stdout').read_bytes()
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
