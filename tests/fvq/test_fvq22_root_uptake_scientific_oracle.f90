program test_fvq22_root_uptake_scientific_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK, ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW, ROOT_UPTAKE_INVALID_REQUEST
  implicit none

  type(root_water_uptake_parameters_t) :: p
  type(root_water_uptake_request_t) :: r, bad_r
  type(process_hydraulic_view_t) :: v, bad_v, v_b
  type(root_water_uptake_flux_result_t) :: f, f_a1, f_b, f_a2
  type(root_water_uptake_diagnostics_t) :: d, d_a1, d_b, d_a2
  real(real64), parameter :: ptra_cases(5) = [0.05_real64, 0.10_real64, 0.30_real64, 0.50_real64, 0.80_real64]
  real(real64), parameter :: dist_a(6) = [0.0_real64,0.07_real64,0.21_real64,0.48_real64,0.78_real64,1.0_real64]
  real(real64), parameter :: dist_b(6) = [0.0_real64,0.18_real64,0.33_real64,0.60_real64,0.88_real64,1.0_real64]
  real(real64), parameter :: tol = 4096.0_real64*epsilon(1.0_real64)
  real(real64) :: h3, expected_q(6), expected_pot(6), expected_alpha(6)
  integer :: k

  call configure_parameters(p)

  do k=1,size(ptra_cases)
    call configure_request(r,ptra_cases(k),dist_a)
    h3 = oracle_hlim3(p,r%potential_transpiration)
    call configure_boundary_view(v,p,h3)
    call oracle_qrot(p,r,v,expected_pot,expected_alpha,expected_q)
    call evaluate_macro_feddes_drought_uptake(p,v,r,f,d)
    call require(d%status==ROOT_UPTAKE_OK .and. d%evaluated,'ptra branch admitted')
    call require(close(d%critical_pressure_head,h3),'independent hlim3')
    call require(all_close(d%potential_root_sink,expected_pot),'independent potential uptake')
    call require(all_close(d%drought_reduction_factor,expected_alpha),'independent drought alpha')
    call require(all_close(f%root_extraction_sink,expected_q),'independent qrot')
    call require(close(f%actual_uptake_total,sum(expected_q)),'independent qrosum')
    call require(close(d%potential_uptake_total,sum(expected_pot)),'independent qpot sum')
    call require(close(d%drought_reduction_total,sum(expected_pot-expected_q)),'independent drought reduction sum')
  end do
  write(*,'(A)') 'FVQ22_PTRA_AND_HLIM3_BOUNDARY_ORACLE=PASS'
  write(*,'(A)') 'FVQ22_FEDDES_PRESSURE_BOUNDARY_ORACLE=PASS'

  call configure_request(r,0.37_real64,dist_a)
  h3=oracle_hlim3(p,r%potential_transpiration)
  call configure_boundary_view(v,p,h3)
  call oracle_qrot(p,r,v,expected_pot,expected_alpha,expected_q)
  call evaluate_macro_feddes_drought_uptake(p,v,r,f,d)
  call require(all_close(f%root_extraction_sink,expected_q),'distribution A oracle')

  call configure_request(r,0.37_real64,dist_b)
  call oracle_qrot(p,r,v,expected_pot,expected_alpha,expected_q)
  call evaluate_macro_feddes_drought_uptake(p,v,r,f,d)
  call require(all_close(f%root_extraction_sink,expected_q),'distribution B oracle')
  call require(close(d%potential_uptake_total,r%potential_transpiration),'dynamic distribution remains normalized')
  write(*,'(A)') 'FVQ22_DYNAMIC_ROOT_DISTRIBUTION_ORACLE=PASS'

  bad_v=process_hydraulic_view_t()
  r=root_water_uptake_request_t()
  r%potential_transpiration=0.2_real64
  r%rooted_nodes=0
  call evaluate_macro_feddes_drought_uptake(p,bad_v,r,f,d)
  call require(d%status==ROOT_UPTAKE_OK .and. d%no_roots,'no roots legacy exit')
  call require(allocated(f%root_extraction_sink) .and. maxval(abs(f%root_extraction_sink))==0.0_real64,'no roots zero qrot')
  write(*,'(A)') 'FVQ22_NO_ROOT_DEPENDENCY_FREE_ORACLE=PASS'

  r=root_water_uptake_request_t()
  r%potential_transpiration=0.5e-10_real64
  r%rooted_nodes=5
  call evaluate_macro_feddes_drought_uptake(p,bad_v,r,f,d)
  call require(d%status==ROOT_UPTAKE_OK .and. d%negligible_transpiration,'ptra below nihil legacy exit')
  call require(maxval(abs(f%root_extraction_sink))==0.0_real64,'ptra below nihil zero qrot')
  write(*,'(A)') 'FVQ22_BELOW_NIHIL_DEPENDENCY_FREE_ORACLE=PASS'

  call configure_request(r,1.0e-10_real64,dist_a)
  h3=oracle_hlim3(p,r%potential_transpiration)
  call configure_boundary_view(v,p,h3)
  call oracle_qrot(p,r,v,expected_pot,expected_alpha,expected_q)
  call evaluate_macro_feddes_drought_uptake(p,v,r,f,d)
  call require(d%status==ROOT_UPTAKE_OK .and. d%evaluated .and. .not. d%negligible_transpiration, &
       'ptra exactly nihil is active')
  call require(all_close(f%root_extraction_sink,expected_q),'ptra exactly nihil oracle')
  write(*,'(A)') 'FVQ22_EXACT_NIHIL_ACTIVE_EVALUATION=PASS'

  call configure_request(bad_r,0.3_real64,dist_a)
  bad_r%cumulative_root_fraction(4)=bad_r%cumulative_root_fraction(3)-0.02_real64
  call evaluate_macro_feddes_drought_uptake(p,v,bad_r,f,d)
  call require(d%status==ROOT_UPTAKE_INVALID_REQUEST,'nonmonotonic distribution fail closed')
  call configure_request(bad_r,0.3_real64,dist_a)
  bad_r%cumulative_root_fraction(6)=0.97_real64
  call evaluate_macro_feddes_drought_uptake(p,v,bad_r,f,d)
  call require(d%status==ROOT_UPTAKE_INVALID_REQUEST,'unnormalized distribution fail closed')
  bad_v=v
  bad_v%active_nodes=p%active_nodes-1
  call configure_request(r,0.3_real64,dist_a)
  call evaluate_macro_feddes_drought_uptake(p,bad_v,r,f,d)
  call require(d%status==ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW,'invalid active hydraulic view fail closed')
  write(*,'(A)') 'FVQ22_ACTIVE_INVALID_DOMAIN_FAIL_CLOSED=PASS'

  call configure_request(r,0.32_real64,dist_b)
  h3=oracle_hlim3(p,r%potential_transpiration)
  call configure_boundary_view(v,p,h3)
  call evaluate_macro_feddes_drought_uptake(p,v,r,f_a1,d_a1)
  v_b=v
  v_b%pressure_head(3)=p%hlim4-500.0_real64
  call evaluate_macro_feddes_drought_uptake(p,v_b,r,f_b,d_b)
  call require(.not. all_bits_identical(f_a1%root_extraction_sink,f_b%root_extraction_sink),'B distinct from A')
  call evaluate_macro_feddes_drought_uptake(p,v,r,f_a2,d_a2)
  call require(all_bits_identical(f_a1%root_extraction_sink,f_a2%root_extraction_sink),'A/B/A qrot')
  call require(all_bits_identical(d_a1%potential_root_sink,d_a2%potential_root_sink),'A/B/A qpotential')
  call require(all_bits_identical(d_a1%drought_reduction,d_a2%drought_reduction),'A/B/A drought reduction')
  call require(same_bits(f_a1%actual_uptake_total,f_a2%actual_uptake_total),'A/B/A qrosum')
  write(*,'(A)') 'FVQ22_DIRECT_PROCESS_A_B_A_IDENTITY=PASS'

  write(*,'(A)') 'FVQ22_ROOT_UPTAKE_SCIENTIFIC_ORACLE PASS'

