program test_fsi24_gate_b_exact_manufactured_bound
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_linear_solver, only: reference_tridag
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_fsi23_mms_providers, only: fsi23_linear_hydraulics_provider_t
  implicit none

  integer, parameter :: nsingle=5, nmulti=5
  real(real64), parameter :: h_eq=-100.0_real64, theta_eq=0.30_real64
  real(real64), parameter :: cap=0.001_real64, kval=0.01_real64
  real(real64), parameter :: eig1=0.25619777153614321838009463228648061698_real64
  real(real64), parameter :: eig2=1.5788967897778011939109549498314371066_real64
  real(real64), parameter :: lambda1=2.5619777153614321838009463228648061698_real64
  real(real64), parameter :: lambda2=15.788967897778011939109549498314371066_real64
  real(real64), parameter :: amp_single=10.0_real64, amp1=5.0_real64
  real(real64), parameter :: v1(numnod)=[ &
       0.6752098721931038_real64, 0.5887162399055651_real64, &
       0.4268087132525549_real64, 0.1555537453920313_real64]
  real(real64), parameter :: v2(numnod)=[ &
      -0.85993755826055324873547636713317468951_real64, &
      -0.18106123318707904408753054543225232895_real64, &
       0.64075359180253965173186093246533823150_real64, &
       0.45088462765653286067989087747721881613_real64]
  real(real64), parameter :: single_x(nsingle)=[ &
       0.025_real64,0.1_real64,0.4_real64,1.6_real64,6.4_real64]
  real(real64), parameter :: multi_dt(nmulti)=[ &
       0.0125_real64,0.05_real64,0.2_real64,0.8_real64,1.6_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(fsi23_linear_hydraulics_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64) :: a_over_k(numnod,numnod), mdiag(numnod), amp2
  real(real64) :: av(numnod), mv(numnod), cross_m, bound
  real(real64) :: hdot_multi(numnod), cancellation_scale
  integer :: i

  call require(numnod==4,'frozen four-node geometry')
  call initialize_geometry_and_providers()

  a_over_k = reshape([ &
       1.0_real64,-1.0_real64, 0.0_real64, 0.0_real64, &
      -1.0_real64, 2.0_real64,-1.0_real64, 0.0_real64, &
       0.0_real64,-1.0_real64, 2.0_real64,-1.0_real64, &
       0.0_real64, 0.0_real64,-1.0_real64, 3.0_real64], [numnod,numnod])
  mdiag=cap*parameters%dz

  av=matmul(a_over_k,v1)
  mv=parameters%dz*v1
  bound=fp_bound(max(maxval(abs(av)),maxval(abs(eig1*mv))))
  call require(maxval(abs(av-eig1*mv))<=bound,'mode1 generalized eigenpair')

  av=matmul(a_over_k,v2)
  mv=parameters%dz*v2
  bound=fp_bound(max(maxval(abs(av)),maxval(abs(eig2*mv))))
  call require(maxval(abs(av-eig2*mv))<=bound,'mode2 generalized eigenpair')

  call require(abs(lambda1-(kval/cap)*eig1)<=fp_bound(lambda1),'lambda1 construction')
  call require(abs(lambda2-(kval/cap)*eig2)<=fp_bound(lambda2),'lambda2 construction')
  cross_m=sum(parameters%dz*v1*v2)
  call require(abs(cross_m)<=fp_bound(max(sum(abs(parameters%dz*v1*v2)),1.0_real64)),'M orthogonality')

  amp2=lambda1*amp1*v1(2)/(-lambda2*v2(2))
  hdot_multi=-lambda1*amp1*v1-lambda2*amp2*v2
  cancellation_scale=max(abs(lambda1*amp1*v1(2)),abs(lambda2*amp2*v2(2)))
  call require(abs(hdot_multi(2))<=fp_bound(cancellation_scale),'predeclared near-zero derivative node2')
  write(*,'(A,ES24.15E3,A,ES24.15E3)') 'FSI24_GB_PRECHECK:M_CROSS=',cross_m,':HDOT2=',hdot_multi(2)

  do i=1,nsingle
    call run_point('SINGLE',i,single_x(i)/lambda1,amp_single*v1, &
         amp_single*v1/(1.0_real64+single_x(i)), &
         amp_single*v1*exp(-single_x(i)), &
         -lambda1*amp_single*v1, &
         0.5_real64*amp_single*v1*single_x(i)**2/(1.0_real64+single_x(i)), &
         0.5_real64*amp_single*v1*single_x(i)**2/(1.0_real64+single_x(i))**2, &
         single_x(i),0.0_real64,amp_single,0.0_real64)
  end do

  do i=1,nmulti
    call run_multimode_point(i,multi_dt(i),amp2)
  end do

  write(*,'(A)') 'FSI24_GATE_B_EXACT_MANUFACTURED_BOUND PASS'

contains

  subroutine run_multimode_point(ipoint,dt,second_amplitude)
    integer, intent(in) :: ipoint
    real(real64), intent(in) :: dt, second_amplitude
    real(real64) :: x1, x2
    real(real64) :: u0(numnod), ube(numnod), uexact(numnod), hdotn(numnod)
    real(real64) :: eraw_exact(numnod), delta_exact(numnod)

    x1=lambda1*dt
    x2=lambda2*dt
    u0=amp1*v1+second_amplitude*v2
    ube=amp1*v1/(1.0_real64+x1)+second_amplitude*v2/(1.0_real64+x2)
    uexact=amp1*v1*exp(-x1)+second_amplitude*v2*exp(-x2)
    hdotn=-lambda1*amp1*v1-lambda2*second_amplitude*v2
    eraw_exact=0.5_real64*amp1*v1*x1*x1/(1.0_real64+x1) + &
         0.5_real64*second_amplitude*v2*x2*x2/(1.0_real64+x2)
    delta_exact=0.5_real64*amp1*v1*x1*x1/(1.0_real64+x1)**2 + &
         0.5_real64*second_amplitude*v2*x2*x2/(1.0_real64+x2)**2
    call run_point('MULTI',ipoint,dt,u0,ube,uexact,hdotn,eraw_exact,delta_exact,x1,x2,amp1,second_amplitude)
  end subroutine run_multimode_point

  subroutine run_point(axis,ipoint,dt,u0,ube,uexact,hdotn,eraw_exact,delta_exact,x1,x2,a1,a2)
    character(len=*), intent(in) :: axis
    integer, intent(in) :: ipoint
    real(real64), intent(in) :: dt, u0(:), ube(:), uexact(:), hdotn(:), eraw_exact(:), delta_exact(:)
    real(real64), intent(in) :: x1, x2, a1, a2
    type(soil_water_physical_state_t) :: initial_state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: h0(numnod), theta0(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: hbe(numnod), hexact(numnod), hdotnp1(numnod), eraw(numnod), delta(numnod)
    real(real64) :: lower(numnod), main(numnod), upper(numnod), rhs(numnod), gamma(numnod)
    real(real64) :: jv(numnod), jv_expected(numnod)
    real(real64) :: storage0, storage1, dmass, exact_storage_delta, exact_qint, emass
    real(real64) :: endpoint_diff, eraw_diff, delta_diff, raw_norm, double_defect_norm, bm
    real(real64) :: exact_mnorm, exact_inf, binf, inequality_allow, scale
    integer :: ierr

    h0=h_eq+u0
    hbe=h_eq+ube
    hexact=h_eq+uexact
    call constitutive%evaluate(h0,theta0,conductivity,capacity,dkdh)
    initial_state%active_nodes=numnod
    allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
    initial_state%pressure_head=h0
    initial_state%water_content=theta0
    initial_state%ponding_depth=0.0_real64
    initial_state%groundwater_level=-2.0_real64
    storage0=sum(theta0*parameters%dz)

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=initial_state
    request%step_duration=dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=5
    request%boundary%top_flux=-kval
    request%boundary%top_head=h0(1)
    request%boundary%bottom_flux=12345.678_real64
    request%boundary%bottom_head=h_eq
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=8
    request%numerical%max_backtracking=4
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-6_real64
    request%numerical%compartment_balance_tolerance=1.0e-12_real64
    request%numerical%total_balance_tolerance=1.0e-12_real64
    request%numerical%head_abs_tolerance=1.0e-12_real64
    request%numerical%head_rel_tolerance=1.0e-12_real64
    request%numerical%ponding_tolerance=1.0e-12_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider

    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,trim(axis)//' HeadCalc converged')

    endpoint_diff=maxval(abs(result%candidate_state%pressure_head-hbe))
    scale=max(maxval(abs(result%candidate_state%pressure_head)),maxval(abs(hbe)))
    call require(endpoint_diff<=fp_bound(scale),trim(axis)//' analytic BE endpoint')

    hdotnp1=(result%candidate_state%pressure_head-h0)/dt
    eraw=0.5_real64*dt*(hdotnp1-hdotn)
    eraw_diff=maxval(abs(eraw-eraw_exact))
    scale=max(maxval(abs(eraw)),maxval(abs(eraw_exact)))
    call require(eraw_diff<=fp_bound(scale),trim(axis)//' raw observer algebra')

    call assemble_jacobian(dt,lower,main,upper)
    if (trim(axis)=='SINGLE') then
      call apply_tridiag(lower,main,upper,v1,jv)
      jv_expected=mdiag*(1.0_real64/dt+lambda1)*v1
      call require(maxval(abs(jv-jv_expected))<=fp_bound(max(maxval(abs(jv)),maxval(abs(jv_expected)))), &
           'SINGLE reconstructed J eigen-action')
    else
      call apply_tridiag(lower,main,upper,v1,jv)
      jv_expected=mdiag*(1.0_real64/dt+lambda1)*v1
      call require(maxval(abs(jv-jv_expected))<=fp_bound(max(maxval(abs(jv)),maxval(abs(jv_expected)))), &
           'MULTI reconstructed J mode1 action')
      call apply_tridiag(lower,main,upper,v2,jv)
      jv_expected=mdiag*(1.0_real64/dt+lambda2)*v2
      call require(maxval(abs(jv-jv_expected))<=fp_bound(max(maxval(abs(jv)),maxval(abs(jv_expected)))), &
           'MULTI reconstructed J mode2 action')
    end if

    rhs=(mdiag/dt)*eraw
    gamma=0.0_real64
    call reference_tridag(numnod,lower,main,upper,rhs,delta,gamma,ierr)
    call require(ierr==0,trim(axis)//' defect tridiagonal solve')
    delta_diff=maxval(abs(delta-delta_exact))
    scale=max(maxval(abs(delta)),maxval(abs(delta_exact)))
    call require(delta_diff<=fp_bound(scale),trim(axis)//' analytic transported defect')

    raw_norm=mnorm(eraw)
    double_defect_norm=2.0_real64*mnorm(delta)
    exact_mnorm=mnorm((hbe-hexact))
    bm=min(raw_norm,double_defect_norm)
    exact_inf=maxval(abs(hbe-hexact))
    binf=bm/sqrt(minval(mdiag))
    inequality_allow=fp_bound(max(raw_norm,double_defect_norm,exact_mnorm,bm))
    call require(exact_mnorm<=raw_norm+inequality_allow,trim(axis)//' raw M bound')
    call require(exact_mnorm<=double_defect_norm+inequality_allow,trim(axis)//' double defect M bound')
    call require(exact_mnorm<=bm+inequality_allow,trim(axis)//' combined M bound')
    call require(exact_inf<=binf+fp_bound(max(exact_inf,binf)),trim(axis)//' head infinity bound')

    if (trim(axis)=='SINGLE') then
      if (x1<1.0_real64) then
        call require(raw_norm<=double_defect_norm+inequality_allow,'SINGLE raw route for x<1')
      else if (x1>1.0_real64) then
        call require(double_defect_norm<raw_norm,'SINGLE defect route for x>1')
      end if
    end if

    storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
    dmass=(storage1-storage0)-dt*(result%bottom_flux-result%top_flux)
    call require(abs(dmass)<=fp_bound(max(storage0,storage1)),'principal discrete mass ledger')
    call require(abs(result%top_flux+kval)<=fp_bound(kval),'manufactured top gravity flux')

    exact_storage_delta=cap*sum(parameters%dz*(uexact-u0))
    exact_qint=mode_bottom_integral(dt,a1,v1,lambda1)
    if (abs(a2)>0.0_real64) exact_qint=exact_qint+mode_bottom_integral(dt,a2,v2,lambda2)
    emass=exact_storage_delta-exact_qint
    call require(abs(emass)<=fp_bound(max(abs(exact_storage_delta),abs(exact_qint))), &
         trim(axis)//' exact continuous mass identity')

    call require(ieee_is_finite(raw_norm) .and. ieee_is_finite(double_defect_norm) .and. &
         ieee_is_finite(bm) .and. ieee_is_finite(exact_mnorm),'finite bound metrics')

    write(*,'(A,A,A,I0,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
         'FSI24_GB_POINT:AXIS=',trim(axis),':I=',ipoint,':DT=',dt,':X1=',x1,':X2=',x2, &
         ':ERR_M=',exact_mnorm,':RAW_M=',raw_norm,':D2_M=',double_defect_norm,':BM=',bm, &
         ':ERR_INF=',exact_inf,':BINF=',binf
    write(*,'(A,A,A,I0,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
         'FSI24_GB_MASS:AXIS=',trim(axis),':I=',ipoint,':DMASS=',dmass,':EMASS=',emass,':DELTA_DIFF=',delta_diff
  end subroutine run_point

  subroutine assemble_jacobian(dt,lower,main,upper)
    real(real64), intent(in) :: dt
    real(real64), intent(out) :: lower(:),main(:),upper(:)
    lower=0.0_real64
    upper=0.0_real64
    lower(2:numnod)=-kval
    upper(1:numnod-1)=-kval
    main=mdiag/dt+kval*[1.0_real64,2.0_real64,2.0_real64,3.0_real64]
  end subroutine assemble_jacobian

  subroutine apply_tridiag(lower,main,upper,x,y)
    real(real64), intent(in) :: lower(:),main(:),upper(:),x(:)
    real(real64), intent(out) :: y(:)
    integer :: j
    y=main*x
    do j=2,numnod
      y(j)=y(j)+lower(j)*x(j-1)
    end do
    do j=1,numnod-1
      y(j)=y(j)+upper(j)*x(j+1)
    end do
  end subroutine apply_tridiag

  pure real(real64) function mnorm(x) result(value)
    real(real64), intent(in) :: x(:)
    value=sqrt(sum(mdiag*x*x))
  end function mnorm

  pure real(real64) function mode_bottom_integral(dt,amplitude,vec,lambda) result(value)
    real(real64), intent(in) :: dt,amplitude,vec(:),lambda
    real(real64) :: x
    x=lambda*dt
    value=-(kval/(0.5_real64*parameters%dz(numnod)))*amplitude*vec(numnod)*(1.0_real64-exp(-x))/lambda
  end function mode_bottom_integral

  subroutine initialize_geometry_and_providers()
    parameters%parameter_set_id=240241_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)
    call require(maxval(abs(parameters%dz-[0.5_real64,0.5_real64,1.0_real64,1.0_real64]))==0.0_real64, &
         'frozen dz geometry')
    call require(all(abs(parameters%node_distance-1.0_real64)==0.0_real64),'frozen internal distance geometry')

    constitutive%equilibrium_head=h_eq
    constitutive%theta_equilibrium=theta_eq
    constitutive%capacity=cap
    constitutive%conductivity=kval

    allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
    drainage=0.0_real64
    subsurface=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
    if (.not.same_type_as(top_provider,top_provider)) error stop 'F-SI24 invalid top provider type'
  end subroutine initialize_geometry_and_providers

  pure real(real64) function fp_bound(scale) result(bound_value)
    real(real64), intent(in) :: scale
    bound_value=65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(scale))
  end function fp_bound

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI24_GATE_B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi24_gate_b_exact_manufactured_bound
