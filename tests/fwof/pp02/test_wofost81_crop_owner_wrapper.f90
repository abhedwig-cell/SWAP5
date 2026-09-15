program test_wofost81_crop_owner_wrapper
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost81_parameter_contract, only: wofost81_nitrogen_parameters_t
  use mod_wofost81_n_owner_state, only: initialize_wofost81_n_owner_state, WOFOST81_N_OWNER_OK
  use mod_wofost81_crop_owner_state
  implicit none
  type(wofost81_crop_owner_state_t) :: owner
  type(wofost81_nitrogen_parameters_t) :: p
  class(transaction_state_t), allocatable :: cloned
  integer :: status

  p%nmaxst_fr=.5_real64; p%nmaxrt_fr=.5_real64; p%nmaxso=.0176_real64
  p%nresidlv=.004_real64; p%nresidst=.002_real64; p%nresidrt=.002_real64
  p%tcnt=10._real64; p%nfix_fr=.2_real64; p%rnuptakemax=4.26_real64; p%dvs_n_transl=.8_real64
  p%rgrlai_min=.004_real64
  call initialize_wofost81_n_owner_state(1000._real64,800._real64,600._real64,.03_real64,p,owner%nitrogen,status)
  call check(status == WOFOST81_N_OWNER_OK, 'N initialization')
  owner%crop%test_marker = 7
  call check(owner%validate() == WOFOST81_CROP_OWNER_OK, 'wrapper valid')

  call owner%clone(cloned)
  select type(copy => cloned)
  type is(wofost81_crop_owner_state_t)
    call check(copy%crop%test_marker == 7, 'crop clone')
    call check(abs(copy%nitrogen%value%namountlv-owner%nitrogen%value%namountlv)<1e-15_real64, 'N clone')
    copy%crop%test_marker = 8
    copy%nitrogen%value%namountlv = copy%nitrogen%value%namountlv + 1._real64
    call check(owner%crop%test_marker == 7, 'crop clone independent')
    call check(abs(copy%nitrogen%value%namountlv-owner%nitrogen%value%namountlv)>.5_real64, 'N clone independent')
  class default
    error stop 'unexpected wrapper clone type'
  end select

  owner%crop%test_marker = -1
  call check(owner%validate() == WOFOST81_CROP_OWNER_INVALID_CROP_STATE, 'invalid nested crop rejected')
  owner%crop%test_marker = 7
  owner%nitrogen%value%namountlv = owner%nitrogen%value%namountlv + 1._real64
  call check(owner%validate() == WOFOST81_CROP_OWNER_INVALID_N_STATE, 'invalid nested N rejected')

  print '(A)', 'F_WOF_PP02_WRAPPER_PASS'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      print '(A)',trim(label)//' failed'; error stop 1
    end if
  end subroutine
end program
