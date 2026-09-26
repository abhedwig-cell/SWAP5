program test_fpe_approx02_richards_effort
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: base_tol=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(b110_source_sink_provider_t), target :: ss
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), target :: drainage(1,numnod), irrigation(numnod), roots(numnod)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0,hbot,top_factor,duration,tol_mult
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,k0
  real(real64) :: water(numnod),cond(numnod),cap(numnod),dkdh(numnod),heads(numnod)
  real(real64) :: t0,t1,elapsed
  character(len=64) :: arg
  character(len=8) :: material
  integer :: i,j,calls,warmups

  if(command_argument_count()/=6 .and. command_argument_count()/=7) &
       error stop 'usage: MATERIAL H0_CM HBOT_CM TOP_FACTOR DURATION_DAY TOL_MULT [CALLS]'
  call get_command_argument(1,material)
  call get_command_argument(2,arg); read(arg,*) h0
  call get_command_argument(3,arg); read(arg,*) hbot
  call get_command_argument(4,arg); read(arg,*) top_factor
  call get_command_argument(5,arg); read(arg,*) duration
  call get_command_argument(6,arg); read(arg,*) tol_mult
  calls=1
  if(command_argument_count()==7)then
    call get_command_argument(7,arg); read(arg,*) calls
  end if
  if(duration<=0.0_real64 .or. tol_mult<=0.0_real64 .or. calls<=0) error stop 'invalid duration/tolerance/calls'

  call material_parameters(trim(material),tr,ts,alpha,nvg,ksat,lambda)
  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=630001_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=tr; cofgen(2,i)=ts; cofgen(3,i)=ksat
    cofgen(4,i)=alpha; cofgen(5,i)=lambda; cofgen(6,i)=nvg
    cofgen(7,i)=1.0_real64-1.0_real64/nvg; cofgen(8,i)=alpha
    cofgen(9,i)=0.0_real64; cofgen(10,i)=ksat; cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*ksat; cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,duration)

  heads=h0
  call hyd%evaluate(heads,water,cond,cap,dkdh)
  k0=cond(1)

  drainage=0.0_real64; irrigation=0.0_real64; roots=0.0_real64
  call bind_b110_source_sink_provider(ss,drainage,irrigation,roots)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=heads
  request%base_state%water_content=water
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-2.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=7
  request%boundary%top_flux=top_factor*k0
  request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=48
  request%numerical%max_backtracking=16
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
  request%numerical%compartment_balance_tolerance=base_tol
  request%numerical%total_balance_tolerance=base_tol
  request%numerical%head_abs_tolerance=base_tol*tol_mult
  request%numerical%head_rel_tolerance=base_tol*tol_mult
  request%numerical%ponding_tolerance=base_tol
  request%evaluation%constitutive=>hyd
  request%evaluation%source_sink=>ss
  request%evaluation%top_boundary=>top
  request%step_duration=duration
  request%request_interface_sensitivity=.false.

  warmups=0
  if(calls>1) warmups=min(20,max(2,calls/100))
  do j=1,warmups
    call solver%solve(request,workspace,result)
  end do

  call cpu_time(t0)
  do j=1,calls
    call solver%solve(request,workspace,result)
  end do
  call cpu_time(t1)
  elapsed=(t1-t0)/real(calls,real64)

  write(*,'(*(g0))') 'APPROX02_SOLVE|MATERIAL=',trim(material),'|H0=',h0,'|HBOT=',hbot, &
       '|TOP_FACTOR=',top_factor,'|DURATION=',duration,'|TOL_MULT=',tol_mult, &
       '|STATUS=',result%status,'|CALLS=',calls,'|SECONDS_PER_SOLVE=',elapsed,'|NS_PER_SOLVE=',1.0e9_real64*elapsed, &
       '|NONLINEAR=',result%diagnostics%nonlinear_iterations, &
       '|JACOBIAN=',result%diagnostics%jacobian_builds, &
       '|LINEAR=',result%diagnostics%linear_solves, &
       '|BACKTRACK=',result%diagnostics%backtracking_attempts, &
       '|BOTTOM_FLUX=',result%bottom_flux, &
       '|MASS_RESIDUAL=',result%integrated_mass_balance_residual_cm, &
       '|H1=',result%candidate_state%pressure_head(1), &
       '|H2=',result%candidate_state%pressure_head(2), &
       '|H3=',result%candidate_state%pressure_head(3), &
       '|H4=',result%candidate_state%pressure_head(4), &
       '|TH1=',result%candidate_state%water_content(1), &
       '|TH2=',result%candidate_state%water_content(2), &
       '|TH3=',result%candidate_state%water_content(3), &
       '|TH4=',result%candidate_state%water_content(4)

  if(result%status==SW_SOLVE_CONVERGED)then
    if(.not.ieee_is_finite(result%bottom_flux)) error stop 'nonfinite bottom flux'
    if(any(.not.ieee_is_finite(result%candidate_state%pressure_head))) error stop 'nonfinite pressure head'
    if(any(.not.ieee_is_finite(result%candidate_state%water_content))) error stop 'nonfinite water content'
  end if

contains

  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop 'unknown material'
    end select
  end subroutine material_parameters
end program test_fpe_approx02_richards_effort
