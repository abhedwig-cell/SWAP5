program test_fvq53_surface_evaporation_capacity_independent
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_result_t, &
       SURFACE_EVAP_CAPACITY_AVAILABLE, SURFACE_EVAP_CAPACITY_INVALID_INPUT, &
       SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION
  use mod_b110_surface_evaporation_capacity_provider, only: b110_surface_evaporation_capacity_provider_t, &
       bind_b110_surface_evaporation_capacity_provider, B110_SURFACE_ATMOSPHERIC_HEAD_CM
  implicit none

  integer, parameter :: nnode = 2
  integer, parameter :: nfamily = 3
  real(real64), parameter :: heads(10) = [ &
       1.0_real64, 0.0_real64, -0.005_real64, -0.01_real64, -0.1_real64, &
       -10.0_real64, -100.0_real64, -10000.0_real64, -275000.0_real64, -300000.0_real64 ]
  real(real64), parameter :: hatm = -275000.0_real64

  type(soil_water_parameter_set_t), target :: geometry
  type(b110_default_mvg_parameters_t), target :: candidate_hydraulics
  type(b110_surface_evaporation_capacity_provider_t) :: provider, unbound_provider
  type(soil_water_physical_state_t) :: state
  type(surface_evaporation_capacity_result_t) :: result, a1, b, a2
  real(real64) :: raw(24,nnode), oracle_c(42,nnode)
  real(real64) :: k_atm, k_top, k_face, expected, scalar_k, zero_head
  real(real64) :: head_before(nnode), theta_before(nnode), pond_before, gw_before
  real(real64) :: nanv
  logical :: ok
  integer :: family, method, ih, oracle_cases, conductivity_cases

  oracle_cases = 0
  conductivity_cases = 0
  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  do family = 1, nfamily
    call configure_family(family, raw, geometry)
    call oracle_expand(raw, oracle_c)
    call initialize_b110_default_mvg_parameters(candidate_hydraulics, raw)

    state%active_nodes = nnode
    if (.not. allocated(state%pressure_head)) allocate(state%pressure_head(nnode))
    if (.not. allocated(state%water_content)) allocate(state%water_content(nnode))
    state%pressure_head = [-100.0_real64, -250.0_real64]
    state%water_content = [0.20_real64, 0.24_real64]
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -180.0_real64

    ! Independent constitutive oracle. Expected values never call the candidate constitutive routine.
    do ih = 1, size(heads)
      call evaluate_b110_default_mvg_conductivity(candidate_hydraulics, 1, heads(ih), scalar_k, ok)
      call require(ok, 531)
      call require_close(scalar_k, oracle_hconduc(oracle_c(:,1), heads(ih)), 532)
      conductivity_cases = conductivity_cases + 1
    end do

    k_atm = oracle_hconduc(oracle_c(:,1), hatm)
    call require(k_atm >= 0.0_real64, 533)

    do method = 1, 6
      call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
           method, .false., .false., ok)
      call require(ok, 534)

      do ih = 1, size(heads)
        state%pressure_head(1) = heads(ih)
        head_before = state%pressure_head
        theta_before = state%water_content
        pond_before = state%ponding_depth
        gw_before = state%groundwater_level

        call provider%evaluate(state, result)
        call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 535)

        k_top = oracle_hconduc(oracle_c(:,1), heads(ih))
        k_face = oracle_hcomean(method, k_atm, k_top, geometry%dz(1), geometry%dz(1))
        expected = -k_face*((hatm-heads(ih))/geometry%node_distance(1) + 1.0_real64)
        call require_close(result%evaporation_capacity, expected, 536)

        call require(all_same_real_bits(state%pressure_head, head_before), 537)
        call require(all_same_real_bits(state%water_content, theta_before), 538)
        call require(same_real_bits(state%ponding_depth, pond_before), 539)
        call require(same_real_bits(state%groundwater_level, gw_before), 540)
        oracle_cases = oracle_cases + 1
      end do

      ! Exact sign boundary implied by the B1.10 equation, then a head below hatm for negative Emax.
      zero_head = hatm + geometry%node_distance(1)
      state%pressure_head(1) = zero_head
      call provider%evaluate(state, result)
      call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 541)
      call require(abs(result%evaporation_capacity) <= &
           8192.0_real64*epsilon(1.0_real64)*max(1.0_real64,k_atm), 542)

      state%pressure_head(1) = -300000.0_real64
      call provider%evaluate(state, result)
      call require(result%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 543)
      call require(result%evaporation_capacity < 0.0_real64, 544)
    end do
  end do

  call require(oracle_cases == nfamily*6*size(heads), 545)
  call require(conductivity_cases == nfamily*size(heads), 546)

  ! Independent fail-closed review of all deliberately held configurations.
  call configure_family(1, raw, geometry)
  call initialize_b110_default_mvg_parameters(candidate_hydraulics, raw)
  state%active_nodes = nnode
  if (.not. allocated(state%pressure_head)) allocate(state%pressure_head(nnode))
  if (.not. allocated(state%water_content)) allocate(state%water_content(nnode))
  state%pressure_head = [-100.0_real64, -250.0_real64]
  state%water_content = [0.20_real64, 0.24_real64]
  state%ponding_depth = 0.0_real64
  state%groundwater_level = -180.0_real64

  call unbound_provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 547)
  call require(same_real_bits(result%evaporation_capacity, 0.0_real64), 548)

  call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
       7, .false., .false., ok)
  call require(ok, 549)
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 550)
  call require(same_real_bits(result%evaporation_capacity, 0.0_real64), 551)

  call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
       0, .false., .false., ok)
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 552)

  call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
       1, .true., .false., ok)
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 553)

  call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
       1, .false., .true., ok)
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_UNSUPPORTED_CONFIGURATION, 554)

  call bind_b110_surface_evaporation_capacity_provider(provider, geometry, candidate_hydraulics, &
       1, .false., .false., ok)
  state%pressure_head(1) = nanv
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 555)
  state%pressure_head(1) = -100.0_real64

  geometry%node_distance(1) = 0.0_real64
  call provider%evaluate(state, result)
  call require(result%status == SURFACE_EVAP_CAPACITY_INVALID_INPUT, 556)
  geometry%node_distance(1) = 2.75_real64

  ! Ponding classification is not part of Emax. Finite changes in ponding must not affect capacity.
  state%ponding_depth = 0.0_real64
  call provider%evaluate(state, a1)
  state%ponding_depth = 12.5_real64
  call provider%evaluate(state, a2)
  call require(a1%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 557)
  call require(a2%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 558)
  call require_close(a1%evaporation_capacity, a2%evaporation_capacity, 559)

  ! A-B-A replay checks there is no hidden evolving state in the provider.
  state%ponding_depth = 0.0_real64
  state%pressure_head(1) = -37.0_real64
  call provider%evaluate(state, a1)
  state%pressure_head(1) = -5000.0_real64
  call provider%evaluate(state, b)
  state%pressure_head(1) = -37.0_real64
  call provider%evaluate(state, a2)
  call require(a1%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 560)
  call require(b%status == SURFACE_EVAP_CAPACITY_AVAILABLE, 561)
  call require(a2%status == a1%status, 562)
  call require_close(a2%evaporation_capacity, a1%evaporation_capacity, 563)

  write(*,'(A,I0)') 'FVQ53_ORACLE_CASES=', oracle_cases
  write(*,'(A,I0)') 'FVQ53_CONDUCTIVITY_CASES=', conductivity_cases
  write(*,'(A)') 'FVQ53_B110_CONSTITUTIVE_ORACLE=PASS'
  write(*,'(A)') 'FVQ53_HCOMEAN_1_TO_6_ORACLE=PASS'
  write(*,'(A)') 'FVQ53_SIGNED_EMAX_ORACLE=PASS'
  write(*,'(A)') 'FVQ53_HELD_SCOPE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FVQ53_STATELESS_READ_ONLY_ABA=PASS'
  write(*,'(A)') 'FVQ53_INDEPENDENT_ORACLE=PASS'

