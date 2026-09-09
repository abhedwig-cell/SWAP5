program test_fvq28_reference_reachability
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
  implicit none

  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: nonlinear_head_tol = 1.0e-12_real64
  integer, parameter :: nh=6, nj=4, na=3, nn=4
  real(real64), parameter :: initial_heads(nh) = [ &
       -40.0_real64,-55.0_real64,-110.0_real64,-160.0_real64,-210.0_real64,-320.0_real64 ]
  real(real64), parameter :: head_jumps(nj) = [ -0.05_real64,-0.01_real64,0.01_real64,0.05_real64 ]
  real(real64), parameter :: horizons(na) = [ 0.25_real64,0.125_real64,0.0625_real64 ]
  integer, parameter :: nrefs(nn) = [64,128,256,512]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  integer :: ih,ij,ia,inr,case_id,rows

  call configure_shared(parameters,hydraulic_parameters,constitutive,source_sink,top_provider, &
       drainage,subsurface,root_sink,cofgen)
  write(*,'(A,I0,A,I0,A,I0,A,I0)') 'FVQ28R_BEGIN:NH=',nh,':NJ=',nj,':NA=',na,':NN=',nn
  case_id=0; rows=0
  do ih=1,nh
    do ij=1,nj
      case_id=case_id+1
      do ia=1,na
        do inr=1,nn
          call characterize(case_id,ih,ij,ia,inr,initial_heads(ih),head_jumps(ij),horizons(ia),nrefs(inr), &
               parameters,hydraulic_parameters,constitutive,source_sink,top_provider,solver,workspace)
          rows=rows+1
        end do
      end do
    end do
  end do
  call require(case_id==24,'held-out case count')
  call require(rows==288,'reachability row count')
  write(*,'(A,I0,A,I0)') 'FVQ28R_REFERENCE_REACHABILITY_DRIVER PASS CASES=',case_id,':ROWS=',rows

