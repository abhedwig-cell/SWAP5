module mod_solute_macropore_exchange
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

  public :: transfer_mobile_macro_salt_trial, transfer_mobile_macro_salt_trace

contains

  ! Stateless conservative exchange operator for one already accepted water
  ! exchange step. Positive exchange is macro-to-matrix; negative is the
  ! reverse. Masses use mg/cm2 and water depths use cm per node/domain. This
  ! operator owns neither persistent salt state nor transport boundaries.
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

  ! Applies only the internal matrix/macropore salt exchange represented by a
  ! fully ordered accepted-water trace. Boundary, root, drainage, and Richards
  ! face-transport receipts remain outside this operator. Any invalid or
  ! donor-unavailable substep discards the entire salt candidate and receipt.
  subroutine transfer_mobile_macro_salt_trace(committed,matrix_water_start_cm,matrix_water_end_cm, &
       macro_water_start_cm,macro_water_end_cm,exchange_cm_day,duration_day,t0,t1,candidate,receipt,status)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: matrix_water_start_cm(:,:),matrix_water_end_cm(:,:)
    real(real64), intent(in) :: macro_water_start_cm(:,:,:),macro_water_end_cm(:,:,:)
    real(real64), intent(in) :: exchange_cm_day(:,:,:),duration_day(:),t0(:),t1(:)
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    type(mobile_macro_salt_transfer_t), intent(out) :: receipt
    integer, intent(out) :: status
    type(mobile_macro_salt_state_t) :: current,next
    type(mobile_macro_salt_transfer_t) :: step_receipt
    real(real64) :: time_tolerance,water_tolerance,total_before,total_after
    integer :: n,nd,ns,k

    candidate=mobile_macro_salt_state_t()
    receipt=mobile_macro_salt_transfer_t()
    status=EXCHANGE_INVALID
    n=size(matrix_water_start_cm,1); ns=size(matrix_water_start_cm,2)
    nd=size(macro_water_start_cm,1)
    if(n<=0.or.ns<=0.or.nd<=0) return
    if(any(shape(matrix_water_end_cm)/=[n,ns]))return
    if(any(shape(macro_water_start_cm)/=[nd,n,ns]).or.any(shape(macro_water_end_cm)/=[nd,n,ns]).or. &
       any(shape(exchange_cm_day)/=[nd,n,ns]))return
    if(size(duration_day)/=ns.or.size(t0)/=ns.or.size(t1)/=ns)return
    if(.not.allocated(committed%matrix_mass_mg_cm2).or..not.allocated(committed%macro_mass_mg_cm2))return
    if(size(committed%matrix_mass_mg_cm2)/=n.or. &
       any(shape(committed%macro_mass_mg_cm2)/=[nd,n]))return
    if(.not.all(ieee_is_finite(matrix_water_start_cm)).or..not.all(ieee_is_finite(matrix_water_end_cm)).or. &
       .not.all(ieee_is_finite(macro_water_start_cm)).or..not.all(ieee_is_finite(macro_water_end_cm)).or. &
       .not.all(ieee_is_finite(exchange_cm_day)).or..not.all(ieee_is_finite(duration_day)).or. &
       .not.all(ieee_is_finite(t0)).or..not.all(ieee_is_finite(t1)))return
    if(any(matrix_water_start_cm<0.0_real64).or.any(matrix_water_end_cm<0.0_real64).or. &
       any(macro_water_start_cm<0.0_real64).or.any(macro_water_end_cm<0.0_real64))return

    allocate(receipt%macro_to_matrix_mg_cm2(n),receipt%matrix_to_macro_mg_cm2(n))
    receipt%macro_to_matrix_mg_cm2=0.0_real64
    receipt%matrix_to_macro_mg_cm2=0.0_real64
    current=committed
    status=EXCHANGE_INVALID
    do k=2,ns
      time_tolerance=128.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t0(k)),abs(t1(k)))
      if(abs(t0(k)-t1(k-1))>time_tolerance)goto 800
      water_tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
           maxval(abs(matrix_water_start_cm(:,k))),maxval(abs(matrix_water_end_cm(:,k-1))))
      if(any(abs(matrix_water_start_cm(:,k)-matrix_water_end_cm(:,k-1))>water_tolerance))goto 800
      water_tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
           maxval(abs(macro_water_start_cm(:,:,k))),maxval(abs(macro_water_end_cm(:,:,k-1))))
      if(any(abs(macro_water_start_cm(:,:,k)-macro_water_end_cm(:,:,k-1))>water_tolerance))goto 800
    end do
    do k=1,ns
      if(t1(k)<=t0(k).or.duration_day(k)<=0.0_real64)goto 800
      time_tolerance=128.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t0(k)),abs(t1(k)))
      if(abs((t1(k)-t0(k))-duration_day(k))>time_tolerance)goto 800
      call transfer_mobile_macro_salt_trial(current,matrix_water_start_cm(:,k),macro_water_start_cm(:,:,k), &
           exchange_cm_day(:,:,k),duration_day(k),next,step_receipt,status)
      if(status/=EXCHANGE_OK)then
        candidate=mobile_macro_salt_state_t()
        receipt=mobile_macro_salt_transfer_t()
        return
      end if
      current=next
      receipt%macro_to_matrix_mg_cm2=receipt%macro_to_matrix_mg_cm2+step_receipt%macro_to_matrix_mg_cm2
      receipt%matrix_to_macro_mg_cm2=receipt%matrix_to_macro_mg_cm2+step_receipt%matrix_to_macro_mg_cm2
    end do

    total_before=sum(committed%matrix_mass_mg_cm2)+sum(committed%macro_mass_mg_cm2)
    total_after=sum(current%matrix_mass_mg_cm2)+sum(current%macro_mass_mg_cm2)
    receipt%closure_error_mg_cm2=total_after-total_before
    if(.not.ieee_is_finite(receipt%closure_error_mg_cm2))then
      goto 800
    end if
    candidate=current
    status=EXCHANGE_OK
    return

800 candidate=mobile_macro_salt_state_t()
    receipt=mobile_macro_salt_transfer_t()
    status=EXCHANGE_INVALID
  end subroutine transfer_mobile_macro_salt_trace

end module mod_solute_macropore_exchange
