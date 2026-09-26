program test_fpe_approx01_cadence_timing
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_soil_water_accepted_step_direction_contract, only: soil_water_accepted_step_direction_request_t, &
       soil_water_accepted_step_direction_result_t, SW_STEP_DIRECTION_AVAILABLE, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_accepted_step_directional_service, only: solve_with_accepted_step_direction
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: duration=1.0e-4_real64, tol=1.0e-12_real64
  real(real64), parameter :: pattern(12)=[0.0_real64,0.1_real64,0.2_real64,0.5_real64,1.0_real64,0.5_real64, &
       0.2_real64,0.0_real64,-0.1_real64,-0.2_real64,-0.5_real64,-1.0_real64]
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
  real(real64) :: h0,k0,water(numnod),cond(numnod),cap(numnod),dkdh(numnod),heads(numnod)
  real(real64) :: checksum,cached_tangent,elapsed,physical_checksum,amplitude,head_threshold,current_head,last_refresh_head
  integer :: i,j,calls,cadence,clock_start,clock_end,clock_rate,refreshes,point,age
  character(len=64) :: arg,mode

  if(command_argument_count()/=4 .and. command_argument_count()/=6) &
       error stop 'usage: test MODE CADENCE CALLS H0_CM [AMPLITUDE_CM HEAD_THRESHOLD_CM]'
  call get_command_argument(1,mode)
  call get_command_argument(2,arg); read(arg,*) cadence
  call get_command_argument(3,arg); read(arg,*) calls
  call get_command_argument(4,arg); read(arg,*) h0
  amplitude=0.5_real64
  head_threshold=0.25_real64
  if(command_argument_count()==6) then
    call get_command_argument(5,arg); read(arg,*) amplitude
    call get_command_argument(6,arg); read(arg,*) head_threshold
  end if
  if(calls<=0 .or. cadence<=0 .or. amplitude<0.0_real64 .or. head_threshold<0.0_real64) &
       error stop 'invalid timing arguments'

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
  params%parameter_set_id=629201_int64; params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)
  cofgen=0.0_real64
  do i=1,numnod
    cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
    cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
    cofgen(9,i)=0.0_real64; cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i); cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
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
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=32; request%numerical%max_backtracking=12
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

  ! Warm the exact path.
  request%boundary%bottom_head=h0
  call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
  if(solve_result%status/=SW_SOLVE_CONVERGED .or. dres%status/=SW_STEP_DIRECTION_AVAILABLE) error stop 'warmup failed'

  checksum=0.0_real64; physical_checksum=0.0_real64; cached_tangent=0.0_real64; refreshes=0
  age=cadence
  last_refresh_head=huge(1.0_real64)
  call system_clock(clock_start,clock_rate)
  do j=1,calls
    point=1+mod(j-1,12)
    current_head=h0+amplitude*pattern(point)
    request%boundary%bottom_head=current_head
    if(trim(mode)=='fresh') then
      refresh=.true.
    else if(trim(mode)=='lag') then
      refresh=mod(j-1,cadence)==0
    else if(trim(mode)=='adaptive') then
      refresh=(j==1) .or. age>=cadence .or. abs(current_head-last_refresh_head)>=head_threshold
    else
      error stop 'unknown timing mode'
    end if
    if(refresh) then
      call solve_with_accepted_step_direction(solver,request,workspace,dreq,solve_result,dres)
      if(solve_result%status/=SW_SOLVE_CONVERGED .or. dres%status/=SW_STEP_DIRECTION_AVAILABLE) error stop 'fresh solve failed'
      cached_tangent=dres%bottom_flux_derivative
      refreshes=refreshes+1
      last_refresh_head=current_head
      age=0
    else
      call solver%solve(request,workspace,solve_result)
      if(solve_result%status/=SW_SOLVE_CONVERGED) error stop 'reference solve failed'
    end if
    age=age+1
    if(.not.ieee_is_finite(cached_tangent)) error stop 'cached tangent nonfinite'
    physical_checksum=physical_checksum+solve_result%bottom_flux+sum(solve_result%candidate_state%pressure_head)+ &
         sum(solve_result%candidate_state%water_content)
    checksum=checksum+cached_tangent
  end do
  call system_clock(clock_end)
  elapsed=real(clock_end-clock_start,real64)/real(clock_rate,real64)

  write(*,'(*(g0))') 'APPROX01_CADENCE_TIMING|MODE=',trim(mode),'|CADENCE=',cadence,'|CALLS=',calls, &
       '|NS_PER_EVAL=',1.0e9_real64*elapsed/real(calls,real64),'|REFRESHES=',refreshes, &
       '|REFRESH_FRACTION=',real(refreshes,real64)/real(calls,real64),'|AMPLITUDE_CM=',amplitude, &
       '|HEAD_THRESHOLD_CM=',head_threshold,'|TANGENT_CHECKSUM=',checksum,'|PHYSICAL_CHECKSUM=',physical_checksum
  print '(A)','FPE_APPROX01_CADENCE_TIMING=PASS'
end program test_fpe_approx01_cadence_timing
