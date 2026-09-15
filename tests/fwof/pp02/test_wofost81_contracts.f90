program test_wofost81_contracts
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use MOD_wofost81_nitrogen, only: WOFOST81_n_param
  use mod_wofost81_parameter_contract
  use mod_wofost81_n_owner_state
  implicit none

  type(wofost81_parameter_contract_t) :: p
  type(wofost81_n_owner_state_t) :: owner
  type(WOFOST81_n_param) :: donor
  class(transaction_state_t), allocatable :: cloned
  integer :: status

  p%assimilation%amax_lnb = 0.0_real64
  p%assimilation%amax_ref = 35.0_real64
  p%assimilation%amax_slp = 3.24_real64
  p%assimilation%kn = 0.4_real64
  p%nitrogen%nmaxst_fr = 0.5_real64
  p%nitrogen%nmaxrt_fr = 0.5_real64
  p%nitrogen%nmaxso = 0.0176_real64
  p%nitrogen%nresidlv = 0.004_real64
  p%nitrogen%nresidst = 0.002_real64
  p%nitrogen%nresidrt = 0.002_real64
  p%nitrogen%tcnt = 10.0_real64
  p%nitrogen%nfix_fr = 0.2_real64
  p%nitrogen%rnuptakemax = 4.26_real64
  p%nitrogen%dvs_n_transl = 0.8_real64
  p%nitrogen%rgrlai_min = 0.004_real64

  call check(p%validate() == WOFOST81_PARAMETER_OK, 'valid parameter contract')
  donor = p%nitrogen%donor_view()
  call check(abs(donor%nmaxst_fr - p%nitrogen%nmaxst_fr) < 1e-15_real64, 'donor nmaxst')
  call check(abs(donor%nmaxrt_fr - p%nitrogen%nmaxrt_fr) < 1e-15_real64, 'donor nmaxrt')
  call check(abs(donor%nfix_fr - p%nitrogen%nfix_fr) < 1e-15_real64, 'donor nfix')
  call check(abs(donor%rnuptakemax - p%nitrogen%rnuptakemax) < 1e-15_real64, 'donor max uptake')

  call initialize_wofost81_n_owner_state(1000.0_real64, 800.0_real64, 600.0_real64, 0.03_real64, &
                                          p%nitrogen, owner, status)
  call check(status == WOFOST81_N_OWNER_OK, 'owner initialization')
  call check(abs(owner%value%namountlv - 30.0_real64) < 1e-12_real64, 'leaf N initialization')
  call check(abs(owner%value%namountst - 12.0_real64) < 1e-12_real64, 'stem N initialization')
  call check(abs(owner%value%namountrt - 9.0_real64) < 1e-12_real64, 'root N initialization')
  call check(owner%validate() == WOFOST81_N_OWNER_OK, 'owner validation')

  call owner%clone(cloned)
  select type (copy => cloned)
  type is (wofost81_n_owner_state_t)
    call check(abs(copy%value%namountlv - owner%value%namountlv) < 1e-15_real64, 'clone leaf N')
    copy%value%namountlv = copy%value%namountlv + 1.0_real64
    call check(abs(copy%value%namountlv - owner%value%namountlv) > 0.5_real64, 'clone independence')
  class default
    error stop 'unexpected clone dynamic type'
  end select

  owner%value%namountlv = owner%value%namountlv + 1.0_real64
  call check(owner%validate() == WOFOST81_N_OWNER_BALANCE_FAILURE, 'balance corruption rejected')
  owner%value%namountlv = owner%value%namountlv - 1.0_real64

  p%assimilation%kn = 0.0_real64
  call check(p%validate() == WOFOST81_PARAMETER_INVALID_ASSIMILATION, 'invalid KN rejected')
  p%assimilation%kn = 0.4_real64
  p%nitrogen%nfix_fr = 1.1_real64
  call check(p%validate() == WOFOST81_PARAMETER_INVALID_NITROGEN, 'invalid fixation fraction rejected')
  p%nitrogen%nfix_fr = 0.2_real64
  p%nitrogen%tcnt = 0.0_real64
  call check(p%validate() == WOFOST81_PARAMETER_INVALID_NITROGEN, 'zero translocation time rejected')

  print '(A)', 'F_WOF_PP02_CONTRACT_STATE_PASS'
contains
  subroutine check(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(A)', trim(label)//' failed'
      error stop 1
    end if
  end subroutine check
end program test_wofost81_contracts
