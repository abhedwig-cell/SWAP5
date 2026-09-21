program test_gc_hlink_low01a_below_profile
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_gc_hlink_low01_groundwater_level_adapter, only: gc_low01_groundwater_level_control_t, &
       materialize_low01a_below_profile, classify_low01_groundwater_level, LOW01_GWL_OK, &
       LOW01_GWL_UNSUPPORTED_BRANCH, LOW01_BRANCH_BELOW_PROFILE, LOW01_BRANCH_INSIDE_PROFILE, &
       LOW01_BRANCH_ABOVE_OR_AT_TOP
  implicit none

  real(real64), parameter :: dt_day=1.0e-2_real64
  real(real64), parameter :: hard_mass=1.0e-12_real64
  real(real64), parameter :: head_offset=-5.0e-2_real64
  real(real64), parameter :: groundwater_levels(3)=[-3.25_real64,-4.0_real64,-5.0_real64]
  real(real64), parameter :: expected_hbot(3)=[-0.25_real64,-1.0_real64,-2.0_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws_typed, ws_direct, ws_replay
  type(fmr_b110_physical_forcing_t) :: base_forcing, typed_forcing
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  integer :: i

  call configure_parameters(parameters,hydraulic_parameters,constitutive,source_sink, &
       base_forcing,drainage,subsurface,root_sink,cofgen)

  call branch_fail_closed_controls(base_forcing)

  do i=1,size(groundwater_levels)
    call run_equivalence_case(i,groundwater_levels(i),expected_hbot(i))
  end do

  write(*,'(A)') 'GC_LOW01A_SOURCE_MAPPING_IDENTITY=PASS'
  write(*,'(A)') 'GC_LOW01A_LIVE_MODE5_EQUIVALENCE=PASS'
  write(*,'(A)') 'GC_LOW01A_REPLAY_DETERMINISM=PASS'
  write(*,'(A)') 'GC_LOW01A_UNSUPPORTED_BRANCH_FAIL_CLOSED=PASS'
  write(*,'(A)') 'GC_LOW01A_LIVE_GATE=PASS'

contains

  subroutine run_equivalence_case(case_id,gwl,hbot_expected)
    integer, intent(in) :: case_id
    real(real64), intent(in) :: gwl,hbot_expected
    type(gc_low01_groundwater_level_control_t) :: control
    type(soil_water_physical_state_t) :: origin, origin_copy
    type(soil_water_solve_request_t) :: typed_request, direct_request, replay_request
    type(soil_water_solve_result_t) :: typed_result, direct_result, replay_result
    real(real64) :: heads0(numnod), water0(numnod), conductivity0(numnod), capacity0(numnod), dkdh0(numnod)
    real(real64) :: initial_head, top_flux, lower_face, gradient_mode1, gradient_mode5
    integer :: branch,status

    control%groundwater_level=gwl
    call materialize_low01a_below_profile(control,parameters%z,parameters%dz,base_forcing,typed_forcing,branch,status)
    call require(status==LOW01_GWL_OK,'typed GWL materialization status')
    call require(branch==LOW01_BRANCH_BELOW_PROFILE,'typed GWL below-profile branch')
    call require(close_fp(typed_forcing%bottom_head,hbot_expected),'typed hbot oracle')

    lower_face=parameters%z(numnod)-0.5_real64*parameters%dz(numnod)
    call require(gwl<lower_face,'preregistered GWL below lower face')
    call require(close_fp(hbot_expected,gwl-parameters%z(numnod)+0.5_real64*parameters%dz(numnod)), &
         'source hbot identity')

    initial_head=hbot_expected+head_offset
    heads0=initial_head
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt_day)
    call constitutive%evaluate(heads0,water0,conductivity0,capacity0,dkdh0)
    call require(all(ieee_is_finite(water0)) .and. all(ieee_is_finite(conductivity0)), &
         'finite initial constitutive state')
    top_flux=-conductivity0(1)

    call initialize_origin(origin,heads0,water0,gwl)
    origin_copy=origin

    call build_request(typed_request,origin,typed_forcing%bottom_head,top_flux)
    call build_request(direct_request,origin,hbot_expected,top_flux)
    call build_request(replay_request,origin,typed_forcing%bottom_head,top_flux)

    gradient_mode1=(initial_head-(gwl-parameters%z(numnod)+0.5_real64*parameters%dz(numnod))) / &
         parameters%node_distance(numnod) + 1.0_real64
    gradient_mode5=(initial_head-hbot_expected)/parameters%node_distance(numnod)+1.0_real64
    call require(close_fp(gradient_mode1,gradient_mode5),'mode1/mode5 lower-gradient identity')

    call solver%solve(typed_request,ws_typed,typed_result)
    call solver%solve(direct_request,ws_direct,direct_result)
    call solver%solve(replay_request,ws_replay,replay_result)

    call require(typed_result%status==SW_SOLVE_CONVERGED,'typed route converged')
    call require(direct_result%status==SW_SOLVE_CONVERGED,'direct mode5 converged')
    call require(replay_result%status==SW_SOLVE_CONVERGED,'typed replay converged')

    call compare_result(typed_result,direct_result,'typed/direct')
    call compare_result(typed_result,replay_result,'typed/replay')
    call compare_origin(origin,origin_copy)

    write(*,'(A,I0,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') &
         'GC_LOW01A_CASE_',case_id,'_GWL=',gwl,':HBOT=',typed_forcing%bottom_head, &
         ':QBOT=',typed_result%bottom_flux,':MASS=',typed_result%integrated_mass_balance_residual_cm
  end subroutine run_equivalence_case

  subroutine build_request(request,origin,bottom_head,top_flux)
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_physical_state_t), intent(in) :: origin
    real(real64), intent(in) :: bottom_head,top_flux

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=origin
    request%step_duration=dt_day
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=5
    request%boundary%top_flux=top_flux
    request%boundary%top_head=origin%pressure_head(1)
    request%boundary%bottom_flux=0.0_real64
    request%boundary%bottom_head=bottom_head
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=16
    request%numerical%max_backtracking=8
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-8_real64
    request%numerical%compartment_balance_tolerance=hard_mass
    request%numerical%total_balance_tolerance=hard_mass
    request%numerical%head_abs_tolerance=1.0e-12_real64
    request%numerical%head_rel_tolerance=1.0e-12_real64
    request%numerical%ponding_tolerance=1.0e-12_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider
  end subroutine build_request

  subroutine configure_parameters(p,hp,cp,sp,forcing,qdra,qssdi,qrot,c)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    integer :: k

    p%parameter_set_id=910101_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z
    p%dz=dz
    p%node_distance=disnod(1:numnod)

    allocate(c(24,numnod))
    c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,dt_day)

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)

    forcing=fmr_b110_physical_forcing_t()
    forcing%top_flux=0.0_real64
    forcing%top_head=0.0_real64
    forcing%bottom_flux=0.0_real64
    forcing%bottom_head=0.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine configure_parameters

  subroutine initialize_origin(state,heads,water,gwl)
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), intent(in) :: heads(:),water(:),gwl
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=gwl
  end subroutine initialize_origin

  subroutine compare_result(a,b,label)
    type(soil_water_solve_result_t), intent(in) :: a,b
    character(len=*), intent(in) :: label
    call require(a%candidate_state%active_nodes==b%candidate_state%active_nodes,label//' active nodes')
    call require(array_close_fp(a%candidate_state%pressure_head,b%candidate_state%pressure_head),label//' heads')
    call require(array_close_fp(a%candidate_state%water_content,b%candidate_state%water_content),label//' water')
    call require(close_fp(a%candidate_state%ponding_depth,b%candidate_state%ponding_depth),label//' ponding')
    call require(close_fp(a%candidate_state%groundwater_level,b%candidate_state%groundwater_level),label//' gwl')
    call require(close_fp(a%top_flux,b%top_flux),label//' qtop')
    call require(close_fp(a%bottom_flux,b%bottom_flux),label//' qbot')
    call require(a%integrated_mass_balance_residual_available .eqv. b%integrated_mass_balance_residual_available, &
         label//' mass availability')
    if(a%integrated_mass_balance_residual_available) then
      call require(close_fp(a%integrated_mass_balance_residual_cm,b%integrated_mass_balance_residual_cm),label//' mass residual')
      call require(abs(a%integrated_mass_balance_residual_cm)<=hard_mass,label//' hard mass')
    end if
  end subroutine compare_result

  subroutine compare_origin(a,b)
    type(soil_water_physical_state_t), intent(in) :: a,b
    call require(a%active_nodes==b%active_nodes,'origin active nodes immutable')
    call require(array_close_fp(a%pressure_head,b%pressure_head),'origin heads immutable')
    call require(array_close_fp(a%water_content,b%water_content),'origin water immutable')
    call require(close_fp(a%ponding_depth,b%ponding_depth),'origin ponding immutable')
    call require(close_fp(a%groundwater_level,b%groundwater_level),'origin gwl immutable')
  end subroutine compare_origin

  subroutine branch_fail_closed_controls(forcing)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(gc_low01_groundwater_level_control_t) :: control
    type(fmr_b110_physical_forcing_t) :: candidate
    integer :: branch,status

    control%groundwater_level=-2.75_real64
    call classify_low01_groundwater_level(control,parameters%z,parameters%dz,branch,status)
    call require(status==LOW01_GWL_OK .and. branch==LOW01_BRANCH_INSIDE_PROFILE,'inside classification')
    call materialize_low01a_below_profile(control,parameters%z,parameters%dz,forcing,candidate,branch,status)
    call require(status==LOW01_GWL_UNSUPPORTED_BRANCH,'inside fail closed')

    control%groundwater_level=0.0_real64
    call classify_low01_groundwater_level(control,parameters%z,parameters%dz,branch,status)
    call require(status==LOW01_GWL_OK .and. branch==LOW01_BRANCH_ABOVE_OR_AT_TOP,'above classification')
    call materialize_low01a_below_profile(control,parameters%z,parameters%dz,forcing,candidate,branch,status)
    call require(status==LOW01_GWL_UNSUPPORTED_BRANCH,'above fail closed')
  end subroutine branch_fail_closed_controls

  logical function close_fp(a,b)
    real(real64), intent(in) :: a,b
    close_fp=abs(a-b)<=16.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function close_fp

  logical function array_close_fp(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: j
    array_close_fp=.false.
    if(size(a)/=size(b))return
    do j=1,size(a)
      if(.not.close_fp(a(j),b(j)))return
    end do
    array_close_fp=.true.
  end function array_close_fp

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'GC_LOW01A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_gc_hlink_low01a_below_profile
