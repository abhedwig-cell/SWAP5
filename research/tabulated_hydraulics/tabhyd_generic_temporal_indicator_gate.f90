program tabhyd_generic_temporal_indicator_gate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_temporal_indicator, only: evaluate_reference_richards_temporal_indicator
  use mod_reference_richards_temporal_indicator_generic_research, only: &
       evaluate_reference_richards_temporal_indicator_generic
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, &
       TABHYD_RAW_TABLE_N
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: wa, wt
  type(soil_water_solve_request_t) :: ra, rt
  type(soil_water_solve_result_t) :: resa, rest
  type(soil_water_temporal_indicator_request_t) :: ireqa, ireqt
  type(soil_water_temporal_indicator_result_t) :: original_a, generic_a, original_t, generic_t

  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: h0(:), ta(:),ka(:),ca(:),da(:), tt(:),kt(:),ct(:),dtbl(:)
  real(real64) :: step_duration, hbase, bottom_jump, top_flux
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr,mpar
  real(real64) :: scale, max_derivative_diff
  integer :: nodes,nt,i,j,iu,ios
  character(len=32) :: soil
  character(len=512) :: path

  if(command_argument_count()<1) error stop 'usage: temporal-gate INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) nodes,nt,step_duration,hbase,bottom_jump
  if(ios/=0 .or. nodes/=numnod .or. nt/=TABHYD_RAW_TABLE_N) error stop 'invalid input header'

  allocate(cofgen(24,nodes),headtab(nt,nodes),thetatab(nt,nodes),ktab(nt,nodes))
  cofgen=0.0_real64
  do i=1,nodes
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp,henpr
    if(ios/=0) error stop 'invalid material row'
    mpar=1.0_real64-1.0_real64/npar
    cofgen(1,i)=ores; cofgen(2,i)=osat; cofgen(3,i)=ksat
    cofgen(4,i)=alpha; cofgen(5,i)=lexp; cofgen(6,i)=npar
    cofgen(7,i)=mpar; cofgen(9,i)=henpr
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  parameters%parameter_set_id=552001_int64
  parameters%active_nodes=nodes
  allocate(parameters%z(nodes),parameters%dz(nodes),parameters%node_distance(nodes))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:nodes)

  allocate(drainage(1,nodes),subsurface(nodes),root_sink(nodes))
  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  allocate(h0(nodes),ta(nodes),ka(nodes),ca(nodes),da(nodes),tt(nodes),kt(nodes),ct(nodes),dtbl(nodes))
  do i=1,nodes
    h0(i)=hbase + 0.15_real64*real(i-1,real64)
  end do
  call analytic%evaluate(h0,ta,ka,ca,da)
  call table%evaluate(h0,tt,kt,ct,dtbl)
  top_flux=-0.97_real64*ka(1)

  call configure_request(ra,analytic,h0,ta,top_flux)
  call configure_request(rt,table,h0,tt,top_flux)

  call solver%solve(ra,wa,resa)
  call solver%solve(rt,wt,rest)
  call require(resa%status==SW_SOLVE_CONVERGED,'analytic solve converged')
  call require(rest%status==SW_SOLVE_CONVERGED,'table solve converged')

  ireqa%previous_right_derivative_available=.true.
  allocate(ireqa%previous_right_derivative(nodes))
  ireqa%previous_right_derivative=0.25_real64 * &
       (resa%candidate_state%pressure_head-ra%base_state%pressure_head)/step_duration
  ireqt%previous_right_derivative_available=.true.
  allocate(ireqt%previous_right_derivative(nodes))
  ! Use the same physical history construction for each provider route.
  ireqt%previous_right_derivative=0.25_real64 * &
       (rest%candidate_state%pressure_head-rt%base_state%pressure_head)/step_duration

  call evaluate_reference_richards_temporal_indicator(ra,resa,ireqa,original_a)
  call evaluate_reference_richards_temporal_indicator_generic(ra,resa,ireqa,generic_a)

  call require(original_a%status==generic_a%status,'phase A status')
  call require(original_a%available.eqv.generic_a%available,'phase A availability')
  call require(trim(original_a%route)==trim(generic_a%route),'phase A route')
  call require(original_a%additional_full_nonlinear_solves==generic_a%additional_full_nonlinear_solves, &
       'phase A nonlinear count')
  call require(original_a%additional_tridiagonal_solves==generic_a%additional_tridiagonal_solves, &
       'phase A tridiagonal count')
  call require_close(original_a%raw_m_norm,generic_a%raw_m_norm,'phase A raw norm')
  call require_close(original_a%defect_m_norm,generic_a%defect_m_norm,'phase A defect norm')
  call require_close(original_a%bounded_m_norm,generic_a%bounded_m_norm,'phase A bounded norm')
  call require_close(original_a%head_inf_bound,generic_a%head_inf_bound,'phase A head bound')
  call require_close(original_a%min_mass_weight,generic_a%min_mass_weight,'phase A min mass weight')
  call require(allocated(original_a%current_right_derivative).and.allocated(generic_a%current_right_derivative), &
       'phase A derivative allocated')
  scale=max(1.0_real64,maxval(abs(original_a%current_right_derivative)))
  max_derivative_diff=maxval(abs(original_a%current_right_derivative-generic_a%current_right_derivative))
  call require(max_derivative_diff<=1.0e-14_real64*scale,'phase A derivative')

  write(*,'(a,i0)') 'PHASE_A_STATUS=',original_a%status
  write(*,'(a,a)') 'PHASE_A_ROUTE=',trim(original_a%route)
  write(*,'(a,es24.16)') 'PHASE_A_HEAD_BOUND=',original_a%head_inf_bound
  write(*,'(a,es24.16)') 'PHASE_A_DERIVATIVE_MAX_DIFF=',max_derivative_diff
  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_A_ANALYTICAL_EQUIVALENCE=PASS'

  ! Canonical implementation must still reject the non-analytical provider.
  call evaluate_reference_richards_temporal_indicator(rt,rest,ireqt,original_t)
  call require(original_t%status==SW_TEMPORAL_INDICATOR_UNAVAILABLE,'canonical table indicator unavailable')
  call require(trim(original_t%route)=='constitutive-policy-deferred','canonical table deferred route')

  ! Research generic implementation may characterize the exact same formula.
  call evaluate_reference_richards_temporal_indicator_generic(rt,rest,ireqt,generic_t)
  call require(generic_t%status==SW_TEMPORAL_INDICATOR_AVAILABLE,'generic table indicator available')
  call require(generic_t%available,'generic table indicator flag')
  call require(generic_t%additional_tridiagonal_solves==1,'generic table tridiagonal count')

  write(*,'(a,i0)') 'PHASE_B_ANALYTIC_STATUS=',generic_a%status
  write(*,'(a,i0)') 'PHASE_B_TABLE_STATUS=',generic_t%status
  write(*,'(a,a)') 'PHASE_B_ANALYTIC_ROUTE=',trim(generic_a%route)
  write(*,'(a,a)') 'PHASE_B_TABLE_ROUTE=',trim(generic_t%route)
  write(*,'(a,es24.16)') 'PHASE_B_ANALYTIC_RAW_NORM=',generic_a%raw_m_norm
  write(*,'(a,es24.16)') 'PHASE_B_TABLE_RAW_NORM=',generic_t%raw_m_norm
  write(*,'(a,es24.16)') 'PHASE_B_ANALYTIC_DEFECT_NORM=',generic_a%defect_m_norm
  write(*,'(a,es24.16)') 'PHASE_B_TABLE_DEFECT_NORM=',generic_t%defect_m_norm
  write(*,'(a,es24.16)') 'PHASE_B_ANALYTIC_HEAD_BOUND=',generic_a%head_inf_bound
  write(*,'(a,es24.16)') 'PHASE_B_TABLE_HEAD_BOUND=',generic_t%head_inf_bound
  write(*,'(a,es24.16)') 'PHASE_B_HEAD_BOUND_DELTA=',generic_t%head_inf_bound-generic_a%head_inf_bound
  write(*,'(a)') 'TABHYD_TEMPORAL_PHASE_B_TABLE_CHARACTERIZATION=PASS'

contains

  subroutine configure_request(req,provider,heads,water,forcing_top)
    use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
    type(soil_water_solve_request_t), intent(out) :: req
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: heads(:),water(:),forcing_top
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=nodes
    allocate(req%base_state%pressure_head(nodes),req%base_state%water_content(nodes))
    req%base_state%pressure_head=heads
    req%base_state%water_content=water
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-100.0_real64
    req%step_duration=step_duration
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=5
    req%boundary%top_flux=forcing_top
    req%boundary%top_head=heads(1)
    req%boundary%bottom_flux=0.0_real64
    req%boundary%bottom_head=heads(nodes)+bottom_jump
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=20
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-7_real64
    req%numerical%total_balance_tolerance=1.0e-7_real64
    req%numerical%head_abs_tolerance=1.0e-6_real64
    req%numerical%head_rel_tolerance=1.0e-6_real64
    req%numerical%ponding_tolerance=1.0e-8_real64
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine configure_request

  subroutine require_close(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    real(real64)::tol
    tol=1.0e-14_real64*max(1.0_real64,abs(a))
    call require(abs(a-b)<=tol,label)
  end subroutine require_close

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'TABHYD_TEMPORAL_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program tabhyd_generic_temporal_indicator_gate
