program test_fahl_p01_selection_policy
  use mod_fmr_adaptive_hydraulic_policy, only: &
       FMR_AHL_ROUTE_ANALYTICAL, FMR_AHL_ROUTE_ADAPTIVE_DEFAULT_MVG, &
       select_fmr_adaptive_hydraulic_route
  implicit none

  call require(select_fmr_adaptive_hydraulic_route(5,0,.false.,.true.) == &
       FMR_AHL_ROUTE_ADAPTIVE_DEFAULT_MVG, 'qualified default MvG prescribed-head route')

  call require(select_fmr_adaptive_hydraulic_route(2,0,.false.,.true.) == &
       FMR_AHL_ROUTE_ANALYTICAL, 'prescribed qbot must remain analytical')

  call require(select_fmr_adaptive_hydraulic_route(5,1,.false.,.true.) == &
       FMR_AHL_ROUTE_ANALYTICAL, 'SWKIMPL=1 must remain analytical')

  call require(select_fmr_adaptive_hydraulic_route(5,0,.true.,.true.) == &
       FMR_AHL_ROUTE_ANALYTICAL, 'KSATEXM must remain analytical')

  call require(select_fmr_adaptive_hydraulic_route(5,0,.false.,.false.) == &
       FMR_AHL_ROUTE_ANALYTICAL, 'non-default hydraulic family must remain analytical')

  call require(select_fmr_adaptive_hydraulic_route(7,0,.false.,.true.) == &
       FMR_AHL_ROUTE_ANALYTICAL, 'unqualified lower-boundary mode must remain analytical')

  write(*,'(A)') 'F_AHL_P01_SELECTION_POLICY=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A,1X,A)') 'F_AHL_P01_SELECTION_POLICY_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fahl_p01_selection_policy
