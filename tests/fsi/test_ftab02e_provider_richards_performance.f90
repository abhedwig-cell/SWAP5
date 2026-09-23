program test_ftab02e_provider_richards_performance
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

  integer, parameter :: NSEQ=512, NREPEAT=50, NROUND=10
  integer, parameter :: NRICH_REPEAT=1200, NRICH_ROUND=8
  real(real64), parameter :: STEP_DURATION=4.0e-2_real64
  character(len=512) :: fixture

  if (command_argument_count() /= 1) error stop 'usage: test_ftab02e_provider_richards_performance FIXTURE'
  call get_command_argument(1,fixture)

  call provider_benchmark(trim(fixture))
  call richards_profile('coarse',0.01_real64,0.42_real64,0.0163_real64,1.559_real64,54.80_real64,0.177_real64,-180.0_real64)
  call richards_profile('loam',0.00_real64,0.43_real64,0.0065_real64,1.325_real64,1.54_real64,-2.161_real64,-75.0_real64)
  call richards_profile('clay',0.00_real64,0.55_real64,0.0532_real64,1.081_real64,15.46_real64,-8.823_real64,-40.0_real64)
  write(*,'(a)') 'F-TAB02-E PROVIDER AND REFERENCE-RICHARDS PERFORMANCE CHARACTERIZATION PASS'

