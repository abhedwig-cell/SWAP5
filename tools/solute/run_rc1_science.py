"""Cloud coherent-worker causal and complete nodal heat/iteration controls."""
import argparse,json,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();reference=a.reference.resolve();q=a.qualification.resolve();events=[]
for name in ('grass','hupsel','saltfarm'):
 bundle=q/(name+'-O2-baseline-build');full=q/(name+'-O2-baseline-full');meta=json.loads((bundle/'BUILD.json').read_text())
 original=a.output/(name+'-original');original.mkdir()
 for n in meta['inputs']:
  (original/n).parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(full/'original'/n,original/n)
 exe=reference/'build/swap_b0_gfortran'
 with (a.output/(name+'-original.stdout')).open('wb') as stdout,(a.output/(name+'-original.stderr')).open('wb') as stderr:
  t=time.perf_counter();r=subprocess.run([str(exe),'./swap.swp'],cwd=original,stdout=stdout,stderr=stderr,stdin=subprocess.DEVNULL,timeout=60)
 assert r.returncode==100 and (original/'swap.ok').exists()
 events.append(dict(project=name,original_wall_seconds=time.perf_counter()-t))
 command=[sys.executable,'-B','tools/solute/diagnose_coherent_worker.py','--bundle',str(bundle),'--reference',str(reference),'--full',str(full),'--original-case',str(original),'--output',str(a.output/(name+'-coherent'))]
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
 (a.output/(name+'-coherent.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stdout+r.stderr
 print(name,'COHERENT_COMPLETE_PASS',flush=True)
(a.output/'RESULT.json').write_text(json.dumps(dict(status='CLOUD_COHERENT_ALL3_COMPLETE',events=events),indent=2)+'\n')
