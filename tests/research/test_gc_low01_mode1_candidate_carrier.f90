program test_gc_low01_mode1_candidate_carrier
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_gc_low01_mode1_candidate_carrier, only: low01_mode1_candidate_t, &
       classify_low01_h_phreatic, materialize_low01_mode1_candidate, low01_branch_name, &
       LOW01_BRANCH_ABOVE_OR_AT_TOP, LOW01_BRANCH_INSIDE_PROFILE, LOW01_BRANCH_BELOW_PROFILE
  implicit none

  real(real64), parameter :: z(4)=[-25.0_real64,-75.0_real64,-150.0_real64,-250.0_real64]
  real(real64), parameter :: dz(4)=[50.0_real64,50.0_real64,100.0_real64,100.0_real64]
  real(real64) :: h(4), theta(4), eff, face, hbot
  integer :: branch, nn, i
  type(low01_mode1_candidate_t) :: a, b

  call check_case(-10.0_real64, LOW01_BRANCH_ABOVE_OR_AT_TOP, 0, -10.0_real64, 0.0_real64)
  call check_case(-60.0_real64, LOW01_BRANCH_INSIDE_PROFILE, 1, -60.0_real64, 0.0_real64)
  call check_case(-120.0_real64, LOW01_BRANCH_INSIDE_PROFILE, 2, -120.0_real64, 0.0_real64)
  call check_case(-200.0_real64, LOW01_BRANCH_INSIDE_PROFILE, 3, -200.0_real64, 0.0_real64)
  call check_case(-275.0_real64, LOW01_BRANCH_INSIDE_PROFILE, 4, -275.0_real64, 0.0_real64)
  call check_case(-150.00005_real64, LOW01_BRANCH_INSIDE_PROFILE, 2, -150.0_real64, 0.0_real64)
  call check_case(-149.99995_real64, LOW01_BRANCH_INSIDE_PROFILE, 2, -149.99995_real64, 0.0_real64)
  call check_case(-300.0_real64, LOW01_BRANCH_BELOW_PROFILE, 4, -300.0_real64, 0.0_real64)
  call check_case(-350.0_real64, LOW01_BRANCH_BELOW_PROFILE, 4, -350.0_real64, -50.0_real64)

  h=[-35.0_real64,15.0_real64,90.0_real64,190.0_real64]
  theta=[0.31_real64,0.32_real64,0.40_real64,0.41_real64]

  call materialize_low01_mode1_candidate(z,dz,-60.0_real64,-120.0_real64,.false.,1.25_real64,0.30_real64,h,theta,a)
  call materialize_low01_mode1_candidate(z,dz,-60.0_real64,-120.0_real64,.false.,1.25_real64,0.30_real64,h,theta,b)

  call require(a%branch==LOW01_BRANCH_INSIDE_PROFILE,'materialized inside branch')
  call require(a%active_richards_nodes==1,'materialized NN')
  call require(bits(a%groundwater_level_cm)==bits(-60.0_real64),'typed groundwater level is requested control')
  call require(bits(a%raw_legacy_groundwater_level_cm)==bits(-120.0_real64),'raw legacy gwl preserved separately')
  call require(bits(a%qbot_cm_per_day)==bits(1.25_real64),'qbot preserved')
  call require(bits(a%storage_change_cm)==bits(0.30_real64),'storage preserved')
  do i=1,4
    call require(bits(a%pressure_head_cm(i))==bits(h(i)),'head copied exactly')
    call require(bits(a%water_content(i))==bits(theta(i)),'water copied exactly')
  end do
  call require(candidates_bitwise_equal(a,b),'repeated materialization bitwise')
  call require(trim(low01_branch_name(a%branch))=='INSIDE_PROFILE','branch name')

  call materialize_low01_mode1_candidate(z,dz,-350.0_real64,-350.0_real64,.true.,-0.2_real64,0.0_real64,h,theta,a)
  call require(a%branch==LOW01_BRANCH_BELOW_PROFILE,'below materialized branch')
  call require(a%fllowgwl,'below typed fllowgwl')
  call require(bits(a%groundwater_level_cm)==bits(-350.0_real64),'below typed groundwater level')

  print '(A)','GC_LOW01_CARRIER_EXPLICIT_BOTTOM_FACE=PASS'
  print '(A)','GC_LOW01_CARRIER_BRANCH_CLASSIFICATION=PASS'
  print '(A)','GC_LOW01_CARRIER_NODE_SNAP=PASS'
  print '(A)','GC_LOW01_CARRIER_TYPED_GWL_SEPARATE_FROM_RAW=PASS'
  print '(A)','GC_LOW01_CARRIER_QBOT_AND_STATE_EXACT_COPY=PASS'
  print '(A)','GC_LOW01_CARRIER_BITWISE_REPLAY=PASS'
  print '(A)','GC_LOW01_CARRIER_GATE=PASS'

contains

  subroutine check_case(requested, expected_branch, expected_nn, expected_eff, expected_hbot)
    real(real64), intent(in) :: requested, expected_eff, expected_hbot
    integer, intent(in) :: expected_branch, expected_nn
    call classify_low01_h_phreatic(z,dz,requested,branch,nn,eff,face,hbot)
    call require(branch==expected_branch,'branch classification')
    call require(nn==expected_nn,'active node classification')
    call require(abs(face+300.0_real64)<=1.0e-14_real64,'explicit bottom face')
    call require(abs(eff-expected_eff)<=1.0e-10_real64,'effective H')
    call require(abs(hbot-expected_hbot)<=1.0e-10_real64,'derived hbot')
    write(*,'(A,ES24.16E3,A,A,A,I0,A,ES24.16E3,A,ES24.16E3)') &
      'GC_LOW01_CARRIER_CASE:H=',requested,':BRANCH=',trim(low01_branch_name(branch)),':NN=',nn, &
      ':EFFECTIVE=',eff,':HBOT=',hbot
  end subroutine check_case

  integer(int64) function bits(x)
    real(real64), intent(in) :: x
    bits=transfer(x,0_int64)
  end function bits

  logical function candidates_bitwise_equal(x,y)
    type(low01_mode1_candidate_t), intent(in) :: x,y
    integer :: k
    candidates_bitwise_equal=.false.
    if(x%branch/=y%branch .or. x%active_richards_nodes/=y%active_richards_nodes) return
    if(x%fllowgwl .neqv. y%fllowgwl) return
    if(bits(x%requested_h_phreatic_cm)/=bits(y%requested_h_phreatic_cm)) return
    if(bits(x%effective_h_phreatic_cm)/=bits(y%effective_h_phreatic_cm)) return
    if(bits(x%groundwater_level_cm)/=bits(y%groundwater_level_cm)) return
    if(bits(x%raw_legacy_groundwater_level_cm)/=bits(y%raw_legacy_groundwater_level_cm)) return
    if(bits(x%qbot_cm_per_day)/=bits(y%qbot_cm_per_day)) return
    if(bits(x%storage_change_cm)/=bits(y%storage_change_cm)) return
    do k=1,size(x%pressure_head_cm)
      if(bits(x%pressure_head_cm(k))/=bits(y%pressure_head_cm(k))) return
      if(bits(x%water_content(k))/=bits(y%water_content(k))) return
    end do
    candidates_bitwise_equal=.true.
  end function candidates_bitwise_equal

  subroutine require(ok,msg)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: msg
    if(.not.ok) then
      write(*,'(A,1X,A)') 'GC_LOW01_CARRIER_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_gc_low01_mode1_candidate_carrier
