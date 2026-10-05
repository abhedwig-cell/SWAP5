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
    real(real64), allocatable :: macro_to_matrix_mg_cm2(:,:), matrix_to_macro_mg_cm2(:,:)
    real(real64), allocatable :: root_solute_uptake_mg_cm2(:)
    real(real64), allocatable :: qdra_signed_out_mg_cm2(:)
    real(real64) :: closure_error_mg_cm2=0.0_real64
  end type

  type, public :: mobile_macro_salt_substep_t
    real(real64) :: t0=0.0_real64,t1=0.0_real64
    real(real64) :: matrix_top_concentration_mg_cm3=0.0_real64
    real(real64) :: matrix_bottom_concentration_mg_cm3=0.0_real64
    real(real64), allocatable :: matrix_water_start(:),matrix_water_end(:)
    real(real64), allocatable :: macro_water_start(:,:),macro_water_end(:,:)
    real(real64), allocatable :: matrix_face_rate(:),macro_face_rate(:,:),exchange_rate(:,:)
    real(real64), allocatable :: root_water_sink(:),macro_top_concentration_mg_cm3(:)
    real(real64), allocatable :: macro_bottom_concentration_mg_cm3(:)
  end type

  public :: initialize_mobile_macro_salt_state, derive_mobile_macro_salt_concentration
  public :: advance_mobile_macro_salt_trial, advance_mobile_macro_salt_trace
  public :: advance_mobile_macro_salt_drainage

