module mod_solute_compartment_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SOLCOMP_OK=0, SOLCOMP_INVALID=1
  integer, parameter, public :: SOLCOMP_NEGATIVE=2, SOLCOMP_BALANCE=3

  ! Companion persistent stores beyond the already admitted dissolved-mobile
  ! matrix owner. This module owns storage and transfer accounting only.
  ! B1.11 sorption, reaction, pond, aquifer and age equations remain separate.
  type, public :: solute_compartment_state_t
    real(real64), allocatable :: sorbed_matrix_mass(:)
    real(real64) :: pond_mass=0.0_real64
    real(real64) :: aquifer_mass=0.0_real64
    real(real64), allocatable :: age_amount(:)
    real(real64) :: age_pond_previous_concentration=0.0_real64
  contains
    procedure :: solute_total => solcomp_solute_total
    procedure :: valid => solcomp_valid
  end type

  type, public :: solute_compartment_transfer_t
    real(real64), allocatable :: sorbed_matrix_delta(:)
    real(real64) :: pond_delta=0.0_real64
    real(real64) :: aquifer_delta=0.0_real64
    real(real64), allocatable :: age_amount_delta(:)
    real(real64) :: external_solute_input=0.0_real64
    real(real64) :: external_solute_output=0.0_real64
  end type

  type, public :: solute_compartment_receipt_t
    integer :: status=SOLCOMP_OK
    real(real64) :: solute_before=0.0_real64
    real(real64) :: solute_after=0.0_real64
    real(real64) :: external_solute_input=0.0_real64
    real(real64) :: external_solute_output=0.0_real64
    real(real64) :: solute_balance_residual=0.0_real64
  end type

  public :: initialize_solute_compartment_state
  public :: apply_solute_compartment_transfer

contains

  subroutine initialize_solute_compartment_state(sorbed,pond,aquifer,age_amount,state,status,age_pond_previous_concentration)
    real(real64),intent(in)::sorbed(:),pond,aquifer,age_amount(:)
    real(real64),intent(in),optional::age_pond_previous_concentration
    type(solute_compartment_state_t),intent(out)::state
    integer,intent(out)::status
    state=solute_compartment_state_t()
    status=SOLCOMP_INVALID
    if(size(sorbed)<1.or.size(age_amount)<1) return
    if(.not.all(ieee_is_finite(sorbed)).or..not.all(ieee_is_finite(age_amount)).or. &
       .not.ieee_is_finite(pond).or..not.ieee_is_finite(aquifer)) return
    if(any(sorbed<0.0_real64).or.any(age_amount<0.0_real64).or.pond<0.0_real64.or.aquifer<0.0_real64) then
      status=SOLCOMP_NEGATIVE
      return
    end if
    state%sorbed_matrix_mass=sorbed
    state%pond_mass=pond
    state%aquifer_mass=aquifer
    state%age_amount=age_amount
    if(present(age_pond_previous_concentration))then
      if(.not.ieee_is_finite(age_pond_previous_concentration).or.age_pond_previous_concentration<0.0_real64)return
      state%age_pond_previous_concentration=age_pond_previous_concentration
    end if
    status=SOLCOMP_OK
  end subroutine

  pure real(real64) function solcomp_solute_total(self) result(total)
    class(solute_compartment_state_t),intent(in)::self
    total=0.0_real64
    if(allocated(self%sorbed_matrix_mass)) total=total+sum(self%sorbed_matrix_mass)
    total=total+self%pond_mass+self%aquifer_mass
  end function

  pure logical function solcomp_valid(self) result(valid)
    class(solute_compartment_state_t),intent(in)::self
    valid=.false.
    if(.not.allocated(self%sorbed_matrix_mass).or..not.allocated(self%age_amount)) return
    if(size(self%sorbed_matrix_mass)<1.or.size(self%age_amount)<1) return
    if(.not.all(ieee_is_finite(self%sorbed_matrix_mass)).or. &
       .not.all(ieee_is_finite(self%age_amount)).or. &
       .not.ieee_is_finite(self%age_pond_previous_concentration).or. &
       .not.ieee_is_finite(self%pond_mass).or..not.ieee_is_finite(self%aquifer_mass)) return
    valid=all(self%sorbed_matrix_mass>=0.0_real64).and.all(self%age_amount>=0.0_real64).and. &
          self%age_pond_previous_concentration>=0.0_real64.and. &
          self%pond_mass>=0.0_real64.and.self%aquifer_mass>=0.0_real64
  end function

  subroutine apply_solute_compartment_transfer(committed,transfer,candidate,receipt,tolerance)
    type(solute_compartment_state_t),intent(in)::committed
    type(solute_compartment_transfer_t),intent(in)::transfer
    type(solute_compartment_state_t),intent(out)::candidate
    type(solute_compartment_receipt_t),intent(out)::receipt
    real(real64),intent(in),optional::tolerance
    real(real64)::tol,scale

    candidate=committed
    receipt=solute_compartment_receipt_t()
    receipt%status=SOLCOMP_INVALID
    if(.not.committed%valid()) return
    if(.not.allocated(transfer%sorbed_matrix_delta).or..not.allocated(transfer%age_amount_delta)) return
    if(size(transfer%sorbed_matrix_delta)/=size(committed%sorbed_matrix_mass)) return
    if(size(transfer%age_amount_delta)/=size(committed%age_amount)) return
    if(.not.all(ieee_is_finite(transfer%sorbed_matrix_delta)).or. &
       .not.all(ieee_is_finite(transfer%age_amount_delta)).or. &
       .not.ieee_is_finite(transfer%pond_delta).or..not.ieee_is_finite(transfer%aquifer_delta).or. &
       .not.ieee_is_finite(transfer%external_solute_input).or. &
       .not.ieee_is_finite(transfer%external_solute_output)) return
    if(transfer%external_solute_input<0.0_real64.or.transfer%external_solute_output<0.0_real64) return

    candidate%sorbed_matrix_mass=committed%sorbed_matrix_mass+transfer%sorbed_matrix_delta
    candidate%pond_mass=committed%pond_mass+transfer%pond_delta
    candidate%aquifer_mass=committed%aquifer_mass+transfer%aquifer_delta
    candidate%age_amount=committed%age_amount+transfer%age_amount_delta
    if(.not.candidate%valid()) then
      candidate=committed
      receipt%status=SOLCOMP_NEGATIVE
      return
    end if

    receipt%solute_before=committed%solute_total()
    receipt%solute_after=candidate%solute_total()
    receipt%external_solute_input=transfer%external_solute_input
    receipt%external_solute_output=transfer%external_solute_output
    receipt%solute_balance_residual=receipt%solute_after-receipt%solute_before- &
         receipt%external_solute_input+receipt%external_solute_output

    tol=1e-12_real64
    if(present(tolerance)) tol=max(0.0_real64,tolerance)
    scale=max(1.0_real64,abs(receipt%solute_before),abs(receipt%solute_after), &
         receipt%external_solute_input,receipt%external_solute_output)
    if(abs(receipt%solute_balance_residual)>tol*scale) then
      candidate=committed
      receipt%status=SOLCOMP_BALANCE
      return
    end if
    receipt%status=SOLCOMP_OK
  end subroutine
end module
