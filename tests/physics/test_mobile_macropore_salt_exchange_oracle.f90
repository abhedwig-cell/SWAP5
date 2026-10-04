program test_mobile_macropore_salt_exchange_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_solute_macropore_exchange, only: mobile_macro_salt_state_t, &
       mobile_macro_salt_transfer_t, transfer_mobile_macro_salt_trial, EXCHANGE_OK, &
       EXCHANGE_INVALID, EXCHANGE_DONOR_UNAVAILABLE
  implicit none
  type(mobile_macro_salt_state_t) :: accepted,candidate,reversed,rejected,dry_state
  type(mobile_macro_salt_transfer_t) :: receipt
  real(real64) :: matrix_water(1),macro_water(2,1),exchange(2,1),total_before
  integer :: status

  allocate(accepted%matrix_mass_mg_cm2(1),accepted%macro_mass_mg_cm2(2,1))
  accepted%matrix_mass_mg_cm2=[0.6_real64]
  accepted%macro_mass_mg_cm2(:,1)=[0.2_real64,1.0_real64]
  matrix_water=[2.0_real64]; macro_water(:,1)=[1.0_real64,2.0_real64]
  total_before=sum(accepted%matrix_mass_mg_cm2)+sum(accepted%macro_mass_mg_cm2)

  ! Unequal donor concentration: 0.1 cm from domain 1 at 0.2 mg/cm3.
  exchange(:,1)=[0.5_real64,0.0_real64]
  call transfer_mobile_macro_salt_trial(accepted,matrix_water,macro_water,exchange,0.2_real64,candidate,receipt,status)
  call require(status==EXCHANGE_OK,'macro-to-matrix exchange status')
  call require_close(candidate%matrix_mass_mg_cm2(1),0.62_real64,'macro donor mass')
  call require_close(candidate%macro_mass_mg_cm2(1,1),0.18_real64,'macro mass debit')
  call require_close(receipt%macro_to_matrix_mg_cm2(1),0.02_real64,'macro transfer receipt')
  call require_close(receipt%closure_error_mg_cm2,0.0_real64,'positive transfer closure')

  ! Reversal uses the newly accepted candidate's concentration, not stale C.
  matrix_water=[1.9_real64]; macro_water(:,1)=[1.1_real64,2.0_real64]
  exchange(:,1)=[-0.25_real64,0.0_real64]
  call transfer_mobile_macro_salt_trial(candidate,matrix_water,macro_water,exchange,0.2_real64,reversed,receipt,status)
  call require(status==EXCHANGE_OK,'matrix-to-macro reversal status')
  call require_close(receipt%matrix_to_macro_mg_cm2(1),0.05_real64*0.62_real64/1.9_real64, &
       'matrix donor concentration on reversal')
  call require_close(sum(reversed%matrix_mass_mg_cm2)+sum(reversed%macro_mass_mg_cm2),total_before, &
       'reversal total salt closure')

  ! Two macro donors may drain to the matrix at different concentrations.
  exchange(:,1)=[0.25_real64,0.5_real64]
  call transfer_mobile_macro_salt_trial(accepted,[2.0_real64],reshape([1.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,candidate,receipt,status)
  call require(status==EXCHANGE_OK,'multi-domain macro transfer status')
  call require_close(receipt%macro_to_matrix_mg_cm2(1),0.06_real64,'multi-domain transfer sum')

  ! Zero exchange is an identity and produces no transfer.
  exchange=0.0_real64
  call transfer_mobile_macro_salt_trial(accepted,[2.0_real64],reshape([1.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,candidate,receipt,status)
  call require(status==EXCHANGE_OK,'zero exchange status')
  call require(maxval(abs(candidate%matrix_mass_mg_cm2-accepted%matrix_mass_mg_cm2))<=tiny(1.0_real64), &
       'zero exchange matrix identity')
  call require(maxval(abs(candidate%macro_mass_mg_cm2-accepted%macro_mass_mg_cm2))<=tiny(1.0_real64), &
       'zero exchange macro identity')

  ! A dry or undersupplied donor rejects without publishing any candidate.
  exchange(:,1)=[0.5_real64,0.0_real64]
  call transfer_mobile_macro_salt_trial(accepted,[2.0_real64],reshape([0.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,rejected,receipt,status)
  call require(status==EXCHANGE_INVALID,'dry mobile salt state rejected')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'inconsistent dry candidate absent')
  dry_state=accepted
  dry_state%macro_mass_mg_cm2(1,1)=0.0_real64
  call transfer_mobile_macro_salt_trial(dry_state,[2.0_real64],reshape([0.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,rejected,receipt,status)
  call require(status==EXCHANGE_DONOR_UNAVAILABLE,'dry macro donor rejected')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'dry macro candidate absent')
  exchange(:,1)=[-11.0_real64,0.0_real64]
  call transfer_mobile_macro_salt_trial(accepted,[2.0_real64],reshape([1.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,rejected,receipt,status)
  call require(status==EXCHANGE_DONOR_UNAVAILABLE,'matrix water overdraw rejected')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'overdraw candidate absent')

  ! Aggregate outflow to two macropore domains cannot remove more than the
  ! shared matrix donor water or salt, even when each individual transfer fits.
  exchange(:,1)=[-0.6_real64,-0.6_real64]
  call transfer_mobile_macro_salt_trial(accepted,[1.0_real64],reshape([1.0_real64,1.0_real64],[2,1]), &
       exchange,1.0_real64,rejected,receipt,status)
  call require(status==EXCHANGE_DONOR_UNAVAILABLE,'aggregate matrix water donor rejected')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'aggregate water rejection has no candidate')
  exchange(:,1)=[ieee_value(0.0_real64,ieee_quiet_nan),0.0_real64]
  call transfer_mobile_macro_salt_trial(accepted,[2.0_real64],reshape([1.0_real64,2.0_real64],[2,1]), &
       exchange,0.2_real64,rejected,receipt,status)
  call require(status==EXCHANGE_INVALID,'nonfinite exchange rejected')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'invalid candidate absent')

  write(*,'(a)') 'PPA_WU05E_MACROPORE_SALT_EXCHANGE_ORACLE=PASS'

contains

  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      write(*,'(a)') 'FAIL: '//message
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual,expected,message)
    real(real64),intent(in)::actual,expected
    character(*),intent(in)::message
    call require(abs(actual-expected)<=1.0e-13_real64,message)
  end subroutine require_close

end program test_mobile_macropore_salt_exchange_oracle
