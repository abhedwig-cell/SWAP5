program test_ppa_wu05a3_mpvolume_candidate_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_mpvolume_candidate
  implicit none
  real(real64) :: subsidy,volume,expected_subsidy,expected_volume
  integer(int32) :: status

  call ppa_wu05a3_mpvolume_candidate(0.15_real64,0.45_real64,0.30_real64, &
      0.20_real64,2.0_real64,10.0_real64,0.90_real64,0.50_real64,subsidy,volume,status)
  call require(status==PPA_WU05A3_MPVOLUME_OK,1)
  expected_subsidy=max((1.0_real64-sqrt(0.80_real64))*10.0_real64,0.50_real64)
  expected_volume=0.90_real64*(2.0_real64-expected_subsidy)*10.0_real64/(10.0_real64-expected_subsidy)
  call require(abs(subsidy-expected_subsidy)<1.0e-12_real64,2)
  call require(abs(volume-expected_volume)<1.0e-12_real64 .and. volume>0.0_real64,3)

  call ppa_wu05a3_mpvolume_candidate(0.35_real64,0.45_real64,0.30_real64, &
      0.20_real64,2.0_real64,10.0_real64,0.90_real64,0.50_real64,subsidy,volume,status)
  call require(status==PPA_WU05A3_MPVOLUME_OK,4)
  call require(abs(subsidy-2.0_real64)<1.0e-12_real64 .and. abs(volume)<1.0e-12_real64,5)

  call ppa_wu05a3_mpvolume_candidate(0.15_real64,0.45_real64,0.30_real64, &
      0.05_real64,2.0_real64,10.0_real64,0.90_real64,1.0_real64,subsidy,volume,status)
  call require(status==PPA_WU05A3_MPVOLUME_OK,6)
  call require(abs(subsidy-0.5_real64)<1.0e-12_real64 .and. abs(volume)<1.0e-12_real64,7)

  call ppa_wu05a3_mpvolume_candidate(0.44995_real64,0.45_real64,0.30_real64, &
      0.20_real64,2.0_real64,10.0_real64,0.90_real64,0.50_real64,subsidy,volume,status)
  call require(status==PPA_WU05A3_MPVOLUME_OK,8)
  call require(abs(subsidy)<1.0e-12_real64 .and. abs(volume)<1.0e-12_real64,9)

  call ppa_wu05a3_mpvolume_candidate(0.15_real64,0.45_real64,0.30_real64, &
      0.20_real64,0.0_real64,10.0_real64,0.90_real64,0.50_real64,subsidy,volume,status)
  call require(status==PPA_WU05A3_MPVOLUME_INVALID,10)

  print '(A)','PPA_WU05A3_MPVOLUME_CANDIDATE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SHRINKAGE_GEOMETRY=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_CRITICAL_MOISTURE_BRANCH=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_MINIMUM_SUBSIDENCE_NEGATIVE_CANDIDATE_CORRECTION=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_NEAR_SATURATION_CUTOFF=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_INVALID_GEOMETRY_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MPVOLUME_CANDIDATE_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05a3_mpvolume_candidate_source_oracle
