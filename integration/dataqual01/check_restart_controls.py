"""Six real native corrupt/foreign restart controls; no accepted output publication."""
import argparse,json,shutil,subprocess
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path,required=True);ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();a.output.mkdir()
m=json.loads((a.run/'manifest.json').read_text());b=json.loads((a.bundle/'bundle.json').read_text());original=(a.run/'restart.bin').read_bytes();events=[]
variants={'truncated':original[:-20],'crc':original[:-1]+bytes([original[-1]^1]),'header':bytes([original[0]^1])+original[1:],'payload':original[:150]+bytes([original[150]^1])+original[151:],'empty':b'','foreign':original}
for label,raw in variants.items():
 out=a.output/label;out.mkdir()
 for name in ['input.nml','input.swp','macro.nml']:shutil.copyfile(a.run/name,out/name)
 (out/'input.bin').write_bytes(raw)
 binding=m['binding_sha256']if label!='foreign'else'0'*64
 cmd=[b['exe'],'input.nml','input.bin','3','input.swp','macro.nml',binding,'1.7976931348623157e308','anchored-cauchy','0.0001','comparison']
 cp=subprocess.run(cmd,cwd=out,stdin=subprocess.DEVNULL,capture_output=True,timeout=20)
 (out/'stdout').write_bytes(cp.stdout);(out/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and b'native macro water restart rejected'in cp.stdout,label
 assert (out/'input.bin').read_bytes()==raw
 assert not any((out/n).exists()for n in ['budget.csv','progress.csv','state.csv','restart.bin']),label
 events.append(dict(label=label,command=cmd,returncode=cp.returncode,atomic=True))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(events),events=events),indent=2)+'\n')
