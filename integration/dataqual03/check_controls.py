"""Direct numerical-policy guards and restart publication controls."""
import argparse,json,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
w=a.output.parent;run=w/'dataqual03-primary-O2/jacobian-primary/run';off=w/'dataqual03-primary-O2/surface-two-off/run';b=json.loads((w/'dataqual03-native-O2/bundle.json').read_text());m=json.loads((run/'manifest.json').read_text());good=(run/'restart.bin').read_bytes();records=[]
for name,mode,source,policy,raw,binding in [
 ('production','production','','perched-jacobian',good,m['binding_sha256']),('comparison','comparison','','perched-jacobian',good,m['binding_sha256']),('unknown','experimental','source-surface-demand','unknown-jacobian',good,m['binding_sha256']),('crc','experimental','source-surface-demand','perched-jacobian',good[:-1]+bytes([good[-1]^1]),m['binding_sha256']),('foreign','experimental','source-surface-demand','perched-jacobian',good,'0'*64),('off-file','experimental','source-surface-demand','perched-jacobian',(off/'restart.bin').read_bytes(),m['binding_sha256'])]:
 d=a.output/name;d.mkdir()
 for f in ['input.nml','input.swp','macro.nml']:shutil.copyfile(run/f,d/f)
 (d/'origin.bin').write_bytes(raw);cmd=[b['exe'],'input.nml','origin.bin','3','input.swp','macro.nml',binding,'3','anchored-cauchy','.0001',mode,source,policy]
 cp=subprocess.run(cmd,cwd=d,capture_output=True,stdin=subprocess.DEVNULL,timeout=15);(d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 expected='perched Jacobian requires experimental mode'if name in ['production','comparison']else'unknown numerical Jacobian policy'if name=='unknown'else'native macro water restart rejected'
 assert cp.returncode!=0 and expected.encode()in cp.stdout,name
 assert (d/'origin.bin').read_bytes()==raw and not any((d/f).exists()for f in ['budget.csv','progress.csv','state.csv','restart.bin']),name
 records.append(dict(name=name,returncode=cp.returncode,atomic=True,expected=expected,command=cmd))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(records),records=records),indent=2)+'\n')
