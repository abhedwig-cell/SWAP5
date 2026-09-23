program test_rm21_transaction_temporal_provenance
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  real(real64), parameter :: dts(4)=[1.0e-4_real64,5.0e-5_real64,2.5e-5_real64,1.25e-5_real64]
  real(real64), parameter :: seconds(4)=[8.64_real64,4.32_real64,2.16_real64,1.08_real64]
  real(real64), parameter :: h0=-75.0_real64,qbot=1.0e-6_real64,budget=1.0e-5_real64
  real(real64), parameter :: rm19_terminal=92569.71928978531_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res
  type(soil_water_temporal_indicator_request_t) :: ind_req
  type(soil_water_temporal_indicator_result_t) :: ind
  real(real64),target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
  real(real64) :: cofgen(24,numnod),heads(numnod),water(numnod),k(numnod),cap(numnod),dkdh(numnod),fixed_k
  real(real64) :: normalized(3)
  logical :: ok
  integer :: i,j

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  heads(1)=h0
  do i=2,numnod
    heads(i)=heads(i-1)+p%node_distance(i)
  end do
  call bind_b110_default_mvg_provider(constitutive,hp,dts(1))
  call constitutive%evaluate(heads,water,k,cap,dkdh)
  call evaluate_b110_default_mvg_conductivity(hp,1,heads(1),fixed_k,ok)
  call require(ok,'top K')
  qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)

  do j=1,4
    call bind_b110_default_mvg_provider(constitutive,hp,dts(j))
    call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,0.0_real64,dts(j), &
         0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
         1.0_real64,1.0_real64,1.0_real64,fixed_k)
    call build_request(req,p,heads,water,dts(j))
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
    req%evaluation%dynamic_top_boundary=>dynamic_top
    call solver%solve(req,ws,res)
    write(*,'(A,F0.6,A,I0)') 'RM21_RAW seconds=',seconds(j),' status=',res%status
    if(j<=3)then
      call require(res%status==SW_SOLVE_CONVERGED,'expected successful raw retry point')
      ind_req=soil_water_temporal_indicator_request_t()
      ind_req%previous_right_derivative_available=.true.
      allocate(ind_req%previous_right_derivative(numnod))
      ind_req%previous_right_derivative=0.0_real64
      call solver%evaluate_temporal_indicator(req,res,ind_req,ws,ind)
      call require(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. ind%available,'indicator available')
      normalized(j)=ind%head_inf_bound/budget
      write(*,'(A,F0.6,A,ES26.17E3,A,ES26.17E3,A,A)') &
           'RM21_POINT seconds=',seconds(j),' binf=',ind%head_inf_bound,' normalized=',normalized(j), &
           ' route=',trim(ind%route)
    else
      call require(res%status/=SW_SOLVE_CONVERGED,'1.08 s raw failure preserved')
    end if
  end do

  call require(normalized(1)>normalized(2) .and. normalized(2)>normalized(3),'retry indicators decrease')
  call require(abs(normalized(3)-rm19_terminal) <= 1.0e-6_real64*max(1.0_real64,abs(rm19_terminal)), &
       '2.16 s matches RM19 terminal diagnostic')
  call require(normalized(1)>rm19_terminal,'full-window indicator exceeds RM19 diagnostic')

  write(*,'(A,ES26.17E3)') 'RM21_FULL_NORMALIZED=',normalized(1)
  write(*,'(A,ES26.17E3)') 'RM21_HALF_NORMALIZED=',normalized(2)
  write(*,'(A,ES26.17E3)') 'RM21_QUARTER_NORMALIZED=',normalized(3)
  write(*,'(A,ES26.17E3)') 'RM21_RM19_REPORTED=',rm19_terminal
  write(*,'(A)') 'RM21_LAST_SUCCESSFUL_ATTEMPT_PROVENANCE=PASS'

contains
  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::m
    parameters%parameter_set_id=210021_int64;parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
    c=0.0_real64
    do m=1,numnod
      c(1,m)=0.032_real64;c(2,m)=0.423_real64;c(3,m)=4.75_real64
      c(4,m)=0.0135_real64;c(5,m)=0.365_real64;c(6,m)=1.455_real64
      c(7,m)=1.0_real64-1.0_real64/c(6,m);c(8,m)=c(4,m);c(9,m)=0.0_real64
      c(10,m)=c(3,m);c(11,m)=0.999_real64;c(12,m)=0.99_real64*c(3,m)
      c(22,m)=-1.0e6_real64;c(23,m)=1.0e-12_real64
    end do
  end subroutine configure

  subroutine build_request(r,parameters,h,w,step)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:),step
    r=soil_water_solve_request_t()
    r%parameters=>parameters;r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h;r%base_state%water_content=w
    r%base_state%ponding_depth=0.0_real64;r%base_state%groundwater_level=-2.0_real64
    r%step_duration=step
    r%boundary%bottom_mode=2;r%boundary%bottom_flux=qbot;r%boundary%bottom_head=h0;r%boundary%top_head=h0
    r%numerical%max_iterations=16;r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0;r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64;r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64;r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
    r%evaluation%constitutive=>constitutive;r%evaluation%source_sink=>source_sink
  end subroutine build_request

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'RM21_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm21_transaction_temporal_provenance
