"""Build explicit RFM bridge with bounds checks and test-only sorptivity telemetry."""
from pathlib import Path
import os,subprocess,sys
root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run(['git','rev-parse','HEAD'],cwd=root,check=True)
base=(root/'tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().split('MODULE_SRC=(')[1].split('\n)')[0].split()
extra=[
'src/runtime/mod_groundwater_coupling_contract.f90',
'src/runtime/mod_groundwater_swap_forcing_adapter.f90',
'src/runtime/mod_groundwater_swap_transaction_participant.f90',
'src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90',
'src/runtime/mod_fmr_groundwater_swap_participant.f90',
'src/runtime/mod_groundwater_interface_mass_ledger.f90',
'src/runtime/mod_groundwater_tile_aggregation.f90',
'src/runtime/mod_groundwater_multiswap_types.f90',
'src/runtime/mod_modflow6_swap_predictor_response.f90',
'src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90',
'src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90',
'src/runtime/mod_modflow6_swap_predictor_origin.f90',
'src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90',
'src/runtime/mod_modflow6_multiswap_cell_response.f90',
'src/runtime/mod_modflow6_linear_response_backend.f90',
'src/runtime/mod_modflow6_api_binding.f90',
'src/adapter/mod_modflow6_fgc34_c_bridge.f90',
 'tests/fpe/support/mod_fpe_a28_fgc45_rfm_bridge.f90']
sources=subprocess.check_output(['python3','tests/support/augment_bartholomeus_backend_sources.py',*(base+extra)],cwd=root,text=True).split()
# Optional field-depth grid is a generated build-local replacement for the
# four-node FSI grid stub. Only the grid declaration changes; all state and
# coupling code remains the same qualification-only bridge.
field_grid=None
if os.environ.get('A28_FIELD_DEPTH')=='1':
 grid_source=root/'tests/fsi/fsi04_real_headcalc_stubs.f90'
 grid_text=grid_source.read_text()
 old=[
  '  integer, parameter :: numnod = 4',
  '  real(8), parameter :: z(numnod) = [-0.25d0, -0.75d0, -1.50d0, -2.50d0]',
  '  real(8), parameter :: dz(numnod) = [0.50d0, 0.50d0, 1.00d0, 1.00d0]',
  '  real(8), parameter :: disnod(numnod+1) = 1.0d0',
 ]
 assert all(grid_text.count(x)==1 for x in old),'unexpected FSI grid stub declaration'
 new=[
  '  integer, parameter :: numnod = 10',
  '  real(8), parameter :: z(numnod) = [-5d0,-15d0,-25d0,-35d0,-45d0,-55d0,-65d0,-75d0,-85d0,-95d0]',
  '  real(8), parameter :: dz(numnod) = 10d0',
  '  real(8), parameter :: disnod(numnod+1) = 10d0',
 ]
 for before,after in zip(old,new,strict=True):grid_text=grid_text.replace(before,after,1)
 field_grid=out/'a28_field_depth_grid_stubs.f90';field_grid.write_text(grid_text)
# Optional retry-cause probe: compile a build-local HeadCalc source copy with
# prints at the existing typed-bottom invalidation and iteration-budget exits.
# The repository production source is never edited by this diagnostic path.
retry_headcalc=None
headcalc_path=root/'src/legacy/b1_10_port/headcalc.f90'
if os.environ.get('A28_RETRY_CAUSE_DIAGNOSTICS')=='1':
 headcalc_text=headcalc_path.read_text()
 declaration='   real(8)                          :: factor, Fmax\n'
 assert headcalc_text.count(declaration)==1,'unexpected HeadCalc diagnostic declaration'
 headcalc_text=headcalc_text.replace(declaration,declaration+'''   real(8)                          :: a28_probe_head_error, a28_probe_head_tolerance
''',1)
 initial_invalid='''   if (typed_bottom_invalid) then
      state%fldecdt=.true.
'''
 assert headcalc_text.count(initial_invalid)==1,'unexpected initial typed-bottom invalidation branch'
 headcalc_text=headcalc_text.replace(initial_invalid,'''   if (typed_bottom_invalid) then
      write(*,*) 'A28_RETRY_TYPED_INVALID phase=initial swbotb=',swbotb
      state%fldecdt=.true.
''',1)
 iterate_invalid='''         if (typed_bottom_invalid) then
            state%fldecdt=.true.
'''
 assert headcalc_text.count(iterate_invalid)==1,'unexpected iterative typed-bottom invalidation branch'
 headcalc_text=headcalc_text.replace(iterate_invalid,'''         if (typed_bottom_invalid) then
            write(*,*) 'A28_RETRY_TYPED_INVALID phase=iterate swbotb=',swbotb,' iteration=',solver_numbit
            state%fldecdt=.true.
''',1)
 budget_exit='''   ! Preserve the legacy DO-variable value after normal loop exhaustion.
   state%numbit = solver_numbit
'''
 assert headcalc_text.count(budget_exit)==1,'unexpected HeadCalc iteration-budget exit'
 headcalc_text=headcalc_text.replace(budget_exit,budget_exit+'''   write(*,*) 'A28_RETRY_BUDGET', 'iterations=',solver_numbit-1,'limit=',MaxIt1, &
        'max_abs_balance=',maxval(abs(fsi_ws%residual(1:NN))),'balance_tol=',CritDevBalCp, &
        'abs_total_balance=',abs(sum1),'total_balance_tol=',CritDevBalTot,'typed_invalid=',typed_bottom_invalid
   do i=1,NN
      if (abs(fsi_ws%residual(i)) > CritDevBalCp) &
           write(*,*) 'A28_RETRY_BALANCE_FAIL', 'node=',i,'residual=',fsi_ws%residual(i),'tol=',CritDevBalCp
      a28_probe_head_error=abs(state%h(i)-fsi_ws%old_head(i))
      if (abs(fsi_ws%old_head(i)) < 1.0d0) then
         a28_probe_head_tolerance=CritDevh2Cp
      else
         a28_probe_head_tolerance=CritDevh1Cp*abs(fsi_ws%old_head(i))
      end if
      if (a28_probe_head_error > a28_probe_head_tolerance) &
           write(*,*) 'A28_RETRY_HEAD_FAIL', 'node=',i,'head_error=',a28_probe_head_error,'tol=',a28_probe_head_tolerance
   end do
   if (abs(sum1) > CritDevBalTot) &
        write(*,*) 'A28_RETRY_TOTAL_BALANCE_FAIL', 'sum=',sum1,'tol=',CritDevBalTot
''',1)
 retry_headcalc=out/'a28_retry_probe_headcalc.f90';retry_headcalc.write_text(headcalc_text)
if os.environ.get('A28_TYPED_STABLE_STORAGE_INCREMENT')=='1':
 headcalc_text=retry_headcalc.read_text() if retry_headcalc is not None else headcalc_path.read_text()
 anchor='   if (provider_constitutive_active .and. matrix_area_scaling_active()) then'
 assert headcalc_text.count(anchor)==1
 headcalc_text=headcalc_text.replace(anchor,'   if (provider_constitutive_active) then',1)
 retry_headcalc=out/'a28_stable_storage_headcalc.f90';retry_headcalc.write_text(headcalc_text)
if os.environ.get('A28_SATURATED_EQUATION_DIAGNOSTICS')=='1':
 assert retry_headcalc is not None
 headcalc_text=retry_headcalc.read_text()
 anchor='      if (.NOT.flnonconv) then      ! convergence has been reached'
 assert headcalc_text.count(anchor)==1
 headcalc_text=headcalc_text.replace(anchor,anchor+'''
         if(dt<1.0d-7.and.swbotb==2)then
           write(*,*) 'A28_SAT_EQUATION dt=',dt,' q=',state%qbot,' residual=',fsi_ws%residual(1:NN)
           write(*,*) 'A28_SAT_HEAD old=',state%hm1(1:NN),' new=',state%h(1:NN)
           write(*,*) 'A28_SAT_WATER delta=',fsi_ws%provider_water_content_increment(1:NN),' cap=',state%dimoca(1:NN)
           write(*,*) 'A28_SAT_FLUX kmean=',state%kmean(1:NN+1),' source=',fsi_ws%source(1:NN),' sink=',fsi_ws%sink(1:NN)
         end if
''',1)
 retry_headcalc=out/'a28_saturated_observed_headcalc.f90';retry_headcalc.write_text(headcalc_text)
if os.environ.get('A28_POSTFILL_TERMINAL_PRESSURE_PROTOTYPE')=='1':
 assert os.environ.get('A28_FIELD_DEPTH')=='1' and os.environ.get('A28_TYPED_STABLE_STORAGE_INCREMENT')=='1'
 assert os.environ.get('A28_SATURATED_EQUATION_DIAGNOSTICS')!='1'
 headcalc_text=retry_headcalc.read_text()
 anchor='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, solver_numbit'
 assert headcalc_text.count(anchor)==1
 headcalc_text=headcalc_text.replace(anchor,anchor+', a28_crossing_node',1)
 anchor='      if (.NOT.flnonconv) then      ! convergence has been reached'
 assert headcalc_text.count(anchor)==1
 headcalc_text=headcalc_text.replace(anchor,anchor+'''
         if(swbotb==2.and.swkimpl==0.and.provider_constitutive_active)then
           a28_crossing_node=0
           do i=2,NN
             if(state%hm1(i)<0.0d0.and.state%h(i)>=0.0d0.and.all(state%h(i:NN)>=0.0d0))then
               a28_crossing_node=i
               exit
             end if
           end do
           if(a28_crossing_node>0)then
             if(all(fsi_ws%source(a28_crossing_node:NN)==0.0d0).and. &
                all(fsi_ws%sink(a28_crossing_node:NN)==0.0d0).and. &
                all(state%kmean(a28_crossing_node:NN)>0.0d0))then
               do i=a28_crossing_node,NN
                 state%h(i)=state%h(i-1)+grid_disnod(i)*(1.0d0+state%qbot/state%kmean(i))
               end do
             end if
           end if
         end if
''',1)
 retry_headcalc=out/'a28_terminal_pressure_headcalc.f90';retry_headcalc.write_text(headcalc_text)
# Solver-only causal frontier: freeze RFM physical/accounting tolerance independently.
separated_backend=None
backend_path=root/'src/runtime/mod_fmr_serialized_reference_backend.f90'
if os.environ.get('A28_SEPARATE_RFM_TOLERANCE')=='1':
 backend_text=backend_path.read_text()
 before='max(self%compartment_balance_tolerance,FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM),rfm_live)'
 assert backend_text.count(before)==1
 backend_text=backend_text.replace(before,'1.0e-12_real64,rfm_live)',1)
 if os.environ.get('A28_TEMPORAL_COMPONENT_DIAGNOSTICS')=='1':
  anchor='        value = max(value, maxval(abs(full%rfm%endpoint_water_cm-half%rfm%endpoint_water_cm)))'
  assert backend_text.count(anchor)==1
  backend_text=backend_text.replace(anchor,anchor+'''
        if(value>1.0e-5_real64)write(*,*) 'A28_TEMPORAL_COMPONENTS error=',value, &
          ' head=',maxval(abs(full%pressure_head-half%pressure_head)), &
          ' pond=',abs(full%ponding_depth-half%ponding_depth), &
          ' groundwater=',abs(full%groundwater_level-half%groundwater_level), &
          ' matrix=',maxval(abs((full%water_content-half%water_content)*self%soil_parameters%dz)), &
          ' mb=',abs(full%rfm%mb_water_cm-half%rfm%mb_water_cm), &
          ' endpoint=',maxval(abs(full%rfm%endpoint_water_cm-half%rfm%endpoint_water_cm)), &
          ' node=',maxloc(abs(full%pressure_head-half%pressure_head),dim=1), &
          ' full_heads=',full%pressure_head,' half_heads=',half%pressure_head
''',1)
 if os.environ.get('A28_PARTITION_AWARE_PREFLIGHT')=='1':
  declaration='    real(real64) :: rfm_preferential_input_cm, rfm_deep_receipt_cm'
  assert backend_text.count(declaration)==1
  backend_text=backend_text.replace(declaration,declaration+', a28_original_supply',1)
  before='        if(.not.rfm_live%valid)return'
  assert backend_text.count(before)==1
  repair='''        if(.not.rfm_live%valid.and.rfm_live%surface%status==2.and. &
             rfm_live%activation%activation%status==1.and.rfm_physical%ponding_depth==0.0_real64.and. &
             self%rfm_surface_forcing%potential_bare_soil_evaporation_cm_per_day==0.0_real64.and. &
             self%rfm_surface_forcing%potential_pond_evaporation_cm_per_day==0.0_real64)then
          a28_original_supply=rfm_preflight%net_potential_surface_flux
          call bind_b110_dynamic_top_boundary_solver_provider(self%rfm_top_provider,self%soil_parameters, &
               self%hydraulic_parameters,self%swkmean,rfm_physical%ponding_depth,step_duration, &
               rfm_live%activation%activation%matrix_rate_cm_per_day,0.0_real64,0.0_real64,0.0_real64, &
               0.0_real64,0.0_real64,self%rfm_surface_forcing%ponding_max_cm, &
               self%rfm_surface_forcing%runoff_resistance_day,self%rfm_surface_forcing%runoff_exponent,fixed_top_conductivity)
          call self%rfm_top_provider%evaluate(rfm_physical%pressure_head(1),rfm_physical%water_content(1), &
               rfm_physical%ponding_depth,request%boundary,rfm_preflight)
          rfm_preflight%net_potential_surface_flux=a28_original_supply
          call prepare_rfm_live_trial(rfm_physical%rfm,self%rfm_configuration,self%rfm_surface_forcing,hydraulic_start, &
               self%constitutive,rfm_preflight,rfm_node_depth_cm,self%soil_parameters%dz,step_duration,1.0e-12_real64,rfm_live)
          if(.not.rfm_live%valid)write(*,*) 'A28_PARTITION_PREFLIGHT valid=',rfm_live%valid,' surface_status=',rfm_live%surface%status
        end if
'''
  backend_text=backend_text.replace(before,repair+before,1)
 separated_backend=out/'a28_separated_backend.f90';separated_backend.write_text(backend_text)
# Observe pre-solver RFM failure without changing its acceptance rules.
observed_preparer=None
if os.environ.get('A28_RFM_PREPARER_DIAGNOSTICS')=='1':
 preparer_path=root/'src/runtime/mod_rfm_live_trial_preparer.f90'
 preparer_text=preparer_path.read_text().replace('contains\n',' integer,save::a28_surface_failure_count=0\ncontains\n',1)
 before='  if(result%surface%status/=RFM_SURFACE_COMPOSITION_AVAILABLE)return'
 assert preparer_text.count(before)==1
 preparer_text=preparer_text.replace(before,'''  if(result%surface%status/=RFM_SURFACE_COMPOSITION_AVAILABLE)then
   a28_surface_failure_count=a28_surface_failure_count+1
   if(a28_surface_failure_count<=8.or.mod(a28_surface_failure_count,100000)==0) &
   write(*,*) 'A28_RFM_PREPARE_SURFACE_FAIL count=',a28_surface_failure_count,' status=',result%surface%status, &
     ' regime=',preflight%regime,' pond=',preflight%candidate_ponding_depth, &
     ' runoff=',preflight%runoff_depth,' head=',view%pressure_head(1),' dt=',step_duration_day, &
     ' age=',accepted%tau_surface_day,' preferential=',result%activation%activation%preferential_rate_cm_per_day
   return
  end if''',1)
 observed_preparer=out/'a28_observed_preparer.f90';observed_preparer.write_text(preparer_text)
observed_participant=None
bounded_interval=None
if os.environ.get('A28_BOUNDED_TRANSACTION_PROPOSAL')=='1':
 interval_path=root/'src/runtime/mod_canonical_interval_runtime.f90'
 interval_text=interval_path.read_text()
 anchor='      transaction_t1 = interval%t1'
 assert interval_text.count(anchor)==1
 interval_text=interval_text.replace(anchor,'      transaction_t1 = min(interval%t1,cursor+1.0e-4_real64)',1)
 bounded_interval=out/'a28_bounded_interval.f90';bounded_interval.write_text(interval_text)
if os.environ.get('A28_CORRECTOR_DIAGNOSTICS')=='1':
 participant_path=root/'src/runtime/mod_fmr_groundwater_swap_participant.f90'
 participant_text=participant_path.read_text()
 before='    if (.not. accepted_whole_window(self%trial_result, self%candidate, window)) then'
 assert participant_text.count(before)==1
 participant_text=participant_text.replace(before,'''    write(*,*) 'A28_CORRECTOR_WORK t0=',window%t0,' t1=',window%t1, &
        ' completed=',self%trial_result%completed,' status=',self%trial_result%status, &
        ' completed_t=',self%trial_result%completed_t,' head_m=',prescribed_head_m, &
        ' accepted_substeps=',self%diagnostics%accepted_substeps,' attempts=',self%diagnostics%attempts, &
        ' retries=',self%diagnostics%retries,' solver_rejections=',self%diagnostics%solver_rejections, &
        ' temporal_rejections=',self%diagnostics%temporal_rejections,' mass_rejections=',self%diagnostics%mass_rejections, &
        ' mass_cm=',self%trial_result%mass%residual,' max_step_mass=',self%diagnostics%max_abs_step_mass_residual, &
        ' nonlinear_iterations=',self%diagnostics%nonlinear_iterations
    write(*,*) 'A28_CORRECTOR_WATER t0=',window%t0,' complete=',self%trial_result%mass%complete, &
        ' storage_start=',self%trial_result%mass%storage_start,' storage_end=',self%trial_result%mass%storage_end, &
        ' input=',self%trial_result%mass%total_in,' output=',self%trial_result%mass%total_out, &
        ' matrix_bottom=',self%trial_result%bottom_outward_exchange_native
'''+before,1)
 observed_participant=out/'a28_observed_participant.f90';observed_participant.write_text(participant_text)
# Bounded test-only instrumentation: only successful quadrature loops count.
source=root/'src/process/macropore/mod_rfm_surface_sorptivity.f90'
s=source.read_text().replace('  implicit none','  use, intrinsic :: iso_c_binding, only: c_int, c_double\n  implicit none',1)
s=s.replace('contains\n','''  integer,save::eval_counts(3)=0,panels_evaluated=0
  real(real64),save::head_min=huge(0._real64),head_max=-huge(0._real64),eval_seconds=0
contains
  subroutine a28_sorptivity_stats_c(counts,npanels,hmin,hmax,seconds) bind(C,name="a28_sorptivity_stats_c")
    integer(c_int),intent(out)::counts(3),npanels
    real(c_double),intent(out)::hmin,hmax,seconds
    counts=eval_counts;npanels=panels_evaluated;hmin=head_min;hmax=head_max;seconds=eval_seconds
  end subroutine
  subroutine a28_sorptivity_stats_reset_c() bind(C,name="a28_sorptivity_stats_reset_c")
    eval_counts=0;panels_evaluated=0;head_min=huge(0._real64);head_max=-huge(0._real64);eval_seconds=0
  end subroutine
  subroutine record_eval(panels,head)
    integer,intent(in)::panels
    real(real64),intent(in)::head
    integer::idx
    select case(panels)
    case(64);idx=1
    case(32);idx=2
    case(16);idx=3
    case default;error stop 'unexpected sorptivity panels'
    end select
    eval_counts(idx)=eval_counts(idx)+1;panels_evaluated=panels_evaluated+panels
    head_min=min(head_min,head);head_max=max(head_max,head)
  end subroutine
''',1)
assert s.count('real(real64) :: h_initial')==2
s=s.replace('real(real64) :: h_initial','real(real64) :: clock0,clock1\n    real(real64) :: h_initial')
assert s.count('    do i=1,panels')==2
s=s.replace('    do i=1,panels','    call cpu_time(clock0)\n    call record_eval(panels,h_initial)\n    do i=1,panels')
assert s.count('    sorptivity = sqrt')==1 and s.count('    sorptivity=sqrt')==1
for anchor in ['    sorptivity = sqrt','    sorptivity=sqrt']:
 s=s.replace(anchor,'    call cpu_time(clock1)\n    eval_seconds=eval_seconds+clock1-clock0\n'+anchor,1)
instrumented=out/source.name;instrumented.write_text(s)
objs=[]
for name in sources:
 if field_grid is not None and name==base[0]:src=field_grid
 elif separated_backend is not None and name==str(backend_path.relative_to(root)):src=separated_backend
 elif observed_preparer is not None and name=='src/runtime/mod_rfm_live_trial_preparer.f90':src=observed_preparer
 elif observed_participant is not None and name=='src/runtime/mod_fmr_groundwater_swap_participant.f90':src=observed_participant
 elif bounded_interval is not None and name=='src/runtime/mod_canonical_interval_runtime.f90':src=bounded_interval
 elif retry_headcalc is not None and name==str(headcalc_path.relative_to(root)):src=retry_headcalc
 else:src=instrumented if name==str(source.relative_to(root)) else root/name
 obj=out/(src.stem+'.o')
 subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fPIC','-fopenmp','-fcheck=all','-fbacktrace','-O2','-J',str(out),'-I',str(out),'-c',str(src),'-o',str(obj)],check=True)
 objs.append(str(obj))
subprocess.run(['gfortran','-shared','-fopenmp',*objs,'-o',str(out/'libfgc45_multiswap.so')],check=True)
print('A28_BUILD=PASS')
