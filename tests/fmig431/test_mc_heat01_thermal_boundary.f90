program test_mc_heat01_thermal_boundary
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_restricted_soil_temperature, only: &
       SOIL_TEMP_OK, SOIL_TEMP_INVALID_FORCING, SOIL_TEMP_SOLUTION_ANALYTIC, &
       SOIL_TEMP_TOP_AIR_TEMPERATURE, SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE, &
       SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX, SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION, &
       SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX, SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE, &
       soil_temperature_parameters_t, soil_temperature_numerical_config_t, soil_temperature_forcing_t, &
       soil_temperature_state_t, soil_temperature_restart_payload_t, soil_temperature_workspace_t, &
       soil_temperature_result_t, soil_temperature_diagnostics_t, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state, trial_restricted_soil_temperature, commit_soil_temperature_state, &
       copy_soil_temperature_profile, export_soil_temperature_restart, reconstruct_soil_temperature_restart
  implicit none

  integer, parameter :: n=3
  real(real64), parameter :: dz(n)=[2.0_real64,4.0_real64,6.0_real64]
  real(real64), parameter :: dist(n)=[1.0_real64,3.0_real64,5.0_real64]
  real(real64), parameter :: theta_sat(n)=[0.45_real64,0.47_real64,0.50_real64]
  real(real64), parameter :: quartz(n)=[0.45_real64,0.35_real64,0.25_real64]
  real(real64), parameter :: clay(n)=[0.12_real64,0.18_real64,0.22_real64]
  real(real64), parameter :: organic(n)=[0.03_real64,0.05_real64,0.08_real64]
  real(real64), parameter :: initial_temperature(n)=[8.0_real64,9.0_real64,10.0_real64]
  type(soil_temperature_parameters_t) :: numeric_parameters,analytic_parameters
  type(soil_temperature_numerical_config_t) :: numerical
  type(process_hydraulic_view_t) :: hydraulic
  integer :: status

  call initialize_soil_temperature_parameters(dz,dist,theta_sat,quartz,clay,organic,numeric_parameters,status)
  call require(status==SOIL_TEMP_OK.and.numeric_parameters%ready(),'numeric parameters')
  call initialize_soil_temperature_parameters(dz,dist,theta_sat,quartz,clay,organic,analytic_parameters,status, &
       solution_mode=SOIL_TEMP_SOLUTION_ANALYTIC,analytic_mean_temperature_c=10.0_real64, &
       analytic_amplitude_c=8.0_real64,analytic_reference_day=200.0_real64,analytic_damping_depth_cm=40.0_real64)
  call require(status==SOIL_TEMP_OK.and.analytic_parameters%ready(),'analytic parameters')
  numerical%energy_abs_tolerance_j_cm2=1.0e-9_real64
  call make_hydraulic([0.18_real64,0.22_real64,0.27_real64],hydraulic)

  call test_prescribed_flux_and_bottom_temperature()
  call test_surface_temperature_flux_correction()
  call test_analytical_profile()
  call test_snow_resistance_component()
  call test_fail_closed_and_restart()

  print '(a)','MC_HEAT01_SOURCE_BOUNDARY_CASES=6'
  print '(a)','MC_HEAT01_BC3_BC4_BOTTOM2_O0O2=PASS'
  print '(a)','MC_HEAT01_ANALYTIC_B111_PROFILE=PASS'
  print '(a)','MC_HEAT01_SNOW_RESISTANCE_COMPONENT_ONLY=PASS'
  print '(a)','MC_HEAT01_ENERGY_STATE_RESTART_CONTRACTS=PASS'
  print '(a)','MC_HEAT01_PROCESS_GATE=PASS'

