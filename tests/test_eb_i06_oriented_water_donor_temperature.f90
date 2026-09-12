program test_eb_i06_oriented_water_donor_temperature
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_oriented_water_donor_temperature, only: &
       OWDT_OK, OWDT_INVALID_TRANSFER, OWDT_DONOR_UNAVAILABLE, OWDT_INVALID_DONOR_TEMPERATURE, &
       OWDT_NO_DONOR, OWDT_ENDPOINT_A, OWDT_ENDPOINT_B, oriented_water_donor_temperature_result_t, &
       select_oriented_water_donor_temperature
  implicit none

  type(oriented_water_donor_temperature_result_t) :: positive, negative, zero, missing, reversed, tiny, invalid
  real(real64) :: nan_value
  real(real64), parameter :: tol = 0.0_real64

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)

  call select_oriented_water_donor_temperature(0.50_real64, 12.0_real64, .true., &
       8.0_real64, .true., positive)
  if (positive%status /= OWDT_OK) error stop 'EB-I06 positive transfer failed'
  if (.not. positive%transport_present .or. .not. positive%donor_temperature_available) &
       error stop 'EB-I06 positive donor not materialized'
  if (positive%donor_endpoint /= OWDT_ENDPOINT_A) error stop 'EB-I06 positive donor endpoint mismatch'
  if (abs(positive%donor_temperature_c - 12.0_real64) > tol) error stop 'EB-I06 positive donor temperature mismatch'
  if (positive%oriented_water_amount_cm /= 0.50_real64) error stop 'EB-I06 positive amount altered'

  call select_oriented_water_donor_temperature(-0.25_real64, 12.0_real64, .true., &
       8.0_real64, .true., negative)
  if (negative%status /= OWDT_OK) error stop 'EB-I06 negative transfer failed'
  if (negative%donor_endpoint /= OWDT_ENDPOINT_B) error stop 'EB-I06 negative donor endpoint mismatch'
  if (negative%donor_temperature_c /= 8.0_real64) error stop 'EB-I06 negative donor temperature mismatch'
  if (negative%oriented_water_amount_cm /= -0.25_real64) error stop 'EB-I06 negative amount altered'

  ! Exact zero transport has zero carried energy and therefore does not require
  ! either endpoint temperature to be available or finite.
  call select_oriented_water_donor_temperature(0.0_real64, nan_value, .false., &
       nan_value, .false., zero)
  if (zero%status /= OWDT_OK) error stop 'EB-I06 exact zero transfer rejected'
  if (zero%transport_present .or. zero%donor_temperature_available) error stop 'EB-I06 zero transfer has donor'
  if (zero%donor_endpoint /= OWDT_NO_DONOR) error stop 'EB-I06 zero donor endpoint mismatch'

  ! Only the donor implied by the actual direction is required.  The unused
  ! endpoint may be unavailable without blocking a valid transfer.
  call select_oriented_water_donor_temperature(0.50_real64, 12.0_real64, .true., &
       nan_value, .false., positive)
  if (positive%status /= OWDT_OK .or. positive%donor_temperature_c /= 12.0_real64) &
       error stop 'EB-I06 irrelevant missing endpoint blocked positive transfer'
  call select_oriented_water_donor_temperature(-0.25_real64, nan_value, .false., &
       8.0_real64, .true., negative)
  if (negative%status /= OWDT_OK .or. negative%donor_temperature_c /= 8.0_real64) &
       error stop 'EB-I06 irrelevant missing endpoint blocked negative transfer'

  call select_oriented_water_donor_temperature(0.50_real64, 0.0_real64, .false., &
       8.0_real64, .true., missing)
  if (missing%status /= OWDT_DONOR_UNAVAILABLE) error stop 'EB-I06 missing positive donor accepted'
  call select_oriented_water_donor_temperature(-0.25_real64, 12.0_real64, .true., &
       0.0_real64, .false., missing)
  if (missing%status /= OWDT_DONOR_UNAVAILABLE) error stop 'EB-I06 missing negative donor accepted'

  call select_oriented_water_donor_temperature(0.50_real64, nan_value, .true., &
       8.0_real64, .true., invalid)
  if (invalid%status /= OWDT_INVALID_DONOR_TEMPERATURE) error stop 'EB-I06 NaN selected donor accepted'
  call select_oriented_water_donor_temperature(nan_value, 12.0_real64, .true., &
       8.0_real64, .true., invalid)
  if (invalid%status /= OWDT_INVALID_TRANSFER) error stop 'EB-I06 NaN water amount accepted'

  ! Reversing the orientation and swapping endpoints must retain the same
  ! physical donor temperature.
  call select_oriented_water_donor_temperature(-0.50_real64, 8.0_real64, .true., &
       12.0_real64, .true., reversed)
  if (reversed%status /= OWDT_OK) error stop 'EB-I06 orientation reversal failed'
  if (reversed%donor_temperature_c /= positive%donor_temperature_c) &
       error stop 'EB-I06 orientation-reversal donor invariance failed'

  ! There is intentionally no small-flux tolerance: any nonzero transported
  ! water amount still needs a donor temperature for conservation accounting.
  call select_oriented_water_donor_temperature(tiny(1.0_real64), 0.0_real64, .false., &
       8.0_real64, .true., tiny)
  if (tiny%status /= OWDT_DONOR_UNAVAILABLE) error stop 'EB-I06 tiny positive transfer was silently zeroed'

  print '(a)', 'EB-I06 oriented water donor temperature: PASS'
end program test_eb_i06_oriented_water_donor_temperature
