"""Read-only copied-source MICRO forcing, private table and attribution observer."""
import argparse,json,shutil,subprocess
from pathlib import Path
import root_oxygen_observer as prior
ROOT=prior.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';MAIN=prior.MAIN
BACKEND='src/runtime/mod_fmr_serialized_reference_backend.f90'
TABLE='src/process/mod_root_micro_matric_flux_table.f90'
sha=prior.sha
TABLE_BLOCK='''
  subroutine observe_micro_table(table,unit,t0,t1,node)
    type(micro_matric_flux_table_t),intent(in)::table
    integer,intent(in)::unit,node
    real(real64),intent(in)::t0,t1
    integer::i
    if(.not.table%ready)error stop 'observer requires ready MICRO table'
    write(unit,'(*(es25.17e3,1x))')t0,t1,real(node,real64),0d0,table%dry_k,table%saturated_k
    do i=1,MICRO_TABLE_POINTS
      write(unit,'(*(es25.17e3,1x))')t0,t1,real(node,real64),real(i,real64),table%m(i),table%k(i)
    end do
  end subroutine
'''
def table_instrument(source):
 anchor='  public :: build_micro_matric_flux_table, evaluate_micro_matric_flux_table\n';assert source.count(anchor)==1
 result=source.replace(anchor,anchor+'  public :: observe_micro_table\n');assert result.count('\ncontains\n')==1
 result=result.replace('\ncontains\n','\ncontains\n'+TABLE_BLOCK)
 assert result.replace(TABLE_BLOCK,'').replace('  public :: observe_micro_table\n','')==source
 return result
def instrument(source,reg):
 pairs=sorted({tuple(x['receipt'][:2]) for x in reg['selected_profiles']})
 condition='.or. &\n'.join(f'(t0=={a:.17e}_real64.and.t1=={b:.17e}_real64)' for a,b in pairs)
 block='''
          block
            integer,save::micro_observer_unit=0,micro_table_unit=0
            integer::mi
            if(CONDITION)then
              if(micro_observer_unit==0)then
                open(newunit=micro_observer_unit,file='micro_trials.dat',status='replace')
                open(newunit=micro_table_unit,file='micro_tables.dat',status='replace')
              end if
              do mi=1,physical%active_nodes
                write(micro_observer_unit,'(*(es25.17e3,1x))')t0,t1,self%root_potential_transpiration, &
                  self%last_observation%micro_drought_loss,self%last_observation%micro_oxygen_loss, &
                  self%last_observation%micro_salinity_loss,coupled%actual_uptake_total, &
                  self%last_observation%deepest_root_oxygen_factor,1d0,real(mi,real64), &
                  real(self%micro_rooted_nodes,real64),real(self%micro_maximum_drought,real64), &
                  real(self%micro_de_willigen%oxygen_mode,real64),real(self%micro_de_willigen%reduction_mode,real64), &
                  real(self%micro_combined_stress_mode,real64),self%micro_de_willigen%root_radius_cm, &
                  self%micro_de_willigen%root_conductance_cm_per_day,self%micro_de_willigen%stem_a0_per_day, &
                  self%micro_de_willigen%stem_a1_per_cm,self%micro_de_willigen%half_leaf_pressure_cm, &
                  self%micro_de_willigen%campbell_exponent,self%micro_de_willigen%pressure_tolerance_cm, &
                  self%micro_de_willigen%newton_tolerance_cm,self%micro_de_willigen%residual_tolerance_cm_per_day, &
                  real(self%micro_de_willigen%max_iterations,real64),optimal_actual, &
                  physical%micro_drought_factor_carry,self%last_observation%micro_drought_factor, &
                  coupled%root_pressure_cm,coupled%leaf_pressure_cm,coupled%reduction_factor, &
                  physical%pressure_head(mi),physical%water_content(mi),self%soil_parameters%dz(mi), &
                  self%micro_root_length_density(mi),oxygen(mi),salinity(mi),combined(mi), &
                  coupled%potential_root_sink(mi),coupled%root_extraction_sink(mi)
                call observe_micro_table(self%micro_tables(mi),micro_table_unit,t0,t1,mi)
              end do
            end if
          end block
'''.replace('CONDITION',condition)
 anchor='          physical%micro_drought_factor_carry=self%last_observation%micro_drought_factor\n';assert source.count(anchor)==1
 result=source.replace(anchor,block+anchor)
 module='module mod_fmr_serialized_reference_backend\n';assert result.count(module)==1
 use='  use mod_root_micro_matric_flux_table,only:observe_micro_table\n'
 result=result.replace(module,module+use)
 assert result.replace(block,'').replace(use,'')==source
 return result
def build(bundle,out,fc):
 out.mkdir();r=json.loads((bundle/'BUILD.json').read_text());events=[]
 assert subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0]==r['compiler']
 for key in ('source_sha256','object_sha256'):assert all(sha(Path(p))==h for p,h in r[key].items())
 assert sha(Path(r['ttutil_archive']))==r['archive_sha256']
 pub=r['publication_provider'];assert sha(Path(pub['source']))==pub['source_sha256'] and sha(Path(pub['object']))==pub['object_sha256']
 for f in bundle.glob('*.mod'):shutil.copyfile(f,out/f.name)
 reg=json.loads((BASE/'MATCHED_MICRO_PREREGISTRATION_20261104.json').read_text())
 replacements={TABLE:table_instrument((ROOT/TABLE).read_text()),BACKEND:instrument((ROOT/BACKEND).read_text(),reg),MAIN:prior.instrument((ROOT/MAIN).read_text())}
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
 assert set(patches)=={TABLE,MAIN,BACKEND}
 exe=out/'observed.exe';args=['-fopenmp','-Wl,--stack,16777216',*map(str,objects),pub['object'],r['ttutil_archive'],'-o',str(exe)]
 response=out/'link.args';response.write_text('\n'.join('"'+v.replace('\\','/')+'"' for v in args)+'\n',encoding='utf-8');run([fc,'@'+str(response)])
 (out/'BUILD.json').write_text(json.dumps(dict(baseline=r,patches=patches,executable_sha256=sha(exe),link_response_sha256=sha(response),link_arguments=args,events=events),indent=2)+'\n');return exe
def qualify(opt,bundle,case,baseline,out,fc):
 out.mkdir();exe=build(bundle,out/'build',fc)
 prior.run(exe,case,case/'checkpoint-524.bin',out/'whole',537,True)
 prior.run(exe,case,out/'whole/checkpoint-537.bin',out/'strict-own-537')
 assert (out/'whole/checkpoint.bin').read_bytes()==(baseline/'whole/checkpoint.bin').read_bytes()==(out/'strict-own-537/checkpoint.bin').read_bytes()
 for name in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):assert (out/'whole'/name).read_bytes()==(baseline/'whole'/name).read_bytes(),name
 for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:assert prior.daily(out/'strict-own-537'/name)==[r for r in prior.daily(out/'whole'/name) if float(r[clock])>537]
 for name in ('root_accepted.dat','root_nodes.dat','micro_trials.dat','micro_tables.dat'):assert (out/'strict-own-537'/name).read_text().splitlines()==[r for r in (out/'whole'/name).read_text().splitlines() if float(r.split()[0])>=537]
 (out/'RESULT.json').write_text(json.dumps(dict(optimization=opt,exact_prior_outputs=True,strict_own_537=True,scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in ('o0','o2','case','prior','output','compiler'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir()
 for opt,b in [('O0',a.o0),('O2',a.o2)]:qualify(opt,b.resolve(),a.case.resolve(),a.prior.resolve()/opt,out/opt,a.compiler.resolve())
