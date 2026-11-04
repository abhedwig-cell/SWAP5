"""Observe real original accepted root intervals without altering model state."""
import argparse,hashlib,json,re,shutil,subprocess,time,sys,tarfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'dataqual15'))
from original_sources import build_original
from scientific_followup import instrument as profile_instrument
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
USE='''use variables,only:chrono_day=>daycum,chrono_clock=>tcum,chrono_h=>h,chrono_theta=>theta,chrono_qrot=>qrot
use MOD_meteo,only:chrono_ptra=>ptra
use MOD_re_global,only:chrono_actual=>qrosum,chrono_dry=>qreddrysum,chrono_oxy=>qredwetsum, &
 chrono_salt=>qredsolsum,chrono_frost=>qredfrssum,chrono_pot=>qpotrot,chrono_wet=>alpwet, &
 chrono_carry=>alpdrynodrtz,chrono_deep=>alpwetnoddrz
use plant_interface,only:chrono_nodes=>noddrz,chrono_rd=>rd
use MOD_cropdevelopment,only:chrono_lrv=>lrv_node
'''
DECL='''integer,save::chrono_unit=0,chrono_node_unit=0,chrono_sequence=0
real(8),save::chrono_start_h(34),chrono_start_theta(34),chrono_start_temp(34)
'''
BEFORE='''      if(chrono_day==525.or.(chrono_day>=583.and.chrono_day<=585))then
         if(numnod/=34)error stop 'original chronology requires actual34 nodes'
         chrono_start_h=chrono_h(1:34);chrono_start_theta=chrono_theta(1:34);chrono_start_temp=tsoil(1:34)
      end if
'''
AFTER='''      if(chrono_day==525.or.(chrono_day>=583.and.chrono_day<=585))then
         if(chrono_unit==0)then
            open(newunit=chrono_unit,file='original_accepted.dat',status='replace')
            open(newunit=chrono_node_unit,file='original_nodes.dat',status='replace')
         end if
         chrono_sequence=chrono_sequence+1
         write(chrono_unit,'(*(es25.17e3,1x))')real(chrono_day,8),chrono_clock,dt, &
            chrono_ptra,chrono_actual,chrono_dry,chrono_oxy,chrono_salt,chrono_frost, &
            real(chrono_nodes,8),chrono_rd,chrono_carry,chrono_deep,sum(chrono_pot(1:chrono_nodes)),real(chrono_sequence,8)
         if(chrono_day==584)write(chrono_node_unit,'(*(es25.17e3,1x))')chrono_clock,dt, &
            chrono_start_h,chrono_start_theta,chrono_start_temp,chrono_h(1:34),chrono_theta(1:34), &
            chrono_qrot(1:34),chrono_wet(1:34),chrono_lrv(1:34)
      end if
'''

def instrument(source):
 anchor='use swap_exchange\n';position=source.index('subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) ')
 prefix,body=source[:position],source[position:]
 assert body.count(anchor)==1;body=body.replace(anchor,anchor+USE,1)
 anchor='logical :: flError\n';assert body.count(anchor)==1;body=body.replace(anchor,anchor+DECL)
 anchor='      if (swcrop == 1) call RootExtraction(2)\n';assert body.count(anchor)==1;body=body.replace(anchor,BEFORE+anchor)
 anchor='      call integral(3)\n';assert body.count(anchor)==1;body=body.replace(anchor,anchor+AFTER)
 result=prefix+body
 assert result.replace(USE,'').replace(DECL,'').replace(BEFORE,'').replace(AFTER,'')==source
 return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--reuse-provider',type=Path);a=p.parse_args()
 out=a.output.resolve();out.mkdir();fc=a.compiler.resolve();provider=a.reuse_provider.resolve() if a.reuse_provider else build_original(out/'provider',fc,'O2')
 if a.reuse_provider:
  prior=json.loads((provider/'BUILD.json').read_text());assert prior['status']=='BUILT'
  assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==prior['compiler']
  for key in ('source_sha256','selected_sha256','object_sha256'):
   assert all(sha(provider/n)==h for n,h in prior[key].items()),key
  assert sha(provider/'ttobj/libttutil.a')==prior['input_archive_sha256']
 manifest=json.loads((ROOT/'integration/dataqual15_hupsel/SPRINT03_SCIENCE_MANIFEST.json').read_text())
 archive=ROOT/'integration/dataqual15_hupsel'/manifest['archive'];assert sha(archive)==manifest['archive_sha256']
 with tarfile.open(archive) as t:
  inputs={name:t.extractfile('original/dtmax-0.0003125/'+name).read() for name in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')}
 assert all(hashlib.sha256(raw).hexdigest()==manifest['members']['original/dtmax-0.0003125/'+name] for name,raw in inputs.items())
 record=json.loads((provider/'BUILD.json').read_text());flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(out)]
 events=[]
 def run(command,cwd,expected=0,timeout=300):
  begin=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=timeout);i=len(events)
  (out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  events.append(dict(command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-begin))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==expected,r.stderr
 output=out/'swapoutput.f90';output.write_text(profile_instrument((provider/'selected/swapoutput.f90').read_text()),encoding='utf-8',newline='\n')
 main=provider/'selected/swap_main.f90';run([fc,*flags,'-c',output,'-o',out/'output.o'],out);run([fc,*flags,'-c',main,'-o',out/'main.o'],out)
 swap=out/'swap.f90';swap.write_text(instrument((provider/'selected/swap.f90').read_text()),encoding='utf-8',newline='\n');run([fc,*flags,'-c',swap,'-o',out/'swap.o'],out)
 for variant in ('unobserved','observed'):
  objects=[out/'main.o',out/'output.o',*[f for f in sorted((provider/'swobj').glob('*.o')) if f.name not in ('swapoutput.o','swap.o')],out/'swap.o' if variant=='observed' else provider/'swobj/swap.o',provider/'ttobj/libttutil.a']
  exe=out/(variant+'.exe');args=[*map(str,objects),'-o',str(exe)];response=out/(variant+'.args');response.write_text('\n'.join('"'+x.replace('\\','/')+'"' for x in args)+'\n',encoding='utf-8')
  run([fc,'@'+str(response)],out)
  case=out/variant;case.mkdir()
  for name,raw in inputs.items():(case/name).write_bytes(raw)
  run([exe],case,100,600);assert (case/'swap.ok').exists()
  (case/'RUN.json').write_text(json.dumps(dict(executable_sha256=sha(exe),inputs={n:sha(case/n) for n in ('swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra')}),indent=2)+'\n')
 for name in ('result_output.csv','hupsel_profiles.csv'):assert (out/'observed'/name).read_bytes()==(out/'unobserved'/name).read_bytes(),name
 (out/'COMPLETE.json').write_text(json.dumps(dict(exact_full_output_control=True,provider=record,observed_executable_sha256=sha(out/'observed.exe'),source_sha256=sha(swap)),indent=2)+'\n')

if __name__=='__main__':main()
