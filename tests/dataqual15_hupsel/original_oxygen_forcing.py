"""Complete original day584 factor inputs; same accepted ownership hook."""
import json,subprocess,sys,time,hashlib
from pathlib import Path
import original_oxygen_chronology as prior
ROOT=prior.ROOT;sha=prior.sha
USE='''use MOD_grid,only:ch_dz=>dz,ch_layer=>layer
use MOD_MvG,only:ch_cofgen=>cofgen
use MOD_texture_orgmat,only:ch_org=>orgmat,ch_sand=>psand,ch_density=>bdens
use MOD_cropdevelopment,only:ch_srl=>srl,ch_wr=>wroot_node_top,ch_qmicro=>q10_microbial, &
 ch_humus=>specific_resp_humus,ch_radius=>rootradius_m
use plant_interface,only:ch_rootresp=>c_mroot,ch_senes=>f_senes,ch_qroot=>q10_root,ch_max=>max_resp_factor
'''
DECL='integer,save::ch_unit=0\ninteger::ch_i,ch_lay\n'
BLOCK='''      if(chrono_day==584)then
         if(ch_unit==0)open(newunit=ch_unit,file='original_factor_inputs.dat',status='replace')
         do ch_i=1,34
            ch_lay=ch_layer(ch_i)
            write(ch_unit,'(*(es25.17e3,1x))')583d0+chrono_clock,583d0+chrono_clock+dt, &
             chrono_ptra,chrono_dry,chrono_oxy,chrono_salt,chrono_actual,chrono_deep,1d0, &
             real(ch_i,8),real(chrono_nodes,8),chrono_start_h(ch_i),chrono_start_theta(ch_i), &
             chrono_start_temp(ch_i),1d0/ch_srl,ch_wr(ch_i),chrono_pot(ch_i), &
             chrono_pot(ch_i)*chrono_wet(ch_i),chrono_wet(ch_i),672d0/(8.314472d0*(tav+273d0)), &
             tav,ch_cofgen(1:7,ch_i),ch_dz(ch_i),ch_org(ch_lay),ch_sand(ch_lay),ch_density(ch_lay), &
             ch_rootresp,ch_senes,ch_qroot,ch_humus,ch_qmicro,.9d0,.9d0,ch_radius,ch_max
         end do
      end if
'''
def main():
 parent=Path(sys.argv[1]).resolve();provider=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir()
 complete=json.loads((parent/'COMPLETE.json').read_text());assert complete['exact_full_physical_output_control']
 record=json.loads((provider/'BUILD.json').read_text());fc=Path('C:/msys64/ucrt64/bin/gfortran.exe')
 assert all(sha(provider/n)==h for n,h in record['object_sha256'].items())
 source=prior.instrument((provider/'selected/swap.f90').read_text())
 assert source==(parent/'swap.f90').read_text()
 modified=source.replace(prior.USE,prior.USE+USE).replace(prior.DECL,prior.DECL+DECL)
 anchor='      call integral(3)\n';assert modified.count(anchor)==1;modified=modified.replace(anchor,anchor+BLOCK)
 assert modified.replace(USE,'').replace(DECL,'').replace(BLOCK,'')==source
 path=out/'swap.f90';path.write_text(modified,encoding='utf-8',newline='\n')
 flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(out)]
 events=[]
 def run(cmd,cwd,expected=0):
  begin=time.monotonic();p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=600);i=len(events)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr);events.append(dict(command=list(map(str,cmd)),returncode=p.returncode,seconds=time.monotonic()-begin));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==expected,p.stderr
 obj=out/'swap.o';run([fc,*flags,'-c',path,'-o',obj],out)
 exe=out/'observed.exe';objects=[parent/'main.o',parent/'output.o',*[p for p in sorted((provider/'swobj').glob('*.o')) if p.name not in ('swap.o','swapoutput.o')],obj,provider/'ttobj/libttutil.a','-o',exe]
 response=out/'link.args';response.write_text('\n'.join('"'+str(v).replace('\\','/')+'"' for v in objects)+'\n',encoding='utf-8');run([fc,'@'+str(response)],out)
 case=out/'case';case.mkdir()
 for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):(case/n).write_bytes((parent/'observed'/n).read_bytes())
 run([exe],case,100)
 a=(case/'result_output.csv').read_bytes();b=(parent/'unobserved/result_output.csv').read_bytes()
 import re
 normalize=lambda raw:re.sub(rb'(?m)^\* Generated at: [^\n]*\n',b'* Generated at: RUN\n',raw)
 assert normalize(a)==normalize(b)
 for n in ('hupsel_profiles.csv','original_accepted.dat','original_nodes.dat'):assert (case/n).read_bytes()==(parent/'observed'/n).read_bytes(),n
 (out/'COMPLETE.json').write_text(json.dumps(dict(exact_original_controls=True,source_sha256=sha(path),executable_sha256=sha(exe),inputs={n:sha(case/n) for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')}),indent=2)+'\n')
if __name__=='__main__':main()
