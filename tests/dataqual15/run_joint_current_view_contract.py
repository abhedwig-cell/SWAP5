"""Small actual current-view module DAG; no native application or copied formula."""
import argparse,hashlib,json,re,subprocess,time
from pathlib import Path
from build_joint_current_view_candidate import render,ROOT
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir();shadow=render(out/'overlay')
mapping={}
for original in (ROOT/'src').rglob('*.f90'):
 source=shadow.get(original,original)
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',source.read_text(),re.M|re.I):mapping[n.lower()]=source
order=[];seen=set()
def visit(source):
 if source in seen:return
 seen.add(source)
 for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',source.read_text(),re.M|re.I):
  n=n.lower()
  if n in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
  visit(mapping[n])
 order.append(source)
visit(ROOT/'tests/dataqual15/joint_current_view_driver.f90')
report=dict(status='RUNNING',providers=len(order),source_sha256={str(s):hashlib.sha256(s.read_bytes()).hexdigest()for s in order},events=[])
for mode in ('O0','O2'):
 case=out/mode;case.mkdir();exe=case/'view.exe'
 commands=[[str(a.compiler.resolve()),'-'+mode,'-ffree-line-length-none','-fcheck=all',
  '-ffpe-trap=invalid,zero,overflow','-J'+str(case),*map(str,order),'-o',str(exe)],[str(exe)]]
 for label,command in zip(('compile-link','native'),commands):
  start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=60)
  (case/(label+'.stdout')).write_bytes(r.stdout);(case/(label+'.stderr')).write_bytes(r.stderr)
  report['events'].append(dict(optimization=mode,label=label,command=command,seconds=time.monotonic()-start,returncode=r.returncode))
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');assert r.returncode==0,r.stderr.decode(errors='replace')
report['status']='CURRENT_GROUNDWATER_REAL_INTERFACE_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],report['providers'],'providers')
