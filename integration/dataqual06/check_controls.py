"""Atomic native and original-source reader exclusions for the new capability."""
import argparse,json,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
m=json.loads((a.run/'manifest.json').read_text());original=next(e['command']for e in m['events']if e['label']=='native');good=(a.run/'restart.bin').read_bytes();records=[]
for name in ['production','comparison','unknown-mode','crc','binding','source-reader-production']:
 d=a.output/name;d.mkdir();cmd=original.copy()
 for f in ['input.nml','input.swp','macro.nml','input.bbc','input.dra']:shutil.copyfile(a.run/f,d/f)
 cmd[2]='-';cmd[3]='2';cmd[11]='';cmd[12]=''
 expected=''
 if name in ['production','comparison']:
  cmd[10]=name
  t=(d/'input.nml').read_text();t,n=re.subn(r'(runoff_exponent\s*=\s*)[^\n]+',r'\g<1>1.0',t,count=1);assert n==1;(d/'input.nml').write_text(t)
  expected='variable surface conductivity requires experimental mode'
 if name=='unknown-mode':cmd[10]=name;expected='unknown execution mode'
 if name in ['crc','binding']:
  raw=good[:-1]+bytes([good[-1]^1])if name=='crc'else good;(d/'input.bin').write_bytes(raw);cmd[2]='input.bin'
  if name=='binding':cmd[6]='0'*64
  expected='native macro water restart rejected'
 if name=='source-reader-production':
  reader=m['compiler_and_source_bundle']['macro_reader'];cmd=[reader,'input.swp','input.bbc','rejected.nml','input.dra','native-water'];expected='variable surface conductivity requires experimental mode'
 cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=10)
 (d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and expected.encode()in cp.stdout,(name,cp.returncode,cp.stdout)
 assert not any((d/f).exists()for f in ['budget.csv','progress.csv','state.csv','restart.bin','rejected.nml']),name
 if name in ['crc','binding']:assert(d/'input.bin').read_bytes()==raw
 records.append(dict(name=name,returncode=cp.returncode,atomic=True,expected=expected,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n');print(json.dumps(dict(passed=len(records))))
