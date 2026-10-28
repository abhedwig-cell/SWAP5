"""Direct native budget and unchanged restart rejection checks, with no publication."""
import argparse,json,re,runpy,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();f=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual03_current.py'))['capsule']();r=json.loads(f['RECOVERY.json']);events=[]
for label,mode,budget,expected in [('production','production',128,'requires experimental mode'),('comparison','comparison',128,'requires experimental mode'),('zero','experimental',0,'solver iteration budget range'),('overflow','experimental',257,'solver iteration budget range'),('crc','experimental',128,'native macro water restart rejected'),('binding','experimental',128,'native macro water restart rejected')]:
 d=a.output/label;d.mkdir()
 for name,src in r['prepared_inputs'].items():(d/('origin.bin'if name=='restart.bin'else name)).write_bytes(f[src])
 doc,count=re.subn(r'(&column\b)',lambda m:m[0]+'\n solver_max_iterations='+str(budget)+',',(d/'input.nml').read_text(),count=1,flags=re.I);assert count==1;(d/'input.nml').write_text(doc)
 if label=='crc':
  b=bytearray((d/'origin.bin').read_bytes());b[-1]^=1;(d/'origin.bin').write_bytes(b)
 original=(d/'origin.bin').read_bytes();cmd=[str(a.exe.resolve()),*r['command'][1:]];cmd[10]=mode
 if mode!='experimental':cmd=cmd[:11]
 if label=='binding':cmd[6]='0'*64
 cp=subprocess.run(cmd,cwd=d,capture_output=True,timeout=10);(d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr)
 assert cp.returncode!=0 and expected.encode()in cp.stdout+cp.stderr,label
 assert (d/'origin.bin').read_bytes()==original
 assert not any((d/x).exists()for x in ['budget.csv','progress.csv','state.csv','restart.bin','diagnostic-rejected.bin']),label
 events.append(dict(label=label,mode=mode,budget=budget,returncode=cp.returncode,expected=expected,atomic=True))
(a.output/'RESULT.json').write_text(json.dumps(dict(passed=len(events),records=events),indent=2)+'\n')
