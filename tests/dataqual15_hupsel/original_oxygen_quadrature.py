"""Reference-only full trajectory quadrature controls, never silently replace truth."""
import argparse,json,subprocess,time,hashlib
from pathlib import Path
import original_oxygen_chronology as owner
sha=owner.sha
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--provider',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--eps',choices=['1.d-8','1.d-10'],required=True);a=p.parse_args()
 parent=a.parent.resolve();provider=a.provider.resolve();out=a.output.resolve();out.mkdir();meta=json.loads((provider/'BUILD.json').read_text())
 assert all(sha(provider/n)==h for n,h in meta['object_sha256'].items())
 original=(provider/'selected/oxygenstress.f90').read_text();anchor='      real(8), parameter         :: EPS   = 1.0d-5            ! 1.0D-8';assert original.count(anchor)==1
 replacement='      real(8), parameter         :: EPS   = '+a.eps+'            ! preregistered standard-MvG control'
 modified=original.replace(anchor,replacement);assert modified.replace(replacement,anchor)==original
 source=out/'oxygenstress.f90';source.write_text(modified,encoding='utf-8',newline='\n')
 fc=Path('C:/msys64/ucrt64/bin/gfortran.exe');flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(out)];events=[]
 def run(cmd,cwd,expected=0):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=900);i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==expected,r.stderr
 obj=out/'oxygenstress.o';run([fc,*flags,'-c',source,'-o',obj],out)
 exe=out/'reference.exe';objects=[parent/'main.o',parent/'output.o',*[f for f in sorted((provider/'swobj').glob('*.o')) if f.name not in ('oxygenstress.o','swapoutput.o')],obj,provider/'ttobj/libttutil.a','-o',exe]
 response=out/'link.args';response.write_text('\n'.join('"'+str(x).replace('\\','/')+'"' for x in objects)+'\n',encoding='utf-8');run([fc,'@'+str(response)],out)
 case=out/'case';case.mkdir()
 for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):(case/n).write_bytes((parent/'unobserved'/n).read_bytes())
 run([exe],case,100);assert (case/'swap.ok').exists()
 (out/'COMPLETE.json').write_text(json.dumps(dict(eps=a.eps,only_reference_quadrature_changed=True,original_source_sha256=sha(provider/'selected/oxygenstress.f90'),source_sha256=sha(source),executable_sha256=sha(exe),inputs={n:sha(case/n) for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')},production_admission=False),indent=2)+'\n')
