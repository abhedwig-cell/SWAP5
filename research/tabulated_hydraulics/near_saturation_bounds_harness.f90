program near_saturation_bounds_harness
  use swap_array_dimensions, only: macp, matab, matabentries
  implicit none

  real(8) :: sptab(7,macp,matab)
  integer :: ientrytab(macp,0:matabentries)
  real(8) :: xe, ye, dyedxe

  sptab = 0.0d0
  ientrytab = 0

  ! The current ReadSwap preprocessing explicitly assigns this sentinel.
  ! EvalTabulatedFunction subsequently uses it as the third SPTAB index
  ! for sufficiently small negative pressure heads.
  ientrytab(1,1) = 0

  ! Minimal valid-looking first two knots. The failure under test occurs
  ! before their values can be used because KLO becomes zero.
  sptab(1,1,1) = -dlog(1.0d-4 + 1.0d0)
  sptab(2,1,1) = 0.40d0
  sptab(4,1,1) = 1.0d-3
  sptab(6,1,1) = 0.0d0
  sptab(1,1,2) = 0.0d0
  sptab(2,1,2) = 0.41d0
  sptab(4,1,2) = 1.0d-7
  sptab(6,1,2) = 0.0d0

  xe = -1.0d-6
  ye = -999.0d0
  dyedxe = -999.0d0

  call EvalTabulatedFunction(0, 2, 1, 2, 4, 1, sptab, ientrytab, xe, ye, dyedxe, 1)

  write(*,'(A,ES24.16)') 'UNEXPECTED_SUCCESS theta=', ye
end program near_saturation_bounds_harness
