program test_ahl21g_exact_retention_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl08_klookup_provider, only: ahl08_klookup_provider_t, bind_ahl08_klookup_provider
  implicit none

  real(real64), parameter :: mass_gate=1.0e-12_real64
  real(real64) :: total_dt

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(ahl08_klookup_provider_t), target :: candidate
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: ref_result, candidate_result
  type(reference_richards_legacy_solver_t) :: solver_ref, solver_candidate
  type(reference_richards_legacy_workspace_t) :: workspace_ref, workspace_candidate
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k0, qbot_forced, qfactor
  real(real64) :: h0,hbot,tr,ts,alpha,nvg,ksat,lambda
  real(real64) :: max_dh,max_dw,dtop,dbottom,mass,bottom_head_delta
  character(len=512) :: table_path, material, regime, arg
  logical :: valid
  integer, parameter :: NREPLAY=32768, NTIMING=7
  integer :: k, r, q
  real(real64) :: ref_times(NTIMING), cand_times(NTIMING), ratios(NTIMING), t0, t1

  if(command_argument_count()/=7) error stop 'usage: test TABLE_PATH MATERIAL REGIME H0 HBOT QFACTOR DT'
  call get_command_argument(1,table_path)
  call get_command_argument(2,material)
  call get_command_argument(3,regime)
  call get_command_argument(4,arg); read(arg,*) h0
  call get_command_argument(5,arg); read(arg,*) hbot
  call get_command_argument(6,arg); read(arg,*) qfactor
  call get_command_argument(7,arg); read(arg,*) total_dt
  call material_parameters(trim(material),tr,ts,alpha,nvg,ksat,lambda)

  parameters%parameter_set_id=406001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  allocate(cofgen(24,numnod));cofgen=0.0_real64
  do k=1,numnod
    cofgen(1,k)=tr;cofgen(2,k)=ts;cofgen(3,k)=ksat
    cofgen(4,k)=alpha;cofgen(5,k)=lambda;cofgen(6,k)=nvg
    cofgen(7,k)=1.0_real64-1.0_real64/nvg;cofgen(8,k)=alpha
    cofgen(9,k)=0.0_real64;cofgen(10,k)=ksat;cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*ksat;cofgen(22,k)=-1.0e6_real64;cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,total_dt)
  call bind_ahl08_klookup_provider(candidate,hp,total_dt,trim(table_path),valid)
  call require(valid,'candidate provider bound')

  heads=h0
  call analytical%evaluate(heads,water,conductivity,capacity,dkdh)
  k0=conductivity(1)
  initial_state%active_nodes=numnod
  allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads;initial_state%water_content=water
  initial_state%ponding_depth=0.0_real64;initial_state%groundwater_level=-2.0_real64
  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
  drainage=0.0_real64;subsurface=0.0_real64;root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  qbot_forced=-qfactor*k0
  call build_request(request,parameters,initial_state,source_sink,top_provider,k0,qbot_forced)
  request%evaluation%constitutive=>analytical
  call solver_ref%solve(request,workspace_ref,ref_result)
  call require(ref_result%status==SW_SOLVE_CONVERGED,'reference converged')
  request%base_state=initial_state;request%evaluation%constitutive=>candidate
  call solver_candidate%solve(request,workspace_candidate,candidate_result)
  call require(candidate_result%status==SW_SOLVE_CONVERGED,'candidate converged')

  max_dh=maxval(abs(candidate_result%candidate_state%pressure_head-ref_result%candidate_state%pressure_head))
  max_dw=maxval(abs(candidate_result%candidate_state%water_content-ref_result%candidate_state%water_content))
  dtop=abs(candidate_result%top_flux-ref_result%top_flux)
  dbottom=abs(candidate_result%bottom_flux-ref_result%bottom_flux)
  if(candidate_result%integrated_mass_balance_residual_available)then
    mass=abs(candidate_result%integrated_mass_balance_residual_cm)
  else
    mass=abs(candidate_result%unrounded_mass_balance_residual)
  end if
  call require(max_dh<=0.05_real64,'head gate')
  call require(max_dw<=1.0e-4_real64,'theta gate')
  call require(dbottom<=1.0e-5_real64,'bottom flux gate')
  call require(mass<=mass_gate,'mass gate')
  call require(abs(candidate_result%diagnostics%nonlinear_iterations-ref_result%diagnostics%nonlinear_iterations)==0,'iteration gate')
  call require(abs(candidate_result%diagnostics%backtracking_attempts-ref_result%diagnostics%backtracking_attempts)==0,'backtrack gate')

  bottom_head_delta=abs(candidate_result%candidate_state%pressure_head(numnod)-ref_result%candidate_state%pressure_head(numnod))
  write(*,'(A,1X,A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') &
       'AHL21E_EXACT_RET_HEAD_RESPONSE',trim(material),trim(regime),'REF_DH_BOTTOM=', &
       ref_result%candidate_state%pressure_head(numnod)-h0,'CAND_DH_BOTTOM=', &
       candidate_result%candidate_state%pressure_head(numnod)-h0,'CAND_MINUS_REF=',bottom_head_delta, &
       'FORCED_QBOT=',qbot_forced
  call require(bottom_head_delta<=0.05_real64,'bottom-node head gate')
  write(*,'(A,1X,A,1X,A,1X,A)') 'AHL21G_FIDELITY',trim(material),trim(regime),'PASS'

  do r=1,NTIMING
    if(mod(r,2)==1) then
      call time_reference_batch()
      call time_candidate_batch()
    else
      call time_candidate_batch()
      call time_reference_batch()
    end if
    ratios(r)=cand_times(r)/ref_times(r)
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10,1X,F10.6)') &
         'AHL21G_PAIR',r,ref_times(r),cand_times(r),ratios(r)
  end do
  call sort7(ratios)
  write(*,'(A,1X,F10.6)') 'AHL21G_MEDIAN_PAIRED_RATIO',ratios(4)
  write(*,'(A,1X,F10.6)') 'AHL21G_MEDIAN_REDUCTION_FRACTION',1.0_real64-ratios(4)

