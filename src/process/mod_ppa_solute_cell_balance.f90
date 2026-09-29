module mod_ppa_solute_cell_balance
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: PPA_SOLUTE_CELL_BALANCE_OK = 0
  integer, parameter, public :: PPA_SOLUTE_CELL_BALANCE_INVALID_INPUT = 1
  public :: ppa_solute_cell_storage_update
contains
  pure subroutine ppa_solute_cell_storage_update(previous_storage, bottom_face_amount, top_face_amount, &
       cell_thickness, decomposition_rate, root_uptake_rate, lateral_drainage_rate, interval_days, &
       updated_storage, status)
    real(real64), intent(in) :: previous_storage, bottom_face_amount, top_face_amount, cell_thickness
    real(real64), intent(in) :: decomposition_rate, root_uptake_rate, lateral_drainage_rate, interval_days
    real(real64), intent(out) :: updated_storage
    integer, intent(out) :: status
    real(real64) :: face_difference, face_increment, sink_increment, sink_rate, interim
    logical :: valid

    ! Source: B1.11 solute.f90 task 2 compartment cmsy conservation update.
    updated_storage = 0.0_real64
    status = PPA_SOLUTE_CELL_BALANCE_INVALID_INPUT
    if (.not. all(ieee_is_finite([previous_storage,bottom_face_amount,top_face_amount,cell_thickness, &
        decomposition_rate,root_uptake_rate,lateral_drainage_rate,interval_days]))) return
    if (cell_thickness <= 0.0_real64 .or. interval_days <= 0.0_real64) return

    call checked_add(bottom_face_amount,-top_face_amount,face_difference,valid)
    if (.not. valid) return
    if (cell_thickness < 1.0_real64) then
      if (abs(face_difference) > huge(1.0_real64)*cell_thickness) return
    end if
    face_increment = face_difference/cell_thickness

    call checked_add(-decomposition_rate,-root_uptake_rate,sink_rate,valid)
    if (.not. valid) return
    call checked_add(sink_rate,-lateral_drainage_rate,interim,valid)
    if (.not. valid) return
    sink_rate = interim
    if (interval_days > 1.0_real64) then
      if (abs(sink_rate) > huge(1.0_real64)/interval_days) return
    end if
    sink_increment = sink_rate*interval_days
    call checked_add(previous_storage,face_increment,interim,valid)
    if (.not. valid) return
    call checked_add(interim,sink_increment,updated_storage,valid)
    if (.not. valid) then
      updated_storage = 0.0_real64
      return
    end if
    status = PPA_SOLUTE_CELL_BALANCE_OK
  end subroutine ppa_solute_cell_storage_update

  pure subroutine checked_add(a,b,result,valid)
    real(real64),intent(in)::a,b
    real(real64),intent(out)::result
    logical,intent(out)::valid
    result=0.0_real64
    valid=.false.
    if(a>0.0_real64 .and. b>0.0_real64)then
      if(a>huge(1.0_real64)-b)return
    else if(a<0.0_real64 .and. b<0.0_real64)then
      if(a< -huge(1.0_real64)-b)return
    end if
    result=a+b
    valid=ieee_is_finite(result)
  end subroutine checked_add
end module mod_ppa_solute_cell_balance
