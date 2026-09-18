program test_fvq127_fsi39_ksatexm_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, &
       initialize_b110_default_mvg_parameters, evaluate_b110_default_mvg_conductivity
  implicit none

  type(b110_default_mvg_parameters_t) :: old_route, legacy_extended
  real(real64) :: cof(24,2), k_old, k_new
  logical :: ok_old, ok_new
  integer :: node

  cof = 0.0_real64
  do node=1,2
    cof(1,node)=0.02_real64
    cof(2,node)=0.3870640000000001_real64
    cof(3,node)=22.76176_real64
    cof(4,node)=0.016083_real64
    cof(5,node)=2.4396619999999993_real64
    cof(6,node)=1.524418_real64
    cof(7,node)=0.3440119442305195_real64
    cof(8,node)=0.016083_real64
    cof(9,node)=0.0_real64
    cof(10,node)=227.61759999999998_real64
    cof(11,node)=0.9981816467911503_real64
    cof(12,node)=15.814441314772257_real64
  end do
  ! Node 2 explicitly has no legacy extension despite the same base MvG family.
  cof(10,2)=cof(3,2)

  call initialize_b110_default_mvg_parameters(old_route,cof)
  call initialize_b110_default_mvg_parameters(legacy_extended,cof,enable_ksatexm_extension=.true.)

  ! Exact Hupsel/B1.11 frozen oracle points for lower-layer node 1.
  call oracle(1, 1.0_real64, 22.76176_real64, 227.61759999999998_real64, 1)
  call oracle(1,-1.0_real64, k_old_expected=-1.0_real64, &
              k_new_expected=153.81975964948478_real64, code=10, compare_old=.false.)
  call oracle(1,-0.1_real64, k_old_expected=-1.0_real64, &
              k_new_expected=225.40884633282243_real64, code=20, compare_old=.false.)

  ! Per-node legacy activation remains cofgen(10)>cofgen(3), not a global rewrite.
  call evaluate_b110_default_mvg_conductivity(old_route,2,1.0_real64,k_old,ok_old)
  call evaluate_b110_default_mvg_conductivity(legacy_extended,2,1.0_real64,k_new,ok_new)
  call require(ok_old .and. ok_new .and. k_old==k_new .and. k_new==22.76176_real64,30)

  ! Below threshold, enabled and disabled routes are bit-identical.
  call evaluate_b110_default_mvg_conductivity(old_route,1,-5.0_real64,k_old,ok_old)
  call evaluate_b110_default_mvg_conductivity(legacy_extended,1,-5.0_real64,k_new,ok_new)
  call require(ok_old .and. ok_new .and. k_old==k_new,31)

  print '(A)','F_VQ127_EXACT_B111_ORACLE=PASS'
  print '(A)','F_VQ127_PER_NODE_ACTIVATION=PASS'
  print '(A)','F_VQ127_DEFAULT_ROUTE_PRESERVED=PASS'
  print '(A)','F_VQ127_BELOW_THRESHOLD_IDENTITY=PASS'

contains
  subroutine oracle(node,head,k_old_expected,k_new_expected,code,compare_old)
    integer,intent(in)::node,code
    real(real64),intent(in)::head,k_old_expected,k_new_expected
    logical,intent(in),optional::compare_old
    logical :: check_old
    real(real64),parameter :: tol=3.0e-11_real64
    check_old=.true.; if(present(compare_old)) check_old=compare_old
    call evaluate_b110_default_mvg_conductivity(old_route,node,head,k_old,ok_old)
    call evaluate_b110_default_mvg_conductivity(legacy_extended,node,head,k_new,ok_new)
    call require(ok_old .and. ok_new,code)
    if(check_old) call require(abs(k_old-k_old_expected)<tol,code+1)
    call require(abs(k_new-k_new_expected)<tol,code+2)
  end subroutine

  subroutine require(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(.not.condition) then
      write(*,'(A,I0)') 'F_VQ127_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_fvq127_fsi39_ksatexm_independent