contains

  subroutine provider_benchmark(path)
    character(len=*), intent(in) :: path
    type(b110_default_mvg_parameters_t), target :: parameters
    type(b110_default_mvg_provider_t) :: analytic
    type(b110_generated_mvg_table_state_t), target :: state
    type(b110_generated_mvg_provider_t) :: generated
    real(real64), allocatable :: cofgen(:,:), seq(:,:), ta(:),ka(:),ca(:),da(:), tg(:),kg(:),cg(:),dg(:)
    real(real64) :: at(NROUND), gt(NROUND), it(NROUND)
    real(real64) :: t0,t1,ma,mg,mi,saved,breakeven,checksum_a,checksum_g,frac,exponent
    integer :: n,i,j,r,rep,status

    call read_fixture(path,cofgen,n)
    call initialize_b110_default_mvg_parameters(parameters,cofgen)
    call bind_b110_default_mvg_provider(analytic,parameters,STEP_DURATION)
    call initialize_b110_generated_mvg_table_state(state,parameters,status)
    call require(status==F_TAB02_STATE_OK .and. state%ready(),'provider benchmark generated state')
    call bind_b110_generated_mvg_provider(generated,state,STEP_DURATION,status)
    call require(status==F_TAB02_PROVIDER_OK .and. generated%ready(),'provider benchmark generated bind')

    allocate(seq(n,NSEQ),ta(n),ka(n),ca(n),da(n),tg(n),kg(n),cg(n),dg(n))
    do j=1,NSEQ
      do i=1,n
        frac=real(mod((j-1)*37+(i-1)*101,NSEQ),real64)/real(NSEQ-1,real64)
        exponent=-5.0_real64+12.0_real64*frac
        seq(i,j)=-10.0_real64**exponent
      end do
    end do

    do j=1,NSEQ
      call analytic%evaluate(seq(:,j),ta,ka,ca,da)
      call generated%evaluate(seq(:,j),tg,kg,cg,dg)
    end do

    checksum_a=0.0_real64
    checksum_g=0.0_real64
    do r=1,NROUND
      if (mod(r,2)==1) then
        call cpu_time(t0)
        do rep=1,NREPEAT
          do j=1,NSEQ
            call analytic%evaluate(seq(:,j),ta,ka,ca,da)
            checksum_a=checksum_a+ta(1)+ka(n)+ca(1+mod(j-1,n))
          end do
        end do
        call cpu_time(t1)
        at(r)=t1-t0

        call cpu_time(t0)
        do rep=1,NREPEAT
          do j=1,NSEQ
            call generated%evaluate(seq(:,j),tg,kg,cg,dg)
            checksum_g=checksum_g+tg(1)+kg(n)+cg(1+mod(j-1,n))
          end do
        end do
        call cpu_time(t1)
        gt(r)=t1-t0
      else
        call cpu_time(t0)
        do rep=1,NREPEAT
          do j=1,NSEQ
            call generated%evaluate(seq(:,j),tg,kg,cg,dg)
            checksum_g=checksum_g+tg(1)+kg(n)+cg(1+mod(j-1,n))
          end do
        end do
        call cpu_time(t1)
        gt(r)=t1-t0

        call cpu_time(t0)
        do rep=1,NREPEAT
          do j=1,NSEQ
            call analytic%evaluate(seq(:,j),ta,ka,ca,da)
            checksum_a=checksum_a+ta(1)+ka(n)+ca(1+mod(j-1,n))
          end do
        end do
        call cpu_time(t1)
        at(r)=t1-t0
      end if
    end do

    do r=1,NROUND
      call cpu_time(t0)
      block
        type(b110_generated_mvg_table_state_t) :: local_state
        do rep=1,4
          call initialize_b110_generated_mvg_table_state(local_state,parameters,status)
          call require(status==F_TAB02_STATE_OK,'timed generated state init')
        end do
      end block
      call cpu_time(t1)
      it(r)=(t1-t0)/4.0_real64
    end do

    ma=median_small(at)
    mg=median_small(gt)
    mi=median_small(it)
    saved=(ma-mg)/real(NSEQ*NREPEAT,real64)
    if (saved>0.0_real64) then
      breakeven=mi/saved
    else
      breakeven=-1.0_real64
    end if

    call require(ma>0.0_real64 .and. mg>0.0_real64 .and. mi>0.0_real64,'positive provider timings')
    call require(ieee_is_finite(checksum_a) .and. ieee_is_finite(checksum_g),'finite provider checksums')

    write(*,'(a,i0)') 'F_TAB02_E_PROVIDER_NODES=',n
    write(*,'(a,es24.16)') 'F_TAB02_E_PROVIDER_ANALYTIC_MEDIAN_S=',ma
    write(*,'(a,es24.16)') 'F_TAB02_E_PROVIDER_GENERATED_MEDIAN_S=',mg
    write(*,'(a,f14.8)') 'F_TAB02_E_PROVIDER_DELTA_PCT=',100.0_real64*(mg/ma-1.0_real64)
    write(*,'(a,es24.16)') 'F_TAB02_E_GENERATED_STATE_INIT_MEDIAN_S=',mi
    write(*,'(a,es24.16)') 'F_TAB02_E_PROVIDER_SAVED_PER_VECTOR_EVAL_S=',saved
    write(*,'(a,es24.16)') 'F_TAB02_E_PROVIDER_BREAK_EVEN_VECTOR_EVALS=',breakeven
    write(*,'(a,i0)') 'F_TAB02_E_GENERATED_STATE_BYTES=',state%estimated_bytes()
    write(*,'(a)') 'F_TAB02_E_PROVIDER_TIMING_CAPTURED=PASS'

  end subroutine provider_benchmark

  subroutine richards_profile(label,ores,osat,alpha,npar,ksat,lexp,hbase)
    character(len=*),intent(in)::label
    real(real64),intent(in)::ores,osat,alpha,npar,ksat,lexp,hbase
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t), target :: analytic
    type(b110_generated_mvg_table_state_t), target :: state
    type(b110_generated_mvg_provider_t), target :: generated
    type(b110_source_sink_provider_t), target :: source_sink
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: wa, wg
    type(soil_water_solve_request_t) :: ra, rg
    type(soil_water_solve_result_t) :: resa, resg, timed_res
    real(real64), target :: drainage(1,numnod),subsurface(numnod),root_sink(numnod)
    real(real64) :: cofgen(24,numnod), heads(numnod),ta(numnod),ka(numnod),ca(numnod),da(numnod)
    real(real64) :: tg(numnod),kg(numnod),cg(numnod),dg(numnod), top_flux
    real(real64) :: at(NRICH_ROUND),gt(NRICH_ROUND),ma,mg,checksum_a,checksum_g,t0,t1
    real(real64) :: head_diff,theta_diff,mass_diff
    integer :: i,r,rep,q,status

    call fill_cofgen(cofgen,ores,osat,alpha,npar,ksat,lexp)
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(analytic,hp,STEP_DURATION)
    call initialize_b110_generated_mvg_table_state(state,hp,status)
    call require(status==F_TAB02_STATE_OK,'Richards generated state')
    call bind_b110_generated_mvg_provider(generated,state,STEP_DURATION,status)
    call require(status==F_TAB02_PROVIDER_OK,'Richards generated provider')

    parameters%parameter_set_id=950100_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

    drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

    do i=1,numnod
      heads(i)=hbase+0.15_real64*real(i-1,real64)
    end do
    call analytic%evaluate(heads,ta,ka,ca,da)
    call generated%evaluate(heads,tg,kg,cg,dg)
    top_flux=-0.97_real64*ka(1)

    call build_richards_request(ra,analytic,parameters,source_sink,top_provider,heads,ta,top_flux)
    call build_richards_request(rg,generated,parameters,source_sink,top_provider,heads,tg,top_flux)

    call solver%solve(ra,wa,resa)
    call solver%solve(rg,wg,resg)
    call require(resa%status==SW_SOLVE_CONVERGED,'analytic Richards convergence')
    call require(resg%status==SW_SOLVE_CONVERGED,'generated Richards convergence')
    call require(resa%integrated_mass_balance_residual_available .and. resg%integrated_mass_balance_residual_available, &
         'Richards mass diagnostics available')

    head_diff=maxval(abs(resg%candidate_state%pressure_head-resa%candidate_state%pressure_head))
    theta_diff=maxval(abs(resg%candidate_state%water_content-resa%candidate_state%water_content))
    mass_diff=abs(resg%integrated_mass_balance_residual_cm-resa%integrated_mass_balance_residual_cm)
    call require(head_diff<=5.0e-2_real64,'Richards head fidelity')
    call require(theta_diff<=5.0e-3_real64,'Richards theta fidelity')
    call require(resa%diagnostics%nonlinear_iterations==resg%diagnostics%nonlinear_iterations,'Richards nonlinear count')
    call require(resa%diagnostics%linear_solves==resg%diagnostics%linear_solves,'Richards linear count')

    checksum_a=0.0_real64; checksum_g=0.0_real64
    do r=1,NRICH_ROUND
      if(mod(r,2)==1) then
        call cpu_time(t0)
        do q=1,NRICH_REPEAT
          call solver%solve(ra,wa,timed_res)
          if(timed_res%status/=SW_SOLVE_CONVERGED) error stop 'timed analytical Richards route failed'
          checksum_a=checksum_a+timed_res%candidate_state%pressure_head(1)+timed_res%bottom_flux
        end do
        call cpu_time(t1)
        at(r)=t1-t0

        call cpu_time(t0)
        do q=1,NRICH_REPEAT
          call solver%solve(rg,wg,timed_res)
          if(timed_res%status/=SW_SOLVE_CONVERGED) error stop 'timed generated Richards route failed'
          checksum_g=checksum_g+timed_res%candidate_state%pressure_head(1)+timed_res%bottom_flux
        end do
        call cpu_time(t1)
        gt(r)=t1-t0
      else
        call cpu_time(t0)
        do q=1,NRICH_REPEAT
          call solver%solve(rg,wg,timed_res)
          if(timed_res%status/=SW_SOLVE_CONVERGED) error stop 'timed generated Richards route failed'
          checksum_g=checksum_g+timed_res%candidate_state%pressure_head(1)+timed_res%bottom_flux
        end do
        call cpu_time(t1)
        gt(r)=t1-t0

        call cpu_time(t0)
        do q=1,NRICH_REPEAT
          call solver%solve(ra,wa,timed_res)
          if(timed_res%status/=SW_SOLVE_CONVERGED) error stop 'timed analytical Richards route failed'
          checksum_a=checksum_a+timed_res%candidate_state%pressure_head(1)+timed_res%bottom_flux
        end do
        call cpu_time(t1)
        at(r)=t1-t0
      end if
    end do
    ma=median_small(at); mg=median_small(gt)
    call require(ma>0.0_real64 .and. mg>0.0_real64,'positive Richards timings')
    call require(ieee_is_finite(checksum_a) .and. ieee_is_finite(checksum_g),'finite Richards checksums')

    write(*,'(a,a)') 'F_TAB02_E_RICHARDS_PROFILE=',trim(label)
    write(*,'(a,es24.16)') 'F_TAB02_E_RICHARDS_HEAD_MAX_ABS=',head_diff
    write(*,'(a,es24.16)') 'F_TAB02_E_RICHARDS_THETA_MAX_ABS=',theta_diff
    write(*,'(a,es24.16)') 'F_TAB02_E_RICHARDS_MASS_RESIDUAL_DIFF=',mass_diff
    write(*,'(a,i0)') 'F_TAB02_E_RICHARDS_ANALYTIC_ITERS=',resa%diagnostics%nonlinear_iterations
    write(*,'(a,i0)') 'F_TAB02_E_RICHARDS_GENERATED_ITERS=',resg%diagnostics%nonlinear_iterations
    write(*,'(a,es24.16)') 'F_TAB02_E_RICHARDS_ANALYTIC_MEDIAN_S=',ma
    write(*,'(a,es24.16)') 'F_TAB02_E_RICHARDS_GENERATED_MEDIAN_S=',mg
    write(*,'(a,f14.8)') 'F_TAB02_E_RICHARDS_DELTA_PCT=',100.0_real64*(mg/ma-1.0_real64)
    write(*,'(a)') 'F_TAB02_E_RICHARDS_TIMING_CAPTURED=PASS'

  end subroutine richards_profile

  subroutine build_richards_request(req,provider,parameters,source_sink,top_provider,h0,theta0,qtop)
    type(soil_water_solve_request_t),intent(out)::req
    class(constitutive_hydraulics_provider_t),target,intent(in)::provider
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    type(b110_source_sink_provider_t),target,intent(in)::source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top_provider
    real(real64),intent(in)::h0(:),theta0(:),qtop
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=h0
    req%base_state%water_content=theta0
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-100.0_real64
    req%step_duration=STEP_DURATION
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=5
    req%boundary%top_flux=qtop
    req%boundary%top_head=h0(1)
    req%boundary%bottom_flux=0.0_real64
    req%boundary%bottom_head=h0(numnod)+2.0_real64
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
  end subroutine build_richards_request

  subroutine read_fixture(path,cofgen,n)
    character(len=*),intent(in)::path
    real(real64),allocatable,intent(out)::cofgen(:,:)
    integer,intent(out)::n
    integer::iu,ios,i
    character(len=32)::soil
    real(real64)::ores,osat,alpha,npar,ksat,lexp
    open(newunit=iu,file=path,status='old',action='read',iostat=ios)
    call require(ios==0,'open Staring fixture')
    read(iu,*,iostat=ios)n
    call require(ios==0 .and. n>0,'fixture row count')
    allocate(cofgen(24,n)); cofgen=0.0_real64
    do i=1,n
      read(iu,*,iostat=ios)soil,ores,osat,alpha,npar,ksat,lexp
      call require(ios==0,'fixture row')
      call set_cofgen_column(cofgen(:,i),ores,osat,alpha,npar,ksat,lexp)
    end do
    close(iu)
  end subroutine read_fixture

  subroutine fill_cofgen(c,ores,osat,alpha,npar,ksat,lexp)
    real(real64),intent(out)::c(:,:)
    real(real64),intent(in)::ores,osat,alpha,npar,ksat,lexp
    integer::i
    c=0.0_real64
    do i=1,size(c,2)
      call set_cofgen_column(c(:,i),ores,osat,alpha,npar,ksat,lexp)
    end do
  end subroutine fill_cofgen

  subroutine set_cofgen_column(c,ores,osat,alpha,npar,ksat,lexp)
    real(real64),intent(inout)::c(:)
    real(real64),intent(in)::ores,osat,alpha,npar,ksat,lexp
    c=0.0_real64
    c(1)=ores; c(2)=osat; c(3)=ksat; c(4)=alpha; c(5)=lexp; c(6)=npar
    c(7)=1.0_real64-1.0_real64/npar; c(8)=alpha; c(9)=0.0_real64
    c(10)=ksat; c(11)=0.999_real64; c(12)=0.99_real64*ksat
    c(22)=-1.0e6_real64; c(23)=1.0e-12_real64
  end subroutine set_cofgen_column

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
      write(*,'(a,1x,a)') 'F_TAB02_E_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02e_provider_richards_performance
