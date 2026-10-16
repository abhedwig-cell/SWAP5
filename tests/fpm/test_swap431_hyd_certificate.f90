program test_swap431_hyd_certificate
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_temporal_indicator, only: evaluate_reference_richards_temporal_indicator
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b111_analytical_hydraulic_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=3
  real(real64), parameter :: dt=0.01_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b111_analytical_hydraulic_parameters_t), target :: hydraulic
  type(b111_analytical_hydraulic_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(soil_water_temporal_indicator_request_t) :: indicator_request
  type(soil_water_temporal_indicator_result_t) :: indicator
  real(real64) :: cofgen(42,n)
  real(real64) :: drainage(1,n), irrigation(n), root_sink(n)
  real(real64) :: base_head(n), cand_head(n)
  real(real64) :: water(n), conductivity(n), capacity(n), dkdh(n)
  real(real64) :: expected_raw, expected_defect, expected_bounded, expected_binf
  real(real64) :: previous(n)
  integer :: i, kind

  call configure_parameters(parameters,cofgen)
  do kind=2,3
  call initialize_b111_analytical_hydraulic_parameters(hydraulic,spread(kind,1,n),cofgen)
  call bind_b111_analytical_hydraulic_provider(constitutive,hydraulic)

  base_head=[-12.3_real64,-78.9_real64,-543.2_real64]
  cand_head=[-12.1_real64,-79.2_real64,-542.7_real64]
  previous=[-0.15_real64,0.08_real64,-0.03_real64]

  drainage=0.0_real64
  irrigation=0.0_real64
  root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state%active_nodes=n
  allocate(request%base_state%pressure_head(n),request%base_state%water_content(n))
  request%base_state%pressure_head=base_head
  call constitutive%evaluate(base_head,water,conductivity,capacity,dkdh)
  request%base_state%water_content=water
  request%step_duration=dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=2
  request%boundary%top_flux=0.0_real64
  request%boundary%bottom_flux=0.0_real64
  request%physical%macropore_active=.false.
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%evaluation%constitutive=>constitutive
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  result=soil_water_solve_result_t()
  result%status=SW_SOLVE_CONVERGED
  result%candidate_state%active_nodes=n
  allocate(result%candidate_state%pressure_head(n),result%candidate_state%water_content(n))
  result%candidate_state%pressure_head=cand_head
  call constitutive%evaluate(cand_head,water,conductivity,capacity,dkdh)
  result%candidate_state%water_content=water

  indicator_request%previous_right_derivative_available=.true.
  allocate(indicator_request%previous_right_derivative(n))
  indicator_request%previous_right_derivative=previous

  call evaluate_reference_richards_temporal_indicator(request,result,indicator_request,indicator)
  call require(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE .and. indicator%available, &
       'analytical temporal certificate available')
  call require(indicator%additional_full_nonlinear_solves==0,'no extra nonlinear solve')
  call require(indicator%additional_tridiagonal_solves==1,'one tridiagonal defect solve')

  call independent_oracle(parameters,constitutive,base_head,cand_head,previous,expected_raw,expected_defect, &
       expected_bounded,expected_binf)

  call require(close_value(indicator%raw_m_norm,expected_raw),'raw norm equivalence')
  call require(close_value(indicator%defect_m_norm,expected_defect),'defect norm equivalence')
  call require(close_value(indicator%bounded_m_norm,expected_bounded),'bounded norm equivalence')
  call require(close_value(indicator%head_inf_bound,expected_binf),'head bound equivalence')
  call require(all(ieee_is_finite(indicator%current_right_derivative)),'finite derivative')
  write(*,'(a,i0,4es24.16)') 'HYD_CERTIFICATE_ORACLE_MODEL=',kind,indicator%raw_m_norm, &
       indicator%defect_m_norm,indicator%bounded_m_norm,indicator%head_inf_bound
  ! Missing history and outside-smooth-branch inputs remain unavailable.
  indicator_request%previous_right_derivative_available=.false.
  call evaluate_reference_richards_temporal_indicator(request,result,indicator_request,indicator)
  call require(.not.indicator%available,'missing history rejected')
  indicator_request%previous_right_derivative_available=.true.
  request%base_state%pressure_head=merge(-1.0e5_real64,0.0_real64,kind==2)
  result%candidate_state%pressure_head=request%base_state%pressure_head
  call constitutive%evaluate(result%candidate_state%pressure_head,water,conductivity,capacity,dkdh)
  result%candidate_state%water_content=water
  call evaluate_reference_richards_temporal_indicator(request,result,indicator_request,indicator)
  call require(.not.indicator%available.and.trim(indicator%route)=='constitutive-branch-deferred', &
       'dry floor or saturated branch rejected')
  deallocate(request%base_state%pressure_head,request%base_state%water_content, &
       result%candidate_state%pressure_head,result%candidate_state%water_content, &
       indicator_request%previous_right_derivative)
  end do
  print '(a)','SWAP431_HYD_CERTIFICATE_INDEPENDENT_OPERATOR_AND_BRANCH_CONTROLS=PASS'

contains

  subroutine configure_parameters(p,cof)
    type(soil_water_parameter_set_t),intent(out),target::p
    real(real64),intent(out)::cof(42,n)
    integer::j
    p%parameter_set_id=110011_int64
    p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    p%z=[-5.0_real64,-15.0_real64,-30.0_real64]
    p%dz=[10.0_real64,10.0_real64,20.0_real64]
    p%node_distance=[5.0_real64,10.0_real64,15.0_real64]
    cof=0.0_real64
    do j=1,n
      cof(1,j)=0.032_real64; cof(2,j)=0.423_real64; cof(3,j)=4.75_real64
      cof(4,j)=0.0135_real64; cof(5,j)=0.365_real64; cof(6,j)=1.455_real64
      cof(7,j)=1.0_real64-1.0_real64/cof(6,j); cof(8,j)=cof(4,j)
      cof(9,j)=0.0_real64; cof(10,j)=cof(3,j); cof(11,j)=0.999_real64
      cof(12,j)=0.99_real64*cof(3,j); cof(13,j)=0.05_real64; cof(14,j)=2.2_real64; &
      cof(15,j)=1.0_real64-1.0_real64/2.2_real64; cof(16,j)=0.65_real64; cof(22,j)=-1.0e6_real64; cof(23,j)=1.0e-12_real64
    end do
  end subroutine configure_parameters

  subroutine independent_oracle(p,provider,h0,h1,prev,raw_norm,defect_norm,bounded_norm,binf)
    type(soil_water_parameter_set_t),intent(in)::p
    type(b111_analytical_hydraulic_provider_t),intent(in)::provider
    real(real64),intent(in)::h0(:),h1(:),prev(:)
    real(real64),intent(out)::raw_norm,defect_norm,bounded_norm,binf
    real(real64)::wb(n),kb(n),cb(n),db(n),wc(n),kc(n),cc(n),dc(n)
    real(real64)::mass(n),lower(n),diag(n),upper(n),rhs(n),delta(n),e(n),face
    logical::solved
    integer::j

    call provider%evaluate(h0,wb,kb,cb,db)
    call provider%evaluate(h1,wc,kc,cc,dc)
    mass=cc*p%dz
    e=0.5_real64*dt*((h1-h0)/dt-prev)
    lower=0.0_real64; upper=0.0_real64; diag=mass/dt
    do j=2,n
      face=0.5_real64*(kb(j-1)+kb(j))/p%node_distance(j)
      lower(j)=-face; upper(j-1)=-face
      diag(j-1)=diag(j-1)+face; diag(j)=diag(j)+face
    end do
    rhs=(mass/dt)*e
    call thomas(lower,diag,upper,rhs,delta,solved)
    call require(solved,'independent tridiagonal solve')
    raw_norm=sqrt(sum(mass*e*e))
    defect_norm=sqrt(sum(mass*delta*delta))
    bounded_norm=min(raw_norm,2.0_real64*defect_norm)
    binf=bounded_norm/sqrt(minval(mass))
  end subroutine independent_oracle

  subroutine thomas(lower,diag,upper,rhs,x,ok)
    real(real64),intent(in)::lower(:),diag(:),upper(:),rhs(:)
    real(real64),intent(out)::x(:)
    logical,intent(out)::ok
    real(real64)::a(n,n),b(n),row(n),value,factor
    integer::i,j,pivot
    a=0.0_real64;b=rhs;x=0.0_real64;ok=.false.
    do i=1,n
      a(i,i)=diag(i)
      if(i>1)a(i,i-1)=lower(i)
      if(i<n)a(i,i+1)=upper(i)
    end do
    do i=1,n
      pivot=i-1+maxloc(abs(a(i:n,i)),dim=1)
      if(abs(a(pivot,i))<=tiny(1.0_real64))return
      row=a(i,:);a(i,:)=a(pivot,:);a(pivot,:)=row
      value=b(i);b(i)=b(pivot);b(pivot)=value
      do j=i+1,n
        factor=a(j,i)/a(i,i);a(j,:)=a(j,:)-factor*a(i,:);b(j)=b(j)-factor*b(i)
      end do
    end do
    do i=n,1,-1
      x(i)=(b(i)-sum(a(i,i+1:n)*x(i+1:n)))/a(i,i)
    end do
    ok=all(ieee_is_finite(x))
  end subroutine thomas

  pure logical function close_value(a,b)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    close_value=ieee_is_finite(a) .and. ieee_is_finite(b) .and. &
         abs(a-b)<=32768.0_real64*epsilon(1.0_real64)*scale
  end function close_value

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'TEMPORAL11_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_swap431_hyd_certificate
