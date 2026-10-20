#!/usr/bin/env python3
"""Aggregate gprof samples from repeated real file-driven runs; check all outputs."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 for k in ['build','input','reference','output']:ap.add_argument('--'+k,type=Path,required=True)
 ap.add_argument('--repeat',type=int,default=20);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 base=a.build.resolve();exe=base/'swap5_solute_column';build=json.loads((base/'build-complete.json').read_text())
 if '-pg'not in build['flags']or sha(exe)!=build['executable_sha256']:raise ValueError('profile executable identity')
 files={f:sha(a.reference/f)for f in ['budget.csv','state.csv','endpoint.csv','restart.bin']};records=[];gmons=[]
 for i in range(a.repeat):
  b=out/str(i);b.mkdir();p=subprocess.run(['taskset','-c',str(max(os.sched_getaffinity(0))),str(exe),str(a.input.resolve()),'-','8'],cwd=b,capture_output=True)
  (b/'stdout').write_bytes(p.stdout);(b/'stderr').write_bytes(p.stderr)
  if p.returncode or any(sha(b/f)!=h for f,h in files.items()):raise ValueError('profile run or physical drift')
  records.append(dict(repeat=i,exit=p.returncode,files=files));gmons.append(str(b/'gmon.out'))
 symbols=subprocess.check_output(['nm','-n',str(exe)],text=True).replace(' t ',' T ');(out/'symbols.txt').write_text(symbols)
 result=subprocess.check_output(['gprof','-S',str(out/'symbols.txt'),str(exe),*gmons]);(out/'gprof.txt').write_bytes(result)
 (out/'CONTROL.json').write_text(json.dumps(dict(build=build,runs=records,scope='Model samples; shared-library CPU incompletely sampled; not release timing'),indent=2))
if __name__=='__main__':main()
