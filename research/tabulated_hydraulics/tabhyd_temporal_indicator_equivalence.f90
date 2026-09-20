program tabhyd_temporal_indicator_equivalence
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_temporal_indicator, only: evaluate_reference_richards_temporal_indicator
  use mod_reference_richards_temporal_indicator_generic_research, only: &
       evaluate_reference_richards_temporal_indicator_generic
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, &
       initialize_tabhyd_raw_provider_from_mvg, TABHYD_RAW_TABLE_N
  implicit none

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver_a, solver_t
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_t
  type(soil_water_solve_request_t) :: req_a, req_t
  type(soil_water_solve_result_t) :: res_a, res_t
  type(soil_water_temporal_indicator_request_t) :: ireq
  type(soil_water_temporal_indicator_result_t) :: ican, igen_a, ican_t, igen_t
  real(real64), allocatable :: cofgen(:,:), dummy_h(:,:), dummy_t(:,:), dummy_k(:,:)
  real(real64), target :: drainage(1,numnod), subsurface(numnod), rootsink(numnod)
  real(real64) :: theta_a(numnod), theta_t(numnod), k(numnod), c(numnod), d(numnod)
  real(real64) :: initial_head, step_duration, top_flux, bottom_flux, bottom_head, scale, max_deriv_diff
  integer :: bottom_mode, iu, ios, nodes, nt, i, j
  character(len=512) :: path
  character(len=32) :: soil

  if(command_argument_count()/=1) error stop 'usage: temporal-equivalence INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) nodes,nt,step_duration,initial_head,top_flux,bottom_flux,bottom_mode,bottom_head
  if(ios/=0 .or. nodes/=numnod .or. nt/=TABHYD_RAW_TABLE_N) error stop 'invalid input header'

  allocate(cofgen(24,numnod),dummy_h(nt,numnod),dummy_t(nt,numnod),dummy_k(nt,numnod))
  cofgen=0.0_real64
  do i=1,numnod
    read(iu,*,iostat=ios) soil,cofgen(1,i),cofgen(2,i),cofgen(4,i),cofgen(6,i),cofgen(3,i),cofgen(5,i),cofgen(9,i)
    if(ios/=0) error stop 'invalid material row'
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i); cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*cofgen(3,i)
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    do j=1,nt
      read(iu,*,iostat=ios) dummy_h(j,i),dummy_t(j,i),dummy_k(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  parameters%parameter_set_id=993001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytic,hp,step_duration)
  call initialize_tabhyd_raw_provider_from_mvg(table,cofgen,step_duration)

  call analytic%evaluate(spread(initial_head,1,numnod),theta_a,k,c,d)
  call table%evaluate(spread(initial_head,1,numnod),theta_t,k,c,d)

  drainage=0.0_real64; subsurface=0.0_real64; rootsink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,rootsink)
  call build_request(req_a,analytic,theta_a)
  call build_request(req_t,table,theta_t)

  call solver_a%solve(req_a,workspace_a,res_a)
  call solver_t%solve(req_t,workspace_t,res_t)
  call require(res_a%status==SW_SOLVE_CONVERGED,'analytic solve')
  call require(res_t%status==SW_SOLVE_CONVERGED,'table solve')

  ireq%previous_right_derivative_available=.true.
  allocate(ireq%previous_right_derivative(numnod))
  ireq%previous_right_derivative=0.0_real64

  call evaluate_reference_richards_temporal_indicator(req_a,res_a,ireq,ican)
  call evaluate_reference_richards_temporal_indicator_generic(req_a,res_a,ireq,igen_a)
  call compare_analytic_indicators()

  ! Canonical policy must still demonstrate the present blocker on the table provider.
  call evaluate_reference_richards_temporal_indicator(req_t,res_t,ireq,ican_t)
  call require(ican_t%status==SW_TEMPORAL_INDICATOR_UNAVAILABLE,'canonical table indicator unavailable')
  call require(trim(ican_t%route)=='constitutive-policy-deferred','canonical table policy route')

  call evaluate_reference_richards_temporal_indicator_generic(req_t,res_t,ireq,igen_t)
  call require(igen_t%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. igen_t%available,'generic table indicator available')
  call require(ieee_is_finite(igen_t%head_inf_bound) .and. igen_t%head_inf_bound>=0.0_real64,'table head bound finite')
  call require(all(ieee_is_finite(igen_t%current_right_derivative)),'table derivative finite')

  write(*,'(a,i0)') 'TEMPORAL_CANONICAL_STATUS=',ican%status
  write(*,'(a,a)') 'TEMPORAL_CANONICAL_ROUTE=',trim(ican%route)
  write(*,'(a,es24.16)') 'TEMPORAL_ANALYTIC_HEAD_BOUND=',ican%head_inf_bound
  write(*,'(a,es24.16)') 'TEMPORAL_TABLE_HEAD_BOUND=',igen_t%head_inf_bound
  write(*,'(a,es24.16)') 'TEMPORAL_TABLE_RAW_NORM=',igen_t%raw_m_norm
  write(*,'(a,es24.16)') 'TEMPORAL_TABLE_DEFECT_NORM=',igen_t%defect_m_norm
  write(*,'(a,es24.16)') 'TEMPORAL_TABLE_BOUNDED_NORM=',igen_t%bounded_m_norm
  write(*,'(a,a)') 'TEMPORAL_TABLE_ROUTE=',trim(igen_t%route)
  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_A=PASS'
  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_B=PASS'

