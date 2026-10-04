module mod_solute_mobile_macro_salt_transport
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_macropore_exchange, only: mobile_macro_salt_state_t
  implicit none
  private

  integer, parameter, public :: MACRO_SALT_OK=0, MACRO_SALT_INVALID=1
  integer, parameter, public :: MACRO_SALT_WATER_CLOSURE=2, MACRO_SALT_DONOR_UNAVAILABLE=3
  integer, parameter, public :: MACRO_SALT_BALANCE_FAILURE=4

  type, public :: mobile_macro_salt_receipt_t
    real(real64) :: matrix_top_input_mg_cm2=0.0_real64
    real(real64) :: matrix_top_output_mg_cm2=0.0_real64
    real(real64) :: matrix_bottom_input_mg_cm2=0.0_real64
    real(real64) :: matrix_bottom_output_mg_cm2=0.0_real64
    real(real64), allocatable :: macro_top_input_mg_cm2(:), macro_top_output_mg_cm2(:)
    real(real64), allocatable :: macro_bottom_input_mg_cm2(:), macro_bottom_output_mg_cm2(:)
    real(real64), allocatable :: root_solute_uptake_mg_cm2(:)
    real(real64) :: closure_error_mg_cm2=0.0_real64
  end type

  public :: advance_mobile_macro_salt_trial

