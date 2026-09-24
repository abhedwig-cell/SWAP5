program test_ppa_irr_water_deficit_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_water_deficit
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  implicit none

  integer, parameter :: max_nodes = 24, layer_count = 5, vector_count = 100000
  integer :: layer(max_nodes), noddrz, i, node, status
  real(real64) :: dz(max_nodes), ztopcp(max_nodes), wclos(layer_count), wcmes(layer_count)
  real(real64) :: wchis(layer_count), wcac(max_nodes), rd
  real(real64) :: actual_awlh, actual_awmh, actual_awah, actual_cdef
  real(real64) :: expected_awlh, expected_awmh, expected_awah, expected_cdef
  real(real64) :: unit_value, lower_value, middle_value, high_value, active_fraction
  integer(int64) :: random_state

  random_state = 20260923_int64
  do i = 1, vector_count
    noddrz = 1 + modulo(i-1, max_nodes)
    do node = 1, noddrz
      call random_unit(random_state, unit_value)
      layer(node) = 1 + modulo(int(unit_value*1000000.0_real64), layer_count)
      call random_unit(random_state, unit_value)
      dz(node) = 0.01_real64 + 0.49_real64*unit_value
      call random_unit(random_state, unit_value)
      ztopcp(node) = dz(node)*unit_value
      call random_unit(random_state, unit_value)
      wcac(node) = 0.05_real64 + 0.55_real64*unit_value
    end do
    do node = 1, layer_count
      call random_unit(random_state, unit_value)
      lower_value = 0.05_real64 + 0.2_real64*unit_value
      call random_unit(random_state, unit_value)
      middle_value = lower_value + 0.1_real64 + 0.2_real64*unit_value
      call random_unit(random_state, unit_value)
      high_value = middle_value + 0.1_real64 + 0.2_real64*unit_value
      wclos(node) = lower_value
      wcmes(node) = middle_value
      wchis(node) = high_value
    end do
    call random_unit(random_state, unit_value)
    active_fraction = (1.0_real64 - ztopcp(noddrz)/dz(noddrz))*unit_value
    rd = dz(noddrz)*active_fraction

    call source_accounting(noddrz, layer, dz, ztopcp, rd, wclos, wcmes, wchis, wcac, &
                           expected_awlh, expected_awmh, expected_awah, expected_cdef)
    call evaluate_root_zone_water_deficit(noddrz, layer, dz, ztopcp, rd, wclos, wcmes, wchis, wcac, &
                                          actual_awlh, actual_awmh, actual_awah, actual_cdef)
    call require(transfer(actual_awlh, 0_int64) == transfer(expected_awlh, 0_int64), 1)
    call require(transfer(actual_awmh, 0_int64) == transfer(expected_awmh, 0_int64), 2)
    call require(transfer(actual_awah, 0_int64) == transfer(expected_awah, 0_int64), 3)
    call require(transfer(actual_cdef, 0_int64) == transfer(expected_cdef, 0_int64), 4)
    call evaluate_root_zone_water_deficit_checked(noddrz, layer, dz, ztopcp, rd, wclos, wcmes, wchis, wcac, &
         actual_awlh, actual_awmh, actual_awah, actual_cdef, status)
    call require(status==IRR_DEFICIT_OK,5)
    call require(transfer(actual_awlh,0_int64)==transfer(expected_awlh,0_int64),6)
    call require(transfer(actual_awmh,0_int64)==transfer(expected_awmh,0_int64),7)
    call require(transfer(actual_awah,0_int64)==transfer(expected_awah,0_int64),8)
    call require(transfer(actual_cdef,0_int64)==transfer(expected_cdef,0_int64),9)
  end do

  do i=1,12
    noddrz=1; layer=1; dz=1.0_real64; ztopcp=0.0_real64; rd=0.5_real64
    wclos=0.3_real64; wcmes=0.2_real64; wchis=0.1_real64; wcac=0.2_real64
    select case(i)
    case(1); noddrz=0
    case(2); noddrz=max_nodes+1
    case(3); layer(1)=0
    case(4); layer(1)=layer_count+1
    case(5); dz(1)=0.0_real64
    case(6); rd=2.0_real64
    case(7); ztopcp(1)=-1.0_real64
    case(8); wcac(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    case(9); wclos(1)=1.1_real64
    case(10); dz(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    case(11); rd=ieee_value(0.0_real64,ieee_quiet_nan)
    case(12); dz(1)=1.0e6_real64+1.0_real64
    end select
    call evaluate_root_zone_water_deficit_checked(noddrz,layer,dz,ztopcp,rd,wclos,wcmes,wchis,wcac, &
         actual_awlh,actual_awmh,actual_awah,actual_cdef,status)
    call require(status==IRR_DEFICIT_INVALID_INPUT,10)
    call require(abs(actual_awlh)+abs(actual_awmh)+abs(actual_awah)+abs(actual_cdef)<tiny(1.0_real64),11)
  end do
  print '(A)', 'PPA_IRR_DEFICIT_CHECKED_SOURCE_AND_GUARDS=PASS'

  print '(A)', 'PPA_IRR_ROOT_ZONE_WATER_ACCOUNTING_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_FRACTIONAL_LAST_NODE_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_IRR_WATER_DEFICIT_SOURCE_ORACLE=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine source_accounting(last_node, node_layer, thickness, top_compartment, root_depth, &
                               lower_content, middle_content, upper_content, actual_content, &
                               lower_available, middle_available, actual_available, deficit)
    integer, intent(in) :: last_node, node_layer(:)
    real(real64), intent(in) :: thickness(:), top_compartment(:), root_depth
    real(real64), intent(in) :: lower_content(:), middle_content(:), upper_content(:), actual_content(:)
    real(real64), intent(out) :: lower_available, middle_available, actual_available, deficit
    real(real64) :: fraction, lower, middle, upper, actual
    integer :: k

    fraction = (top_compartment(last_node)+root_depth)/thickness(last_node)
    lower_available = 0.0_real64
    middle_available = 0.0_real64
    actual_available = 0.0_real64
    deficit = 0.0_real64
    do k = 1, last_node
      lower = lower_content(node_layer(k))*thickness(k)
      if (k == last_node) lower = lower*fraction
      middle = middle_content(node_layer(k))*thickness(k)
      if (k == last_node) middle = middle*fraction
      upper = upper_content(node_layer(k))*thickness(k)
      if (k == last_node) upper = upper*fraction
      actual = actual_content(k)*thickness(k)
      if (k == last_node) actual = actual*fraction
      lower_available = lower_available+(lower-upper)
      middle_available = middle_available+(middle-upper)
      actual_available = actual_available+(actual-upper)
      deficit = deficit+(lower-actual)
    end do
  end subroutine source_accounting

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_WATER_DEFICIT_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_water_deficit_source_oracle
