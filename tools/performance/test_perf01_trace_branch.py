#!/usr/bin/env python3
"""Exercise real private context methods through a visibility-only diagnostic build."""
import argparse,hashlib,json,os,shlex,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);base=a.build.resolve();build=json.loads((base/'build-complete.json').read_text())
 if any(sha(ROOT/p)!=h for p,h in build['input_sha256'].items()):raise RuntimeError('build dependency drift')
 source=ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90';text=source.read_text();needle='  implicit none\n  private\n'
 if text.count(needle)!=1:raise RuntimeError('visibility preimage')
 shadow=out/'backend.f90';shadow.write_text(text.replace(needle,'  implicit none\n  public\n',1))
 fc=shlex.split(os.environ.get('FC','gfortran'));flags=['-O0','-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(out),'-I'+str(base)];objects=[]
 for e in build['events']:
  if e['category']!='compile':continue
  cmd=e['command'];p=Path(cmd[cmd.index('-c')+1]);obj=Path(cmd[cmd.index('-o')+1])
  if p==source:objects.append(str(out/'backend.o'))
  elif p!=ROOT/'app/solute_column/main.f90':objects.append(str(obj))
 log=(out/'compile.log').open('w')
 for p,obj in [(shadow,out/'backend.o'),(ROOT/'tests/performance/test_perf01_trace_branch.f90',out/'test.o')]:subprocess.run(fc+flags+['-c',str(p),'-o',str(obj)],check=True,cwd=out,stdout=log,stderr=log)
 subprocess.run(fc+flags+objects+[str(out/'test.o'),'-o',str(out/'test')],check=True,cwd=out,stdout=log,stderr=log)
 records=[]
 for mode in ['', 'stale','invalid']:
  p=subprocess.run([str(out/'test'),mode],capture_output=True);(out/(mode or 'normal')).write_bytes(p.stdout+p.stderr)
  ok=(p.returncode==0 and b'PERF01_TRACE_IMMUTABLE_BRANCH_RESTORE=PASS'in p.stdout)if not mode else(p.returncode!=0 and b'stale or invalid attempt context'in p.stderr)
  records.append(dict(mode=mode,exit=p.returncode,passed=ok));print(mode,ok)
 (out/'CONTROL.json').write_text(json.dumps(dict(records=records,production_source_sha256=sha(source),shadow_sha256=sha(shadow),visibility_only=True),indent=2))
 if not all(x['passed']for x in records):raise SystemExit(1)
if __name__=='__main__':main()
