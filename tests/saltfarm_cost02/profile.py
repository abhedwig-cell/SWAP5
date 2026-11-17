"""Private same-source phase profile; original mathematics/order are untouched."""
from pathlib import Path
import argparse,contextlib,json,shutil,subprocess,sys,time,zipfile
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'));sys.path.insert(0,str(ROOT/'tools/solute'))
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows
p=argparse.ArgumentParser();p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
reference=a.qualification/'provider';original=a.qualification/'saltfarm-O2-candidate-build';parent=a.qualification/'saltfarm-O2-candidate-full';meta,case=validate_bundle(original,reference,h.SALTFARM);build=out/'build';shutil.copytree(original,build)
source=(build/'swap.f90').read_text(encoding='cp1252');source=source.replace('end module hybrid_day_window','real(8)::prof_cpu(5)=0d0,prof_start,prof_finish\ninteger(8)::prof_ticks(5)=0,prof_count(5)=0,prof_begin,prof_end,prof_rate\nend module hybrid_day_window')
source=source.replace('use hybrid_day_window, only: return_at_day_end, budget_step, budget_total, checkpoint_clock','use hybrid_day_window, only: return_at_day_end, budget_step, budget_total, checkpoint_clock, &\nprof_cpu,prof_start,prof_finish,prof_ticks,prof_count,prof_begin,prof_end,prof_rate')
lines=['      if (swcrop == 1) call RootExtraction(2)','         if (.NOT.fldecdt) call SoilWater(2)','      call SoilWater(3)','      if (swhea > 0) call SoilTemperature(2)','      if (swsolu > 0) call Solute(2)']
for i,line in enumerate(lines,1):
 assert source.count(line)==1,line
 source=source.replace(line,f'call system_clock(prof_begin,prof_rate)\ncall cpu_time(prof_start)\n{line}\ncall cpu_time(prof_finish)\ncall system_clock(prof_end)\nprof_cpu({i})=prof_cpu({i})+prof_finish-prof_start\nprof_ticks({i})=prof_ticks({i})+prof_end-prof_begin\nprof_count({i})=prof_count({i})+1')
(build/'swap.f90').write_text(source,encoding='cp1252');source=(build/'swap_main.f90').read_text(encoding='cp1252');source=source.replace('use iso_fortran_env, only: output_unit','use hybrid_day_window, only: prof_cpu,prof_ticks,prof_count,prof_rate\nuse iso_fortran_env, only: output_unit')
anchor="      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900";assert source.count(anchor)==1
source=source.replace(anchor,"      write(*,*)'PROFILE_NATIVE',prof_count,prof_cpu,real(prof_ticks,8)/real(prof_rate,8)\n"+anchor);(build/'swap_main.f90').write_text(source,encoding='cp1252');commands=[]
for name in ('swap','swap_main'):
 command=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(reference/'build/swap-obj'),'-I',str(reference/'build/ttutil-obj'),'-c',name+'.f90'];commands.append(command);r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
objects=[build/x.name if (build/x.name).exists() else x for x in sorted((reference/'build/swap-obj').glob('*.o'))];exe=build/'profile.exe';command=['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(reference/'build/ttutil-obj/libttutil.a')];commands.append(command);r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
folder=out/'run';folder.mkdir()
def trial():
 with contextlib.ExitStack() as stack:
  host=h.DailyHost(stack,exe,h.executable(original,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'diagnostic_profile':h.sha(build/'swap.f90')},model=h.SALTFARM.model,project=h.SALTFARM)
  data=[]
  with (folder/'daily.jsonl').open('w') as journal:
   for day in range(1,366):
    v=host.step(1,checkpoint=day==109);data.append(v);journal.write(json.dumps(v)+'\n');assert v['committed']
  host.close();return data
data,seconds=bounded(15,trial);assert physical(data)==physical(rows(parent)[:365])
with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(parent/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
line=[s for s in (folder/'original/donor.stdout').read_text().splitlines() if s.strip().startswith('PROFILE_NATIVE')][-1].split()[1:];assert len(line)==15
result=dict(days=365,instrumented_seconds=seconds,exact_all_physical=True,exact_native109=True,phases={name:dict(calls=int(line[i]),cpu_seconds=float(line[i+5]),wall_seconds=float(line[i+10])) for i,name in enumerate(['root','water_solve','water_update','heat','solute'])},commands=commands,source_hashes={n:h.sha(build/n) for n in ('swap.f90','swap_main.f90')},note='Diagnostic timings; per-call CPU clock quantization and overlapping instrumentation overhead prevent headline speed claims')
(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps(result['phases'],indent=2),seconds,flush=True)
