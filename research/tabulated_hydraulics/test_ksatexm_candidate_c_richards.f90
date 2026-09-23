program test_tabhyd_ksatexm_candidate_c_richards
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, soil_water_parameter_set_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NROUND=8, NREPEAT=500
  real(real64), parameter :: STEP=4.0e-2_real64
  real(real64), parameter :: H0=-1.0_real64

  call run_profile('top',0.02_real64,0.433878_real64,0.021645_real64,1.34877_real64, &
       7.202077_real64,83.24164_real64,832.4163_real64, &
       0.9962891879895563_real64,36.025513440889625_real64)
  call run_profile('lower',0.02_real64,0.3870640000000001_real64,0.016083_real64,1.524418_real64, &
       2.4396619999999993_real64,22.76176_real64,227.61759999999998_real64, &
       0.9981816467911503_real64,15.814441314772257_real64)

  write(*,'(a)') 'TABHYD-KSATEXM CANDIDATE-C REFERENCE-RICHARDS GATE PASS'

contains

  subroutine run_profile(label,ores,osat,alpha,npar,lexp,ksat,ksatexm,relthr,kthr)
    character(len=*),intent(in)::label
    real(real64),intent(in)::ores,osat,alpha,npar,lexp,ksat,ksatexm,relthr,kthr
    type(soil_water_parameter_set_t),target :: parameters
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: analytic
    type(b110_generated_mvg_table_state_t),target :: state
    type(b110_generated_mvg_provider_t),target :: generated
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: wa,wg
    type(soil_water_solve_request_t) :: ra,rg
    type(soil_water_solve_result_t) :: resa,resg
    real(real64),target :: drainage(1,numnod),subsurface(numnod),root_sink(numnod)
    real(real64) :: cof(24,numnod),heads(numnod),ta(numnod),ka(numnod),ca(numnod),da(numnod)
    real(real64) :: tg(numnod),kg(numnod),cg(numnod),dg(numnod),qref
    real(real64) :: head_diff,theta_diff,mass_diff,at(NROUND),gt(NROUND),ma,mg
    real(real64) :: checksum_a,checksum_g
    integer :: i,r,status

    cof=0.0_real64
    do i=1,numnod
      cof(1,i)=ores; cof(2,i)=osat; cof(3,i)=ksat; cof(4,i)=alpha
      cof(5,i)=lexp; cof(6,i)=npar; cof(7,i)=1.0_real64-1.0_real64/npar
      cof(8,i)=alpha; cof(9,i)=0.0_real64
      cof(10,i)=ksatexm; cof(11,i)=relthr; cof(12,i)=kthr
      cof(22,i)=-1.0e6_real64; cof(23,i)=1.0e-12_real64
    end do

    call initialize_b110_default_mvg_parameters(hp,cof,enable_ksatexm_extension=.true.)
    call bind_b110_default_mvg_provider(analytic,hp,STEP)
    call initialize_b110_generated_mvg_table_state(state,hp,status)
    call require(status==F_TAB02_STATE_OK .and. state%ready(),'generated state')
    call bind_b110_generated_mvg_provider(generated,state,STEP,status)
    call require(status==F_TAB02_PROVIDER_OK .and. generated%ready(),'generated provider')

    parameters%parameter_set_id=971000_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

    drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

    heads=H0
    call analytic%evaluate(heads,ta,ka,ca,da)
    call generated%evaluate(heads,tg,kg,cg,dg)
    call require(maxval(abs(log10(kg)-log10(ka)))<=5.0e-4_real64,'active-branch K precheck')
    qref=ka(1)
    call require(qref>ksat .and. qref<ksatexm,'KSATEXM active at runtime initial state')

    call build_request(ra,parameters,source_sink,top_provider,analytic,heads,ta,qref)
    call build_request(rg,parameters,source_sink,top_provider,generated,heads,tg,qref)

    call solver%solve(ra,wa,resa)
    call solver%solve(rg,wg,resg)
    call require(resa%status==SW_SOLVE_CONVERGED,'analytic convergence')
    call require(resg%status==SW_SOLVE_CONVERGED,'generated convergence')
    call require(resa%integrated_mass_balance_residual_available .and. &
         resg%integrated_mass_balance_residual_available,'mass diagnostics')

    head_diff=maxval(abs(resg%candidate_state%pressure_head-resa%candidate_state%pressure_head))
    theta_diff=maxval(abs(resg%candidate_state%water_content-resa%candidate_state%water_content))
    mass_diff=abs(resg%integrated_mass_balance_residual_cm-resa%integrated_mass_balance_residual_cm)

    call require(head_diff<=5.0e-2_real64,'head fidelity')
    call require(theta_diff<=5.0e-3_real64,'theta fidelity')
    call require(abs(resa%integrated_mass_balance_residual_cm)<=1.0e-7_real64,'analytic mass')
    call require(abs(resg%integrated_mass_balance_residual_cm)<=1.0e-7_real64,'generated mass')
    call require(resa%diagnostics%nonlinear_iterations==resg%diagnostics%nonlinear_iterations,'nonlinear count')
    call require(resa%diagnostics%linear_solves==resg%diagnostics%linear_solves,'linear solve count')

    checksum_a=0.0_real64; checksum_g=0.0_real64
    do r=1,NROUND
      if(mod(r,2)==1) then
        call time_route(solver,ra,wa,at(r),checksum_a)
        call time_route(solver,rg,wg,gt(r),checksum_g)
      else
        call time_route(solver,rg,wg,gt(r),checksum_g)
        call time_route(solver,ra,wa,at(r),checksum_a)
      end if
    end do
    ma=median_small(at); mg=median_small(gt)
    call require(ma>0.0_real64 .and. mg>0.0_real64,'positive timings')
    call require(ieee_is_finite(checksum_a) .and. ieee_is_finite(checksum_g),'finite checksums')

    write(*,'(a,a)') 'TABHYD_KSATEXM_RICHARDS_PROFILE=',trim(label)
    write(*,'(a,es24.16)') 'TABHYD_KSATEXM_RICHARDS_HEAD_MAX_ABS=',head_diff
    write(*,'(a,es24.16)') 'TABHYD_KSATEXM_RICHARDS_THETA_MAX_ABS=',theta_diff
    write(*,'(a,es24.16)') 'TABHYD_KSATEXM_RICHARDS_MASS_RESIDUAL_DIFF=',mass_diff
    write(*,'(a,i0)') 'TABHYD_KSATEXM_RICHARDS_ANALYTIC_ITERS=',resa%diagnostics%nonlinear_iterations
    write(*,'(a,i0)') 'TABHYD_KSATEXM_RICHARDS_GENERATED_ITERS=',resg%diagnostics%nonlinear_iterations
    write(*,'(a,es24.16)') 'TABHYD_KSATEXM_RICHARDS_ANALYTIC_MEDIAN_S=',ma
    write(*,'(a,es24.16)') 'TABHYD_KSATEXM_RICHARDS_GENERATED_MEDIAN_S=',mg
    write(*,'(a,f14.8)') 'TABHYD_KSATEXM_RICHARDS_DELTA_PCT=',100.0_real64*(mg/ma-1.0_real64)
    write(*,'(a)') 'TABHYD_KSATEXM_RICHARDS_SEMANTICS=PASS'
  end subroutine run_profile

  subroutine build_request(req,parameters,source_sink,top_provider,provider,h0,theta0,qref)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    type(b110_source_sink_provider_t),target,intent(in)::source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top_provider
    class(constitutive_hydraulics_provider_t),target,intent(in)::provider
    real(real64),intent(in)::h0(:),theta0(:),qref

    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=h0; req%base_state%water_content=theta0
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-100.0_real64
    req%step_duration=STEP
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=-qref
    req%boundary%bottom_flux=-qref
    req%boundary%top_head=h0(1)
    req%boundary%bottom_head=h0(numnod)
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=20; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-7_real64
    req%numerical%total_balance_tolerance=1.0e-7_real64
    req%numerical%head_abs_tolerance=1.0e-6_real64
    req%numerical%head_rel_tolerance=1.0e-6_real64
    req%numerical%ponding_tolerance=1.0e-8_real64
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine build_request

  subroutine time_route(solver,req,workspace,seconds,checksum)
    type(reference_richards_legacy_solver_t),intent(inout)::solver
    type(soil_water_solve_request_t),intent(in)::req
    type(reference_richards_legacy_workspace_t),intent(inout)::workspace
    real(real64),intent(out)::seconds
    real(real64),intent(inout)::checksum
    type(soil_water_solve_result_t)::res
    real(real64)::t0,t1
    integer::q
    call cpu_time(t0)
    do q=1,NREPEAT
      call solver%solve(req,workspace,res)
      if(res%status/=SW_SOLVE_CONVERGED) error stop 'timed Candidate-C Richards route failed'
      checksum=checksum+res%candidate_state%pressure_head(1)+res%bottom_flux
    end do
    call cpu_time(t1); seconds=t1-t0
  end subroutine time_route

  real(real64) function median_small(v) result(m)
    real(real64),intent(in)::v(:)
    real(real64)::x(size(v)),tmp
    integer::a,b
    x=v
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a);x(a)=x(b);x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      m=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      m=x((size(x)+1)/2)
    end if
  end function median_small

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'TABHYD_KSATEXM_RUNTIME_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_tabhyd_ksatexm_candidate_c_richards
