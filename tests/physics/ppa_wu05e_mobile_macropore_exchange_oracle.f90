module ppa_wu05e_mobile_macropore_exchange_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: EXCHANGE_OK=0, EXCHANGE_INVALID=1, EXCHANGE_DONOR_UNAVAILABLE=2

  type, public :: mobile_macro_salt_state_t
    real(real64), allocatable :: matrix_mass_mg_cm2(:)
    real(real64), allocatable :: macro_mass_mg_cm2(:,:)
  end type

  type, public :: mobile_macro_salt_transfer_t
    real(real64), allocatable :: macro_to_matrix_mg_cm2(:)
    real(real64), allocatable :: matrix_to_macro_mg_cm2(:)
    real(real64) :: closure_error_mg_cm2=0.0_real64
  end type

  public :: transfer_mobile_macro_salt_trial

contains

  ! Test-only conservative interface oracle. Positive exchange is macro-to-
  ! matrix; negative exchange is matrix-to-macro. Water volumes are depth-
  ! equivalent cm per node and salt masses are mg/cm2 per node/domain.
  ! Transfers use each donor's start-of-substep concentration. This prototype
  ! owns neither continuation state nor boundary/transport scheduling.
  subroutine transfer_mobile_macro_salt_trial(committed,matrix_water_cm,macro_water_cm,exchange_cm_day,dt_day, &
       candidate,receipt,status)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: matrix_water_cm(:),macro_water_cm(:,:),exchange_cm_day(:,:)
    real(real64), intent(in) :: dt_day
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    type(mobile_macro_salt_transfer_t), intent(out) :: receipt
    integer, intent(out) :: status
    real(real64), allocatable :: matrix_out(:),matrix_in(:),macro_amount(:,:)
    real(real64) :: water_amount,salt_amount,total_before,total_after
    integer :: n,nd,id,node

    candidate=mobile_macro_salt_state_t()
    receipt=mobile_macro_salt_transfer_t()
    status=EXCHANGE_INVALID
    n=size(matrix_water_cm); nd=size(macro_water_cm,1)
    if(n<=0 .or. nd<=0 .or. size(macro_water_cm,2)/=n .or. &
       any(shape(exchange_cm_day)/=[nd,n])) return
    if(.not. allocated(committed%matrix_mass_mg_cm2) .or. .not. allocated(committed%macro_mass_mg_cm2)) return
    if(size(committed%matrix_mass_mg_cm2)/=n .or. &
       any(shape(committed%macro_mass_mg_cm2)/=[nd,n])) return
    if(.not. all(ieee_is_finite(matrix_water_cm)) .or. .not. all(ieee_is_finite(macro_water_cm)) .or. &
       .not. all(ieee_is_finite(exchange_cm_day)) .or. .not. ieee_is_finite(dt_day) .or. dt_day<=0.0_real64) return
    if(.not. all(ieee_is_finite(committed%matrix_mass_mg_cm2)) .or. &
       .not. all(ieee_is_finite(committed%macro_mass_mg_cm2))) return
    if(any(matrix_water_cm<0.0_real64) .or. any(macro_water_cm<0.0_real64) .or. &
       any(committed%matrix_mass_mg_cm2<0.0_real64) .or. any(committed%macro_mass_mg_cm2<0.0_real64)) return
    if(any(matrix_water_cm<=0.0_real64.and.committed%matrix_mass_mg_cm2>0.0_real64) .or. &
       any(macro_water_cm<=0.0_real64.and.committed%macro_mass_mg_cm2>0.0_real64)) return

    allocate(matrix_out(n),matrix_in(n),macro_amount(nd,n))
    matrix_out=0.0_real64; matrix_in=0.0_real64; macro_amount=0.0_real64
    do node=1,n
      do id=1,nd
        water_amount=abs(exchange_cm_day(id,node))*dt_day
        if(exchange_cm_day(id,node)>0.0_real64) then
          if(macro_water_cm(id,node)<=0.0_real64) then
            status=EXCHANGE_DONOR_UNAVAILABLE; return
          end if
          if(water_amount>macro_water_cm(id,node)) then
            status=EXCHANGE_DONOR_UNAVAILABLE; return
          end if
          salt_amount=water_amount*committed%macro_mass_mg_cm2(id,node)/macro_water_cm(id,node)
          macro_amount(id,node)=-salt_amount
          matrix_in(node)=matrix_in(node)+salt_amount
        else if(exchange_cm_day(id,node)<0.0_real64) then
          if(matrix_water_cm(node)<=0.0_real64) then
            status=EXCHANGE_DONOR_UNAVAILABLE; return
          end if
          if(water_amount>matrix_water_cm(node)) then
            status=EXCHANGE_DONOR_UNAVAILABLE; return
          end if
          salt_amount=water_amount*committed%matrix_mass_mg_cm2(node)/matrix_water_cm(node)
          macro_amount(id,node)=salt_amount
          matrix_out(node)=matrix_out(node)+salt_amount
        end if
      end do
      if(sum(max(0.0_real64,-exchange_cm_day(:,node)))*dt_day>matrix_water_cm(node)) then
        status=EXCHANGE_DONOR_UNAVAILABLE; return
      end if
      if(matrix_out(node)>committed%matrix_mass_mg_cm2(node)) then
        status=EXCHANGE_DONOR_UNAVAILABLE; return
      end if
    end do

    candidate%matrix_mass_mg_cm2=committed%matrix_mass_mg_cm2+matrix_in-matrix_out
    candidate%macro_mass_mg_cm2=committed%macro_mass_mg_cm2+macro_amount
    if(any(candidate%matrix_mass_mg_cm2<0.0_real64) .or. any(candidate%macro_mass_mg_cm2<0.0_real64)) then
      candidate=mobile_macro_salt_state_t(); status=EXCHANGE_DONOR_UNAVAILABLE; return
    end if
    if(.not. all(ieee_is_finite(candidate%matrix_mass_mg_cm2)) .or. &
       .not. all(ieee_is_finite(candidate%macro_mass_mg_cm2))) then
      candidate=mobile_macro_salt_state_t(); status=EXCHANGE_INVALID; return
    end if

    receipt%macro_to_matrix_mg_cm2=matrix_in
    receipt%matrix_to_macro_mg_cm2=matrix_out
    total_before=sum(committed%matrix_mass_mg_cm2)+sum(committed%macro_mass_mg_cm2)
    total_after=sum(candidate%matrix_mass_mg_cm2)+sum(candidate%macro_mass_mg_cm2)
    receipt%closure_error_mg_cm2=total_after-total_before
    status=EXCHANGE_OK
  end subroutine transfer_mobile_macro_salt_trial

end module ppa_wu05e_mobile_macropore_exchange_oracle
