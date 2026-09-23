program test_sw_rib_adm01_g5a_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_external_surface_water_transaction
  implicit none

  type(external_surface_water_origin_t) :: origin, stale
  type(external_surface_water_request_t) :: request
  type(external_surface_water_realization_t) :: realization
  type(external_surface_water_transaction_result_t) :: result, replay

  origin%swap_revision = 11_int64
  origin%ribasim_origin_id = 901_int64
  origin%ribasim_revision = 17_int64

  request%origin = origin
  request%accepted_surface_water_head_cm = -50.0_real64

  ! E1: positive drainage, full realization.
  request%requested_signed_soil_to_surface_amount_cm = 0.01_real64
  realization%origin = origin
  realization%realized_signed_soil_to_surface_amount_cm = 0.01_real64
  call evaluate_external_surface_water_transaction(origin,request,realization,result)
  call require(result%disposition == EXT_SW_TX_COMMIT_READY,'E1 disposition')
  call require(result%swap_may_commit .and. result%ribasim_may_commit,'E1 joint commit')
  call require(result%exactly_once_transfer_ready,'E1 exactly once')
  write(*,'(A)') 'SW_RIB_ADM01_G5A_E1_POSITIVE_FULL=PASS'

  ! E2: negative infiltration, full realization.
  request%requested_signed_soil_to_surface_amount_cm = -0.005_real64
  realization%realized_signed_soil_to_surface_amount_cm = -0.005_real64
  call evaluate_external_surface_water_transaction(origin,request,realization,result)
  call require(result%disposition == EXT_SW_TX_COMMIT_READY,'E2 disposition')
  call require(result%accepted_signed_soil_to_surface_amount_cm < 0.0_real64,'E2 sign')
  write(*,'(A)') 'SW_RIB_ADM01_G5A_E2_NEGATIVE_FULL=PASS'

  ! E3: Ribasim availability changes the realized negative transfer.
  request%requested_signed_soil_to_surface_amount_cm = -0.0051_real64
  realization%realized_signed_soil_to_surface_amount_cm = -0.0020_real64
  call evaluate_external_surface_water_transaction(origin,request,realization,result)
  call require(result%disposition == EXT_SW_TX_RECOMPOSITION_REQUIRED,'E3 disposition')
  call require(.not. result%swap_may_commit .and. .not. result%ribasim_may_commit,'E3 no first commit')
  call require(.not. result%exactly_once_transfer_ready,'E3 not bookable')
  call require(same_bits(result%accepted_signed_soil_to_surface_amount_cm,-0.0020_real64),'E3 realized authority')

  ! Recompose from the exact same accepted origins with the realized transfer.
  request%requested_signed_soil_to_surface_amount_cm = result%accepted_signed_soil_to_surface_amount_cm
  call evaluate_external_surface_water_transaction(origin,request,realization,replay)
  call require(replay%disposition == EXT_SW_TX_COMMIT_READY,'E3 recomposed disposition')
  call require(replay%exactly_once_transfer_ready,'E3 recomposed exactly once')
  write(*,'(A)') 'SW_RIB_ADM01_G5A_E3_RECOMPOSITION=PASS'

  ! E4: stale origin fails closed.
  stale = origin
  stale%ribasim_revision = origin%ribasim_revision + 1_int64
  realization%origin = stale
  call evaluate_external_surface_water_transaction(origin,request,realization,result)
  call require(result%disposition == EXT_SW_TX_STALE_ORIGIN,'E4 stale')
  call require(.not. result%swap_may_commit .and. .not. result%ribasim_may_commit,'E4 no commit')
  write(*,'(A)') 'SW_RIB_ADM01_G5A_E4_STALE_ORIGIN=PASS'

  ! E5: deterministic same-origin replay.
  realization%origin = origin
  request%requested_signed_soil_to_surface_amount_cm = -0.0051_real64
  realization%realized_signed_soil_to_surface_amount_cm = -0.0020_real64
  call evaluate_external_surface_water_transaction(origin,request,realization,result)
  call evaluate_external_surface_water_transaction(origin,request,realization,replay)
  call require(result%disposition == replay%disposition,'E5 disposition replay')
  call require(same_bits(result%accepted_signed_soil_to_surface_amount_cm, &
                         replay%accepted_signed_soil_to_surface_amount_cm),'E5 amount replay')
  call require(result%swap_may_commit .eqv. replay%swap_may_commit,'E5 swap replay')
  call require(result%ribasim_may_commit .eqv. replay%ribasim_may_commit,'E5 ribasim replay')
  write(*,'(A)') 'SW_RIB_ADM01_G5A_E5_RETRY_DETERMINISM=PASS'

  write(*,'(A)') 'SW_RIB_ADM01_G5A_ORIGIN_BOUND_TRANSACTION=PASS'

contains
  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'SW_RIB_ADM01_G5A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_sw_rib_adm01_g5a_transaction
