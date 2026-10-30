import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.compiler=a.compiler.resolve();o=a.output.resolve();o.mkdir();ref=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers');sample=ROOT.parent/'dq15-hupsel-oracle/samples.txt';driver=ROOT/'tests/dataqual15_hupsel/germination_oracle.f90';production=ROOT/'src/crop/mod_crop_germination_preflight.f90';events=[]
for opt in ['O0','O2']:
 f=o/opt;f.mkdir();(f/'samples.txt').write_bytes(sample.read_bytes());(f/'maize.crp').write_bytes((ROOT/'reference/swap-4.3.1/projects/1.hupselbrook/maize.crp').read_bytes())
 commands=[[a.compiler,'-'+opt,'-fcheck=all','-ffree-line-length-none','-I'+str(f),'-J'+str(f),'-c',production,'-o',f/'production.o'],[a.compiler,'-'+opt,'-fcheck=all','-ffree-line-length-none','-I'+str(f),'-I'+str(ref/'swobj'),driver,f/'production.o',*list((ref/'swobj').glob('*.o')),ref/'ttobj/libttutil.a','-o',f/'oracle'],[f/'oracle']]
 for cmd in commands:
  t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=f,capture_output=True);i=len(events);(o/f'{i}.stdout').write_bytes(r.stdout);(o/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=r.returncode));(o/'EVENTS.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()+r.stdout.decode()
 print(opt,r.stdout.decode().strip(),flush=True)
(o/'RESULT.json').write_text(json.dumps(dict(status='COMPILED_ORIGINAL_GERMINATION_O0_O2_PASS',source_sha256={str(p):sha(p)for p in [driver,production,sample]},events=events),indent=2)+'\n')
