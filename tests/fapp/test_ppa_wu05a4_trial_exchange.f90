program test_trial_exchange
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_ppa_wu05a4_trial_exchange
  implicit none
  type(macro_exchange_evaluation) :: e
  type(macro_used_exchange) :: slot
  type(macro_trial_key) :: key, wrong
  real(real64) :: residual(3), diagonal(3), head(3), expected(3)
  real(real64), allocatable :: amount(:)
  logical :: ok
  integer :: i
  key = macro_trial_key(7_int64,2_int64,1_int64,1_int64)
  e%key = key
  e%dt = 0.25_real64
  e%head = [-10.0_real64,0.0_real64,2.0_real64]
  e%rate = [0.25_real64,-0.5_real64,0.125_real64]
  e%derivative = [0.125_real64,-0.25_real64,0.0_real64]
  head = e%head
  do i=1,512
    key%evaluation = int(i,int64)
    e%key = key
    e%rate = [real(i,real64)/1024,-real(i,real64)/512,0.125_real64]
    expected = 1.0_real64-e%rate
    residual = 1
    call apply_macro_residual(e,key,head,residual,slot,ok)
    call require(ok .and. all(abs(residual-expected) < tiny(1.0_real64)),'source residual subtraction')
    diagonal = 2
    call apply_macro_diagonal(slot,key,.true.,diagonal,ok)
    call require(ok .and. all(abs(diagonal-(2-e%derivative)) < tiny(1.0_real64)),'source diagonal subtraction')
    call copy_matrix_transfer(slot,key,amount,ok)
    call require(ok,'transfer available')
    call require(all(abs(amount-e%rate*e%dt) < tiny(1.0_real64)),'used integrated transfer')
  end do
  print '(a)', 'PPA_WU05A4_EXCHANGE_RESIDUAL_DIAGONAL_512=PASS'
  expected = amount
  e%rate = 99
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(ok,'copy retained')
  call require(all(abs(amount-expected) < tiny(1.0_real64)),'input cannot mutate used transfer')
  diagonal = 2
  call apply_macro_diagonal(slot,key,.false.,diagonal,ok)
  call require(ok .and. all(abs(diagonal-2) < tiny(1.0_real64)),'source disabled derivative')
  wrong = key
  wrong%attempt = 2
  call copy_matrix_transfer(slot,wrong,amount,ok)
  call require(.not. ok .and. .not. allocated(amount),'foreign attempt')
  wrong = key
  wrong%evaluation = 1
  call copy_matrix_transfer(slot,wrong,amount,ok)
  call require(.not. ok,'old evaluation')
  wrong = key
  wrong%revision = 3
  call copy_matrix_transfer(slot,wrong,amount,ok)
  call require(.not. ok,'foreign revision')
  wrong = key
  wrong%lineage = 8
  call copy_matrix_transfer(slot,wrong,amount,ok)
  call require(.not. ok,'foreign lineage')
  diagonal = 2
  call apply_macro_diagonal(slot,wrong,.true.,diagonal,ok)
  call require(.not. ok .and. all(abs(diagonal-2) < tiny(1.0_real64)),'foreign diagonal unchanged')
  print '(a)', 'PPA_WU05A4_EXCHANGE_USED_VECTOR_IDENTITY=PASS'
  residual = 1
  head(1) = -9
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(.not. ok .and. all(abs(residual-1) < tiny(1.0_real64)),'head mismatch unchanged')
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(.not. ok,'failed trial invalidates scratch')
  head = e%head
  e%rate(1) = ieee_value(0.0_real64,ieee_quiet_nan)
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(.not. ok,'nonfinite rejection')
  e%rate = 0.25_real64
  key%attempt = 2
  e%key = key
  e%dt = 0.125_real64
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(ok,'changed dt retry')
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(ok,'retry amount')
  call require(all(abs(amount-0.03125_real64) < tiny(1.0_real64)),'retry uses new dt')
  call discard_macro_exchange(slot)
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(.not. ok,'discard no receipt')
  e%rate = -huge(1.0_real64)
  residual = huge(1.0_real64)
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(.not. ok,'subtraction overflow rejected before arithmetic')
  e%head(1) = huge(1.0_real64)
  head(1) = -huge(1.0_real64)
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(.not. ok,'extreme head mismatch without subtraction overflow')
  head = e%head
  e%rate = 0
  e%derivative = -huge(1.0_real64)
  residual = 0
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(ok,'finite extreme derivative captured')
  diagonal = huge(1.0_real64)
  call apply_macro_diagonal(slot,key,.true.,diagonal,ok)
  call require(.not. ok,'diagonal overflow rejection')
  e%dt = 2
  e%rate = huge(1.0_real64)
  e%derivative = 0
  residual = 0
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(ok,'finite extreme rate captured')
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(.not. ok .and. .not. allocated(amount),'integrated transfer overflow rejection')
  e%rate = [0.0_real64]
  residual = 1
  call apply_macro_residual(e,key,head,residual,slot,ok)
  call require(.not. ok .and. all(abs(residual-1) < tiny(1.0_real64)),'shape rejection atomic')
  call copy_matrix_transfer(slot,key,amount,ok)
  call require(.not. ok,'bad shape invalidates old scratch')
  print '(a)', 'PPA_WU05A4_EXCHANGE_RETRY_INVALIDATION=PASS'
contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(*), intent(in) :: label
    if (.not. condition) then
      print *, label
      error stop 1
    end if
  end subroutine
end program
