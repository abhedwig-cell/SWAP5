program test_ref_temporal01_indicator_vs_refined
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NCASE=12
  integer, parameter :: refine_substeps=16
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: h_values(3)=[-75.0_real64,-250.0_real64,-1200.0_real64]
  real(real64), parameter :: q_factor(2)=[-0.01_real64,0.01_real64]
  real(real64), parameter :: dt_values(2)=[1.0e-2_real64,1.0e-3_real64]

  integer :: ih,iq,idt,case_id
  case_id=0
  do ih=1,size(h_values)
    do iq=1,size(q_factor)
      do idt=1,size(dt_values)
        case_id=case_id+1
        call run_case(case_id,h_values(ih),q_factor(iq),dt_values(idt))
      end do
    end do
  end do
  if(case_id/=NCASE) error stop 'REF_TEMPORAL01 case count'
  write(*,'(A,I0)') 'REF_TEMPORAL01_CASE_COUNT=',case_id
  write(*,'(A)') 'REF_TEMPORAL01_WU01=PASS'

contains

  subroutine run_case(id,h0,qfac,dt)
    integer,intent(in)::id
    real(real64),intent(in)::h0,qfac,dt
    type(soil_water_parameter_set_t),target :: p
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: cp
    type(b110_source_sink_provider_t),target :: sp
    type(fixed_flux_top_boundary_provider_t),target :: tp
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws_principal,ws_refined
    type(soil_water_solve_request_t) :: req,subreq
    type(soil_water_solve_result_t) :: principal,subres
    type(soil_water_temporal_indicator_request_t) :: ireq
    type(soil_water_temporal_indicator_result_t) :: ind
    type(soil_water_solve_result_t) :: prev
    real(real64),target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
    real(real64) :: cofgen(24,numnod),heads(numnod),water(numnod),k(numnod),cap(numnod),dkdh(numnod)
    real(real64) :: q,storage_principal,storage_refined,head_err,theta_err,storage_err,ratio
    real(real64) :: subdt
    integer :: i,s

    call configure_parameters(p,cofgen)
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(cp,hp,dt)
    heads=h0
    call cp%evaluate(heads,water,k,cap,dkdh)
    q=qfac*k(1)
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)

    call build_request(req,p,cp,sp,tp,heads,water,q,dt)
    ireq%previous_right_derivative_available=.true.
    allocate(ireq%previous_right_derivative(numnod))
    ireq%previous_right_derivative=0.0_real64

    call solver%solve(req,ws_principal,principal)
    call require(principal%status==SW_SOLVE_CONVERGED,'principal solve')
    call solver%evaluate_temporal_indicator(req,principal,ireq,ws_principal,ind)
    call require(ind%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. ind%available,'indicator available')

    subdt=dt/real(refine_substeps,real64)
    subreq=req
    subreq%step_duration=subdt
    call bind_b110_default_mvg_provider(cp,hp,subdt)
    subreq%evaluation%constitutive=>cp
    do s=1,refine_substeps
      call solver%solve(subreq,ws_refined,subres)
      call require(subres%status==SW_SOLVE_CONVERGED,'refined solve')
      subreq%base_state=subres%candidate_state
    end do

    head_err=maxval(abs(principal%candidate_state%pressure_head-subres%candidate_state%pressure_head))
    theta_err=maxval(abs(principal%candidate_state%water_content-subres%candidate_state%water_content))
    storage_principal=sum(p%dz*principal%candidate_state%water_content)+principal%candidate_state%ponding_depth
    storage_refined=sum(p%dz*subres%candidate_state%water_content)+subres%candidate_state%ponding_depth
    storage_err=abs(storage_principal-storage_refined)
    ratio=huge(1.0_real64)
    if(head_err>0.0_real64) ratio=ind%head_inf_bound/head_err

    call require(ieee_is_finite(head_err) .and. ieee_is_finite(theta_err) .and. ieee_is_finite(storage_err),'finite oracle error')
    call require(ieee_is_finite(ind%head_inf_bound) .and. ind%head_inf_bound>=0.0_real64,'finite bound')

    write(*,'(A,I0,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,ES16.8E3,A,A)') &
      'REF_TEMPORAL01_ROW,case=',id,',h0=',h0,',qfac=',qfac,',dt=',dt,',bound=',ind%head_inf_bound, &
      ',head_err=',head_err,',ratio=',ratio,',route=',trim(ind%route)
    write(*,'(A,I0,A,ES16.8E3,A,ES16.8E3)') 'REF_TEMPORAL01_AUX,case=',id,',theta_err=',theta_err,',storage_err=',storage_err
  end subroutine run_case

  subroutine configure_parameters(p,c)
    type(soil_water_parameter_set_t),target,intent(out)::p
    real(real64),intent(out)::c(24,numnod)
    integer::i
    p%parameter_set_id=990001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    c=0.0_real64
    do i=1,numnod
      c(1,i)=0.032_real64; c(2,i)=0.423_real64; c(3,i)=4.75_real64
      c(4,i)=0.0135_real64; c(5,i)=0.365_real64; c(6,i)=1.455_real64
      c(7,i)=1.0_real64-1.0_real64/c(6,i); c(8,i)=c(4,i); c(9,i)=0.0_real64
      c(10,i)=c(3,i); c(11,i)=0.999_real64; c(12,i)=0.99_real64*c(3,i)
      c(22,i)=-1.0e6_real64; c(23,i)=1.0e-12_real64
    end do
  end subroutine configure_parameters

  subroutine build_request(req,p,cp,sp,tp,heads,water,q,dt)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::cp
    type(b110_source_sink_provider_t),target,intent(in)::sp
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::tp
    real(real64),intent(in)::heads(:),water(:),q,dt
    req%parameters=>p
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=heads; req%base_state%water_content=water
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-2.0_real64
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=q; req%boundary%bottom_flux=q
    req%boundary%top_head=heads(1); req%boundary%bottom_head=777777.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-12_real64
    req%numerical%compartment_balance_tolerance=hard_mass_gate
    req%numerical%total_balance_tolerance=hard_mass_gate
    req%numerical%head_abs_tolerance=hard_mass_gate
    req%numerical%head_rel_tolerance=hard_mass_gate
    req%numerical%ponding_tolerance=hard_mass_gate
    req%evaluation%constitutive=>cp; req%evaluation%source_sink=>sp; req%evaluation%top_boundary=>tp
  end subroutine build_request

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(A,1X,A)') 'REF_TEMPORAL01_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ref_temporal01_indicator_vs_refined