contains
  subroutine time_reference_batch()
    call cpu_time(t0)
    do q=1,NREPLAY
      request%base_state=initial_state
      request%evaluation%constitutive=>analytical
      call solver_ref%solve(request,workspace_ref,ref_result)
      if(ref_result%status/=SW_SOLVE_CONVERGED) error stop 'timed reference failure'
    end do
    call cpu_time(t1)
    ref_times(r)=(t1-t0)/real(NREPLAY,real64)
  end subroutine time_reference_batch

  subroutine time_candidate_batch()
    call cpu_time(t0)
    do q=1,NREPLAY
      request%base_state=initial_state
      request%evaluation%constitutive=>candidate
      call solver_candidate%solve(request,workspace_candidate,candidate_result)
      if(candidate_result%status/=SW_SOLVE_CONVERGED) error stop 'timed candidate failure'
    end do
    call cpu_time(t1)
    cand_times(r)=(t1-t0)/real(NREPLAY,real64)
  end subroutine time_candidate_batch

  subroutine sort7(v)
    real(real64),intent(inout)::v(7)
    real(real64)::tmp
    integer::a,b
    do a=1,6
      do b=a+1,7
        if(v(b)<v(a))then
          tmp=v(a);v(a)=v(b);v(b)=tmp
        end if
      end do
    end do
  end subroutine sort7

  subroutine material_parameters(id,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::id
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(id)
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64;nvg=1.734737_real64;ksat=31.225016_real64;lambda=0.98087_real64
    case('B12')
      tr=0.01_real64;ts=0.529749_real64;alpha=0.016562_real64;nvg=1.090671_real64;ksat=2.245895_real64;lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64;ts=0.336701_real64;alpha=0.030304_real64;nvg=2.887502_real64;ksat=17.418504_real64;lambda=0.0736_real64
    case('O14')
      tr=0.01_real64;ts=0.393878_real64;alpha=0.003288_real64;nvg=1.616573_real64;ksat=2.495984_real64;lambda=0.514012_real64
    case default
      error stop 'unknown AHL16 material'
    end select
  end subroutine material_parameters

  subroutine build_request(req,p,state,sp,tp,k0,qbot_forced)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(soil_water_physical_state_t),intent(in)::state
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fmr04_fixed_flux_top_provider_t),target,intent(in)::tp
    real(real64),intent(in)::k0,qbot_forced
    req=soil_water_solve_request_t();req%parameters=>p;req%base_state=state;req%step_duration=total_dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=2
    req%boundary%top_flux=-k0;req%boundary%top_head=h0;req%boundary%bottom_flux=qbot_forced;req%boundary%bottom_head=0.0_real64
    req%physical%macropore_active=.false.;req%numerical%max_iterations=8;req%numerical%max_backtracking=4
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64;req%numerical%compartment_balance_tolerance=mass_gate
    req%numerical%total_balance_tolerance=mass_gate;req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64;req%numerical%ponding_tolerance=1.0e-12_real64
    req%evaluation%source_sink=>sp;req%evaluation%top_boundary=>tp
  end subroutine
  subroutine require(ok,msg)
    logical,intent(in)::ok;character(len=*),intent(in)::msg
    if(.not.ok)then;write(*,'(A,1X,A)')'AHL21G_FAIL',trim(msg);error stop 1;end if
  end subroutine
end program test_ahl21g_exact_retention_timing
