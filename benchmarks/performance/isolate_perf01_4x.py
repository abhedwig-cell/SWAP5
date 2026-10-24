"""Short generated observation of4x interval failures; no production edits."""
import json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE=Path('/tmp/perf01-historical-current-v2');OUT=Path(os.environ.get('PERF01_ISOLATE_OUT','/tmp/perf01-isolate-4x-v1'));OUT.mkdir();meta=json.loads((BASE/'RESULT.json').read_text());events=[]
def run(cmd,cwd,label,cap):
 start=time.perf_counter()
 with(OUT/(label+'.stdout')).open('wb')as o,(OUT/(label+'.stderr')).open('wb')as e:
  try:p=subprocess.run(cmd,cwd=cwd,stdout=o,stderr=e,timeout=cap);code=p.returncode
  except subprocess.TimeoutExpired:code='TIMEOUT'+str(cap)
 events.append(dict(label=label,command=cmd,returncode=code,seconds=time.perf_counter()-start));(OUT/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');return code
source=(BASE/'mod_fmr_serialized_reference_backend.f90').read_text();start=source.index('  real(real64) function fmr_water_flux_temporal_assessment(');end=source.index('  end function',start);body=source[start:end].replace('    logical::available','    integer,save::research_count=0\n    logical::available',1)
body+='''    research_count=research_count+1
    if(mod(research_count,10000)==1)then
      select type(a=>full_state)
      class is(fmr_b110_physical_state_t)
        select type(b=>half_state)
        class is(fmr_b110_physical_state_t)
          write(*,*)'METRIC',research_count,attempt_dt,value,normalized, &
            a%groundwater_level,b%groundwater_level, &
            sum(abs(a%water_content-b%water_content)*self%soil_parameters%dz)+abs(a%ponding_depth-b%ponding_depth), &
            abs(full_outcome%actual_transpiration_amount-half1_outcome%actual_transpiration_amount-half2_outcome%actual_transpiration_amount)/attempt_dt, &
            abs(full_outcome%mass_out-half1_outcome%mass_out-half2_outcome%mass_out)/attempt_dt
          flush(6)
        end select
      end select
    end if
'''
source=source[:start]+body+source[end:]
start=source.index('  real(real64) function fmr_weather_surface_temporal_error(');end=source.index('  end function',start)
weather=source[start:end];needle='        if(.not.ieee_is_finite(value))value=huge(0.0_real64)'
assert weather.count(needle)==1
weather=weather.replace(needle,needle+'''
        if(dt<1.e-5_real64)then
          write(*,*)'HEAD_METRIC',dt,value,head_error,storage_error,full%ponding_depth,half%ponding_depth,minval(full%pressure_head),maxval(full%pressure_head)
          flush(6)
        end if''')
source=source[:start]+weather+source[end:]
needle='            abs(full%boesten_evaporation%saev-half%boesten_evaporation%saev))'
assert source.count(needle)==1
source=source.replace(needle,needle+'''
          if(self%constitutive%step_duration<1.e-5_real64)then
            write(*,*)'BOESTEN_METRIC',value,full%boesten_evaporation%spev,half%boesten_evaporation%spev,full%boesten_evaporation%saev,half%boesten_evaporation%saev,full%ponding_depth,half%ponding_depth
            flush(6)
          end if''')
backend=OUT/'mod_fmr_serialized_reference_backend.f90';backend.write_text(source);cmd=next(e['command']for e in meta['events']if e['label']=='backend-build');cmd=[str(backend)if x==str(BASE/backend.name)else str(OUT/'backend.o')if x==str(BASE/'backend.o')else '-J'+str(OUT)if x.startswith('-J')else x for x in cmd];assert run(cmd,OUT,'backend-build',120)==0
main=(BASE/'main.f90').read_text();needle='      call run_pond_joint_interval(backend,column_id,template,p,candidate_water,segment_forcing,numerical, &';assert main.count(needle)==1
main=main.replace(needle,"      write(*,*)'SEGMENT_BEGIN',j,cursor,endpoint\n      flush(6)\n"+needle)
needle='      if(part%status/=JOINT_OK)then';main=main.replace(needle,"      write(*,*)'SEGMENT_END',j,cursor,endpoint,part%status,part%diagnostics%attempts,part%diagnostics%headcalc_calls\n      flush(6)\n"+needle)
(OUT/'main.f90').write_text(main);cmd=next(e['command']for e in meta['events']if e['label']=='project-build');cmd=[str(OUT/'main.f90')if x==str(BASE/'main.f90')else str(OUT/'backend.o')if x==str(BASE/'backend.o')else str(OUT/'project')if x==str(BASE/'project')else '-J'+str(OUT)if x.startswith('-J')else x for x in cmd];assert run(cmd,OUT,'project-build',120)==0
for arm,stop,restart in [('head',146,'/tmp/perf01-historical-4x-v1/head-stop145/restart.bin'),('flux',1,'-')]:
 folder=OUT/arm;folder.mkdir()
 for n in ['input.nml','input.swp']:(folder/n).write_bytes((Path('/tmp/perf01-historical-4x-v1')/arm/n).read_bytes())
 run([str(OUT/'project'),'input.nml',restart,str(stop),'input.swp'],folder,arm,20)
print(json.dumps(events[-2:],indent=2))