contains

  ! Initializes separate matrix and per-domain macro salt inventories from a
  ! concentration profile and the matching accepted liquid-water volumes.
  ! Matrix water is theta times node thickness; macro water is already depth.
  subroutine initialize_mobile_macro_salt_state(node_thickness_cm,matrix_water_content,macro_water_cm, &
       matrix_concentration_mg_cm3,macro_concentration_mg_cm3,state,status)
    real(real64), intent(in) :: node_thickness_cm(:),matrix_water_content(:),macro_water_cm(:,:)
    real(real64), intent(in) :: matrix_concentration_mg_cm3(:),macro_concentration_mg_cm3(:,:)
    type(mobile_macro_salt_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: n,nd

    state=mobile_macro_salt_state_t();status=MACRO_SALT_INVALID
    n=size(node_thickness_cm);nd=size(macro_water_cm,1)
    if(n<=0.or.nd<=0.or.size(matrix_water_content)/=n.or.size(matrix_concentration_mg_cm3)/=n.or. &
       size(macro_water_cm,2)/=n.or.any(shape(macro_concentration_mg_cm3)/=[nd,n]))return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(matrix_water_content)).or. &
       .not.all(ieee_is_finite(macro_water_cm)).or..not.all(ieee_is_finite(matrix_concentration_mg_cm3)).or. &
       .not.all(ieee_is_finite(macro_concentration_mg_cm3)))return
    if(any(node_thickness_cm<=0.0_real64).or.any(matrix_water_content<0.0_real64).or. &
       any(macro_water_cm<0.0_real64).or.any(matrix_concentration_mg_cm3<0.0_real64).or. &
       any(macro_concentration_mg_cm3<0.0_real64))return
    state%matrix_mass_mg_cm2=matrix_concentration_mg_cm3*matrix_water_content*node_thickness_cm
    state%macro_mass_mg_cm2=macro_concentration_mg_cm3*macro_water_cm
    if(any(.not.ieee_is_finite(state%matrix_mass_mg_cm2)).or. &
       any(.not.ieee_is_finite(state%macro_mass_mg_cm2)))then
      state=mobile_macro_salt_state_t();return
    end if
    status=MACRO_SALT_OK
  end subroutine initialize_mobile_macro_salt_state

  ! Builds a read-only concentration view from a matching candidate mass and
  ! water state. Zero-water/zero-mass compartments report zero concentration;
  ! positive inventory in a dry compartment is rejected.
  subroutine derive_mobile_macro_salt_concentration(state,node_thickness_cm,matrix_water_content,macro_water_cm, &
       matrix_concentration_mg_cm3,macro_concentration_mg_cm3,status)
    type(mobile_macro_salt_state_t), intent(in) :: state
    real(real64), intent(in) :: node_thickness_cm(:),matrix_water_content(:),macro_water_cm(:,:)
    real(real64), allocatable, intent(out) :: matrix_concentration_mg_cm3(:),macro_concentration_mg_cm3(:,:)
    integer, intent(out) :: status
    real(real64), allocatable :: matrix_volume_cm(:)
    integer :: n,nd

    status=MACRO_SALT_INVALID
    n=size(node_thickness_cm);nd=size(macro_water_cm,1)
    if(n<=0.or.nd<=0.or.size(matrix_water_content)/=n.or.size(macro_water_cm,2)/=n)return
    if(.not.allocated(state%matrix_mass_mg_cm2).or..not.allocated(state%macro_mass_mg_cm2))return
    if(size(state%matrix_mass_mg_cm2)/=n.or.any(shape(state%macro_mass_mg_cm2)/=[nd,n]))return
    if(.not.all(ieee_is_finite(node_thickness_cm)).or..not.all(ieee_is_finite(matrix_water_content)).or. &
       .not.all(ieee_is_finite(macro_water_cm)).or..not.all(ieee_is_finite(state%matrix_mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(state%macro_mass_mg_cm2)))return
    if(any(node_thickness_cm<=0.0_real64).or.any(matrix_water_content<0.0_real64).or. &
       any(macro_water_cm<0.0_real64).or.any(state%matrix_mass_mg_cm2<0.0_real64).or. &
       any(state%macro_mass_mg_cm2<0.0_real64))return
    allocate(matrix_volume_cm(n))
    matrix_volume_cm=matrix_water_content*node_thickness_cm
    if(any(matrix_volume_cm<=tiny(1.0_real64).and.state%matrix_mass_mg_cm2>0.0_real64).or. &
       any(macro_water_cm<=tiny(1.0_real64).and.state%macro_mass_mg_cm2>0.0_real64))return
    allocate(matrix_concentration_mg_cm3(n),macro_concentration_mg_cm3(nd,n))
    matrix_concentration_mg_cm3=0.0_real64;macro_concentration_mg_cm3=0.0_real64
    where(matrix_volume_cm>tiny(1.0_real64)) &
       matrix_concentration_mg_cm3=state%matrix_mass_mg_cm2/matrix_volume_cm
    where(macro_water_cm>tiny(1.0_real64)) &
       macro_concentration_mg_cm3=state%macro_mass_mg_cm2/macro_water_cm
    if(any(.not.ieee_is_finite(matrix_concentration_mg_cm3)).or. &
       any(.not.ieee_is_finite(macro_concentration_mg_cm3)))then
      deallocate(matrix_concentration_mg_cm3,macro_concentration_mg_cm3);return
    end if
    status=MACRO_SALT_OK
  end subroutine derive_mobile_macro_salt_concentration

  ! Applies a contiguous ordered sequence of accepted water substeps to one
  ! salt candidate. A later failure clears the full candidate and all receipts.
  subroutine advance_mobile_macro_salt_trace(committed,node_thickness_cm,substeps,tscf,candidate,receipt,status)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: node_thickness_cm(:),tscf
    type(mobile_macro_salt_substep_t), intent(in) :: substeps(:)
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    type(mobile_macro_salt_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status
    type(mobile_macro_salt_state_t) :: current,next
    type(mobile_macro_salt_receipt_t) :: step_receipt
    real(real64) :: tolerance
    integer :: i,n,nd

    candidate=mobile_macro_salt_state_t();receipt=mobile_macro_salt_receipt_t();status=MACRO_SALT_INVALID
    n=size(node_thickness_cm)
    if(size(substeps)==0.or.n<=0)return
    do i=1,size(substeps)
      if(.not.allocated(substeps(i)%matrix_water_start).or..not.allocated(substeps(i)%matrix_water_end).or. &
         .not.allocated(substeps(i)%macro_water_start).or..not.allocated(substeps(i)%macro_water_end).or. &
         .not.allocated(substeps(i)%matrix_face_rate).or..not.allocated(substeps(i)%macro_face_rate).or. &
         .not.allocated(substeps(i)%exchange_rate).or..not.allocated(substeps(i)%root_water_sink).or. &
         .not.allocated(substeps(i)%macro_top_concentration_mg_cm3).or. &
         .not.allocated(substeps(i)%macro_bottom_concentration_mg_cm3))return
    end do
    nd=size(substeps(1)%macro_water_start,1)
    if(nd<=0)return
    do i=1,size(substeps)
      if(size(substeps(i)%matrix_water_start)/=n.or.size(substeps(i)%matrix_water_end)/=n.or. &
         any(shape(substeps(i)%macro_water_start)/=[nd,n]).or.any(shape(substeps(i)%macro_water_end)/=[nd,n]).or. &
         size(substeps(i)%matrix_face_rate)/=n+1.or.any(shape(substeps(i)%macro_face_rate)/=[nd,n+1]).or. &
         any(shape(substeps(i)%exchange_rate)/=[nd,n]).or.size(substeps(i)%root_water_sink)/=n.or. &
         size(substeps(i)%macro_top_concentration_mg_cm3)/=nd.or. &
         size(substeps(i)%macro_bottom_concentration_mg_cm3)/=nd)return
      if(.not.ieee_is_finite(substeps(i)%t0).or..not.ieee_is_finite(substeps(i)%t1).or. &
         substeps(i)%t1<=substeps(i)%t0)return
    end do
    do i=2,size(substeps)
      tolerance=128.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(substeps(i)%t0),abs(substeps(i-1)%t1))
      if(abs(substeps(i)%t0-substeps(i-1)%t1)>tolerance)return
      tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
           maxval(abs(substeps(i)%matrix_water_start)),maxval(abs(substeps(i-1)%matrix_water_end)))
      if(any(abs(substeps(i)%matrix_water_start-substeps(i-1)%matrix_water_end)>tolerance))then
        status=MACRO_SALT_WATER_CLOSURE;return
      end if
      tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64, &
           maxval(abs(substeps(i)%macro_water_start)),maxval(abs(substeps(i-1)%macro_water_end)))
      if(any(abs(substeps(i)%macro_water_start-substeps(i-1)%macro_water_end)>tolerance))then
        status=MACRO_SALT_WATER_CLOSURE;return
      end if
    end do

    allocate(receipt%macro_top_input_mg_cm2(nd),receipt%macro_top_output_mg_cm2(nd), &
         receipt%macro_bottom_input_mg_cm2(nd),receipt%macro_bottom_output_mg_cm2(nd), &
         receipt%macro_to_matrix_mg_cm2(nd,n),receipt%matrix_to_macro_mg_cm2(nd,n), &
         receipt%root_solute_uptake_mg_cm2(n))
    receipt%macro_top_input_mg_cm2=0.0_real64;receipt%macro_top_output_mg_cm2=0.0_real64
    receipt%macro_bottom_input_mg_cm2=0.0_real64;receipt%macro_bottom_output_mg_cm2=0.0_real64
    receipt%macro_to_matrix_mg_cm2=0.0_real64;receipt%matrix_to_macro_mg_cm2=0.0_real64
    receipt%root_solute_uptake_mg_cm2=0.0_real64
    current=committed
    do i=1,size(substeps)
      call advance_mobile_macro_salt_trial(current,node_thickness_cm,substeps(i)%matrix_water_start, &
           substeps(i)%matrix_water_end,substeps(i)%macro_water_start,substeps(i)%macro_water_end, &
           substeps(i)%matrix_face_rate,substeps(i)%macro_face_rate,substeps(i)%exchange_rate, &
           substeps(i)%root_water_sink,substeps(i)%matrix_top_concentration_mg_cm3, &
           substeps(i)%matrix_bottom_concentration_mg_cm3,substeps(i)%macro_top_concentration_mg_cm3, &
           substeps(i)%macro_bottom_concentration_mg_cm3,tscf,substeps(i)%t1-substeps(i)%t0,next, &
           step_receipt,status)
      if(status/=MACRO_SALT_OK)then
        candidate=mobile_macro_salt_state_t();receipt=mobile_macro_salt_receipt_t();return
      end if
      current=next
      receipt%matrix_top_input_mg_cm2=receipt%matrix_top_input_mg_cm2+step_receipt%matrix_top_input_mg_cm2
      receipt%matrix_top_output_mg_cm2=receipt%matrix_top_output_mg_cm2+step_receipt%matrix_top_output_mg_cm2
      receipt%matrix_bottom_input_mg_cm2=receipt%matrix_bottom_input_mg_cm2+step_receipt%matrix_bottom_input_mg_cm2
      receipt%matrix_bottom_output_mg_cm2=receipt%matrix_bottom_output_mg_cm2+step_receipt%matrix_bottom_output_mg_cm2
      receipt%macro_top_input_mg_cm2=receipt%macro_top_input_mg_cm2+step_receipt%macro_top_input_mg_cm2
      receipt%macro_top_output_mg_cm2=receipt%macro_top_output_mg_cm2+step_receipt%macro_top_output_mg_cm2
      receipt%macro_bottom_input_mg_cm2=receipt%macro_bottom_input_mg_cm2+step_receipt%macro_bottom_input_mg_cm2
      receipt%macro_bottom_output_mg_cm2=receipt%macro_bottom_output_mg_cm2+step_receipt%macro_bottom_output_mg_cm2
      receipt%macro_to_matrix_mg_cm2=receipt%macro_to_matrix_mg_cm2+step_receipt%macro_to_matrix_mg_cm2
      receipt%matrix_to_macro_mg_cm2=receipt%matrix_to_macro_mg_cm2+step_receipt%matrix_to_macro_mg_cm2
      receipt%root_solute_uptake_mg_cm2=receipt%root_solute_uptake_mg_cm2+step_receipt%root_solute_uptake_mg_cm2
      receipt%closure_error_mg_cm2=receipt%closure_error_mg_cm2+step_receipt%closure_error_mg_cm2
      if(.not.all(ieee_is_finite([receipt%matrix_top_input_mg_cm2,receipt%matrix_top_output_mg_cm2, &
         receipt%matrix_bottom_input_mg_cm2,receipt%matrix_bottom_output_mg_cm2,receipt%closure_error_mg_cm2])).or. &
         .not.all(ieee_is_finite(receipt%macro_top_input_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%macro_top_output_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%macro_bottom_input_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%macro_bottom_output_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%macro_to_matrix_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%matrix_to_macro_mg_cm2)).or. &
         .not.all(ieee_is_finite(receipt%root_solute_uptake_mg_cm2)))then
        candidate=mobile_macro_salt_state_t();receipt=mobile_macro_salt_receipt_t();status=MACRO_SALT_INVALID;return
      end if
    end do
    candidate=current
  end subroutine advance_mobile_macro_salt_trace

  ! Conservative explicit-advection candidate for one accepted water substep.
  ! All mobile compartments use donor concentrations from the committed start
  ! state. Positive vertical face rate is downward; positive exchange is macro
  ! to matrix. The routine owns salt only and never changes committed input.
  subroutine advance_mobile_macro_salt_trial(committed,node_thickness_cm,matrix_water_start,matrix_water_end, &
       macro_water_start,macro_water_end,matrix_face_rate,macro_face_rate,exchange_rate,root_water_sink, &
       matrix_top_concentration,matrix_bottom_concentration,macro_top_concentration,macro_bottom_concentration, &
       tscf,dt_day,candidate,receipt,status,qdra_rate,qssdi_rate,cdrain_mg_cm3,cdrain_available)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: node_thickness_cm(:),matrix_water_start(:),matrix_water_end(:)
    real(real64), intent(in) :: macro_water_start(:,:),macro_water_end(:,:)
    real(real64), intent(in) :: matrix_face_rate(:),macro_face_rate(:,:),exchange_rate(:,:),root_water_sink(:)
    real(real64), intent(in) :: matrix_top_concentration,matrix_bottom_concentration
    real(real64), intent(in) :: macro_top_concentration(:),macro_bottom_concentration(:),tscf,dt_day
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    type(mobile_macro_salt_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status
    real(real64), intent(in), optional :: qdra_rate(:,:),qssdi_rate(:),cdrain_mg_cm3
    logical, intent(in), optional :: cdrain_available
    real(real64), allocatable :: cm(:),cp(:,:),dm(:),dp(:,:),outm(:),outp(:,:),matrix_volume_start(:)
    real(real64) :: q,amount,root_salt,total_before,total_after,tol,water_expected,drain_c,drainage_export
    logical :: has_drain_c
    integer :: n,nd,i,d

    candidate=mobile_macro_salt_state_t(); receipt=mobile_macro_salt_receipt_t(); status=MACRO_SALT_INVALID
    n=size(matrix_water_start); nd=size(macro_water_start,1)
    if(n<=0.or.nd<=0.or.size(node_thickness_cm)/=n.or.size(matrix_water_end)/=n.or.size(root_water_sink)/=n.or. &
       size(matrix_face_rate)/=n+1.or.any(shape(macro_water_end)/=[nd,n]).or. &
       any(shape(exchange_rate)/=[nd,n]).or.any(shape(macro_face_rate)/=[nd,n+1]).or. &
       size(macro_top_concentration)/=nd.or.size(macro_bottom_concentration)/=nd)return
    if(.not.allocated(committed%matrix_mass_mg_cm2).or..not.allocated(committed%macro_mass_mg_cm2))return
    if(size(committed%matrix_mass_mg_cm2)/=n.or.any(shape(committed%macro_mass_mg_cm2)/=[nd,n]))return
    if(present(qdra_rate))then
      if(size(qdra_rate,2)/=n.or..not.all(ieee_is_finite(qdra_rate)))return
      if(any(qdra_rate<0.0_real64))then
        if(.not.present(cdrain_available).or..not.present(cdrain_mg_cm3))return
        if(.not.cdrain_available)return
      end if
    end if
    if(present(qssdi_rate))then
      if(size(qssdi_rate)/=n.or..not.all(ieee_is_finite(qssdi_rate)))return
    end if
    if(present(cdrain_mg_cm3))then
      if(.not.ieee_is_finite(cdrain_mg_cm3).or.cdrain_mg_cm3<0.0_real64)return
    end if
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
    if(present(qdra_rate))tol=max(tol,dt_day*maxval(abs(qdra_rate)))
    if(present(qssdi_rate))tol=max(tol,dt_day*maxval(abs(qssdi_rate)))
    do i=1,n
      water_expected=dt_day*(matrix_face_rate(i)-matrix_face_rate(i+1)+sum(exchange_rate(:,i))-root_water_sink(i))
      if(present(qssdi_rate))water_expected=water_expected+dt_day*qssdi_rate(i)
      if(present(qdra_rate))water_expected=water_expected-dt_day*sum(qdra_rate(:,i))
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
         receipt%macro_to_matrix_mg_cm2(nd,n),receipt%matrix_to_macro_mg_cm2(nd,n), &
         receipt%root_solute_uptake_mg_cm2(n))
    receipt%macro_top_input_mg_cm2=0.0_real64;receipt%macro_top_output_mg_cm2=0.0_real64
    receipt%macro_bottom_input_mg_cm2=0.0_real64;receipt%macro_bottom_output_mg_cm2=0.0_real64
    receipt%macro_to_matrix_mg_cm2=0.0_real64;receipt%matrix_to_macro_mg_cm2=0.0_real64
    receipt%root_solute_uptake_mg_cm2=0.0_real64
    if(present(qdra_rate))then
      allocate(receipt%qdra_signed_out_mg_cm2(size(qdra_rate,1)))
      receipt%qdra_signed_out_mg_cm2=0.0_real64
      drain_c=0.0_real64;has_drain_c=.false.
      if(present(cdrain_mg_cm3))drain_c=cdrain_mg_cm3
      if(present(cdrain_available))has_drain_c=cdrain_available
      if(any(qdra_rate<0.0_real64).and..not.has_drain_c)return
      do i=1,n
        do d=1,size(qdra_rate,1)
          if(qdra_rate(d,i)>0.0_real64)then
            amount=qdra_rate(d,i)*dt_day*cm(i)
            outm(i)=outm(i)+qdra_rate(d,i)*dt_day
          else
            amount=qdra_rate(d,i)*dt_day*drain_c
          end if
          dm(i)=dm(i)-amount
          receipt%qdra_signed_out_mg_cm2(d)=receipt%qdra_signed_out_mg_cm2(d)+amount
        end do
      end do
    end if

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
          receipt%macro_to_matrix_mg_cm2(d,i)=amount
        else if(q<0.0_real64)then
          amount=-q*cm(i);dm(i)=dm(i)-amount;dp(d,i)=dp(d,i)+amount;outm(i)=outm(i)-q
          receipt%matrix_to_macro_mg_cm2(d,i)=amount
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
    drainage_export=0.0_real64
    if(allocated(receipt%qdra_signed_out_mg_cm2))drainage_export=sum(receipt%qdra_signed_out_mg_cm2)
    receipt%closure_error_mg_cm2=total_after-total_before-receipt%matrix_top_input_mg_cm2+ &
         receipt%matrix_top_output_mg_cm2-receipt%matrix_bottom_input_mg_cm2+ &
         receipt%matrix_bottom_output_mg_cm2+drainage_export- &
         sum(receipt%macro_top_input_mg_cm2)+ &
         sum(receipt%macro_top_output_mg_cm2)-sum(receipt%macro_bottom_input_mg_cm2)+ &
         sum(receipt%macro_bottom_output_mg_cm2)+sum(receipt%root_solute_uptake_mg_cm2)
    tol=1024.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(total_before),abs(total_after))
    if(abs(receipt%closure_error_mg_cm2)>tol)then
      candidate=mobile_macro_salt_state_t();status=MACRO_SALT_BALANCE_FAILURE;return
    end if
    status=MACRO_SALT_OK
  end subroutine advance_mobile_macro_salt_trial


  ! Exact B1.11 lateral-drainage donor rule: positive qdra exports at local
  ! CML; negative qdra imports at explicit Cdrain. qssdi has no salt term.
  subroutine advance_mobile_macro_salt_drainage(committed,matrix_water_cm,qdra_rate,cdrain_mg_cm3, &
       cdrain_available,dt_day,candidate,receipt_by_level_mg_cm2,status)
    type(mobile_macro_salt_state_t), intent(in) :: committed
    real(real64), intent(in) :: matrix_water_cm(:),qdra_rate(:,:),cdrain_mg_cm3,dt_day
    logical, intent(in) :: cdrain_available
    type(mobile_macro_salt_state_t), intent(out) :: candidate
    real(real64), allocatable, intent(out) :: receipt_by_level_mg_cm2(:)
    integer, intent(out) :: status
    real(real64), allocatable :: cml(:),level_transfer(:,:),mass_delta(:)
    real(real64) :: amount
    integer :: n,nlev,lev,node
    candidate=mobile_macro_salt_state_t()
    if(allocated(receipt_by_level_mg_cm2)) deallocate(receipt_by_level_mg_cm2)
    status=MACRO_SALT_INVALID
    n=size(matrix_water_cm); nlev=size(qdra_rate,1)
    if(n<=0.or.nlev<=0.or.size(qdra_rate,2)/=n)return
    if(.not.allocated(committed%matrix_mass_mg_cm2).or..not.allocated(committed%macro_mass_mg_cm2))return
    if(size(committed%matrix_mass_mg_cm2)/=n)return
    if(.not.all(ieee_is_finite(matrix_water_cm)).or..not.all(ieee_is_finite(qdra_rate)).or. &
       .not.all(ieee_is_finite(committed%matrix_mass_mg_cm2)).or. &
       .not.all(ieee_is_finite(committed%macro_mass_mg_cm2)).or. &
       .not.ieee_is_finite(cdrain_mg_cm3).or..not.ieee_is_finite(dt_day))return
    if(any(matrix_water_cm<0.0_real64).or.any(committed%matrix_mass_mg_cm2<0.0_real64).or. &
       any(committed%macro_mass_mg_cm2<0.0_real64).or.cdrain_mg_cm3<0.0_real64.or.dt_day<=0.0_real64)return
    if(any(matrix_water_cm<=tiny(1.0_real64).and.committed%matrix_mass_mg_cm2>0.0_real64))return
    if(any(qdra_rate<0.0_real64).and..not.cdrain_available)return
    allocate(cml(n),level_transfer(nlev,n),mass_delta(n),receipt_by_level_mg_cm2(nlev))
    cml=0.0_real64
    where(matrix_water_cm>tiny(1.0_real64)) cml=committed%matrix_mass_mg_cm2/matrix_water_cm
    do lev=1,nlev
      do node=1,n
        if(qdra_rate(lev,node)>0.0_real64)then
          amount=qdra_rate(lev,node)*cml(node)*dt_day
        else
          amount=qdra_rate(lev,node)*cdrain_mg_cm3*dt_day
        end if
        level_transfer(lev,node)=amount
      end do
    end do
    mass_delta=-sum(level_transfer,dim=1)
    if(any(.not.ieee_is_finite(mass_delta)))then
      deallocate(receipt_by_level_mg_cm2);return
    end if
    if(any(committed%matrix_mass_mg_cm2+mass_delta<0.0_real64))then
      deallocate(receipt_by_level_mg_cm2);return
    end if
    receipt_by_level_mg_cm2=sum(level_transfer,dim=2)
    if(any(.not.ieee_is_finite(receipt_by_level_mg_cm2)))then
      deallocate(receipt_by_level_mg_cm2);return
    end if
    candidate=committed
    candidate%matrix_mass_mg_cm2=committed%matrix_mass_mg_cm2+mass_delta
    if(any(.not.ieee_is_finite(candidate%matrix_mass_mg_cm2)))then
      candidate=mobile_macro_salt_state_t()
      deallocate(receipt_by_level_mg_cm2);return
    end if
    status=MACRO_SALT_OK
  end subroutine advance_mobile_macro_salt_drainage

end module mod_solute_mobile_macro_salt_transport
