"""Fresh unmodified original-source refinement on the held-out day584 prefix."""
import argparse,json,re,subprocess,time
from pathlib import Path
from original_oxygen_chronology import sha
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 parent=a.parent.resolve();out=a.output.resolve();out.mkdir();case=out/'case';case.mkdir()
 complete=json.loads((parent/'COMPLETE.json').read_text());assert complete['exact_full_physical_output_control']
 run=json.loads((parent/'unobserved/RUN.json').read_text());exe=parent/'unobserved.exe';assert sha(exe)==run['executable_sha256']
 assert all(sha(parent/'unobserved'/n)==h for n,h in run['inputs'].items())
 for n in run['inputs']:(case/n).write_bytes((parent/'unobserved'/n).read_bytes())
 f=case/'swap.swp';raw=f.read_bytes()
 changed,n=re.subn(rb'(?m)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+',rb'\g<1>0.00015625',raw);assert n==1
 changed,n=re.subn(rb'(?m)^(\s*TEND\s*=\s*)2004-12-31',rb'\g<1>2003-08-07',changed);assert n==1;f.write_bytes(changed)
 (out/'PREREGISTRATION.json').write_text(json.dumps(dict(unmodified_original_executable_sha256=sha(exe),only_input_changes=dict(DTMAX=.00015625,TEND='2003-08-07'),inputs_sha256={n:sha(case/n) for n in run['inputs']},production_admission=False),indent=2)+'\n')
 start=time.monotonic();r=subprocess.run([str(exe)],cwd=case,capture_output=True,timeout=1800)
 (out/'stdout').write_bytes(r.stdout);(out/'stderr').write_bytes(r.stderr)
 (out/'RESULT.json').write_text(json.dumps(dict(returncode=r.returncode,seconds=time.monotonic()-start,swap_ok=(case/'swap.ok').exists()),indent=2)+'\n')
 assert r.returncode==100 and (case/'swap.ok').exists()
