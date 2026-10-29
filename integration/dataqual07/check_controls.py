"""Reject invalid numerical policy and corrupt restart before publishing physical state."""
import argparse,json,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(exist_ok=False)
m=json.loads((a.run/'manifest.json').read_text());original=next(e['command']for e in m['events']if e['label']=='native');good=(a.run/'restart.bin').read_bytes();records=[]
assert len(original)==14 and original[13]=='conservative-macro-storage'
for name in ['production','comparison','unknown-policy','crc','binding']:
 d=a.output/name;d.mkdir()
 for f in ['input.nml','input.swp','macro.nml']:shutil.copyfile(a.run/f,d/f)
 cmd=original.copy();cmd[2]='-'
 if name in ['production','comparison']:
  cmd[10]=name;cmd[11]='';cmd[12]='';expected='macro storage policy requires experimental mode'
 elif name=='unknown-policy':cmd[13]='unsafe';expected='unknown macro storage policy'
 else:
  raw=good[:-1]+bytes([good[-1]^1])if name=='crc'else good;(d/'input.bin').write_bytes(raw);cmd[2]='input.bin';cmd[7]='2'
  if name=='binding':cmd[6]='0'*64
  expected='native macro water restart rejected'
 cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=10)
 (d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and expected.encode()in cp.stdout,(name,cp.stdout,cp.stderr)
 assert not any((d/f).exists()for f in ['budget.csv','progress.csv','state.csv','restart.bin']),name
 if name in ['crc','binding']:assert(d/'input.bin').read_bytes()==raw
 records.append(dict(name=name,returncode=cp.returncode,expected=expected,atomic=True,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n');print(json.dumps(dict(passed=len(records))))
