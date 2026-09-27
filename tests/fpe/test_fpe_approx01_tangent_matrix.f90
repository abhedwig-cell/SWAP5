program test_fpe_approx01_tangent_matrix
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_accepted_step_direction_contract, only: soil_water_accepted_step_direction_request_t, &
       soil_water_accepted_step_direction_result_t, SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: duration=1.0e-4_real64, tol=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(b110_source_sink_provider_t), target :: ss
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: solve_result
  type(soil_water_accepted_step_direction_request_t) :: dreq
  type(soil_water_accepted_step_direction_result_t) :: dres
  real(real64), target :: drainage(1,numnod), irrigation(numnod), roots(numnod)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h0,hbot,k0,tr,ts,alpha,nvg,ksat,lambda
  real(real64) :: water(numnod),cond(numnod),cap(numnod),dkdh(numnod),heads(numnod)
  character(len=64) :: arg,material
  integer :: i

  if(command_argument_count()/=3) error stop 'usage: test MATERIAL H0_CM HBOT_CM'
  call get_command_argument(1,material)
  call get_command_argument(2,arg); read(arg,*) h0
  call get_command_argument(3,arg); read(arg,*) hbot
  call material_parameters(trim(material),tr,ts,alpha,nvg,ksat,lambda)

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=629301_int64; params%active_nodes=numnod
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
  request%base_state%pressure_head=heads; request%base_state%water_content=water
  request%base_state%ponding_depth=0.0_real64; request%base_state%groundwater_level=-2.0_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=SW_STEP_CONTROL_BOTTOM_HEAD
  request%boundary%top_flux=-k0
  request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=48; request%numerical%max_backtracking=16
  request%numerical%conductivity_implicit_mode=0; request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-10_real64
  request%numerical%compartment_balance_tolerance=tol; request%numerical%total_balance_tolerance=tol
  request%numerical%head_abs_tolerance=tol; request%numerical%head_rel_tolerance=tol; request%numerical%ponding_tolerance=tol
  request%evaluation%constitutive=>hyd; request%evaluation%source_sink=>ss; request%evaluation%top_boundary=>top
  request%step_duration=duration; request%request_interface_sensitivity=.false.

  dreq%requested=.true.; dreq%control_coordinate=SW_STEP_CONTROL_BOTTOM_HEAD
  allocate(dreq%incoming_pressure_head(numnod),dreq%incoming_water_content(numnod))
  dreq%incoming_pressure_head=0.0_real64; dreq%incoming_water_content=0.0_real64
  dreq%incoming_ponding_depth=0.0_real64; dreq%direct_control_derivative=1.0_real64

  call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
  write(*,'(*(g0))') 'APPROX01_MATRIX_POINT|MATERIAL=',trim(material),'|H0_CM=',h0,'|HBOT_CM=',hbot, &
       '|SOLVE_STATUS=',solve_result%status,'|DIRECTION_STATUS=',dres%status,'|ROUTE=',trim(dres%route), &
       '|TANGENT=',dres%bottom_flux_derivative,'|BOTTOM_FLUX=',solve_result%bottom_flux, &
       '|NONLINEAR=',solve_result%diagnostics%nonlinear_iterations,'|BACKTRACK=',solve_result%diagnostics%backtracking_attempts

  if(solve_result%status/=SW_SOLVE_CONVERGED) error stop 'matrix physical solve did not converge'
  if(dres%status/=SW_STEP_DIRECTION_AVAILABLE .or. .not.dres%available) error stop 'matrix tangent unavailable'
  if(.not.ieee_is_finite(dres%bottom_flux_derivative)) error stop 'matrix tangent nonfinite'
  print '(A)','FPE_APPROX01_TANGENT_MATRIX_POINT=PASS'

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
end program test_fpe_approx01_tangent_matrix
