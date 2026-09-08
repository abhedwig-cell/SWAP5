program test_fwof11_root_uptake_crop_input_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, crop_root_uptake_input_provider_t, &
       canonicalize_crop_root_uptake_input, validate_crop_root_uptake_input, evaluate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK, CROP_ROOT_INPUT_INVALID_ACTIVE_NODES, CROP_ROOT_INPUT_NONFINITE_PTRA, &
       CROP_ROOT_INPUT_NEGATIVE_PTRA, CROP_ROOT_INPUT_ROOTED_NODES_RANGE, CROP_ROOT_INPUT_DISTRIBUTION_MISSING, &
       CROP_ROOT_INPUT_DISTRIBUTION_SIZE, CROP_ROOT_INPUT_DISTRIBUTION_INVALID, &
       CROP_ROOT_INPUT_PROVIDER_REJECTED, CROP_ROOT_INPUT_NOT_CANONICAL
  implicit none

  type, extends(crop_root_uptake_input_provider_t) :: mock_provider_t
    integer :: mode = 0
  contains
    procedure :: evaluate => mock_evaluate
  end type mock_provider_t

  type(crop_root_uptake_input_t) :: raw, got
  type(mock_provider_t) :: provider
  integer :: status, provider_status
  real(real64) :: nan_value

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  call canonicalize_crop_root_uptake_input(raw, 0, got, status)
  call require(status == CROP_ROOT_INPUT_INVALID_ACTIVE_NODES, 'active_nodes <= 0 fails closed')

  raw = crop_root_uptake_input_t()
  raw%crop_emerged = .false.
  raw%potential_transpiration = -99.0_real64
  raw%rooted_nodes = 99
  allocate(raw%cumulative_root_fraction(2))
  raw%cumulative_root_fraction = [nan_value, -7.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 4, got, status)
  call require(status == CROP_ROOT_INPUT_OK, 'inactive crop canonicalizes without stale dependency')
  call require(.not. got%crop_emerged, 'inactive crop remains inactive')
  call require(abs(got%potential_transpiration) <= tiny(1.0_real64), 'inactive ptra canonical zero')
  call require(got%rooted_nodes == 0, 'inactive rooted_nodes canonical zero')
  call require(.not. allocated(got%cumulative_root_fraction), 'inactive distribution unallocated')
  call validate_crop_root_uptake_input(raw, 4, status)
  call require(status == CROP_ROOT_INPUT_NOT_CANONICAL, 'stale inactive input rejected as noncanonical')
  print '(a)', 'FWOF11_INACTIVE_CROP_CANONICALIZATION=PASS'

  raw = crop_root_uptake_input_t()
  raw%crop_emerged = .true.
  raw%potential_transpiration = 0.0_real64
  raw%rooted_nodes = 0
  allocate(raw%cumulative_root_fraction(2))
  raw%cumulative_root_fraction = [0.0_real64, 1.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 4, got, status)
  call require(status == CROP_ROOT_INPUT_OK, 'active zero-root canonicalization accepted')
  call require(got%crop_emerged .and. got%rooted_nodes == 0, 'active zero-root identity')
  call require(.not. allocated(got%cumulative_root_fraction), 'active zero-root distribution stripped')
  call validate_crop_root_uptake_input(raw, 4, status)
  call require(status == CROP_ROOT_INPUT_NOT_CANONICAL, 'active zero-root stale distribution is noncanonical')
  call validate_crop_root_uptake_input(got, 4, status)
  call require(status == CROP_ROOT_INPUT_OK, 'canonical active zero-root validates')
  print '(a)', 'FWOF11_ACTIVE_ZERO_ROOT_CANONICALIZATION=PASS'

  raw = crop_root_uptake_input_t()
  raw%crop_emerged = .true.
  raw%potential_transpiration = 0.24_real64
  raw%rooted_nodes = 3
  allocate(raw%cumulative_root_fraction(4))
  raw%cumulative_root_fraction = [0.0_real64, 0.20_real64, 0.65_real64, 1.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_OK, 'valid rooted input canonicalizes')
  call require(got%crop_emerged, 'valid rooted crop emerged')
  call require(abs(got%potential_transpiration - 0.24_real64) < 1.0e-15_real64, 'valid rooted ptra preserved')
  call require(got%rooted_nodes == 3, 'valid rooted node count preserved')
  call require(allocated(got%cumulative_root_fraction), 'valid rooted distribution allocated')
  call require(maxval(abs(got%cumulative_root_fraction - [0.0_real64, 0.20_real64, 0.65_real64, 1.0_real64])) < &
       1.0e-15_real64, 'valid rooted distribution preserved')
  call validate_crop_root_uptake_input(got, 5, status)
  call require(status == CROP_ROOT_INPUT_OK, 'valid rooted canonical input validates')
  print '(a)', 'FWOF11_ACTIVE_ROOTED_NORMALIZED_DISTRIBUTION=PASS'

  raw%potential_transpiration = nan_value
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_NONFINITE_PTRA, 'nonfinite ptra fails closed')

  raw%potential_transpiration = -0.01_real64
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_NEGATIVE_PTRA, 'negative ptra fails closed')

  raw%potential_transpiration = 0.24_real64
  raw%rooted_nodes = 6
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_ROOTED_NODES_RANGE, 'rooted node overflow fails closed')

  raw = crop_root_uptake_input_t()
  raw%crop_emerged = .true.
  raw%potential_transpiration = 0.24_real64
  raw%rooted_nodes = 2
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_MISSING, 'missing distribution fails closed')

  allocate(raw%cumulative_root_fraction(2))
  raw%cumulative_root_fraction = [0.0_real64, 1.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_SIZE, 'malformed distribution size fails closed')

  deallocate(raw%cumulative_root_fraction)
  allocate(raw%cumulative_root_fraction(3))
  raw%cumulative_root_fraction = [0.0_real64, nan_value, 1.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_INVALID, 'nonfinite distribution fails closed')

  raw%cumulative_root_fraction = [0.02_real64, 0.5_real64, 1.0_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_INVALID, 'nonzero first cumulative fraction fails closed')

  raw%cumulative_root_fraction = [0.0_real64, 0.5_real64, 0.98_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_INVALID, 'nonunit last cumulative fraction fails closed')

  raw%cumulative_root_fraction = [0.0_real64, 0.7_real64, 0.6_real64]
  call canonicalize_crop_root_uptake_input(raw, 5, got, status)
  call require(status == CROP_ROOT_INPUT_DISTRIBUTION_INVALID, 'nonmonotone distribution fails closed')
  print '(a)', 'FWOF11_INVALID_INPUTS_FAIL_CLOSED=PASS'

  provider%mode = 1
  call evaluate_crop_root_uptake_input(provider, 5, got, status, provider_status)
  call require(provider_status == CROP_ROOT_INPUT_OK, 'provider success status preserved')
  call require(status == CROP_ROOT_INPUT_OK, 'provider output accepted')
  call require(got%crop_emerged .and. got%rooted_nodes == 2, 'provider active crop mapped')
  call require(abs(got%potential_transpiration - 0.18_real64) < 1.0e-15_real64, 'provider ptra mapped')
  call require(maxval(abs(got%cumulative_root_fraction - [0.0_real64, 0.4_real64, 1.0_real64])) < &
       1.0e-15_real64, 'provider root distribution mapped')

  provider%mode = 2
  call evaluate_crop_root_uptake_input(provider, 5, got, status, provider_status)
  call require(provider_status == CROP_ROOT_INPUT_OK, 'inactive provider success status preserved')
  call require(status == CROP_ROOT_INPUT_OK, 'inactive provider canonicalization accepted')
  call require(.not. got%crop_emerged .and. got%rooted_nodes == 0, 'inactive provider canonicalized')
  call require(.not. allocated(got%cumulative_root_fraction), 'inactive provider stale distribution removed')

  provider%mode = 3
  call evaluate_crop_root_uptake_input(provider, 5, got, status, provider_status)
  call require(provider_status == 73, 'provider failure detail preserved')
  call require(status == CROP_ROOT_INPUT_PROVIDER_REJECTED, 'provider failure mapped fail closed')
  print '(a)', 'FWOF11_PROVIDER_INTERFACE_STATUS_AND_CANONICALIZATION=PASS'

  print '(a)', 'FWOF11_RUNTIME_AND_SOLVER_INDEPENDENT_CONTRACT=PASS'
  print '(a)', 'FWOF11_ROOT_UPTAKE_CROP_INPUT_CONTRACT_TEST PASS'

contains

  subroutine mock_evaluate(self, raw_input, provider_status)
    class(mock_provider_t), intent(in) :: self
    type(crop_root_uptake_input_t), intent(out) :: raw_input
    integer, intent(out) :: provider_status

    raw_input = crop_root_uptake_input_t()
    provider_status = CROP_ROOT_INPUT_OK

    select case (self%mode)
    case (1)
      raw_input%crop_emerged = .true.
      raw_input%potential_transpiration = 0.18_real64
      raw_input%rooted_nodes = 2
      allocate(raw_input%cumulative_root_fraction(3))
      raw_input%cumulative_root_fraction = [0.0_real64, 0.4_real64, 1.0_real64]
    case (2)
      raw_input%crop_emerged = .false.
      raw_input%potential_transpiration = -999.0_real64
      raw_input%rooted_nodes = 99
      allocate(raw_input%cumulative_root_fraction(2))
      raw_input%cumulative_root_fraction = [-1.0_real64, 9.0_real64]
    case default
      provider_status = 73
    end select
  end subroutine mock_evaluate

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message

    if (.not. condition) then
      write(*, '(a)') 'FWOF11_FAIL: ' // trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof11_root_uptake_crop_input_contract
