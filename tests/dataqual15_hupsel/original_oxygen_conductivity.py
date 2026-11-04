"""Reference-only continuous conductivity control, never silently replace truth."""
import argparse,json,subprocess,time,hashlib
from pathlib import Path
import original_oxygen_chronology as owner
sha=owner.sha
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--parent',type=Path,required=True);p.add_argument('--provider',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 parent=a.parent.resolve();provider=a.provider.resolve();out=a.output.resolve();out.mkdir();meta=json.loads((provider/'BUILD.json').read_text())
 assert all(sha(provider/n)==h for n,h in meta['object_sha256'].items())
 original=(provider/'selected/MOD_MvG_functions.f90').read_text()
 anchor="""                  else if (relsat > (1.0d0-1.0d-6)) then
                     hconduc = ksatfit(node)
                  else"""
 replacement="""                  else if (head > h_crit .and. head < 0d0) then
                     ! The retained linear theta branch: recover its deficit before rounding.
                     term2 = c_crit(node)*head/wcsMINwcr(node)
                     if(abs(term2)<1d-3) then
                        term2=term2-term2**2/2d0+term2**3/3d0-term2**4/4d0+term2**5/5d0-term2**6/6d0
                     else
                        term2=log(1d0+term2)
                     end if
                     term1=term2*oneOVERm(node)
                     if(abs(term1)<1d-3) then
                        term1=-(term1+term1**2/2d0+term1**3/6d0+term1**4/24d0+term1**5/120d0+term1**6/720d0)
                     else
                        term1=1d0-exp(term1)
                     end if
                     hconduc=ksatfit(node)*exp(lambda(node)*term2)*(1d0-term1**m(node))**2
                  else if (relsat >= 1d0) then
                     hconduc = ksatfit(node)
                  else"""
 assert original.count(anchor)==1
 modified=original.replace(anchor,replacement);assert modified.replace(replacement,anchor)==original
 source=out/'MOD_MvG_functions.f90';source.write_text(modified,encoding='utf-8',newline='\n')
 fc=Path('C:/msys64/ucrt64/bin/gfortran.exe');flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(out)];events=[]
 def run(cmd,cwd,expected=0):
  start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=900);i=len(events);(out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr);events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==expected,r.stderr
 obj=out/'MOD_MvG_functions.o';run([fc,*flags,'-c',source,'-o',obj],out)
 exe=out/'reference.exe';objects=[parent/'main.o',parent/'output.o',*[f for f in sorted((provider/'swobj').glob('*.o')) if f.name not in ('MOD_MvG_functions.o','swapoutput.o')],obj,provider/'ttobj/libttutil.a','-o',exe]
 response=out/'link.args';response.write_text('\n'.join('"'+str(x).replace('\\','/')+'"' for x in objects)+'\n',encoding='utf-8');run([fc,'@'+str(response)],out)
 case=out/'case';case.mkdir()
 for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):(case/n).write_bytes((parent/'unobserved'/n).read_bytes())
 run([exe],case,100);assert (case/'swap.ok').exists()
 (out/'COMPLETE.json').write_text(json.dumps(dict(only_reference_conductivity_changed=True,original_source_sha256=sha(provider/'selected/MOD_MvG_functions.f90'),source_sha256=sha(source),executable_sha256=sha(exe),inputs={n:sha(case/n) for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')},production_admission=False),indent=2)+'\n')
