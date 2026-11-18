"""Count original, mass and forced-polish work without changing stopping."""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess,sys,zipfile
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--days',type=int,default=365);a=p.parse_args();sys.path[:0]=[str(a.source/'app/hybrid_water'),str(a.source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.qualification/'provider';old=a.qualification/'saltfarm-O2-candidate-build';parent=a.qualification/'saltfarm-O2-candidate-full';meta,case=validate_bundle(old,ref,h.SALTFARM);build=out/'build';shutil.copytree(old,build)
(build/'newton_counts.f90').write_text('module newton_counts\nimplicit none\ninteger(8)::counts(8)=0,bins(5)=0\nreal(8)::ratio\nend module\n')
src=(old/'headcalc.f90').read_text(encoding='cp1252');src=src.replace('subroutine headcalc\n','subroutine headcalc\nuse newton_counts\n',1)
anchor='   mass_polish_at = 0';assert src.count(anchor)==1;src=src.replace(anchor,'   counts(1)=counts(1)+1\n'+anchor)
anchor='      if (flnonconv) hybrid_physical_iterations=0';assert src.count(anchor)==1
src=src.replace(anchor,'      counts(8)=counts(8)+1\n      if(flnonconv)then\n       counts(2)=counts(2)+1\n       if(mass_polish_at>0)counts(6)=counts(6)+1\n      endif\n'+anchor)
anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert src.count(anchor)==1
src=src.replace(anchor,anchor+'\n         if(flnonconv)then\n          counts(3)=counts(3)+1\n          if(mass_polish_at>0)counts(7)=counts(7)+1\n         endif')
anchor='            mass_polish_at=numbit';assert src.count(anchor)==1
src=src.replace(anchor,'''            counts(4)=counts(4)+1
            ratio=abs(budget_total+budget_step)/(1d-10*(t1900-budget_start+dt))
            if(ratio<0.01d0)then
             bins(1)=bins(1)+1
            elseif(ratio<0.1d0)then
             bins(2)=bins(2)+1
            elseif(ratio<0.5d0)then
             bins(3)=bins(3)+1
            elseif(ratio<0.9d0)then
             bins(4)=bins(4)+1
            else
             bins(5)=bins(5)+1
            endif
'''+anchor)
anchor='      if (.NOT.flnonconv) then      ! convergence has been reached';assert src.count(anchor)==1;src=src.replace(anchor,'      if(.not.flnonconv)counts(5)=counts(5)+1\n'+anchor)
(build/'headcalc.f90').write_text(src,encoding='cp1252')
main=(old/'swap_main.f90').read_text(encoding='cp1252').replace('use iso_fortran_env, only: output_unit','use newton_counts\nuse iso_fortran_env, only: output_unit');anchor="      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900";assert main.count(anchor)==1;main=main.replace(anchor,"      write(*,'(a,*(1x,i0))')'HYBRID_NEWTON_COUNTS',counts,bins\n"+anchor);(build/'swap_main.f90').write_text(main,encoding='cp1252');commands=[]
for name in ('newton_counts','headcalc','swap_main'):
 cmd=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c',name+'.f90'];commands.append(cmd);r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
exe=build/'trace.exe';objects=[build/f.name if (build/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];cmd=['gfortran','-o',str(exe),*map(str,objects),str(build/'newton_counts.o'),str(build/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(cmd);r=subprocess.run(cmd,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
folder=out/'run';folder.mkdir()
def trial():
 with contextlib.ExitStack() as stack:
  host=h.DailyHost(stack,exe,h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'read_only_newton_trace':h.sha(build/'headcalc.f90')},model=h.SALTFARM.model,project=h.SALTFARM)
  data=[]
  with (folder/'daily.jsonl').open('w') as journal:
   for day in range(1,a.days+1):
    row=host.step(1,checkpoint=day==109);assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
  host.close();return data
data,seconds=bounded(15,trial);assert physical(data)==physical(rows(parent)[:a.days])
if a.days>=109:
 with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(parent/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
words=[s.split()[1:] for s in (folder/'original/donor.stdout').read_text().splitlines() if s.startswith('HYBRID_NEWTON_COUNTS')][-1];values=list(map(int,words));assert len(values)==13;names=['headcalc_calls','original_nonconverged','mass_rejected','forced_polish','accepted','original_nonconverged_after_polish','mass_rejected_after_polish','iterations'];counts=dict(zip(names,values[:8]));assert counts['iterations']==sum(counts[k] for k in ('original_nonconverged','mass_rejected','forced_polish','accepted'))
result=dict(days=a.days,counts=counts,first_mass_pass_ratio_bins=values[8:],bin_edges=['<.01','<.1','<.5','<.9','<=1'],model_seconds=seconds,exact_physical=True,exact_native109=a.days>=109,commands=commands,actual_source={n:h.sha(build/n) for n in ('headcalc.f90','swap_main.f90','newton_counts.f90')});(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2)[:1800])
