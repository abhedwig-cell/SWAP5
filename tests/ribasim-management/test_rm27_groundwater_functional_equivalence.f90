program test_rm27_groundwater_functional_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: h0=-75.0_real64, qbot=1.0e-6_real64
  real(real64), parameter :: day_s=86400.0_real64
  real(real64), parameter :: probes_cm(3)=[-75.0002_real64,-75.0_real64,-74.9998_real64]
  real(real64), parameter :: flux_tol_m_s=1.0e-15_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  real(real64) :: cofgen(24,numnod), origin_h(numnod), origin_w(numnod)
  real(real64) :: h1(numnod),w1(numnod),h2(numnod),w2(numnod)
  real(real64) :: pond1,pond2,top1,top2,bot1,bot2
  real(real64) :: q1(3),q2(3),maxdiff,storage_diff,bottom_origin_diff
  real(real64) :: slope1,slope2,intercept1,intercept2
  logical :: ok1,ok2,probe_ok
  integer :: i,j

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  origin_h(1)=h0
  do i=2,numnod
    origin_h(i)=origin_h(i-1)+p%node_distance(i)
  end do
  call evaluate_origin_water(origin_h,origin_w)

  call run_irrigation_sequence(1,1.0e-4_real64,origin_h,origin_w,h1,w1,pond1,top1,bot1,ok1)
  call run_irrigation_sequence(2,5.0e-5_real64,origin_h,origin_w,h2,w2,pond2,top2,bot2,ok2)
  call require(ok1 .and. ok2,'RM23 endpoint origins')

  do j=1,3
    call run_groundwater_probe(h1,w1,pond1,probes_cm(j),q1(j),probe_ok)
    write(*,'(A,I0,A,I0)') 'RM27_ENDPOINT_1_PROBE_',j,'_STATUS=',merge(1,0,probe_ok)
    call require(probe_ok,'endpoint 1 probe convergence')
    call run_groundwater_probe(h2,w2,pond2,probes_cm(j),q2(j),probe_ok)
    write(*,'(A,I0,A,I0)') 'RM27_ENDPOINT_2_PROBE_',j,'_STATUS=',merge(1,0,probe_ok)
    call require(probe_ok,'endpoint 2 probe convergence')
    write(*,'(A,I0,A,ES26.17E3)') 'RM27_PROBE_',j,'_Q1_M_PER_S=',q1(j)
    write(*,'(A,I0,A,ES26.17E3)') 'RM27_PROBE_',j,'_Q2_M_PER_S=',q2(j)
    write(*,'(A,I0,A,ES26.17E3)') 'RM27_PROBE_',j,'_ABS_DIFF_M_PER_S=',abs(q1(j)-q2(j))
  end do

  maxdiff=maxval(abs(q1-q2))
  slope1=(q1(3)-q1(1))/(4.0e-6_real64)
  slope2=(q2(3)-q2(1))/(4.0e-6_real64)
  intercept1=q1(2)-slope1*(-0.75_real64)
  intercept2=q2(2)-slope2*(-0.75_real64)
  storage_diff=sum((w1-w2)*dz)
  bottom_origin_diff=abs(h1(numnod)-h2(numnod))

  write(*,'(A,ES26.17E3)') 'RM27_MAX_QSWAP_DIFF_M_PER_S=',maxdiff
  write(*,'(A,ES26.17E3)') 'RM27_FGC44_FLUX_RESOLUTION_M_PER_S=',flux_tol_m_s
  write(*,'(A,ES26.17E3)') 'RM27_RESPONSE_SLOPE_1_PER_S=',slope1
  write(*,'(A,ES26.17E3)') 'RM27_RESPONSE_SLOPE_2_PER_S=',slope2
  write(*,'(A,ES26.17E3)') 'RM27_RESPONSE_INTERCEPT_1_M_PER_S=',intercept1
  write(*,'(A,ES26.17E3)') 'RM27_RESPONSE_INTERCEPT_2_M_PER_S=',intercept2
  write(*,'(A,ES26.17E3)') 'RM27_ORIGIN_BOTTOM_NODE_HEAD_DIFF_CM=',bottom_origin_diff
  write(*,'(A,ES26.17E3)') 'RM27_ORIGIN_COLUMN_STORAGE_DIFF_CM=',storage_diff

  call require(maxdiff<=flux_tol_m_s,'groundwater response equivalence at admitted resolution')
  write(*,'(A)') 'RM27_GROUNDWATER_FUNCTIONAL_EQUIVALENCE=PASS'

