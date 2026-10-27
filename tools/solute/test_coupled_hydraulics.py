#!/usr/bin/env python3
"""Compile focused hydraulic contact/wall contracts against the real modules."""
import argparse,json,re,subprocess
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--physical-build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--fc',default='gfortran');a=p.parse_args()
root=Path(__file__).resolve().parents[2]
manifest=json.loads((a.physical_build/'build-complete.json').read_text())
paths=[root/x for x in manifest['input_sha256'] if x.endswith('.f90')]
modules={name.lower():path for path in paths for name in re.findall(r'^\s*module\s+(\w+)\s*$',path.read_text(),re.M|re.I)}
for test,entry in [('test_bordered_drain_control','mod_reference_linear_solver'),('test_integrated_wet_wall','mod_macropore_standard_rate_adapter')]:
 ordered=[];seen=set()
 def visit(path):
  if path in seen:return
  seen.add(path)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',path.read_text(),re.M|re.I):
   if name.lower() in modules and modules[name.lower()]!=path:visit(modules[name.lower()])
  ordered.append(path)
 visit(modules[entry])
 for opt in ['O0','O2']:
  directory=(a.output/(test+'-'+opt)).resolve();directory.mkdir(parents=True,exist_ok=False)
  flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-J'+str(directory),'-I'+str(directory)]
  objects=[]
  for i,path in enumerate(ordered):
   obj=directory/(str(i)+'.o');subprocess.run([a.fc,*flags,'-c',str(path),'-o',str(obj)],check=True);objects.append(str(obj))
  exe=directory/'test';subprocess.run([a.fc,*flags,str(root/'tests/macropore'/(test+'.f90')),*objects,'-o',str(exe)],check=True)
  result=subprocess.run([str(exe)],capture_output=True,text=True);(directory/'result.txt').write_text(result.stdout+result.stderr)
  print(opt,test,result.stdout,result.stderr,flush=True);result.check_returncode()
