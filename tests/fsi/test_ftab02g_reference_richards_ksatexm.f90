program test_ftab02g_reference_richards_ksatexm
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, soil_water_parameter_set_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  call run_regime('below_threshold',-5.0_real64)
  call run_regime('transition',-2.0_real64)
  call run_regime('active_extension',-1.0_real64)
  write(*,'(a)') 'F-TAB02-G REFERENCE RICHARDS F-SI39 GATE PASS'

contains

  subroutine run_regime(label,initial_head)
    character(len=*),intent(in)::label
    real(real64),intent(in)::initial_head
    real(real64),parameter::STEP=4.0e-2_real64
    type(soil_water_parameter_set_t),target::parameters
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t),target::analytic
    type(b110_generated_mvg_table_state_t),target::state
    type(b110_generated_mvg_provider_t),target::generated
    type(b110_source_sink_provider_t),target::source_sink
    type(fixed_flux_top_boundary_provider_t),target::top_provider
    type(reference_richards_legacy_solver_t)::solver_a,solver_g
    type(reference_richards_legacy_workspace_t)::wa,wg
    type(soil_water_solve_request_t)::ra,rg
    type(soil_water_solve_result_t)::resa,resg
    real(real64),target::drainage(1,numnod),subsurface(numnod),root_sink(numnod)
    real(real64)::cof(42,numnod),ha(numnod),hg(numnod),ta(numnod),ka(numnod),ca(numnod),da(numnod)
    real(real64)::tg(numnod),kg(numnod),cg(numnod),dg(numnod)
    real(real64)::head_diff,theta_diff,mass_diff,top_flux
    integer::i,status

    cof=0.0_real64
    do i=1,numnod
      if(i<=numnod/2) then
        call set_upper(cof(:,i))
      else
        call set_lower(cof(:,i))
      end if
    end do

    call initialize_b110_default_mvg_parameters(hp,cof,enable_ksatexm_extension=.true.)
    call bind_b110_default_mvg_provider(analytic,hp,STEP)
    call initialize_b110_generated_mvg_table_state(state,hp,status)
    call require(status==F_TAB02_STATE_OK,'generated KSATEXM state')
    call bind_b110_generated_mvg_provider(generated,state,STEP,status)
    call require(status==F_TAB02_PROVIDER_OK,'generated KSATEXM provider')

    parameters%parameter_set_id=970100_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

    drainage=0.0_real64;subsurface=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

    ha=initial_head;hg=initial_head
    call analytic%evaluate(ha,ta,ka,ca,da)
    call generated%evaluate(hg,tg,kg,cg,dg)
    top_flux=2.0e-2_real64

    call build_request(ra,parameters,source_sink,top_provider,analytic,ha,ta,top_flux,STEP)
    call build_request(rg,parameters,source_sink,top_provider,generated,hg,tg,top_flux,STEP)
    call solver_a%solve(ra,wa,resa)
    call solver_g%solve(rg,wg,resg)

    call require(resa%status==SW_SOLVE_CONVERGED,'analytical convergence')
    call require(resg%status==SW_SOLVE_CONVERGED,'generated convergence')
    call require(resa%integrated_mass_balance_residual_available .and. resg%integrated_mass_balance_residual_available, &
         'mass diagnostics')

    head_diff=maxval(abs(resg%candidate_state%pressure_head-resa%candidate_state%pressure_head))
    theta_diff=maxval(abs(resg%candidate_state%water_content-resa%candidate_state%water_content))
    mass_diff=abs(resg%integrated_mass_balance_residual_cm-resa%integrated_mass_balance_residual_cm)

    call require(head_diff<=5.0e-2_real64,'head fidelity')
    call require(theta_diff<=2.0e-2_real64,'theta fidelity')
    call require(abs(resg%integrated_mass_balance_residual_cm)<=1.0e-8_real64,'generated mass')
    call require(resa%diagnostics%nonlinear_iterations==resg%diagnostics%nonlinear_iterations,'nonlinear count')
    call require(resa%diagnostics%linear_solves==resg%diagnostics%linear_solves,'linear count')

    write(*,'(a,a)') 'F_TAB02_G_RICHARDS_PROFILE=',trim(label)
    write(*,'(a,es24.16)') 'F_TAB02_G_RICHARDS_HEAD_MAX_ABS=',head_diff
    write(*,'(a,es24.16)') 'F_TAB02_G_RICHARDS_THETA_MAX_ABS=',theta_diff
    write(*,'(a,es24.16)') 'F_TAB02_G_RICHARDS_MASS_RESIDUAL_DIFF=',mass_diff
    write(*,'(a,i0)') 'F_TAB02_G_RICHARDS_ANALYTIC_ITERS=',resa%diagnostics%nonlinear_iterations
    write(*,'(a,i0)') 'F_TAB02_G_RICHARDS_GENERATED_ITERS=',resg%diagnostics%nonlinear_iterations
    write(*,'(a,i0)') 'F_TAB02_G_RICHARDS_ANALYTIC_LINEAR_SOLVES=',resa%diagnostics%linear_solves
    write(*,'(a,i0)') 'F_TAB02_G_RICHARDS_GENERATED_LINEAR_SOLVES=',resg%diagnostics%linear_solves
    write(*,'(a)') 'F_TAB02_G_RICHARDS_PROFILE_PASS=PASS'
  end subroutine run_regime

  subroutine build_request(req,parameters,source_sink,top_provider,provider,h0,theta0,qtop,step)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    type(b110_source_sink_provider_t),target,intent(in)::source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top_provider
    class(constitutive_hydraulics_provider_t),target,intent(in)::provider
    real(real64),intent(in)::h0(:),theta0(:),qtop,step
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=h0;req%base_state%water_content=theta0
    req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-999.0_real64
    req%step_duration=step
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop;req%boundary%top_head=h0(1)
    req%boundary%bottom_flux=0.0_real64;req%boundary%bottom_head=-9.99999e5_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16;req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-10_real64;req%numerical%head_rel_tolerance=1.0e-10_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine build_request

  subroutine set_upper(c)
    real(real64),intent(out)::c(:)
    c=0.0_real64
    c(1)=0.02_real64;c(2)=0.433878_real64;c(3)=83.24164_real64;c(4)=0.021645_real64
    c(5)=7.202077_real64;c(6)=1.34877_real64;c(7)=1.0_real64-1.0_real64/c(6)
    c(8)=0.021645_real64;c(9)=0.0_real64;c(10)=832.4163_real64
    ! Exact admitted F-SI39 Hupsel threshold authority; do not rederive algebraically.
    c(11)=0.99628918798955624_real64;c(12)=36.025513440889291_real64
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_upper

  subroutine set_lower(c)
    real(real64),intent(out)::c(:)
    c=0.0_real64
    c(1)=0.02_real64;c(2)=0.3870640000000001_real64;c(3)=22.76176_real64;c(4)=0.016083_real64
    c(5)=2.4396619999999993_real64;c(6)=1.524418_real64;c(7)=1.0_real64-1.0_real64/c(6)
    c(8)=0.016083_real64;c(9)=0.0_real64;c(10)=227.61759999999998_real64
    ! Exact admitted F-SI39 Hupsel threshold authority; do not rederive algebraically.
    c(11)=0.9981816467911503_real64;c(12)=15.814441314772257_real64
    c(22)=-1.0e6_real64;c(23)=1.0e-12_real64
  end subroutine set_lower

  subroutine derive_threshold(c)
    real(real64),intent(inout)::c(:)
    real(real64)::m,se,term1
    m=1.0_real64-1.0_real64/c(6)
    se=(1.0_real64+abs(c(4)*(-2.0_real64))**c(6))**(-m)
    term1=(1.0_real64-se**(1.0_real64/m))**m
    c(11)=se;c(12)=c(3)*se**c(5)*(1.0_real64-term1)*(1.0_real64-term1)
  end subroutine derive_threshold

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'F_TAB02_G_RICHARDS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02g_reference_richards_ksatexm
