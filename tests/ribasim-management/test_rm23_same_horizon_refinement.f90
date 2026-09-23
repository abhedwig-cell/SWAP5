program test_rm23_same_horizon_refinement
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: h0=-75.0_real64, qbot=1.0e-6_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  real(real64) :: cofgen(24,numnod), origin_h(numnod), origin_w(numnod)
  real(real64) :: h1(numnod),w1(numnod),h2(numnod),w2(numnod),h4(numnod),w4(numnod)
  real(real64) :: pond1,pond2,pond4, top1,top2,top4, bot1,bot2,bot4
  real(real64) :: dh12,dw12,dh24,dw24,ratio
  logical :: ok1,ok2,ok4
  integer :: i

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  origin_h(1)=h0
  do i=2,numnod
    origin_h(i)=origin_h(i-1)+p%node_distance(i)
  end do
  call evaluate_origin_water(origin_h,origin_w)

  call run_sequence(1,1.0e-4_real64,origin_h,origin_w,h1,w1,pond1,top1,bot1,ok1)
  call run_sequence(2,5.0e-5_real64,origin_h,origin_w,h2,w2,pond2,top2,bot2,ok2)
  call run_sequence(4,2.5e-5_real64,origin_h,origin_w,h4,w4,pond4,top4,bot4,ok4)

  call require(ok1,'one-step sequence must converge')
  write(*,'(A,L1)') 'RM23_ONE_STEP_COMPLETE=',ok1
  write(*,'(A,L1)') 'RM23_TWO_HALF_COMPLETE=',ok2
  write(*,'(A,L1)') 'RM23_FOUR_QUARTER_COMPLETE=',ok4
  write(*,'(A,ES26.17E3)') 'RM23_ONE_STEP_MAX_HEAD_RESPONSE_CM=',maxval(abs(h1-origin_h))

  if(ok2)then
    dh12=maxval(abs(h1-h2)); dw12=maxval(abs(w1-w2))
    write(*,'(A,ES26.17E3)') 'RM23_ONE_VS_TWO_MAX_HEAD_DIFF_CM=',dh12
    write(*,'(A,ES26.17E3)') 'RM23_ONE_VS_TWO_MAX_WATER_DIFF=',dw12
    write(*,'(A,ES26.17E3)') 'RM23_ONE_VS_TWO_PONDING_DIFF_CM=',abs(pond1-pond2)
    write(*,'(A,ES26.17E3)') 'RM23_ONE_VS_TWO_TOP_FLUX_DIFF_CM_DAY=',abs(top1-top2)
    write(*,'(A,ES26.17E3)') 'RM23_ONE_VS_TWO_BOTTOM_FLUX_DIFF_CM_DAY=',abs(bot1-bot2)
  end if

  if(ok2 .and. ok4)then
    dh24=maxval(abs(h2-h4)); dw24=maxval(abs(w2-w4))
    write(*,'(A,ES26.17E3)') 'RM23_TWO_VS_FOUR_MAX_HEAD_DIFF_CM=',dh24
    write(*,'(A,ES26.17E3)') 'RM23_TWO_VS_FOUR_MAX_WATER_DIFF=',dw24
    write(*,'(A,ES26.17E3)') 'RM23_TWO_VS_FOUR_PONDING_DIFF_CM=',abs(pond2-pond4)
    write(*,'(A,ES26.17E3)') 'RM23_TWO_VS_FOUR_TOP_FLUX_DIFF_CM_DAY=',abs(top2-top4)
    write(*,'(A,ES26.17E3)') 'RM23_TWO_VS_FOUR_BOTTOM_FLUX_DIFF_CM_DAY=',abs(bot2-bot4)
    if(dh24>tiny(1.0_real64))then
      ratio=dh12/dh24
    else
      ratio=huge(1.0_real64)
    end if
    write(*,'(A,ES26.17E3)') 'RM23_HEAD_REFINEMENT_RATIO=',ratio
  end if

  call require(ok2,'two-half same-horizon sequence')
  write(*,'(A)') 'RM23_SAME_HORIZON_REFINEMENT=PASS'

contains

  subroutine run_sequence(nsteps,dt,h_start,w_start,h_end,w_end,pond_end,top_end,bot_end,complete)
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
    complete=.false.
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64

    do s=1,nsteps
      call bind_b110_default_mvg_provider(constitutive,hp,dt)
      call evaluate_b110_default_mvg_conductivity(hp,1,h(1),fixed_k,k_ok)
      call require(k_ok,'fixed top K')
      call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
      call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,pond,dt, &
           0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
           1.0_real64,1.0_real64,1.0_real64,fixed_k)
      call build_request(req,p,h,w,pond,dt)
      req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
      req%evaluation%constitutive=>constitutive
      req%evaluation%source_sink=>source_sink
      req%evaluation%dynamic_top_boundary=>dynamic_top
      call solver%solve(req,ws,res)
      write(*,'(A,I0,A,I0,A,I0)') 'RM23_SEQ_',nsteps,'_SUBSTEP_',s,'_STATUS=',res%status
      if(res%status/=SW_SOLVE_CONVERGED)return
      h=res%candidate_state%pressure_head
      w=res%candidate_state%water_content
      pond=res%candidate_state%ponding_depth
      top_end=res%top_flux; bot_end=res%bottom_flux
    end do
    h_end=h; w_end=w; pond_end=pond
    complete=.true.
  end subroutine run_sequence

  subroutine evaluate_origin_water(h,w)
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::w(:)
    type(b110_default_mvg_provider_t)::provider
    real(real64)::kk(numnod),cc(numnod),dd(numnod)
    call bind_b110_default_mvg_provider(provider,hp,1.0e-4_real64)
    call provider%evaluate(h,w,kk,cc,dd)
  end subroutine evaluate_origin_water

  subroutine build_request(r,parameters,h,w,pond,dt)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:),pond,dt
    r=soil_water_solve_request_t()
    r%parameters=>parameters; r%step_duration=dt
    r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h; r%base_state%water_content=w
    r%base_state%ponding_depth=pond; r%base_state%groundwater_level=-2.0_real64
    r%boundary%bottom_mode=2; r%boundary%bottom_flux=qbot; r%boundary%bottom_head=h0; r%boundary%top_head=h0
    r%numerical%max_iterations=16; r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0; r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64; r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64; r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
  end subroutine build_request

  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::m
    parameters%parameter_set_id=230023_int64; parameters%active_nodes=numnod
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
      write(*,'(A,1X,A)')'RM23_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm23_same_horizon_refinement
