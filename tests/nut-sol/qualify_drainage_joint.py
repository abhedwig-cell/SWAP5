"""Execute real positive drainage, accepted partition, rejection/retry and ABA."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--boesten',action='store_true');a=ap.parse_args()
 out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());m=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text());events=[]
 def run(cmd):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);i=len(events)
  for stream in ['stdout','stderr']:(out/f'{i:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode))
  (out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,r.stdout.decode()+r.stderr.decode()
 src=(ROOT/'tests/nut-sol/test_root_substep_transaction.f90').read_text().split(' base=water;original=chemical;other=water;other_chemical=chemical')[0]
 src=src.replace(' implicit none',''' use mod_fmr_drainage_response_binding,only:FMR_DRAIN_VARIANT_DRAMET3
 use mod_drainage_dramet3_response
 use mod_drainage_spatial_distribution
 use mod_b111_profile_groundwater_projection
 implicit none''')
 src=src.replace(' initial%pressure_head=[-110d0,-110d0]',' initial%pressure_head=[-.5d0,1d0]')
 # The original declaration shares a line with the assignment.
 src=src.replace('initial%pressure_head=[-110d0,-110d0]','initial%pressure_head=[-.5d0,1d0]')
 src=src.replace('initial%groundwater_level=-3d0','initial%groundwater_level=-1d0')
 src=src.replace('type(fmr_substep_root_forcing_t)::saved_root','''type(fmr_substep_root_forcing_t)::saved_root
 type(b111_profile_groundwater_projection_t)::projection
 type(drainage_node_transfer_t)::partition
 type(drainage_distribution_diagnostics_t)::partition_diagnostic
 type(dramet3_level_result_t)::scalar
 type(fmr_b110_physical_parameters_t)::bad
 real(real64)::drained''')
 src=src.replace(' config%transaction%temporal_tolerance=1d-4',' config%transaction%temporal_tolerance=1d-3')
 src=src.replace(' call bind_b110_default_mvg_provider(provider,hp,.001d0)', ''' hp%continuous_saturation_conductivity=.true.;p%prepared_default_mvg=hp;p%prepared_default_mvg_available=.true.
 p%picard_conductivity_iteration=.true.;p%max_iterations=64
 call bind_b110_default_mvg_provider(provider,hp,.001d0)''')
 src=src.replace(" call backend%initialize(top);call fresh%initialize(top)",''' p%drainage_response_active=.true.;p%drainage_qbot_smooth_freatic_projection=.true.
 allocate(p%drainage_response_levels(1),p%drainage_trial_distribution,forcing%drainage_response_controls(1))
 deallocate(forcing%drainage_flux_by_level)
 p%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_DRAMET3
 p%drainage_response_levels(1)%dramet3=dramet3_level_parameters_t(-2d0,500d0,220d0,3,1,.false.)
 call initialize_dramet3_channel_control(p%drainage_response_levels(1)%dramet3_channel,0d0,36000d0, &
  [36000d0,36001d0],[-1.5d0,-1.4d0],s)
 call check(s==0,'channel initialization')
 p%drainage_trial_distribution%active_nodes=numnod
 p%drainage_trial_distribution%dz=dz;p%drainage_trial_distribution%zbotcp=z-.5d0*dz
 p%drainage_trial_distribution%saturated_conductivity=p%cofgen(3,:)
 p%drainage_trial_distribution%horizontal_anisotropy_factor=[1d0,2d0]
 p%drainage_trial_distribution%drain_spacing=1000d0
 call backend%initialize(top);call fresh%initialize(top)''')
 src+=''' base=water;original=chemical;other=water;other_chemical=chemical
 allocate(forcing%substep_root)
 forcing%substep_root%parameters=root_water_uptake_parameters_t(numnod,-100d0,-100d0,-120d0,.1d0,.5d0)
 forcing%substep_root%request%potential_transpiration=.0001d0
 forcing%substep_root%request%rooted_nodes=2
 forcing%substep_root%request%cumulative_root_fraction=[0d0,.5d0,1d0]
 supply%t0=0d0;supply%t1=.2d0
 call snapshot('original.bin')
 invalid=supply;invalid%rain_c=-1d0
 call run_pond_joint_interval(backend,column,template,p,water,forcing,config,chemical,invalid,0d0,.2d0,result)
 print *, 'REJECT_DEBUG',result%status,result%water%status,result%diagnostics
 observation=backend%observation()
 print *, 'DRAIN_DEBUG',observation%drainage_response%status,observation%drainage_response_evaluations, &
  observation%drainage_projected_groundwater_level,observation%drainage_response_signed_exchange_native
 print *, 'SOLVE_DEBUG',observation%solver_status,observation%solver_diagnostics
 call check(result%status==JOINT_CHEMICAL_REJECTED.and.result%water%completed,'real chemical rejection')
 call snapshot('rejected.bin')
 call run_pond_joint_interval(backend,column,template,p,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status==JOINT_OK,'retry accepts')
 call check(abs(result%water%mass%residual)<1d-10.and.abs(result%chemical%residual)<1d-10,'joint mass')
 observation=backend%observation();drained=0d0
 call check(observation%accepted_water_flux_trace_available,'accepted drainage trace')
 do i=1,size(observation%accepted_water_flux_substeps)
  associate(t=>observation%accepted_water_flux_substeps(i))
   call evaluate_b111_profile_groundwater_projection(z,disnod(:numnod),t%root_pressure_head_start, &
    t%pond_start_cm,projection)
   call check(projection%valid.and.projection%level_present,'actual trial groundwater')
   call evaluate_dramet3_level(p%drainage_response_levels(1)%dramet3,p%drainage_response_levels(1)%dramet3_channel, &
    projection%level_cm,t%t1,scalar)
   call check(scalar%available.and.scalar%signed_exchange_cm_per_day>0d0,'positive actual scalar')
   view%groundwater_level=projection%level_cm
   call distribute_single_level_signed_divdra(p%drainage_trial_distribution,view,scalar%signed_exchange_cm_per_day, &
    partition,partition_diagnostic)
   call check(partition_diagnostic%status==DRAIN_DIST_OK,'existing DIVDRA owner')
   call check(all(t%drainage_sink_by_level(1,:)==partition%soil_to_drain_rate),'exact trial-local partition')
   call check(abs(sum(t%drainage_sink_by_level)-scalar%signed_exchange_cm_per_day)<1d-15,'scalar booked once')
   drained=drained+sum(t%drainage_sink_by_level)*(t%t1-t%t0)
  end associate
 end do
 call check(drained>0d0,'positive accepted drainage');call snapshot('retry.bin')
 water=base;chemical=original
 call run_pond_joint_interval(fresh,column,template,p,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status==JOINT_OK,'fresh accepts');call snapshot('fresh.bin')
 water=base;chemical=original;bad=p;bad%drainage_response_levels(1)%dramet3%allocation_mode=1
 call run_pond_joint_interval(backend,column,template,bad,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status/=JOINT_OK,'unqualified infiltration rejects');call snapshot('invalid.bin')
 bad=p;bad%drainage_trial_distribution%horizontal_anisotropy_factor(1)=-1d0
 call run_pond_joint_interval(backend,column,template,bad,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status/=JOINT_OK,'invalid geometry rejects');call snapshot('geometry.bin')
 bad=p;bad%drainage_response_levels(1)%dramet3%drainage_resistance_day=700d0
 call run_pond_joint_interval(backend,column,template,bad,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status==JOINT_OK,'B accepts')
 water=base;chemical=original
 call run_pond_joint_interval(backend,column,template,p,water,forcing,config,chemical,supply,0d0,.2d0,result)
 call check(result%status==JOINT_OK,'A again accepts');call snapshot('again.bin')
 print *, 'DRAINAGE_TRIAL_PARTITION_REJECTION_RETRY_ABA_PASS',drained
contains
 subroutine check(ok,why)
  logical,intent(in)::ok
  character(*),intent(in)::why
  if(.not.ok)then
   print *,why;error stop 1
  end if
 end subroutine
 subroutine snapshot(path)
  character(*),intent(in)::path
  call write_matrix_joint_restart_file(path,column,template,p%parameter_set_id,water,chemical,s,allow_surface_mass=.true.)
  call check(s==JOINT_OK,'snapshot')
 end subroutine
end program
'''
 if a.boesten:
  src=src.replace(' implicit none',' use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t\n implicit none')
  src=src.replace(' real(real64)::drained',' class(transaction_state_t),allocatable::endpoint_state\n real(real64)::drained')
  src=src.replace('allocate(forcing%pond_input);forcing%pond_input%ponding_max_cm=1d6', '''p%boesten_evaporation_active=.true.;allocate(p%boesten_evaporation,forcing%boesten_evaporation)
 p%boesten_evaporation%cofred=.79d0
 forcing%boesten_evaporation%ponding_max_cm=1d6
 forcing%boesten_evaporation%precipitation_rate_cm_per_day=.1d0
 forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=.002d0''')
  src=src.replace('call fmr_new_b110_committed_state(water,column%column_id,initial,0d0,ok)', '''template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
 call fmr_new_b110_boesten_evaporation_committed_state(water,column%column_id,initial, &
  boesten_evaporation_state_t(.03d0,.03d0),0d0,ok)''')
  src=src.replace('supply%t0=0d0;supply%t1=.2d0','supply%t0=0d0;supply%t1=.2d0;supply%rain_rate=.1d0;supply%exact_empty_pool_chemistry=.true.')
  src=src.replace("call snapshot('retry.bin')",'''call snapshot('retry.bin')
 call water%snapshot(endpoint_state,ok);call check(ok,'event endpoint snapshot')
 select type(endpoint_state)
 type is(fmr_b110_boesten_evaporation_state_t)
  call check(endpoint_state%ponding_depth>1d-10,'dry to wet event actually occurred')
  call check(endpoint_state%boesten_evaporation%spev==0d0.and.endpoint_state%boesten_evaporation%saev==0d0, &
   'existing Boesten wet endpoint reset')
 class default
  error stop 1
 end select''')
 path=out/'joint.f90';path.write_text(src)
 flags=[f for f in m['flags']if not f.startswith('-J')]+['-J'+str(out)]
 objects=[p for p in m['reused_artifact_sha256']if p.endswith('.o')];archive=[p for p in m['reused_artifact_sha256']if p.endswith('/libttutil.a')]
 assert len(objects)==193 and len(archive)==1
 assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in m['input_sha256'].items())
 assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in m['reused_artifact_sha256'].items())
 run(m['compiler_command']+flags+[path,*objects,*archive,'-o',out/'joint']);run([out/'joint'])
 for x,y in [('original.bin','rejected.bin'),('original.bin','invalid.bin'),('original.bin','geometry.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin')]:assert(out/x).read_bytes()==(out/y).read_bytes(),(x,y)
 (out/'result.json').write_text(json.dumps(dict(status='DRAINAGE_JOINT_PASS',boesten=a.boesten,optimization=bundle['optimization'],events=events,driver_sha256=hashlib.sha256(src.encode()).hexdigest()),indent=2)+'\n')
 print('DRAINAGE_JOINT_PASS')
if __name__=='__main__':main()