contains

  subroutine test_prescribed_flux_and_bottom_temperature()
    type(soil_temperature_forcing_t) :: forcing
    forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
    forcing%prescribed_top_heat_flux_j_cm2_day=12.0_real64
    call compare_numeric_case(forcing,.true.,.false.)
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
    forcing%prescribed_bottom_temperature_c=6.0_real64
    call compare_numeric_case(forcing,.true.,.true.)
    forcing=soil_temperature_forcing_t()
    forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
    forcing%prescribed_surface_temperature_c=20.0_real64
    forcing%prescribed_bottom_temperature_c=4.0_real64
    call compare_numeric_case(forcing,.false.,.true.)
  end subroutine test_prescribed_flux_and_bottom_temperature

  subroutine test_surface_temperature_flux_correction()
    type(soil_temperature_forcing_t) :: forcing
    forcing%top_boundary_mode=SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
    forcing%prescribed_surface_temperature_c=15.0_real64
    forcing%prescribed_top_heat_flux_j_cm2_day=4.0_real64
    call compare_numeric_case(forcing,.false.,.false.)
  end subroutine test_surface_temperature_flux_correction

  subroutine test_analytical_profile()
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_state_t) :: committed,trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:)
    real(real64) :: expected(n),pi,omega
    integer :: i,s
    forcing%day_number=220
    call initialize_soil_temperature_state(initial_temperature,committed,s)
    call trial_restricted_soil_temperature(analytic_parameters,numerical,forcing,hydraulic,hydraulic,committed, &
         219.0_real64,220.0_real64,workspace,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_OK.and.result%produced,'analytic trial')
    call copy_soil_temperature_profile(trial,profile,s)
    pi=4.0_real64*atan(1.0_real64); omega=2.0_real64*pi/365.0_real64
    do i=1,n
      expected(i)=10.0_real64+8.0_real64*sin(0.5_real64*pi+omega*20.0_real64+ &
           analytic_parameters%node_depth_cm(i)/40.0_real64)* &
           exp(analytic_parameters%node_depth_cm(i)/40.0_real64)
    end do
    call require(maxval(abs(profile-expected))<1.0e-13_real64,'analytic literal equation')
    call require(diagnostics%analytical_profile_used.and.diagnostics%energy_accounting_complete,'analytic diagnostics')
    call require(abs(result%energy_residual_j_cm2)<1.0e-9_real64,'analytic energy')
  end subroutine test_analytical_profile

  subroutine test_snow_resistance_component()
    type(soil_temperature_forcing_t) :: forcing
    type(soil_temperature_state_t) :: committed,trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64) :: ksnow,snow_depth,ratio,expected_surface
    integer :: s
    forcing%top_boundary_mode=SOIL_TEMP_TOP_AIR_TEMPERATURE
    forcing%air_temperature_c=-5.0_real64
    forcing%snow_water_storage_cm=5.0_real64
    call initialize_soil_temperature_state(initial_temperature,committed,s)
    call trial_restricted_soil_temperature(numeric_parameters,numerical,forcing,hydraulic,hydraulic,committed, &
         0.0_real64,0.25_real64,workspace,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_OK.and.diagnostics%snow_thermal_resistance_used,'snow component trial')
    ksnow=2.86e-6_real64*864.0_real64*170.0_real64**2
    snow_depth=5.0_real64/0.17_real64
    ratio=(0.5_real64*ksnow*dz(1))/(workspace%node_conductivity_j_cm_k_day(1)*snow_depth)
    expected_surface=(initial_temperature(1)+ratio*(-5.0_real64))/(1.0_real64+ratio)
    call require(abs(result%surface_temperature_c-expected_surface)<1.0e-13_real64,'snow literal equation')
    call require(abs(result%energy_residual_j_cm2)<1.0e-9_real64,'snow component energy')
  end subroutine test_snow_resistance_component

  subroutine test_fail_closed_and_restart()
    type(soil_temperature_forcing_t) :: forcing,bad
    type(soil_temperature_state_t) :: committed,trial,continuous,split,restored
    type(soil_temperature_restart_payload_t) :: payload
    type(soil_temperature_workspace_t) :: workspace_a,workspace_b
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: before(:),after(:),a(:),b(:)
    integer :: s,k
    forcing%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
    forcing%prescribed_top_heat_flux_j_cm2_day=7.0_real64
    forcing%prescribed_bottom_temperature_c=5.0_real64
    call initialize_soil_temperature_state(initial_temperature,committed,s)
    call copy_soil_temperature_profile(committed,before,s)
    bad=forcing; bad%top_boundary_mode=99
    call trial_restricted_soil_temperature(numeric_parameters,numerical,bad,hydraulic,hydraulic,committed, &
         0.0_real64,0.25_real64,workspace_a,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_INVALID_FORCING.and..not.result%produced,'invalid selector')
    call copy_soil_temperature_profile(committed,after,s)
    call require(same_bits(before,after),'failure immutability')
    bad=forcing; bad%prescribed_top_heat_flux_j_cm2_day=ieee_value(0.0_real64,ieee_quiet_nan)
    call trial_restricted_soil_temperature(numeric_parameters,numerical,bad,hydraulic,hydraulic,committed, &
         0.0_real64,0.25_real64,workspace_a,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_INVALID_FORCING,'nonfinite forcing')
    bad=forcing; bad%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE; bad%snow_water_storage_cm=1.0_real64
    call trial_restricted_soil_temperature(numeric_parameters,numerical,bad,hydraulic,hydraulic,committed, &
         0.0_real64,0.25_real64,workspace_a,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_INVALID_FORCING,'snow selector mismatch')

    call initialize_soil_temperature_state(initial_temperature,continuous,s)
    call initialize_soil_temperature_state(initial_temperature,split,s)
    do k=1,4
      call advance(continuous,workspace_a,forcing,real(k-1,real64)*0.2_real64,real(k,real64)*0.2_real64)
    end do
    do k=1,2
      call advance(split,workspace_b,forcing,real(k-1,real64)*0.2_real64,real(k,real64)*0.2_real64)
    end do
    call export_soil_temperature_restart(split,payload,s); call require(s==SOIL_TEMP_OK,'restart export')
    call reconstruct_soil_temperature_restart(payload,restored,s); call require(s==SOIL_TEMP_OK,'restart restore')
    do k=3,4
      call advance(restored,workspace_b,forcing,real(k-1,real64)*0.2_real64,real(k,real64)*0.2_real64)
    end do
    call copy_soil_temperature_profile(continuous,a,s); call copy_soil_temperature_profile(restored,b,s)
    call require(same_bits(a,b),'split restart exact identity')
  end subroutine test_fail_closed_and_restart

  subroutine compare_numeric_case(forcing,expect_top_flux,expect_bottom_temperature)
    type(soil_temperature_forcing_t), intent(in) :: forcing
    logical, intent(in) :: expect_top_flux,expect_bottom_temperature
    type(soil_temperature_state_t) :: committed,trial
    type(soil_temperature_workspace_t) :: workspace
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    real(real64), allocatable :: profile(:)
    real(real64) :: matrix(n,n),rhs(n),expected(n),surface
    integer :: s
    call initialize_soil_temperature_state(initial_temperature,committed,s)
    call trial_restricted_soil_temperature(numeric_parameters,numerical,forcing,hydraulic,hydraulic,committed, &
         0.0_real64,0.25_real64,workspace,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_OK.and.result%produced,'numeric boundary trial')
    call copy_soil_temperature_profile(trial,profile,s)
    call source_boundary_system(forcing,workspace,0.25_real64,matrix,rhs,surface)
    call solve_dense(matrix,rhs,expected)
    call require(maxval(abs(profile-expected))<5.0e-12_real64,'boundary dense oracle')
    call require(abs(result%energy_residual_j_cm2)<1.0e-9_real64.and. &
         diagnostics%energy_accounting_complete,'numeric energy closure')
    call require(diagnostics%prescribed_top_heat_flux_used.eqv.expect_top_flux,'top flux diagnostic')
    call require(diagnostics%prescribed_bottom_temperature_used.eqv.expect_bottom_temperature,'bottom diagnostic')
    if (forcing%top_boundary_mode==SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION) then
      call require(diagnostics%surface_temperature_flux_correction_used,'bc4 diagnostic')
      call require(abs(profile(1)-(forcing%prescribed_surface_temperature_c-dist(1)/ &
           workspace%face_conductivity_j_cm_k_day(1)*forcing%prescribed_top_heat_flux_j_cm2_day))<5.0e-13_real64, &
           'bc4 literal first node')
    end if
    if (forcing%top_boundary_mode==SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX) then
      call require(abs(result%top_heat_flux_into_soil_j_cm2_day-forcing%prescribed_top_heat_flux_j_cm2_day)<1.0e-15_real64, &
           'bc3 exact flux')
      call require(abs(result%surface_temperature_c-(profile(1)+forcing%prescribed_top_heat_flux_j_cm2_day* &
           dist(1)/workspace%face_conductivity_j_cm_k_day(1)))<5.0e-13_real64,'bc3 surface reconstruction')
    end if
  end subroutine compare_numeric_case

  subroutine source_boundary_system(forcing,w,dt,matrix,rhs,surface)
    type(soil_temperature_forcing_t), intent(in) :: forcing
    type(soil_temperature_workspace_t), intent(in) :: w
    real(real64), intent(in) :: dt
    real(real64), intent(out) :: matrix(n,n),rhs(n),surface
    real(real64) :: lower,upper
    integer :: i
    matrix=0.0_real64; rhs=0.0_real64; surface=forcing%prescribed_surface_temperature_c
    i=1; upper=-dt*w%face_conductivity_j_cm_k_day(2)/(dz(1)*dist(2))
    select case(forcing%top_boundary_mode)
    case(SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE)
      lower=-dt*w%face_conductivity_j_cm_k_day(1)/(dz(1)*dist(1))
      matrix(1,1)=w%heat_capacity_j_cm3_k(1)-lower-upper; matrix(1,2)=upper
      rhs(1)=w%heat_capacity_j_cm3_k(1)*initial_temperature(1)-lower*surface
    case(SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX)
      matrix(1,1)=w%heat_capacity_j_cm3_k(1)-upper; matrix(1,2)=upper
      rhs(1)=w%heat_capacity_j_cm3_k(1)*initial_temperature(1)+ &
           forcing%prescribed_top_heat_flux_j_cm2_day*dt/dz(1)
    case(SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION)
      matrix(1,1)=1.0_real64
      rhs(1)=surface-dist(1)/w%face_conductivity_j_cm_k_day(1)*forcing%prescribed_top_heat_flux_j_cm2_day
    end select
    i=2
    lower=-dt*w%face_conductivity_j_cm_k_day(i)/(dz(i)*dist(i))
    upper=-dt*w%face_conductivity_j_cm_k_day(i+1)/(dz(i)*dist(i+1))
    matrix(i,i-1)=lower; matrix(i,i)=w%heat_capacity_j_cm3_k(i)-lower-upper; matrix(i,i+1)=upper
    rhs(i)=w%heat_capacity_j_cm3_k(i)*initial_temperature(i)
    i=n; lower=-dt*w%face_conductivity_j_cm_k_day(i)/(dz(i)*dist(i)); matrix(i,i-1)=lower
    if (forcing%bottom_boundary_mode==SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX) then
      matrix(i,i)=w%heat_capacity_j_cm3_k(i)-lower
      rhs(i)=w%heat_capacity_j_cm3_k(i)*initial_temperature(i)
    else
      upper=-dt*w%node_conductivity_j_cm_k_day(i)/(dz(i)*0.5_real64*dz(i))
      matrix(i,i)=w%heat_capacity_j_cm3_k(i)-lower-upper
      rhs(i)=w%heat_capacity_j_cm3_k(i)*initial_temperature(i)-upper*forcing%prescribed_bottom_temperature_c
    end if
  end subroutine source_boundary_system

  subroutine solve_dense(matrix,rhs,solution)
    real(real64), intent(in) :: matrix(n,n),rhs(n)
    real(real64), intent(out) :: solution(n)
    real(real64) :: a(n,n),b(n),factor
    integer :: i,k
    a=matrix; b=rhs
    do k=1,n-1
      call require(abs(a(k,k))>1.0e-24_real64,'oracle pivot')
      do i=k+1,n
        factor=a(i,k)/a(k,k); a(i,k:n)=a(i,k:n)-factor*a(k,k:n); b(i)=b(i)-factor*b(k)
      end do
    end do
    solution(n)=b(n)/a(n,n)
    do i=n-1,1,-1
      solution(i)=(b(i)-sum(a(i,i+1:n)*solution(i+1:n)))/a(i,i)
    end do
  end subroutine solve_dense

  subroutine advance(state,workspace,forcing,t0,t1)
    type(soil_temperature_state_t), intent(inout) :: state
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    type(soil_temperature_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0,t1
    type(soil_temperature_state_t) :: trial
    type(soil_temperature_result_t) :: result
    type(soil_temperature_diagnostics_t) :: diagnostics
    integer :: s
    call trial_restricted_soil_temperature(numeric_parameters,numerical,forcing,hydraulic,hydraulic,state,t0,t1, &
         workspace,trial,result,diagnostics)
    call require(result%status==SOIL_TEMP_OK,'advance trial')
    call commit_soil_temperature_state(state,trial,s); call require(s==SOIL_TEMP_OK,'advance commit')
  end subroutine advance

  subroutine make_hydraulic(theta,view)
    real(real64), intent(in) :: theta(n)
    type(process_hydraulic_view_t), intent(out) :: view
    view%active_nodes=n; allocate(view%pressure_head(n),view%water_content(n))
    view%pressure_head=-100.0_real64; view%water_content=theta
  end subroutine make_hydraulic

  logical function same_bits(left,right) result(same)
    real(real64), intent(in) :: left(:),right(:)
    integer(int64), allocatable :: left_bits(:),right_bits(:)
    same=.false.
    if (size(left)/=size(right)) return
    allocate(left_bits(size(left)),right_bits(size(right)))
    left_bits=transfer(left,left_bits); right_bits=transfer(right,right_bits)
    same=all(left_bits==right_bits)
  end function same_bits

  subroutine require(ok,label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if (.not.ok) then
      write(*,'(a,1x,a)') 'MC_HEAT01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_mc_heat01_thermal_boundary
