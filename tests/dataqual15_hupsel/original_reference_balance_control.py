"""Fresh reference-only input convergence control; original hard ranges retained."""
import argparse,json,re,subprocess,time
from pathlib import Path
from original_oxygen_chronology import sha
VALUES={'CRITDEVBALCP':'1e-8','CRITDEVBALTOT':'1e-7','CRITDEVH1CP':'1e-6','CRITDEVH2CP':'1e-6','CRITDEVPONDDT':'1e-6'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 parent=a.parent.resolve();out=a.output.resolve();out.mkdir();case=out/'case';case.mkdir()
 for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):(case/n).write_bytes((parent/'case'/n).read_bytes())
 f=case/'swap.swp';raw=f.read_bytes();changed=raw
 for k,v in VALUES.items():
  changed,n=re.subn(rb'(?m)^(\s*'+k.encode()+rb'\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+v.encode(),changed);assert n==1
 f.write_bytes(changed);exe=parent/'reference.exe'
 record=dict(purpose='Reference-only convergence discrimination, no production tolerance or oracle replacement',parameters=VALUES,parent_executable_sha256=sha(exe),parent_source_sha256=sha(parent/'MOD_MvG_functions.f90'),inputs_sha256={x.name:sha(x) for x in case.iterdir()},production_admission=False)
 (out/'PREREGISTRATION.json').write_text(json.dumps(record,indent=2)+'\n')
 start=time.monotonic();r=subprocess.run([str(exe)],cwd=case,capture_output=True,timeout=1800)
 (out/'stdout').write_bytes(r.stdout);(out/'stderr').write_bytes(r.stderr)
 (out/'RESULT.json').write_text(json.dumps(dict(returncode=r.returncode,seconds=time.monotonic()-start,swap_ok=(case/'swap.ok').exists()),indent=2)+'\n')
 assert r.returncode==100 and (case/'swap.ok').exists()
