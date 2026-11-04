"""Copied-source actual oxygen forcing observer; no state publication."""
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
import root_oxygen_observer as prior
ROOT=prior.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90';MAIN=prior.MAIN
sha=prior.sha
def instrument(source,registration):
 pairs=sorted({tuple(x['receipt'][:2]) for x in registration['selected_profiles']})
 condition='.or. &\n'.join(f'(t0=={a:.17e}_real64.and.t1=={b:.17e}_real64)' for a,b in pairs)
 block='''
          block
            integer,save::oxygen_observer_unit=0
            integer::oi
            real(real64)::ow,od,of
            if(CONDITION)then
              if(oxygen_observer_unit==0)open(newunit=oxygen_observer_unit,file='oxygen_trials.dat',status='replace')
              do oi=1,size(self%soil_parameters%dz)
                ow=1d0/self%bartholomeus%specific_root_length_m_kg;od=0d0;of=1d0
                if(oi<=oxygen_nodes)then
                  od=self%crop_oxygen%root_density_kg_m3(oi);of=oxygen_factors(oi)
                end if
                write(oxygen_observer_unit,'(*(es25.17e3,1x))')t0,t1, &
                  self%substep_root_diagnostics%potential_uptake_total, &
                  self%substep_root_diagnostics%drought_reduction_total, &
                  self%substep_root_diagnostics%oxygen_reduction_total+ &
                  oxygen_base%actual_uptake_total-oxygen_final%actual_uptake_total, &
                  0d0,oxygen_final%actual_uptake_total,oxygen_factors(oxygen_nodes),1d0, &
                  real(oi,real64),real(oxygen_nodes,real64), &
                  hydraulic_start%pressure_head(oi),hydraulic_start%water_content(oi),oxygen_thermal%temperature_c(oi), &
                  ow,od,oxygen_base%root_extraction_sink(oi),oxygen_final%root_extraction_sink(oi),of, &
                  atmospheric_ctop,self%crop_oxygen%air_temperature_c,self%hydraulic_parameters%cofgen(1:7,oi), &
                  self%soil_parameters%dz(oi), &
                  self%bartholomeus%soil%soil(oi)%percent_org_mat/100d0, &
                  self%bartholomeus%soil%soil(oi)%percent_sand/ &
                  (100d0-self%bartholomeus%soil%soil(oi)%percent_org_mat), &
                  self%bartholomeus%soil%soil(oi)%soil_density, &
                  self%bartholomeus%crop%c_mroot,self%bartholomeus%crop%f_senes,self%bartholomeus%crop%q10_root, &
                  self%bartholomeus%crop%specific_resp_humus,self%bartholomeus%crop%q10_microbial, &
                  self%bartholomeus%crop%microbial_shape_m,self%bartholomeus%crop%root_shape_m, &
                  self%bartholomeus%crop%root_radius_m,self%bartholomeus%crop%max_resp_factor
              end do
            end if
          end block
'''.replace('CONDITION',condition)
 anchor='          if(oxygen_status/=FMR_BARTHOLOMEUS_EXEC_OK) return\n'
 assert source.count(anchor)==1
 result=source.replace(anchor,anchor+block);assert result.replace(block,'')==source
 return result
def build(bundle,out,fc):
 out.mkdir();r=json.loads((bundle/'BUILD.json').read_text());events=[]
 assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==r['compiler']
 for key in ('source_sha256','object_sha256'):assert all(sha(Path(p))==h for p,h in r[key].items())
 assert sha(Path(r['ttutil_archive']))==r['archive_sha256']
 pub=r['publication_provider'];assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(pub['object']))==pub['object_sha256']
 for f in bundle.glob('*.mod'):shutil.copyfile(f,out/f.name)
 reg=json.loads((BASE/'MATCHED_OXYGEN_PREREGISTRATION_20261104.json').read_text())
 replacements={BACKEND:instrument((ROOT/BACKEND).read_text(),reg),MAIN:prior.instrument((ROOT/MAIN).read_text())}
 flags=[v for v in r['flags'] if not v.startswith(('-I','-J'))]+['-I'+str(out),'-J'+str(out)]
 objects=list(map(Path,r['object_sha256']));patches={}
 def run(cmd):
  p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);i=len(events)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr)
  events.append(dict(command=list(map(str,cmd)),returncode=p.returncode));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr
 for i,name in enumerate(r['source_sha256']):
  path=Path(name)
  if path.is_relative_to(ROOT) and path.relative_to(ROOT).as_posix() in replacements:
   relative=path.relative_to(ROOT).as_posix();src=out/path.name;src.write_text(replacements[relative],encoding='utf-8',newline='\n')
   obj=out/(str(i)+'.o');run([fc,*flags,'-c',src,'-o',obj]);objects[i]=obj
   patches[relative]=dict(source=src.name,source_sha256=sha(src),object=obj.name,object_sha256=sha(obj))
 assert set(patches)=={MAIN,BACKEND}
 exe=out/'observed.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),pub['object'],r['ttutil_archive'],'-o',str(exe)]
 response=out/'link.args';response.write_text('\n'.join('"'+v.replace('\\','/')+'"' for v in args)+'\n',encoding='utf-8');run([fc,'@'+str(response)])
 (out/'BUILD.json').write_text(json.dumps(dict(baseline=r,patches=patches,executable_sha256=sha(exe),link_response_sha256=sha(response),link_arguments=args,events=events),indent=2)+'\n');return exe
def qualify(opt,bundle,case,baseline,out,fc):
 out.mkdir();exe=build(bundle,out/'build',fc)
 prior.run(exe,case,case/'checkpoint-524.bin',out/'whole',537,True)
 prior.run(exe,case,out/'whole/checkpoint-537.bin',out/'strict-own-537')
 assert (out/'whole/checkpoint.bin').read_bytes()==(baseline/'whole/checkpoint.bin').read_bytes()==(out/'strict-own-537/checkpoint.bin').read_bytes()
 for name in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):
  assert (out/'whole'/name).read_bytes()==(baseline/'whole'/name).read_bytes(),name
 for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:assert prior.daily(out/'strict-own-537'/name)==[r for r in prior.daily(out/'whole'/name) if float(r[clock])>537]
 for name in ('root_accepted.dat','root_nodes.dat','oxygen_trials.dat'):
  assert (out/'strict-own-537'/name).read_text().splitlines()==[r for r in (out/'whole'/name).read_text().splitlines() if float(r.split()[0])>=537]
 (out/'RESULT.json').write_text(json.dumps(dict(optimization=opt,exact_prior_outputs=True,strict_own_537=True,scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('o0','o2','case','prior','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 for opt,b in [('O0',a.o0),('O2',a.o2)]:qualify(opt,b.resolve(),a.case.resolve(),a.prior.resolve()/opt,out/opt,a.compiler.resolve())
