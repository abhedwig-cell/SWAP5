program test_rm26_temporal_localization
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
  real(real64) :: h1(numnod),w1(numnod),h2(numnod),w2(numnod)
  real(real64) :: pond1,pond2,top1,top2,bot1,bot2
  real(real64) :: dh(numnod),dw(numnod),storage_signed,storage_abs
  real(real64) :: lower_max,upper_max
  logical :: ok1,ok2
  integer :: i,imax,nband,lower_start

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  origin_h(1)=h0
  do i=2,numnod
    origin_h(i)=origin_h(i-1)+p%node_distance(i)
  end do
  call evaluate_origin_water(origin_h,origin_w)

  call run_sequence(1,1.0e-4_real64,origin_h,origin_w,h1,w1,pond1,top1,bot1,ok1)
  call run_sequence(2,5.0e-5_real64,origin_h,origin_w,h2,w2,pond2,top2,bot2,ok2)
  call require(ok1,'one-step sequence')
  call require(ok2,'two-half sequence')

  dh=abs(h1-h2)
  dw=abs(w1-w2)
  imax=maxloc(dh,dim=1)
  nband=max(1,numnod/5)
  lower_start=numnod-nband+1
  upper_max=maxval(dh(1:nband))
  lower_max=maxval(dh(lower_start:numnod))
  storage_signed=sum((w1-w2)*dz)
  storage_abs=abs(storage_signed)

  write(*,'(A,I0)') 'RM26_NODE_COUNT=',numnod
  write(*,'(A,I0)') 'RM26_GLOBAL_MAX_HEAD_NODE=',imax
  write(*,'(A,ES26.17E3)') 'RM26_GLOBAL_MAX_HEAD_NODE_Z_CM=',z(imax)
  write(*,'(A,ES26.17E3)') 'RM26_GLOBAL_MAX_HEAD_DIFF_CM=',dh(imax)
  write(*,'(A,ES26.17E3)') 'RM26_BOTTOM_NODE_HEAD_DIFF_CM=',dh(numnod)
  write(*,'(A,I0)') 'RM26_BAND_NODE_COUNT=',nband
  write(*,'(A,ES26.17E3)') 'RM26_UPPER20_MAX_HEAD_DIFF_CM=',upper_max
  write(*,'(A,ES26.17E3)') 'RM26_LOWER20_MAX_HEAD_DIFF_CM=',lower_max
  write(*,'(A,ES26.17E3)') 'RM26_GLOBAL_MAX_WATER_CONTENT_DIFF=',maxval(dw)
  write(*,'(A,ES26.17E3)') 'RM26_COLUMN_STORAGE_DIFF_SIGNED_CM=',storage_signed
  write(*,'(A,ES26.17E3)') 'RM26_COLUMN_STORAGE_DIFF_ABS_CM=',storage_abs
  write(*,'(A,ES26.17E3)') 'RM26_PONDING_DIFF_CM=',abs(pond1-pond2)
  write(*,'(A,ES26.17E3)') 'RM26_TOP_FLUX_DIFF_CM_DAY=',abs(top1-top2)
  write(*,'(A,ES26.17E3)') 'RM26_BOTTOM_FLUX_DIFF_CM_DAY=',abs(bot1-bot2)
  write(*,'(A)') 'RM26_TEMPORAL_LOCALIZATION=PASS'

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
    parameters%parameter_set_id=260026_int64; parameters%active_nodes=numnod
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
      write(*,'(A,1X,A)')'RM26_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm26_temporal_localization
