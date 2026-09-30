program test_fpe_nlglob14z39_richards_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: nwarm=50, nblock=5, nper=200
  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: cof(:,:),water(:),kk(:),cap(:),dk(:)
  character(len=32) :: material_id
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,checksum
  real(real64) :: block_time(nblock),t0,t1,med,mean_time,over13,over12
  integer :: i,j,ib,total_nl,total_jac,total_lin,total_back
  logical :: ok

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda)

  dt=0.00125_real64
  call setup()
  call initialize_state(-100.0_real64,state)
  call build_request()
  timeint02_mode=1
  timeint02_thetam2=0.0_real64
  timeint02_thetam2(1:numnod)=state%water_content

  checksum=0.0_real64
  total_nl=0; total_jac=0; total_lin=0; total_back=0

  do i=1,nwarm
     call solve_once(checksum,ok)
     call require(ok,'warmup solve failed')
  end do

  do ib=1,nblock
     call cpu_time(t0)
     do j=1,nper
        call solve_once(checksum,ok)
        call require(ok,'measured solve failed')
     end do
     call cpu_time(t1)
     block_time(ib)=(t1-t0)/real(nper,real64)
  end do

  call median5(block_time,med)
  mean_time=sum(block_time)/real(nblock,real64)
  over13=0.018e-6_real64/med
  over12=0.009e-6_real64/med

  call require(ieee_is_finite(checksum),'checksum nonfinite')
  call require(med>0.0_real64,'timer invalid')

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z39_CASE|MATERIAL=',trim(material_id), &
       '|MEDIAN_S=',med,'|MEAN_S=',mean_time,'|OVERHEAD_FRAC_N13=',over13, &
       '|OVERHEAD_FRAC_N12=',over12,'|NL=',total_nl,'|JAC=',total_jac, &
       '|LIN=',total_lin,'|BACK=',total_back,'|CHECKSUM=',checksum
  if (over13<0.05_real64 .and. over12<0.05_real64) then
     write(*,'(a)') 'F_PE_NLGLOB14Z39_CASE_CLASS=AMORTIZED'
  else
     write(*,'(a)') 'F_PE_NLGLOB14Z39_CASE_CLASS=MATERIAL'
  end if
  write(*,'(a)') 'F_PE_NLGLOB14Z39=PASS'

contains

  subroutine read_real(iarg,x)
    integer,intent(in)::iarg
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s)
    read(s,*)x
  end subroutine read_real

  subroutine setup()
    integer::k
    real(real64)::mm
    p%parameter_set_id=3901_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),cof(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    cof=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do k=1,numnod
       cof(1,k)=tr; cof(2,k)=ts; cof(3,k)=ksat; cof(4,k)=alpha; cof(5,k)=lambda
       cof(6,k)=nvg; cof(7,k)=mm; cof(8,k)=alpha; cof(9,k)=0.0_real64
       cof(10,k)=ksat; cof(11,k)=0.999_real64; cof(12,k)=0.99_real64*ksat
       cof(22,k)=-1.0e6_real64; cof(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cof)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  end subroutine setup

  subroutine initialize_state(h,s)
    real(real64),intent(in)::h
    type(soil_water_physical_state_t),intent(out)::s
    real(real64)::heads(numnod)
    allocate(water(numnod),kk(numnod),cap(numnod),dk(numnod))
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    heads=h
    call constitutive%evaluate(heads,water,kk,cap,dk)
    s%active_nodes=numnod
    allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=heads; s%water_content=water
    s%ponding_depth=0.0_real64; s%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine build_request()
    req%parameters=>p
    req%base_state=state
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-0.01_real64
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8
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
    req%evaluation%top_boundary=>top
  end subroutine build_request

  subroutine solve_once(sumcheck,solve_ok)
    real(real64),intent(inout)::sumcheck
    logical,intent(out)::solve_ok
    call bind_b110_default_mvg_provider(constitutive,hp,dt)
    call solver%solve(req,ws,res)
    solve_ok=res%status==SW_SOLVE_CONVERGED
    if (.not.solve_ok) return
    if (.not.all(ieee_is_finite(res%candidate_state%pressure_head))) then
       solve_ok=.false.; return
    end if
    sumcheck=sumcheck+res%candidate_state%pressure_head(1)*1.0e-12_real64
    total_nl=total_nl+res%diagnostics%nonlinear_iterations
    total_jac=total_jac+res%diagnostics%jacobian_builds
    total_lin=total_lin+res%diagnostics%linear_solves
    total_back=total_back+res%diagnostics%backtracking_attempts
  end subroutine solve_once

  subroutine median5(v,medout)
    real(real64),intent(in)::v(nblock)
    real(real64),intent(out)::medout
    real(real64)::x(nblock),key
    integer::ii,jj
    x=v
    do ii=2,nblock
       key=x(ii); jj=ii-1
       do while(jj>=1)
          if (x(jj)<=key) exit
          x(jj+1)=x(jj); jj=jj-1
       end do
       x(jj+1)=key
    end do
    medout=x(3)
  end subroutine median5

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
       write(*,'(A,1X,A)')'F_PE_NLGLOB14Z39_FAIL',trim(msg)
       error stop 1
    end if
  end subroutine require

end program test_fpe_nlglob14z39_richards_timing