contains

  subroutine run_irrigation_sequence(nsteps,dt,h_start,w_start,h_end,w_end,pond_end,top_end,bot_end,complete)
    integer,intent(in)::nsteps
    real(real64),intent(in)::dt,h_start(:),w_start(:)
    real(real64),intent(out)::h_end(:),w_end(:),pond_end,top_end,bot_end
    logical,intent(out)::complete
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: res
    real(real64), target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: h(numnod),w(numnod),pond,fixed_k
    logical :: k_ok
    integer :: s
    h=h_start; w=w_start; pond=0.0_real64
    h_end=h; w_end=w; pond_end=pond; top_end=0.0_real64; bot_end=0.0_real64
    complete=.false.; qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    do s=1,nsteps
      call bind_b110_default_mvg_provider(constitutive,hp,dt)
      call evaluate_b110_default_mvg_conductivity(hp,1,h(1),fixed_k,k_ok)
      call require(k_ok,'irrigation fixed top K')
      call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
      call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,pond,dt, &
           0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
           1.0_real64,1.0_real64,1.0_real64,fixed_k)
      call build_request(req,p,h,w,pond,dt,2,qbot,h0)
      req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
      req%evaluation%constitutive=>constitutive
      req%evaluation%source_sink=>source_sink
      req%evaluation%dynamic_top_boundary=>dynamic_top
      call solver%solve(req,ws,res)
      if(res%status/=SW_SOLVE_CONVERGED)return
      h=res%candidate_state%pressure_head; w=res%candidate_state%water_content
      pond=res%candidate_state%ponding_depth; top_end=res%top_flux; bot_end=res%bottom_flux
    end do
    h_end=h; w_end=w; pond_end=pond; complete=.true.
  end subroutine run_irrigation_sequence

  subroutine run_groundwater_probe(h_start,w_start,pond_start,bottom_head_cm,qswap_m_s,complete)
    real(real64),intent(in)::h_start(:),w_start(:),pond_start,bottom_head_cm
    real(real64),intent(out)::qswap_m_s
    logical,intent(out)::complete
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: res
    real(real64), target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: fixed_k
    logical :: k_ok
    qswap_m_s=0.0_real64; complete=.false.
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_default_mvg_provider(constitutive,hp,1.0e-4_real64)
    call evaluate_b110_default_mvg_conductivity(hp,1,h_start(1),fixed_k,k_ok)
    call require(k_ok,'probe fixed top K')
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
    call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,pond_start,1.0e-4_real64, &
         0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
         1.0_real64,1.0_real64,1.0_real64,fixed_k)
    call build_request(req,p,h_start,w_start,pond_start,1.0e-4_real64,SW_STEP_CONTROL_BOTTOM_HEAD,0.0_real64,bottom_head_cm)
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%dynamic_top_boundary=>dynamic_top
    call solver%solve(req,ws,res)
    if(res%status/=SW_SOLVE_CONVERGED)return
    qswap_m_s=-res%bottom_flux/100.0_real64/day_s
    complete=.true.
  end subroutine run_groundwater_probe

  subroutine evaluate_origin_water(h,w)
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::w(:)
    type(b110_default_mvg_provider_t)::provider
    real(real64)::kk(numnod),cc(numnod),dd(numnod)
    call bind_b110_default_mvg_provider(provider,hp,1.0e-4_real64)
    call provider%evaluate(h,w,kk,cc,dd)
  end subroutine evaluate_origin_water

  subroutine build_request(r,parameters,h,w,pond,dt,bottom_mode,bottom_flux,bottom_head)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:),pond,dt,bottom_flux,bottom_head
    integer,intent(in)::bottom_mode
    r=soil_water_solve_request_t()
    r%parameters=>parameters; r%step_duration=dt
    r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h; r%base_state%water_content=w
    r%base_state%ponding_depth=pond; r%base_state%groundwater_level=-2.0_real64
    r%boundary%bottom_mode=bottom_mode; r%boundary%bottom_flux=bottom_flux
    r%boundary%bottom_head=bottom_head; r%boundary%top_head=h0
    r%numerical%max_iterations=16; r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0; r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64
    r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64
    r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
  end subroutine build_request

  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::m
    parameters%parameter_set_id=270027_int64; parameters%active_nodes=numnod
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
      write(*,'(A,1X,A)')'RM27_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm27_groundwater_functional_equivalence