contains

  subroutine configure_parameters(x)
    type(root_water_uptake_parameters_t), intent(out) :: x
    x%active_nodes=6
    x%hlim3l=-920.0_real64
    x%hlim3h=-430.0_real64
    x%hlim4=-16000.0_real64
    x%adcrl=0.10_real64
    x%adcrh=0.50_real64
  end subroutine configure_parameters

  subroutine configure_request(x,ptra,distribution)
    type(root_water_uptake_request_t), intent(out) :: x
    real(real64), intent(in) :: ptra
    real(real64), intent(in) :: distribution(6)
    x%potential_transpiration=ptra
    x%rooted_nodes=5
    allocate(x%cumulative_root_fraction(6))
    x%cumulative_root_fraction=distribution
  end subroutine configure_request

  subroutine configure_boundary_view(x,p,h3)
    type(process_hydraulic_view_t), intent(out) :: x
    type(root_water_uptake_parameters_t), intent(in) :: p
    real(real64), intent(in) :: h3
    real(real64) :: middle
    middle=0.5_real64*(p%hlim4+h3)
    x%active_nodes=p%active_nodes
    allocate(x%pressure_head(p%active_nodes),x%water_content(p%active_nodes))
    x%pressure_head=[p%hlim4-100.0_real64,p%hlim4,middle,h3,h3+100.0_real64,h3+500.0_real64]
    x%water_content=0.25_real64
    x%ponding_depth=0.0_real64
    x%groundwater_level=-2.0_real64
  end subroutine configure_boundary_view

  pure real(real64) function oracle_hlim3(p,ptra) result(h3)
    type(root_water_uptake_parameters_t), intent(in) :: p
    real(real64), intent(in) :: ptra
    if (ptra < p%adcrl) then
      h3=p%hlim3l
    else if (ptra <= p%adcrh) then
      h3=p%hlim3h+((p%adcrh-ptra)/(p%adcrh-p%adcrl))*(p%hlim3l-p%hlim3h)
    else
      h3=p%hlim3h
    end if
  end function oracle_hlim3

  pure real(real64) function oracle_alpha(h,h3,h4) result(a)
    real(real64), intent(in) :: h,h3,h4
    if (h < h4) then
      a=0.0_real64
    else if (h <= h3) then
      a=(h4-h)/(h4-h3)
    else
      a=1.0_real64
    end if
  end function oracle_alpha

  subroutine oracle_qrot(p,r,v,qpot,alpha,qrot)
    type(root_water_uptake_parameters_t), intent(in) :: p
    type(root_water_uptake_request_t), intent(in) :: r
    type(process_hydraulic_view_t), intent(in) :: v
    real(real64), intent(out) :: qpot(6),alpha(6),qrot(6)
    real(real64) :: h3
    integer :: i
    qpot=0.0_real64
    alpha=1.0_real64
    qrot=0.0_real64
    h3=oracle_hlim3(p,r%potential_transpiration)
    do i=1,r%rooted_nodes
      qpot(i)=(r%cumulative_root_fraction(i+1)-r%cumulative_root_fraction(i))*r%potential_transpiration
      alpha(i)=oracle_alpha(v%pressure_head(i),h3,p%hlim4)
      qrot(i)=qpot(i)*alpha(i)
    end do
  end subroutine oracle_qrot

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal=abs(a-b)<=tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function all_close(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if (.not. equal) return
    do i=1,size(a)
      if (.not. close(a(i),b(i))) then
        equal=.false.
        return
      end if
    end do
  end function all_close

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function all_bits_identical(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if (.not. equal) return
    do i=1,size(a)
      if (.not. same_bits(a(i),b(i))) then
        equal=.false.
        return
      end if
    end do
  end function all_bits_identical

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ22_ROOT_UPTAKE_ORACLE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq22_root_uptake_scientific_oracle