contains

  subroutine build_request(req,provider,theta0)
    type(soil_water_solve_request_t), intent(out) :: req
    class(*), target, intent(inout) :: provider
    real(real64), intent(in) :: theta0(:)
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=initial_head
    req%base_state%water_content=theta0
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=bottom_mode
    req%boundary%top_flux=top_flux
    req%boundary%bottom_flux=bottom_flux
    req%boundary%top_head=initial_head
    req%boundary%bottom_head=bottom_head
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-10_real64
    req%numerical%head_rel_tolerance=1.0e-10_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%step_duration=step_duration
    select type(provider)
    type is (b110_default_mvg_provider_t)
      req%evaluation%constitutive=>provider
    type is (tabhyd_raw_provider_t)
      req%evaluation%constitutive=>provider
    class default
      error stop 'unsupported provider'
    end select
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_boundary
  end subroutine build_request

  subroutine compare_analytic_indicators()
    call require(ican%status==igen_a%status,'analytic status identity')
    call require(ican%available.eqv.igen_a%available,'analytic availability identity')
    call require(trim(ican%route)==trim(igen_a%route),'analytic route identity')
    call require(ican%additional_full_nonlinear_solves==igen_a%additional_full_nonlinear_solves,'analytic nonlinear counter')
    call require(ican%additional_tridiagonal_solves==igen_a%additional_tridiagonal_solves,'analytic tridag counter')
    call same_scalar(ican%raw_m_norm,igen_a%raw_m_norm,'raw norm')
    call same_scalar(ican%defect_m_norm,igen_a%defect_m_norm,'defect norm')
    call same_scalar(ican%bounded_m_norm,igen_a%bounded_m_norm,'bounded norm')
    call same_scalar(ican%head_inf_bound,igen_a%head_inf_bound,'head bound')
    call same_scalar(ican%min_mass_weight,igen_a%min_mass_weight,'min mass weight')
    call require(allocated(ican%current_right_derivative).and.allocated(igen_a%current_right_derivative),'derivatives allocated')
    scale=max(1.0_real64,maxval(abs(ican%current_right_derivative)))
    max_deriv_diff=maxval(abs(ican%current_right_derivative-igen_a%current_right_derivative))
    call require(max_deriv_diff<=1.0e-14_real64*scale,'right derivative identity')
  end subroutine compare_analytic_indicators

  subroutine same_scalar(a,b,label)
    real(real64), intent(in) :: a,b
    character(len=*), intent(in) :: label
    real(real64) :: s
    s=max(1.0_real64,abs(a))
    call require(abs(a-b)<=1.0e-14_real64*s,label)
  end subroutine same_scalar

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'TABHYD_TEMPORAL_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program tabhyd_temporal_indicator_equivalence