contains

  subroutine configure_shared(p,hp,cp,sp,tp,qdra,qssdi,qrot,c)
    type(soil_water_parameter_set_t),target,intent(out)::p
    type(b110_default_mvg_parameters_t),target,intent(out)::hp
    type(b110_default_mvg_provider_t),target,intent(out)::cp
    type(b110_source_sink_provider_t),target,intent(out)::sp
    type(fmr04_fixed_flux_top_provider_t),target,intent(out)::tp
    real(real64),allocatable,target,intent(out)::qdra(:,:),qssdi(:),qrot(:)
    real(real64),allocatable,intent(out)::c(:,:)
    integer::k
    p%parameter_set_id=282830_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod)); p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    allocate(c(24,numnod)); c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,horizons(1))
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod)); qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
    if(.not.same_type_as(tp,tp)) error stop 'unreachable top provider type'
  end subroutine configure_shared

  subroutine characterize(cid,state_id,jump_id,attempt_id,nref_id,h0,jump,horizon,ns,p,hp,cp,sp,tp,s,ws)
    integer,intent(in)::cid,state_id,jump_id,attempt_id,nref_id,ns
    real(real64),intent(in)::h0,jump,horizon
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    type(b110_default_mvg_provider_t),target,intent(inout)::cp
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fmr04_fixed_flux_top_provider_t),target,intent(in)::tp
    type(reference_richards_legacy_solver_t),intent(inout)::s
    type(reference_richards_legacy_workspace_t),intent(inout)::ws
    type(soil_water_physical_state_t)::initial
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod),k0
    real(real64)::max_mass,max_solver,subdt
    integer::k,first_failed_step,fail_status,max_niter,max_nback,failure_class
    logical::success

    call bind_b110_default_mvg_provider(cp,hp,horizon)
    heads=h0; call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    do k=2,numnod
      call require(transfer(conductivity(k),0_int64)==transfer(conductivity(1),0_int64),'uniform initial conductivity')
    end do
    k0=conductivity(1)
    initial%active_nodes=numnod; allocate(initial%pressure_head(numnod),initial%water_content(numnod))
    initial%pressure_head=heads; initial%water_content=water; initial%ponding_depth=0.0_real64; initial%groundwater_level=-2.0_real64
    call run_reachability(ns,horizon,h0,h0+jump,k0,p,hp,cp,sp,tp,s,ws,initial,success,failure_class, &
         first_failed_step,fail_status,max_mass,max_solver,max_niter,max_nback)
    subdt=horizon/real(ns,real64)
    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,I0,A,ES26.17E3,A,L1,A,I0,A,I0,A,I0,A,ES26.17E3,A,ES26.17E3,A,I0,A,I0)') &
         'FVQ28R_ROW:CASE=',cid,':STATE=',state_id,':JUMP_ID=',jump_id,':ATTEMPT=',attempt_id,':NREF_ID=',nref_id, &
         ':H0=',h0,':JUMP=',jump,':N=',ns,':SUBDT=',subdt,':SUCCESS=',success,':FAILURE_CLASS=',failure_class, &
         ':FIRST_FAILED_STEP=',first_failed_step,':FAIL_STATUS=',fail_status,':MAX_MASS=',max_mass,':MAX_SOLVER_RES=',max_solver, &
         ':MAX_NITER=',max_niter,':MAX_NBACK=',max_nback
  end subroutine characterize

  subroutine run_reachability(ns,horizon,h0,hbot,k0,p,hp,cp,sp,tp,s,ws,initial,success,failure_class, &
       first_failed_step,fail_status,max_mass,max_solver,max_niter,max_nback)
    integer,intent(in)::ns
    real(real64),intent(in)::horizon,h0,hbot,k0
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_parameters_t),target,intent(in)::hp
    type(b110_default_mvg_provider_t),target,intent(inout)::cp
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fmr04_fixed_flux_top_provider_t),target,intent(in)::tp
    type(reference_richards_legacy_solver_t),intent(inout)::s
    type(reference_richards_legacy_workspace_t),intent(inout)::ws
    type(soil_water_physical_state_t),intent(in)::initial
    logical,intent(out)::success
    integer,intent(out)::failure_class,first_failed_step,fail_status,max_niter,max_nback
    real(real64),intent(out)::max_mass,max_solver
    type(soil_water_physical_state_t)::state
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::result
    real(real64)::subdt,storage0,storage1,total_in,total_out,residual
    integer::istep

    subdt=horizon/real(ns,real64)
    call require(subdt>=1.0e-6_real64,'reference substep above dtmin')
    state=initial; success=.true.; failure_class=0; first_failed_step=0; fail_status=0
    max_mass=0.0_real64; max_solver=0.0_real64; max_niter=0; max_nback=0
    do istep=1,ns
      call bind_b110_default_mvg_provider(cp,hp,subdt)
      request=soil_water_solve_request_t(); request%parameters=>p; request%base_state=state; request%step_duration=subdt
      request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; request%boundary%bottom_mode=5
      request%boundary%top_flux=-k0; request%boundary%top_head=h0; request%boundary%bottom_flux=12345.678_real64; request%boundary%bottom_head=hbot
      request%physical%macropore_active=.false.; request%numerical%max_iterations=8; request%numerical%max_backtracking=4
      request%numerical%conductivity_implicit_mode=0; request%numerical%conductivity_mean_method=1; request%numerical%min_step_duration=1.0e-6_real64
      request%numerical%compartment_balance_tolerance=hard_mass_gate; request%numerical%total_balance_tolerance=hard_mass_gate
      request%numerical%head_abs_tolerance=nonlinear_head_tol; request%numerical%head_rel_tolerance=nonlinear_head_tol; request%numerical%ponding_tolerance=nonlinear_head_tol
      request%evaluation%constitutive=>cp; request%evaluation%source_sink=>sp; request%evaluation%top_boundary=>tp
      storage0=sum(state%water_content*p%dz)+state%ponding_depth
      call s%solve(request,ws,result)
      max_niter=max(max_niter,result%diagnostics%nonlinear_iterations)
      max_nback=max(max_nback,result%diagnostics%backtracking_attempts)
      if(result%status/=SW_SOLVE_CONVERGED) then
        success=.false.; failure_class=1; first_failed_step=istep; fail_status=result%status
        return
      end if
      storage1=sum(result%candidate_state%water_content*p%dz)+result%candidate_state%ponding_depth
      total_in=max(0.0_real64,-result%top_flux)*subdt+max(0.0_real64,result%bottom_flux)*subdt
      total_out=max(0.0_real64,result%top_flux)*subdt+max(0.0_real64,-result%bottom_flux)*subdt
      residual=storage1-storage0-(total_in-total_out)
      max_mass=max(max_mass,abs(residual)); max_solver=max(max_solver,abs(result%unrounded_mass_balance_residual))
      if(abs(residual)>hard_mass_gate) then
        success=.false.; failure_class=2; first_failed_step=istep; fail_status=result%status
        return
      end if
      state=result%candidate_state
    end do
  end subroutine run_reachability

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FVQ28R_FAIL',trim(label); error stop 1
    end if
  end subroutine require
end program test_fvq28_reference_reachability
