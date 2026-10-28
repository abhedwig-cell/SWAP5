"""Direct source/native experimental boundary and atomic restart controls."""
import argparse,json,shutil,subprocess,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(exist_ok=False)
m=json.loads((a.run/'manifest.json').read_text());original=next(e['command']for e in m['events']if e['label']=='native');b=json.loads((a.bundle/'bundle.json').read_text());good=(a.run/'restart.bin').read_bytes();records=[]
for name in ['source-production','source-unknown','production','comparison','unknown-mode','conductivity-range','crc','binding']:
 d=a.output/name;d.mkdir()
 for f in ['input.nml','input.swp','macro.nml']:shutil.copyfile(a.run/f,d/f)
 if name.startswith('source-'):
  for f in ['input.bbc','input.dra']:shutil.copyfile(a.run/f,d/f)
  cmd=[b['macro_reader'],'input.swp','input.bbc','rejected.nml','input.dra','native-water'if name=='source-production'else'unknown']
  expected='variable surface conductivity requires experimental mode'if name=='source-production'else'unknown configuration option'
 else:
  cmd=original.copy();cmd[2]='-';cmd[3]='2';cmd[7]='2'
  if name in ['production','comparison']:
   # Isolate the conductivity guard from earlier nonlinear/demand/policy guards.
   cmd[10]=name;cmd[11]='';cmd[12]=''
   text=(d/'input.nml').read_text();text,n=re.subn(r'(runoff_exponent\s*=\s*)[^\n]+',r'\g<1>1.0',text,count=1);assert n==1;(d/'input.nml').write_text(text)
   expected='variable surface conductivity requires experimental mode'
  elif name=='unknown-mode':cmd[10]='unknown';expected='unknown execution mode'
  elif name=='conductivity-range':
   text=(d/'macro.nml').read_text();text,n=re.subn(r'( source_surface_conductivity=)[^\n]+',r'\g<1>-1.0',text,count=1);assert n==1;(d/'macro.nml').write_text(text);expected='surface conductivity range'
  else:
   raw=good[:-1]+bytes([good[-1]^1])if name=='crc'else good;(d/'input.bin').write_bytes(raw);cmd[2]='input.bin'
   if name=='binding':cmd[6]='0'*64
   expected='native macro water restart rejected'
 cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=10)
 (d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and expected.encode()in cp.stdout,(name,expected,cp.stdout,cp.stderr)
 assert not any((d/f).exists()for f in ['rejected.nml','budget.csv','progress.csv','state.csv','restart.bin']),name
 if name in ['crc','binding']:assert(d/'input.bin').read_bytes()==raw
 records.append(dict(name=name,returncode=cp.returncode,expected=expected,atomic=True,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n');print(json.dumps(dict(passed=len(records))))
