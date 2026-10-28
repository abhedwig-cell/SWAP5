"""Direct native mode/range/CRC/binding controls, independent of Python admission."""
import argparse,json,re,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
m=json.loads((a.run/'manifest.json').read_text());original=next(e['command']for e in m['events']if e['label']=='native');good=(a.run/'restart.bin').read_bytes();records=[]
for name in ['production','comparison','unknown-mode','outside-implemented','crc','binding']:
 d=a.output/name;d.mkdir();cmd=original.copy()
 for f in ['input.nml','input.swp','macro.nml']:shutil.copyfile(a.run/f,d/f)
 cmd[2]='-';cmd[3]='2';cmd[7]='2';cmd[11]='';cmd[12]=''
 if name in ['production','comparison','unknown-mode']:cmd[10]=name
 if name=='outside-implemented':
  s=(d/'input.nml').read_text();s,n=re.subn(r'(runoff_exponent\s*=\s*)[^\n]+',r'\g<1>3.0',s,count=1);assert n==1;(d/'input.nml').write_text(s)
 if name in ['crc','binding']:
  raw=good[:-1]+bytes([good[-1]^1])if name=='crc'else good;(d/'input.bin').write_bytes(raw);cmd[2]='input.bin'
  if name=='binding':cmd[6]='0'*64
 cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=10)
 (d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0,name
 assert not any((d/f).exists()for f in ['budget.csv','progress.csv','state.csv','restart.bin']),name
 if name in ['crc','binding']:assert(d/'input.bin').read_bytes()==raw
 expected='nonlinear runoff requires experimental mode'if name in ['production','comparison']else'experimental runoff exponent range0.5..2'if name=='outside-implemented'else'execution mode'if name=='unknown-mode'else'native macro water restart rejected'
 assert expected.encode()in cp.stdout,(name,expected,cp.stdout)
 records.append(dict(name=name,returncode=cp.returncode,atomic=True,expected=expected,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n');print(json.dumps(dict(passed=len(records))))