contains

  ! Conservative explicit-advection candidate for one accepted water substep.
  ! All mobile compartments use donor concentrations from the committed start
  ! state. Positive vertical face rate is downward; positive exchange is macro
  ! to matrix. The routine owns salt only and never changes committed input.
  subroutine advance_mobile_macro_salt_trial(committed,node_thickness_cm,matrix_water_start,matrix_water_end, &
       macro_water_start,macro_water_end,matrix_face_rate,macro_face_rate,exchange_rate,root_water_sink, &
       matrix_top_concentration,matrix_bottom_concentration,macro_top_concentration,macro_bottom_concentration, &
       tscf,dt_day,candidate,receipt,status)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: node_thickness_cm(:),matrix_water_start(:),matrix_water_end(:)
    real(real64), intent(in) :: macro_water_start(:,:),macro_water_end(:,:)
    real(real64), intent(in) :: matrix_face_rate(:),macro_face_rate(:,:),exchange_rate(:,:),root_water_sink(:)
    real(real64), intent(in) :: matrix_top_concentration,matrix_bottom_concentration
    real(real64), intent(in) :: macro_top_concentration(:),macro_bottom_concentration(:),tscf,dt_day
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    type(mobile_macro_salt_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status
    real(real64), allocatable :: cm(:),cp(:,:),dm(:),dp(:,:),outm(:),outp(:,:),matrix_volume_start(:)
    real(real64) :: q,amount,root_salt,total_before,total_after,tol,water_expected
    integer :: n,nd,i,d

    candidate=mobile_macro_salt_state_t(); receipt=mobile_macro_salt_receipt_t(); status=MACRO_SALT_INVALID
    n=size(matrix_water_start); nd=size(macro_water_start,1)
    if(n<=0.or.nd<=0.or.size(node_thickness_cm)/=n.or.size(matrix_water_end)/=n.or.size(root_water_sink)/=n.or. &
       size(matrix_face_rate)/=n+1.or.any(shape(macro_water_end)/=[nd,n]).or. &
       any(shape(exchange_rate)/=[nd,n]).or.any(shape(macro_face_rate)/=[nd,n+1]).or. &
       size(macro_top_concentration)/=nd.or.size(macro_bottom_concentration)/=nd)return
    if(.not.allocated(committed%matrix_mass_mg_cm2).or..not.allocated(committed%macro_mass_mg_cm2))return
    if(size(committed%matrix_mass_mg_cm2)/=n.or.any(shape(committed%macro_mass_mg_cm2)/=[nd,n]))return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(matrix_water_start)).or. &
       .not.all(ieee_is_finite(matrix_water_end)).or. &
       .not.all(ieee_is_finite(macro_water_start)).or..not.all(ieee_is_finite(macro_water_end)).or. &
       .not.all(ieee_is_finite(matrix_face_rate)).or..not.all(ieee_is_finite(macro_face_rate)).or. &
       .not.all(ieee_is_finite(exchange_rate)).or..not.all(ieee_is_finite(root_water_sink)).or. &
       .not.all(ieee_is_finite(committed%matrix_mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(committed%macro_mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(macro_top_concentration)).or..not.all(ieee_is_finite(macro_bottom_concentration)).or. &
       .not.all(ieee_is_finite([matrix_top_concentration,matrix_bottom_concentration,tscf,dt_day])))return
    if(any(node_thickness_cm<=0.0_real64).or.any(matrix_water_start<0.0_real64).or.any(matrix_water_end<0.0_real64).or. &
       any(macro_water_start<0.0_real64).or.any(macro_water_end<0.0_real64).or. &
       any(committed%matrix_mass_mg_cm2<0.0_real64).or.any(committed%macro_mass_mg_cm2<0.0_real64).or. &
       any(root_water_sink<0.0_real64).or.matrix_top_concentration<0.0_real64.or. &
       matrix_bottom_concentration<0.0_real64.or.any(macro_top_concentration<0.0_real64).or. &
       any(macro_bottom_concentration<0.0_real64).or.tscf<0.0_real64.or.tscf>1.0_real64.or.dt_day<=0.0_real64)return
    allocate(matrix_volume_start(n))
    matrix_volume_start=matrix_water_start*node_thickness_cm
    if(any(matrix_volume_start<=tiny(1.0_real64).and.committed%matrix_mass_mg_cm2>0.0_real64).or. &
       any(macro_water_start<=tiny(1.0_real64).and.committed%macro_mass_mg_cm2>0.0_real64))return

    tol=512.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(matrix_volume_start), &
         maxval(matrix_water_end*node_thickness_cm),maxval(macro_water_start),maxval(macro_water_end), &
         dt_day*maxval(abs(matrix_face_rate)),dt_day*maxval(abs(macro_face_rate)), &
         dt_day*maxval(abs(exchange_rate)),dt_day*maxval(root_water_sink))
    do i=1,n
      water_expected=dt_day*(matrix_face_rate(i)-matrix_face_rate(i+1)+sum(exchange_rate(:,i))-root_water_sink(i))
      if(abs((matrix_water_end(i)-matrix_water_start(i))*node_thickness_cm(i)-water_expected)>tol)then
        status=MACRO_SALT_WATER_CLOSURE;return
      end if
      do d=1,nd
        water_expected=dt_day*(macro_face_rate(d,i)-macro_face_rate(d,i+1)-exchange_rate(d,i))
        if(abs(macro_water_end(d,i)-macro_water_start(d,i)-water_expected)>tol)then
          status=MACRO_SALT_WATER_CLOSURE;return
        end if
      end do
    end do

    allocate(cm(n),cp(nd,n),dm(n),dp(nd,n),outm(n),outp(nd,n))
    cm=0.0_real64
    where(matrix_volume_start>0.0_real64) cm=committed%matrix_mass_mg_cm2/matrix_volume_start
    cp=0.0_real64
    where(macro_water_start>0.0_real64) cp=committed%macro_mass_mg_cm2/macro_water_start
    dm=0.0_real64;dp=0.0_real64;outm=0.0_real64;outp=0.0_real64
    allocate(receipt%macro_top_input_mg_cm2(nd),receipt%macro_top_output_mg_cm2(nd), &
         receipt%macro_bottom_input_mg_cm2(nd),receipt%macro_bottom_output_mg_cm2(nd), &
         receipt%root_solute_uptake_mg_cm2(n))
    receipt%macro_top_input_mg_cm2=0.0_real64;receipt%macro_top_output_mg_cm2=0.0_real64
    receipt%macro_bottom_input_mg_cm2=0.0_real64;receipt%macro_bottom_output_mg_cm2=0.0_real64
    receipt%root_solute_uptake_mg_cm2=0.0_real64

    ! Matrix vertical faces, including explicit surface and bottom boundaries.
    q=matrix_face_rate(1)*dt_day
    if(q>=0.0_real64)then
      amount=q*matrix_top_concentration;dm(1)=dm(1)+amount;receipt%matrix_top_input_mg_cm2=amount
    else
      amount=-q*cm(1);dm(1)=dm(1)-amount;outm(1)=outm(1)-q
      receipt%matrix_top_output_mg_cm2=amount
    end if
    do i=1,n-1
      q=matrix_face_rate(i+1)*dt_day
      if(q>=0.0_real64)then
        amount=q*cm(i);dm(i)=dm(i)-amount;dm(i+1)=dm(i+1)+amount;outm(i)=outm(i)+q
      else
        amount=-q*cm(i+1);dm(i+1)=dm(i+1)-amount;dm(i)=dm(i)+amount;outm(i+1)=outm(i+1)-q
      end if
    end do
    q=matrix_face_rate(n+1)*dt_day
    if(q>=0.0_real64)then
      amount=q*cm(n);dm(n)=dm(n)-amount;outm(n)=outm(n)+q;receipt%matrix_bottom_output_mg_cm2=amount
    else
      amount=-q*matrix_bottom_concentration;dm(n)=dm(n)+amount;receipt%matrix_bottom_input_mg_cm2=amount
    end if

    do d=1,nd
      q=macro_face_rate(d,1)*dt_day
      if(q>=0.0_real64)then
        amount=q*macro_top_concentration(d);dp(d,1)=dp(d,1)+amount
        receipt%macro_top_input_mg_cm2(d)=amount
      else
        amount=-q*cp(d,1);dp(d,1)=dp(d,1)-amount;outp(d,1)=outp(d,1)-q
        receipt%macro_top_output_mg_cm2(d)=amount
      end if
      do i=1,n-1
        q=macro_face_rate(d,i+1)*dt_day
        if(q>=0.0_real64)then
          amount=q*cp(d,i);dp(d,i)=dp(d,i)-amount;dp(d,i+1)=dp(d,i+1)+amount;outp(d,i)=outp(d,i)+q
        else
          amount=-q*cp(d,i+1);dp(d,i+1)=dp(d,i+1)-amount;dp(d,i)=dp(d,i)+amount;outp(d,i+1)=outp(d,i+1)-q
        end if
      end do
      q=macro_face_rate(d,n+1)*dt_day
      if(q>=0.0_real64)then
        amount=q*cp(d,n);dp(d,n)=dp(d,n)-amount;outp(d,n)=outp(d,n)+q
        receipt%macro_bottom_output_mg_cm2(d)=amount
      else
        amount=-q*macro_bottom_concentration(d);dp(d,n)=dp(d,n)+amount
        receipt%macro_bottom_input_mg_cm2(d)=amount
      end if
    end do

    ! One synchronized donor snapshot makes exchange conservative and avoids
    ! dependence on loop order when multiple macro domains meet a matrix node.
    do i=1,n
      do d=1,nd
        q=exchange_rate(d,i)*dt_day
        if(q>0.0_real64)then
          amount=q*cp(d,i);dp(d,i)=dp(d,i)-amount;dm(i)=dm(i)+amount;outp(d,i)=outp(d,i)+q
        else if(q<0.0_real64)then
          amount=-q*cm(i);dm(i)=dm(i)-amount;dp(d,i)=dp(d,i)+amount;outm(i)=outm(i)-q
        end if
      end do
      root_salt=tscf*root_water_sink(i)*dt_day*cm(i)
      dm(i)=dm(i)-root_salt;outm(i)=outm(i)+root_water_sink(i)*dt_day
      receipt%root_solute_uptake_mg_cm2(i)=root_salt
    end do

    if(any(outm>matrix_volume_start+tol).or.any(outp>macro_water_start+tol))then
      status=MACRO_SALT_DONOR_UNAVAILABLE;return
    end if
    candidate%matrix_mass_mg_cm2=committed%matrix_mass_mg_cm2+dm
    candidate%macro_mass_mg_cm2=committed%macro_mass_mg_cm2+dp
    if(any(.not.ieee_is_finite(candidate%matrix_mass_mg_cm2)).or. &
       any(.not.ieee_is_finite(candidate%macro_mass_mg_cm2)))then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_INVALID;return
    end if
    if(any(candidate%matrix_mass_mg_cm2 < -tol).or.any(candidate%macro_mass_mg_cm2 < -tol))then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_DONOR_UNAVAILABLE;return
    end if
    if(any(candidate%matrix_mass_mg_cm2<0.0_real64).or.any(candidate%macro_mass_mg_cm2<0.0_real64))then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_DONOR_UNAVAILABLE;return
    end if
    if(any(matrix_water_end*node_thickness_cm<=tiny(1.0_real64).and.candidate%matrix_mass_mg_cm2>0.0_real64).or. &
       any(macro_water_end<=tiny(1.0_real64).and.candidate%macro_mass_mg_cm2>0.0_real64))then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_DONOR_UNAVAILABLE;return
    end if
    total_before=sum(committed%matrix_mass_mg_cm2)+sum(committed%macro_mass_mg_cm2)
    total_after=sum(candidate%matrix_mass_mg_cm2)+sum(candidate%macro_mass_mg_cm2)
    receipt%closure_error_mg_cm2=total_after-total_before-receipt%matrix_top_input_mg_cm2+ &
         receipt%matrix_top_output_mg_cm2-receipt%matrix_bottom_input_mg_cm2+ &
         receipt%matrix_bottom_output_mg_cm2-sum(receipt%macro_top_input_mg_cm2)+ &
         sum(receipt%macro_top_output_mg_cm2)-sum(receipt%macro_bottom_input_mg_cm2)+ &
         sum(receipt%macro_bottom_output_mg_cm2)+sum(receipt%root_solute_uptake_mg_cm2)
    tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(total_before),abs(total_after))
    if(abs(receipt%closure_error_mg_cm2)>tol)then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_BALANCE_FAILURE;return
    end if
    status=MACRO_SALT_OK
  end subroutine advance_mobile_macro_salt_trial

end module mod_solute_mobile_macro_salt_transport
