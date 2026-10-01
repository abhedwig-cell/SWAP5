program test_fpe_miqual13_reference_solve_scaling
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
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t, &
       bind_fixed_flux_top_boundary_provider
  implicit none

  integer, parameter :: nwarm=2000, nrun=200000
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res
  real(real64), allocatable :: cof(:,:), theta(:), conductivity(:), capacity(:), dkdh(:)
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  integer(int64) :: tick0,tick1,rate
  real(real64) :: cpu0,cpu1,ns_per,cpu_per
  integer(int64) :: total_nl,total_jac,total_lin,total_back
  integer :: i,j
  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode,timeint02_thetam2
  real(real64),parameter :: tr=0.01_real64,ts=0.336701_real64,alpha=0.030304_real64
  real(real64),parameter :: nvg=2.887502_real64,ksat=17.418504_real64,lambda=0.0736_real64
  real(real64) :: mm

  call require(numnod>=2,'dimension >=2')
  mm=1.0_real64-1.0_real64/nvg

  p%parameter_set_id=130013_int64
  p%active_nodes=numnod
  allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
  p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)

  allocate(cof(24,numnod)); cof=0.0_real64
  do j=1,numnod
    cof(1,j)=tr;cof(2,j)=ts;cof(3,j)=ksat;cof(4,j)=alpha
    cof(5,j)=lambda;cof(6,j)=nvg;cof(7,j)=mm;cof(8,j)=alpha
    cof(9,j)=0.0_real64;cof(10,j)=ksat;cof(11,j)=0.999_real64
    cof(12,j)=0.99_real64*ksat;cof(22,j)=-1.0e6_real64;cof(23,j)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(constitutive,hp,0.00125_real64)

  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  call bind_fixed_flux_top_boundary_provider(top_boundary,0.0_real64)

  state%active_nodes=numnod
  allocate(state%pressure_head(numnod),state%water_content(numnod))
  do j=1,numnod
    state%pressure_head(j)=-120.0_real64+10.0_real64*real(j-1,real64)
  end do
  allocate(theta(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod))
  call constitutive%evaluate(state%pressure_head,theta,conductivity,capacity,dkdh)
  state%water_content=theta
  state%ponding_depth=0.0_real64
  state%groundwater_level=-120.0_real64

  req%parameters=>p
  req%base_state=state
  req%step_duration=0.00125_real64
  req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  req%boundary%top_flux=0.0_real64
  req%boundary%bottom_mode=2
  req%boundary%bottom_flux=0.0_real64
  req%numerical%max_iterations=16
  req%numerical%max_backtracking=8
  req%numerical%conductivity_implicit_mode=0
  req%numerical%conductivity_mean_method=1
  req%numerical%min_step_duration=1.0e-6_real64
  req%numerical%compartment_balance_tolerance=1.0e-12_real64
  req%numerical%total_balance_tolerance=1.0e-12_real64
  req%numerical%head_abs_tolerance=1.0e-9_real64
  req%numerical%head_rel_tolerance=1.0e-9_real64
  req%numerical%ponding_tolerance=1.0e-10_real64
  req%evaluation%constitutive=>constitutive
  req%evaluation%source_sink=>source_sink
  req%evaluation%top_boundary=>top_boundary

  timeint02_mode=1
  timeint02_thetam2=0.0_real64
  timeint02_thetam2(1:numnod)=state%water_content

  do i=1,nwarm
    call solver%solve(req,workspace,res)
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_MIQUAL13_SAMPLE|N=',numnod,'|VALID=0|PHASE=warmup|I=',i, &
           '|STATUS=',res%status,'|NL=',res%diagnostics%nonlinear_iterations, &
           '|JAC=',res%diagnostics%jacobian_builds,'|LIN=',res%diagnostics%linear_solves, &
           '|BACK=',res%diagnostics%backtracking_attempts
      write(*,'(a)') 'F_PE_MIQUAL13=PASS'
      stop
    end if
  end do

  total_nl=0_int64;total_jac=0_int64;total_lin=0_int64;total_back=0_int64
  call system_clock(tick0,rate)
  call cpu_time(cpu0)
  do i=1,nrun
    call solver%solve(req,workspace,res)
    if(res%status/=SW_SOLVE_CONVERGED)then
      write(*,'(*(g0))') 'F_PE_MIQUAL13_INVALID|N=',numnod,'|I=',i,'|STATUS=',res%status
      error stop 1
    end if
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_back=total_back+res%diagnostics%backtracking_attempts
  end do
  call cpu_time(cpu1)
  call system_clock(tick1)

  call require(rate>0_int64 .and. tick1>tick0,'valid clock')
  ns_per=1.0e9_real64*real(tick1-tick0,real64)/(real(rate,real64)*real(nrun,real64))
  cpu_per=(cpu1-cpu0)/real(nrun,real64)

  write(*,'(*(g0))') 'F_PE_MIQUAL13_SAMPLE|N=',numnod,'|VALID=1|NRUN=',nrun,'|RATE=',rate, &
       '|TICKS=',tick1-tick0,'|NS_PER=',ns_per,'|CPU_PER=',cpu_per, &
       '|NL=',total_nl,'|JAC=',total_jac,'|LIN=',total_lin,'|BACK=',total_back
  write(*,'(a)') 'F_PE_MIQUAL13=PASS'

contains
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(a,1x,a)') 'F_PE_MIQUAL13_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fpe_miqual13_reference_solve_scaling
