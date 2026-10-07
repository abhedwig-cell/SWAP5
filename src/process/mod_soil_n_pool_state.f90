module mod_soil_n_pool_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: SOIL_N_OK=0, SOIL_N_INVALID=1, SOIL_N_NEGATIVE=2, SOIL_N_BALANCE=3

  type, public :: soil_n_pool_state_t
    real(real64), allocatable :: ammonium(:)
    real(real64), allocatable :: nitrate(:)
    real(real64), allocatable :: organic_fast(:)
    real(real64), allocatable :: organic_slow(:)
  contains
    procedure :: total => soil_n_total
    procedure :: valid => soil_n_valid
  end type

  type, public :: soil_n_transfer_t
    real(real64), allocatable :: ammonium_delta(:)
    real(real64), allocatable :: nitrate_delta(:)
    real(real64), allocatable :: organic_fast_delta(:)
    real(real64), allocatable :: organic_slow_delta(:)
    real(real64) :: external_input=0.0_real64
    real(real64) :: external_output=0.0_real64
  end type

  type, public :: soil_n_receipt_t
    integer :: status=SOIL_N_OK
    real(real64) :: storage_before=0.0_real64
    real(real64) :: storage_after=0.0_real64
    real(real64) :: external_input=0.0_real64
    real(real64) :: external_output=0.0_real64
    real(real64) :: balance_residual=0.0_real64
  end type

  public :: initialize_soil_n_pool_state, apply_soil_n_transfer
contains
  subroutine initialize_soil_n_pool_state(ammonium,nitrate,organic_fast,organic_slow,state,status)
    real(real64),intent(in)::ammonium(:),nitrate(:),organic_fast(:),organic_slow(:)
    type(soil_n_pool_state_t),intent(out)::state
    integer,intent(out)::status
    integer::n
    state=soil_n_pool_state_t(); status=SOIL_N_INVALID
    n=size(ammonium)
    if(n<1 .or. size(nitrate)/=n .or. size(organic_fast)/=n .or. size(organic_slow)/=n) return
    if(.not.all(ieee_is_finite(ammonium)) .or. .not.all(ieee_is_finite(nitrate)) .or. &
       .not.all(ieee_is_finite(organic_fast)) .or. .not.all(ieee_is_finite(organic_slow))) return
    if(any(ammonium<0.0_real64) .or. any(nitrate<0.0_real64) .or. &
       any(organic_fast<0.0_real64) .or. any(organic_slow<0.0_real64)) then
      status=SOIL_N_NEGATIVE; return
    end if
    state%ammonium=ammonium; state%nitrate=nitrate
    state%organic_fast=organic_fast; state%organic_slow=organic_slow
    status=SOIL_N_OK
  end subroutine

  pure real(real64) function soil_n_total(self) result(total)
    class(soil_n_pool_state_t),intent(in)::self
    total=0.0_real64
    if(allocated(self%ammonium)) total=total+sum(self%ammonium)
    if(allocated(self%nitrate)) total=total+sum(self%nitrate)
    if(allocated(self%organic_fast)) total=total+sum(self%organic_fast)
    if(allocated(self%organic_slow)) total=total+sum(self%organic_slow)
  end function

  pure logical function soil_n_valid(self) result(valid)
    class(soil_n_pool_state_t),intent(in)::self
    integer::n
    valid=.false.
    if(.not.allocated(self%ammonium).or..not.allocated(self%nitrate).or. &
       .not.allocated(self%organic_fast).or..not.allocated(self%organic_slow)) return
    n=size(self%ammonium)
    if(n<1.or.size(self%nitrate)/=n.or.size(self%organic_fast)/=n.or.size(self%organic_slow)/=n) return
    if(.not.all(ieee_is_finite(self%ammonium)).or..not.all(ieee_is_finite(self%nitrate)).or. &
       .not.all(ieee_is_finite(self%organic_fast)).or..not.all(ieee_is_finite(self%organic_slow))) return
    valid=all(self%ammonium>=0.0_real64).and.all(self%nitrate>=0.0_real64).and. &
          all(self%organic_fast>=0.0_real64).and.all(self%organic_slow>=0.0_real64)
  end function

  subroutine apply_soil_n_transfer(committed,transfer,candidate,receipt,tolerance)
    type(soil_n_pool_state_t),intent(in)::committed
    type(soil_n_transfer_t),intent(in)::transfer
    type(soil_n_pool_state_t),intent(out)::candidate
    type(soil_n_receipt_t),intent(out)::receipt
    real(real64),intent(in),optional::tolerance
    real(real64)::tol,scale
    integer::n
    candidate=committed; receipt=soil_n_receipt_t(); receipt%status=SOIL_N_INVALID
    if(.not.committed%valid()) return
    n=size(committed%ammonium)
    if(.not.allocated(transfer%ammonium_delta).or..not.allocated(transfer%nitrate_delta).or. &
       .not.allocated(transfer%organic_fast_delta).or..not.allocated(transfer%organic_slow_delta)) return
    if(size(transfer%ammonium_delta)/=n.or.size(transfer%nitrate_delta)/=n.or. &
       size(transfer%organic_fast_delta)/=n.or.size(transfer%organic_slow_delta)/=n) return
    if(.not.all(ieee_is_finite(transfer%ammonium_delta)).or. &
       .not.all(ieee_is_finite(transfer%nitrate_delta)).or. &
       .not.all(ieee_is_finite(transfer%organic_fast_delta)).or. &
       .not.all(ieee_is_finite(transfer%organic_slow_delta)).or. &
       .not.ieee_is_finite(transfer%external_input).or..not.ieee_is_finite(transfer%external_output)) return
    if(transfer%external_input<0.0_real64.or.transfer%external_output<0.0_real64) return

    candidate%ammonium=committed%ammonium+transfer%ammonium_delta
    candidate%nitrate=committed%nitrate+transfer%nitrate_delta
    candidate%organic_fast=committed%organic_fast+transfer%organic_fast_delta
    candidate%organic_slow=committed%organic_slow+transfer%organic_slow_delta
    if(.not.candidate%valid()) then
      candidate=committed; receipt%status=SOIL_N_NEGATIVE; return
    end if
    receipt%storage_before=committed%total(); receipt%storage_after=candidate%total()
    receipt%external_input=transfer%external_input; receipt%external_output=transfer%external_output
    receipt%balance_residual=receipt%storage_after-receipt%storage_before- &
                             receipt%external_input+receipt%external_output
    tol=1e-12_real64; if(present(tolerance)) tol=max(0.0_real64,tolerance)
    scale=max(1.0_real64,abs(receipt%storage_before),abs(receipt%storage_after), &
              receipt%external_input,receipt%external_output)
    if(abs(receipt%balance_residual)>tol*scale) then
      candidate=committed; receipt%status=SOIL_N_BALANCE; return
    end if
    receipt%status=SOIL_N_OK
  end subroutine
end module
