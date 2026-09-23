program test_rm18_dynamic_flux_temporal_certificate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX, FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: dt=1.0e-4_real64, h0=-75.0_real64, qtop=-36.0_real64, qbot=1.0e-6_real64
  type(soil_water_parameter_set_t), target :: p
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_dynamic_top_boundary_solver_provider_t), target :: dynamic_top
  type(fixed_flux_top_boundary_provider_t), target :: fixed_top
  type(reference_richards_legacy_solver_t) :: dyn_solver,fix_solver
  type(reference_richards_legacy_workspace_t) :: dyn_ws,fix_ws
  type(soil_water_solve_request_t) :: dyn_req,fix_req
  type(soil_water_solve_result_t) :: dyn_res,fix_res,bad_res
  type(soil_water_temporal_indicator_request_t) :: ind_req
  type(soil_water_temporal_indicator_result_t) :: dyn_ind,fix_ind,bad_ind
  real(real64), target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
  real(real64) :: cofgen(24,numnod),heads(numnod),water(numnod),k(numnod),cap(numnod),dkdh(numnod),fixed_k
  logical :: ok
  integer :: i

  call configure(p,cofgen)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hp,dt)
  heads(1)=h0
  do i=2,numnod
    heads(i)=heads(i-1)+p%node_distance(i)
  end do
  call constitutive%evaluate(heads,water,k,cap,dkdh)
  call evaluate_b110_default_mvg_conductivity(hp,1,heads(1),fixed_k,ok)
  call require(ok,'fixed top K')
  qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)
  call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,p,hp,1,0.0_real64,dt, &
       0.0_real64,36.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
       1.0_real64,1.0_real64,1.0_real64,fixed_k)

  call build_request(dyn_req,p,heads,water)
  dyn_req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER
  dyn_req%evaluation%dynamic_top_boundary=>dynamic_top
  call dyn_solver%solve(dyn_req,dyn_ws,dyn_res)
  call require(dyn_res%status==SW_SOLVE_CONVERGED,'dynamic raw solve')

  call build_request(fix_req,p,heads,water)
  fix_req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  fix_req%boundary%top_flux=qtop
  fix_req%evaluation%top_boundary=>fixed_top
  call fix_solver%solve(fix_req,fix_ws,fix_res)
  call require(fix_res%status==SW_SOLVE_CONVERGED,'fixed raw solve')
  call require(maxval(abs(dyn_res%candidate_state%pressure_head-fix_res%candidate_state%pressure_head))==0.0_real64, &
       'RM17 head identity retained')
  call require(maxval(abs(dyn_res%candidate_state%water_content-fix_res%candidate_state%water_content))==0.0_real64, &
       'RM17 water identity retained')

  ind_req%previous_right_derivative_available=.true.
  allocate(ind_req%previous_right_derivative(numnod))
  ind_req%previous_right_derivative=0.0_real64
  call dyn_solver%evaluate_temporal_indicator(dyn_req,dyn_res,ind_req,dyn_ws,dyn_ind)
  call fix_solver%evaluate_temporal_indicator(fix_req,fix_res,ind_req,fix_ws,fix_ind)
  call require(dyn_ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. dyn_ind%available,'dynamic indicator available')
  call require(fix_ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. fix_ind%available,'fixed indicator available')
  call require(abs(dyn_ind%head_inf_bound-fix_ind%head_inf_bound)<=1.0e-12_real64,'Binf equivalence')
  call require(abs(dyn_ind%raw_m_norm-fix_ind%raw_m_norm)<=1.0e-12_real64,'raw norm equivalence')
  call require(abs(dyn_ind%defect_m_norm-fix_ind%defect_m_norm)<=1.0e-12_real64,'defect norm equivalence')
  call require(index(trim(dyn_ind%route),'reference-dynamic-flux-')==1,'dynamic diagnostic route')

  bad_res=dyn_res
  bad_res%candidate_state%pressure_head(1)=100.0_real64
  call dyn_solver%evaluate_temporal_indicator(dyn_req,bad_res,ind_req,dyn_ws,bad_ind)
  call require(bad_ind%status==SW_TEMPORAL_INDICATOR_UNAVAILABLE .and. .not.bad_ind%available, &
       'HEAD-regime candidate fails closed')
  call require(trim(bad_ind%route)=='dynamic-flux-envelope-deferred','HEAD-regime fail-closed route')

  write(*,'(A,ES26.17E3)') 'RM18_DYNAMIC_BINF=',dyn_ind%head_inf_bound
  write(*,'(A,ES26.17E3)') 'RM18_FIXED_BINF=',fix_ind%head_inf_bound
  write(*,'(A,A)') 'RM18_DYNAMIC_ROUTE=',trim(dyn_ind%route)
  write(*,'(A,A)') 'RM18_HEAD_NEGATIVE_ROUTE=',trim(bad_ind%route)
  write(*,'(A)') 'RM18_DYNAMIC_FLUX_TEMPORAL_CERTIFICATE=PASS'

contains

  subroutine configure(parameters,c)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::c(24,numnod)
    integer::j
    parameters%parameter_set_id=180018_int64; parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)
    c=0.0_real64
    do j=1,numnod
      c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
      c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
      c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      c(10,j)=c(3,j); c(11,j)=0.999_real64; c(12,j)=0.99_real64*c(3,j)
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure

  subroutine build_request(r,parameters,h,w)
    type(soil_water_solve_request_t),intent(out)::r
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    real(real64),intent(in)::h(:),w(:)
    r=soil_water_solve_request_t()
    r%parameters=>parameters
    r%base_state%active_nodes=numnod
    allocate(r%base_state%pressure_head(numnod),r%base_state%water_content(numnod))
    r%base_state%pressure_head=h; r%base_state%water_content=w
    r%base_state%ponding_depth=0.0_real64; r%base_state%groundwater_level=-2.0_real64
    r%step_duration=dt
    r%boundary%bottom_mode=2; r%boundary%bottom_flux=qbot; r%boundary%bottom_head=h0; r%boundary%top_head=h0
    r%numerical%max_iterations=16; r%numerical%max_backtracking=8
    r%numerical%conductivity_implicit_mode=0; r%numerical%conductivity_mean_method=1
    r%numerical%min_step_duration=1.0e-8_real64
    r%numerical%compartment_balance_tolerance=1.0e-12_real64
    r%numerical%total_balance_tolerance=1.0e-12_real64
    r%numerical%head_abs_tolerance=1.0e-12_real64; r%numerical%head_rel_tolerance=1.0e-12_real64
    r%numerical%ponding_tolerance=1.0e-12_real64
    r%evaluation%constitutive=>constitutive; r%evaluation%source_sink=>source_sink
  end subroutine build_request

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'RM18_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_rm18_dynamic_flux_temporal_certificate
