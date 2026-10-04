program test_ppa_wu05d_compensation_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_uptake_compensation_contract
  implicit none
  type(root_compensation_request_t) :: req
  type(root_compensation_result_t) :: out1, out2
  real(real64) :: base(3)
  integer :: status

  base = [0.10_real64, 0.20_real64, 0.30_real64]
  req%potential_transpiration = 1.0_real64
  req%alpha_critical = 1.0_real64
  req%selected_stressor = ROOT_COMPENSATION_DROUGHT
  req%drought_reduction_total = 0.4_real64
  call evaluate_root_compensation_candidate(base, req, out1, status)
  call require(status == ROOT_COMPENSATION_OK, 'off status')
  call require(.not. out1%applied, 'alpha=1 must be exact off')
  call require(all(out1%root_extraction_sink == base), 'off sink preservation')

  req%alpha_critical = 0.7_real64
  call evaluate_root_compensation_candidate(base, req, out1, status)
  call require(status == ROOT_COMPENSATION_OK .and. out1%applied, 'drought compensation applies')
  call require(abs(sum(out1%root_extraction_sink)-out1%actual_uptake_total) < 1.0e-14_real64, 'sum identity')
  call require(out1%actual_uptake_total >= sum(base), 'compensation cannot reduce candidate')
  call require(out1%actual_uptake_total <= req%potential_transpiration, 'cannot exceed ptra')

  call evaluate_root_compensation_candidate(base, req, out2, status)
  call require(all(out1%root_extraction_sink == out2%root_extraction_sink), 'fresh replay deterministic')
  call require(out1%actual_uptake_total == out2%actual_uptake_total, 'fresh replay total deterministic')

  req%alpha_critical = 0.2_real64
  call evaluate_root_compensation_candidate(base, req, out1, status)
  call require(abs(out1%actual_uptake_total-req%potential_transpiration) < 1.0e-14_real64, 'full capacity reaches ptra')
  call require(abs(out1%drought_reduction_total) < 1.0e-14_real64, 'full compensation clears stress total')

  base = [0.001_real64, 0.001_real64, 0.001_real64]
  req%potential_transpiration = 1.0_real64
  req%alpha_critical = 0.7_real64
  req%drought_reduction_total = 0.997_real64
  call evaluate_root_compensation_candidate(base, req, out1, status)
  call require(.not. out1%applied, '95-percent stress guard')

  print *, 'PPA_WU05D_COMPENSATION_CONTRACT=PASS'
contains
  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print *, 'FAIL: ', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05d_compensation_contract
