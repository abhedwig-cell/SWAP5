program test_rm21_temporal_attempt_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: durations(4)=[1.0e-4_real64,5.0e-5_real64,2.5e-5_real64,1.25e-5_real64]
  real(real64), parameter :: h0=-75.0_real64, qbot=1.0e-6_real64, budget=1.0e-5_real64
  real(real64), parameter :: rm19_reported=92569.71928978531_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  real(real64) :: cofgen(24,numnod), heads(numnod), water0(numnod), k(numnod), cap(numnod), dkdh(numnod)
  real(real64) :: indicators(4), responses(4), zero_previous(numnod)
  integer :: statuses(4), i,j

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  heads(1)=h0
  do i=2,numnod
    heads(i)=heads(i-1)+p%node_distance(i)
  end do
  call origin_water(durations(1),heads,water0,k,cap,dkdh)
  zero_previous=0.0_real64
  indicators=huge(1.0_real64); responses=huge(1.0_real64); statuses=-999

  do j=1,size(durations)
    call evaluate_duration(durations(j),heads,water0,zero_previous,statuses(j),indicators(j),responses(j))
    write(*,'(A,I0,A,ES26.17E3)') 'RM21_ATTEMPT_',j,'_DT_DAY=',durations(j)
    write(*,'(A,I0,A,ES26.17E3)') 'RM21_ATTEMPT_',j,'_DT_SECONDS=',durations(j)*86400.0_real64
    write(*,'(A,I0,A,I0)') 'RM21_ATTEMPT_',j,'_SOLVE_STATUS=',statuses(j)
    if(statuses(j)==SW_SOLVE_CONVERGED)then
      write(*,'(A,I0,A,ES26.17E3)') 'RM21_ATTEMPT_',j,'_NORMALIZED_INDICATOR=',indicators(j)
      write(*,'(A,I0,A,ES26.17E3)') 'RM21_ATTEMPT_',j,'_MAX_HEAD_RESPONSE_CM=',responses(j)
    end if
  end do

  call require(statuses(1)==SW_SOLVE_CONVERGED,'8.64 s raw solve')
  call require(statuses(2)==SW_SOLVE_CONVERGED,'4.32 s raw solve')
  call require(statuses(3)==SW_SOLVE_CONVERGED,'2.16 s raw solve')
  call require(statuses(4)/=SW_SOLVE_CONVERGED,'1.08 s raw solve must fail')
  call require(indicators(1)>indicators(2) .and. indicators(2)>indicators(3),'successful retry indicators decrease')
  call require(abs(indicators(3)-rm19_reported) <= 1.0e-8_real64*max(1.0_real64,abs(rm19_reported)), &
       '2.16 s indicator matches RM19 terminal diagnostic')
  call require(indicators(1)>rm19_reported,'full-window indicator exceeds RM19 diagnostic')
  call require(responses(1)>budget*1000.0_real64,'physical head response is much larger than inherited budget')

  write(*,'(A,ES26.17E3)') 'RM21_RM19_REPORTED=',rm19_reported
  write(*,'(A,ES26.17E3)') 'RM21_FULL_TO_REPORTED_RATIO=',indicators(1)/rm19_reported
  write(*,'(A,L1)') 'RM21_HALF_STEP_REFERENCE_AVAILABLE=',statuses(2)==SW_SOLVE_CONVERGED
  write(*,'(A,L1)') 'RM21_QUARTER_STEP_REFERENCE_AVAILABLE=',statuses(3)==SW_SOLVE_CONVERGED
  write(*,'(A,L1)') 'RM21_EIGHTH_STEP_REFERENCE_AVAILABLE=',statuses(4)==SW_SOLVE_CONVERGED
  write(*,'(A)') 'RM21_TEMPORAL_ATTEMPT_PROVENANCE=PASS'

contains

  subroutine evaluate_duration(dt,h,w,previous,status,normalized,response)
    real(real64),intent(in)::dt,h(:),w(:),previous(:)
    integer,intent(out)::status
    real(real64),intent(out)::normalized,response
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: res
    type(soil_water_temporal_indicator_request_t) :: ir
    type(soil_water_temporal_indicator_result_t) :: ind
    real(real64), target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: fixed_k
    logical :: ok

    normalized=huge(1.0_real64); response=huge(1.0_real64)
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    call constitutive%evaluate(h,water0,k,cap,dkdh)
    call evaluate_fixed_k(h(1),fixed_k,ok)
    call require(ok,'fixed top K')
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
    call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,0.0_real64,dt, &
         0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
         1.0_real64,1.0_real64,1.0_real64,fixed_k)
    call build_request(req,p,h,w,dt)
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>dynamic_top
    call solver%solve(req,ws,res)
    status=res%status
    if(status/=SW_SOLVE_CONVERGED)return
    response=maxval(abs(res%candidate_state%pressure_head-req%base_state%pressure_head))
    ir%previous_right_derivative_available=.true.
    allocate(ir%previous_right_derivative(size(previous)))
    ir%previous_right_derivative=previous
    call solver%evaluate_temporal_indicator(req,res,ir,ws,ind)
    call require(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. ind%available,'indicator available')
    normalized=ind%head_inf_bound/budget
  end subroutine evaluate_duration

  subroutine origin_water(dt,h,w,kk,cc,dd)
    real(real64),intent(in)::dt,h(:)
    real(real64),intent(out)::w(:),kk(:),cc(:),dd(:)
    type(b110_default_mvg_provider_t)::provider
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(h,w,kk,cc,dd)
  end subroutine origin_water

  subroutine evaluate_fixed_k(h,kout,ok)
    use mod_b110_default_mvg_provider, only: evaluate_b110_default_mvg_conductivity
    real(real64),intent(in)::h
    real(real64),intent(out)::kout
    logical,intent(out)::ok
    call evaluate_b110_default_mvg_conductivity(hp,1,h,kout,ok)
  end subroutine evaluate_fixed_k

  subroutine build_request(r,parameters,h,w,dt)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:),dt
    r=soil_water_solve_request_t()
    r%parameters=>parameters
    r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h; r%base_state%water_content=w
    r%base_state%ponding_depth=0.0_real64; r%base_state%groundwater_level=-2.0_real64
    r%step_duration=dt
    r%boundary%bottom_mode=2; r%boundary%bottom_flux=qbot; r%boundary%bottom_head=h0; r%boundary%top_head=h0
    r%numerical%max_iterations=16; r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0; r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64
    r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64; r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
  end subroutine build_request

  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::m
    parameters%parameter_set_id=210021_int64; parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)
    c=0.0_real64
    do m=1,numnod
      c(1,m)=0.032_real64; c(2,m)=0.423_real64; c(3,m)=4.75_real64
      c(4,m)=0.0135_real64; c(5,m)=0.365_real64; c(6,m)=1.455_real64
      c(7,m)=1.0_real64-1.0_real64/c(6,m); c(8,m)=c(4,m); c(9,m)=0.0_real64
      c(10,m)=c(3,m); c(11,m)=0.999_real64; c(12,m)=0.99_real64*c(3,m)
      c(22,m)=-1.0e6_real64; c(23,m)=1.0e-12_real64
    end do
  end subroutine configure

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'RM21_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm21_temporal_attempt_provenance