contains

  subroutine configure_family(family_id, c, p)
    integer, intent(in) :: family_id
    real(real64), intent(out) :: c(24,nnode)
    type(soil_water_parameter_set_t), intent(inout) :: p
    integer :: j

    if (allocated(p%z)) deallocate(p%z)
    if (allocated(p%dz)) deallocate(p%dz)
    if (allocated(p%node_distance)) deallocate(p%node_distance)
    p%active_nodes = nnode
    allocate(p%z(nnode), p%dz(nnode), p%node_distance(nnode))
    p%z = [-2.5_real64, -11.0_real64]

    c = 0.0_real64
    select case (family_id)
    case (1)
      p%dz = [5.0_real64, 12.0_real64]
      p%node_distance = [2.75_real64, 8.5_real64]
      do j = 1, nnode
        c(1,j)=0.032_real64; c(2,j)=0.423_real64; c(3,j)=4.75_real64
        c(4,j)=0.0135_real64; c(5,j)=0.365_real64; c(6,j)=1.455_real64
        c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      end do
    case (2)
      p%dz = [8.0_real64, 15.0_real64]
      p%node_distance = [4.125_real64, 11.5_real64]
      do j = 1, nnode
        c(1,j)=0.050_real64; c(2,j)=0.500_real64; c(3,j)=0.50_real64
        c(4,j)=0.005_real64; c(5,j)=0.20_real64; c(6,j)=1.25_real64
        c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=-10.0_real64
      end do
    case (3)
      p%dz = [3.0_real64, 9.0_real64]
      p%node_distance = [1.625_real64, 6.0_real64]
      do j = 1, nnode
        c(1,j)=0.060_real64; c(2,j)=0.460_real64; c(3,j)=1.80_real64
        c(4,j)=0.025_real64; c(5,j)=0.60_real64; c(6,j)=1.70_real64
        c(7,j)=1.0_real64-1.0_real64/c(6,j); c(8,j)=c(4,j); c(9,j)=0.0_real64
      end do
    case default
      error stop 564
    end select

    do j = 1, nnode
      c(10,j)=c(3,j); c(11,j)=0.999_real64; c(12,j)=0.99_real64*c(3,j)
      c(13,j)=0.10_real64; c(14,j)=1.50_real64; c(15,j)=0.50_real64
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine configure_family

  subroutine oracle_expand(raw_c, c)
    real(real64), intent(in) :: raw_c(24,nnode)
    real(real64), intent(out) :: c(42,nnode)
    real(real64), parameter :: hcrit = -1.0e-2_real64
    real(real64) :: h105, t105, c105, aa, bb, alpha
    integer :: j

    c = 0.0_real64
    c(1:24,:) = raw_c
    do j = 1, nnode
      alpha = c(4,j)
      c(25,j)=c(2,j)-c(1,j)
      c(26,j)=c(1,j)+c(25,j)/((1.0_real64+(abs(alpha*hcrit))**c(6,j))**c(7,j))
      c(27,j)=(c(2,j)-c(26,j))/(-hcrit)
      c(28,j)=(1.0_real64+(abs(alpha*c(9,j)))**c(6,j))**(-c(7,j))
      c(29,j)=c(6,j)*c(7,j)*alpha
      c(30,j)=c(6,j)-1.0_real64
      c(31,j)=c(7,j)+1.0_real64
      c(32,j)=1.0_real64/c(7,j)
      c(33,j)=c(6,j)*(2.0_real64+c(7,j)*c(5,j))
      c(34,j)=c(5,j)+2.0_real64
      c(35,j)=c(7,j)-1.0_real64
      c(36,j)=c(5,j)-1.0_real64
      c(37,j)=c(14,j)*c(15,j)*c(13,j)
      c(38,j)=c(14,j)-1.0_real64
      c(39,j)=c(15,j)+1.0_real64
      if (c(15,j) > 0.0_real64) c(40,j)=1.0_real64/c(15,j)

      if (c(9,j) < 0.0_real64) then
        h105=1.05_real64*c(9,j)
        t105=c(1,j)+(c(2,j)-c(1,j))* &
             ((1.0_real64+(abs(alpha*c(9,j)))**c(6,j))**c(7,j))/ &
             ((1.0_real64+(abs(alpha*h105))**c(6,j))**c(7,j))
        c105=(c(2,j)-c(1,j))*alpha*c(7,j)*c(6,j)* &
             (abs(alpha*h105)**(c(6,j)-1.0_real64))* &
             ((1.0_real64+abs(alpha*c(9,j))**c(6,j))**c(7,j))/ &
             ((1.0_real64+abs(alpha*h105)**c(6,j))**(c(7,j)+1.0_real64))
        aa=(t105-c(2,j)-c105*h105)/(c105*h105**2)
        bb=(t105**2-2.0_real64*t105*c(2,j)+c(2,j)**2)/(t105-c(2,j)-c105*h105)
      else
        aa=0.0_real64; bb=0.0_real64
      end if
      c(41,j)=aa
      c(42,j)=aa*bb
    end do
  end subroutine oracle_expand

  pure real(real64) function oracle_watcon(c, head) result(theta)
    real(real64), intent(in) :: c(:), head
    real(real64), parameter :: hcrit = -1.0e-2_real64
    real(real64) :: help, h105, alpha

    alpha=c(4)
    if (head >= 0.0_real64) then
      theta=c(2)
    else if (c(9) > hcrit) then
      if (head > hcrit) then
        theta=min(c(26)+c(27)*(head-hcrit),c(2))
      else
        help=(1.0_real64+abs(alpha*head)**c(6))**c(7)
        theta=c(1)+c(25)/help
      end if
    else
      h105=1.05_real64*c(9)
      if (head >= h105) then
        theta=c(2)+c(42)*head/(1.0_real64+c(41)*head)
      else
        help=(1.0_real64+abs(alpha*head)**c(6))**c(7)
        theta=c(1)+c(25)/(help*c(28))
      end if
    end if
  end function oracle_watcon

  pure real(real64) function oracle_hconduc(c, head) result(k)
    real(real64), intent(in) :: c(:), head
    real(real64), parameter :: hcrit = -1.0e-2_real64
    real(real64), parameter :: verysmall = 1.0e-10_real64
    real(real64) :: theta, relsat, term1, term2, se

    theta=oracle_watcon(c,head)
    relsat=(theta-c(1))/c(25)
    if (c(9) > hcrit) then
      if (head < -1.0e14_real64) then
        k=verysmall
      else if (relsat > 1.0_real64-1.0e-6_real64) then
        k=c(3)
      else
        term1=(1.0_real64-relsat**c(32))**c(7)
        k=c(3)*(relsat**c(5))*(1.0_real64-term1)**2
      end if
    else
      if (head < -1.0e14_real64) then
        k=verysmall
      else if (head >= c(9)) then
        k=c(3)
      else
        se=((1.0_real64+abs(c(4)*head)**c(6))**(-c(7)))/c(28)
        term1=(1.0_real64-(se*c(28))**c(32))**c(7)
        term2=(1.0_real64-c(28)**c(32))**c(7)
        k=c(3)*se**c(5)*((1.0_real64-term1)/(1.0_real64-term2))**2
      end if
    end if
    k=min(k,c(3))
  end function oracle_hconduc

  pure real(real64) function oracle_hcomean(method, kup, klow, dzup, dzlow) result(kmean)
    integer, intent(in) :: method
    real(real64), intent(in) :: kup, klow, dzup, dzlow
    real(real64) :: a1, a2

    a1=dzup/(dzup+dzlow)
    a2=1.0_real64-a1
    select case(method)
    case(1)
      kmean=0.5_real64*(kup+klow)
    case(2)
      kmean=(dzup*kup+dzlow*klow)/(dzup+dzlow)
    case(3)
      kmean=sqrt(kup*klow)
    case(4)
      kmean=kup**a1*klow**a2
    case(5)
      kmean=1.0_real64/(0.5_real64/kup+0.5_real64/klow)
    case(6)
      kmean=1.0_real64/(a1/kup+a2/klow)
    case default
      kmean=-huge(1.0_real64)
    end select
  end function oracle_hcomean

  pure logical function same_real_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  pure logical function all_same_real_bits(a, b) result(equal)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    equal = .false.
    if (size(a) /= size(b)) return
    do i = 1, size(a)
      if (.not. same_real_bits(a(i), b(i))) return
    end do
    equal = .true.
  end function all_same_real_bits

  subroutine require_close(actual, expected_value, code)
    real(real64), intent(in) :: actual, expected_value
    integer, intent(in) :: code
    real(real64) :: scale
    scale=max(1.0_real64,abs(actual),abs(expected_value))
    if (abs(actual-expected_value) > 8192.0_real64*epsilon(1.0_real64)*scale) then
      write(*,'(A,I0,2(1X,ES24.16))') 'FVQ53_NUMERIC_MISMATCH ', code, actual, expected_value
      error stop 53
    end if
  end subroutine require_close

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*,'(A,I0)') 'FVQ53_FAIL ', code
      error stop 53
    end if
  end subroutine require

end program test_fvq53_surface_evaporation_capacity_independent
