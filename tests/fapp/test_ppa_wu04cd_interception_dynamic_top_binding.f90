program test_ppa_wu04cd_interception_dynamic_top_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t
  use mod_ppa_wu04c_vonhhbraden_forcing_adapter
  use mod_ppa_wu04d_gash_forcing_adapter
  implicit none
  type(vonhhbraden_source_window_t) :: source
  type(b110_dynamic_top_boundary_request_t) :: base, bound
  real(real64) :: interception, qnan
  integer :: status

  source%gross_rain_cm_per_day = 0.40_real64
  source%sprinkling_irrigation_cm_per_day = 0.20_real64
  source%leaf_area_index = 2.0_real64
  source%vegetation_cover_fraction = 0.5_real64
  base%precipitation_rate_cm_per_day = 9.0_real64
  base%irrigation_rate_cm_per_day = 8.0_real64
  call bind_ppa_wu04c_vonhhbraden_dynamic_top(base, source, 0.12_real64, 0.20_real64, 0.10_real64, bound, interception, status)
  call require(status == PPA_WU04C_BIND_OK .and. abs(interception - 0.06_real64) < 1.e-14_real64, 'C partition')
  call require(abs(bound%precipitation_rate_cm_per_day - 0.16_real64) < 1.e-14_real64 .and. &
       abs(bound%irrigation_rate_cm_per_day - 0.08_real64) < 1.e-14_real64, 'C net flux')
  call bind_ppa_wu04d_gash_dynamic_top(base, source, 0.12_real64, 0.20_real64, 0.10_real64, bound, interception, status)
  call require(status == PPA_WU04D_BIND_OK .and. abs(interception - 0.06_real64) < 1.e-14_real64, 'D partition')
  qnan = ieee_value(0.0_real64, ieee_quiet_nan)
  call bind_ppa_wu04d_gash_dynamic_top(base, source, qnan, 0.20_real64, 0.10_real64, bound, interception, status)
  call require(status == PPA_WU04D_BIND_REJECTED, 'D nonfinite fails closed')
  print '(a)', 'PPA_WU04CD_DYNAMIC_TOP_PARTITION=PASS'
  print '(a)', 'PPA_WU04D_DYNAMIC_TOP_NONFINITE_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, label)
    logical, intent(in) :: ok
    character(*), intent(in) :: label
    if (.not. ok) then; write(*,'(a)') trim(label); error stop 1; end if
  end subroutine require
end program test_ppa_wu04cd_interception_dynamic_top_binding
