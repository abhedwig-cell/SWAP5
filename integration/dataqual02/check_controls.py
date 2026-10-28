"""Real native mode/variant/restart rejection; preserve all input bytes."""
import argparse,json,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--legacy',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
b=json.loads((a.bundle/'bundle.json').read_text());m=json.loads((a.run/'manifest.json').read_text());good=(a.run/'restart.bin').read_bytes();records=[]
for name,mode,variant,raw,binding in [
 ('production','production','source-surface-demand',good,m['binding_sha256']),
 ('comparison','comparison','source-surface-demand',good,m['binding_sha256']),
 ('unknown','experimental','foreign-source',good,m['binding_sha256']),
 ('bad-crc','experimental','source-surface-demand',good[:-1]+bytes([good[-1]^1]),m['binding_sha256']),
 ('foreign-binding','experimental','source-surface-demand',good,'0'*64),
 ('legacy-file','experimental','source-surface-demand',(a.legacy/'restart.bin').read_bytes(),m['binding_sha256'])]:
 d=a.output/name;d.mkdir()
 for f in ['input.nml','input.swp','macro.nml']:shutil.copyfile(a.run/f,d/f)
 (d/'input.bin').write_bytes(raw);cmd=[b['exe'],'input.nml','input.bin','3','input.swp','macro.nml',binding,'1.7976931348623157e308','anchored-cauchy','0.0001',mode,variant]
 cp=subprocess.run(cmd,cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=15)
 (d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and (d/'input.bin').read_bytes()==raw,name
 assert not any((d/f).exists()for f in ['budget.csv','progress.csv','state.csv','restart.bin']),name
 expected='requires experimental mode'if name in ['production','comparison']else'unknown source forcing variant'if name=='unknown'else'native macro water restart rejected'
 assert expected.encode()in cp.stdout,(name,cp.stdout)
 records.append(dict(name=name,returncode=cp.returncode,atomic=True,expected=expected,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n')
