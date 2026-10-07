module mod_drainage_discharge_layer_top
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_TOP_OK=0
  integer, parameter, public :: DRAIN_TOP_INVALID_PARAMETERS=1
  integer, parameter, public :: DRAIN_TOP_INVALID_HYDRAULIC_VIEW=2
  integer, parameter, public :: DRAIN_TOP_INVALID_CONTROL=3
  integer, parameter, public :: DRAIN_TOP_INVALID_INPUT=4

  integer, parameter, public :: DRAIN_TOP_ABSOLUTE=1
  integer, parameter, public :: DRAIN_TOP_RELATIVE=2
  integer, parameter, public :: DRAIN_TOP_SOURCE_OTHER=0
  integer, parameter, public :: DRAIN_TOP_SOURCE_DRAMET2=2

  real(real64), parameter :: SOURCE_SMALL_SUM=1.0e-8_real64

  type, public :: drainage_discharge_layer_top_control_t
    logical :: active=.false.
    integer :: mode=DRAIN_TOP_ABSOLUTE
    integer :: source_family=DRAIN_TOP_SOURCE_OTHER
    real(real64) :: absolute_top_level_cm=0.0_real64
    real(real64) :: top_fraction=0.0_real64
    real(real64) :: drain_bottom_cm=0.0_real64
    real(real64) :: shape=1.0_real64
    real(real64) :: source_head_difference_cm=0.0_real64
  end type

  type, public :: drainage_discharge_layer_top_diagnostics_t
    integer :: status=DRAIN_TOP_OK
    logical :: evaluated=.false.
    real(real64) :: resolved_top_level_cm=0.0_real64
    integer :: top_node=0
    real(real64) :: retained_top_fraction=0.0_real64
    real(real64) :: pre_rescale_sum=0.0_real64
    real(real64) :: source_ratio=1.0_real64
    real(real64) :: closure_correction=0.0_real64
    logical :: small_sum_fallback=.false.
    logical :: scalar_transfer_is_authoritative=.true.
    logical :: persistent_process_state=.false.
  end type

  public :: redistribute_discharge_layer_top

contains

  subroutine redistribute_discharge_layer_top(dz,scalar_transfer,control,view,input_row,output_row,diagnostics)
    real(real64),intent(in)::dz(:),scalar_transfer
    type(drainage_discharge_layer_top_control_t),intent(in)::control
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::input_row(:)
    real(real64),allocatable,intent(out)::output_row(:)
    type(drainage_discharge_layer_top_diagnostics_t),intent(out)::diagnostics
    real(real64)::ztop,depth_bottom,difztop,ratiodz,sumqdr,ratio,raw_sum
    integer::n,top_node,last,i

    diagnostics=drainage_discharge_layer_top_diagnostics_t()
    n=size(dz)
    if(n<1.or.size(input_row)/=n)then
      diagnostics%status=DRAIN_TOP_INVALID_INPUT
      return
    end if
    if(any(.not.ieee_is_finite(dz)).or.any(dz<=0.0_real64).or. &
         any(.not.ieee_is_finite(input_row)).or..not.ieee_is_finite(scalar_transfer))then
      diagnostics%status=DRAIN_TOP_INVALID_PARAMETERS
      return
    end if
    allocate(output_row(n))
    output_row=input_row
    if(.not.control%active)then
      diagnostics%evaluated=.true.
      return
    end if
    if(.not.ieee_is_finite(view%groundwater_level))then
      diagnostics%status=DRAIN_TOP_INVALID_HYDRAULIC_VIEW
      return
    end if

    select case(control%mode)
    case(DRAIN_TOP_ABSOLUTE)
      if(.not.ieee_is_finite(control%absolute_top_level_cm))then
        diagnostics%status=DRAIN_TOP_INVALID_CONTROL
        return
      end if
      ztop=control%absolute_top_level_cm
    case(DRAIN_TOP_RELATIVE)
      if(.not.all(ieee_is_finite([control%top_fraction,control%drain_bottom_cm, &
           control%shape,control%source_head_difference_cm])))then
        diagnostics%status=DRAIN_TOP_INVALID_CONTROL
        return
      end if
      if(control%top_fraction<0.0_real64.or.control%top_fraction>1.0_real64)then
        diagnostics%status=DRAIN_TOP_INVALID_CONTROL
        return
      end if
      if(control%source_family==DRAIN_TOP_SOURCE_DRAMET2)then
        if(.not.(abs(control%shape)>0.0_real64))then
          diagnostics%status=DRAIN_TOP_INVALID_CONTROL
          return
        end if
        ztop=control%top_fraction*((view%groundwater_level-control%drain_bottom_cm)/control%shape+ &
             control%drain_bottom_cm)+(1.0_real64-control%top_fraction)*control%drain_bottom_cm
      else
        ztop=control%top_fraction*view%groundwater_level+(1.0_real64-control%top_fraction)* &
             (view%groundwater_level-control%source_head_difference_cm)
      end if
    case default
      diagnostics%status=DRAIN_TOP_INVALID_CONTROL
      return
    end select

    depth_bottom=-sum(dz)
    if(ztop>0.0_real64.or.ztop<depth_bottom)then
      diagnostics%status=DRAIN_TOP_INVALID_CONTROL
      return
    end if

    top_node=1
    depth_bottom=-dz(1)
    do while(ztop<depth_bottom)
      top_node=top_node+1
      if(top_node>n)then
        diagnostics%status=DRAIN_TOP_INVALID_CONTROL
        return
      end if
      depth_bottom=depth_bottom-dz(top_node)
    end do
    difztop=ztop-depth_bottom
    ratiodz=difztop/dz(top_node)
    sumqdr=ratiodz*input_row(top_node)
    if(top_node<n)sumqdr=sumqdr+sum(input_row(top_node+1:n))
    if(abs(sumqdr)<SOURCE_SMALL_SUM)then
      ratio=1.0_real64
      diagnostics%small_sum_fallback=.true.
    else
      ratio=scalar_transfer/sumqdr
    end if

    if(top_node>1)output_row(1:top_node-1)=0.0_real64
    output_row(top_node)=input_row(top_node)*ratio*ratiodz
    if(top_node<n)output_row(top_node+1:n)=input_row(top_node+1:n)*ratio
    if(abs(sumqdr)<SOURCE_SMALL_SUM.and.abs(scalar_transfer)>SOURCE_SMALL_SUM)then
      output_row(top_node)=scalar_transfer
      if(top_node<n)output_row(top_node+1:n)=0.0_real64
    end if

    raw_sum=sum(output_row)
    last=0
    do i=n,1,-1
      if(abs(output_row(i))>0.0_real64)then
        last=i
        exit
      end if
    end do
    if(last==0.and.abs(scalar_transfer)>0.0_real64)last=top_node
    if(last>0)then
      diagnostics%closure_correction=scalar_transfer-raw_sum
      output_row(last)=output_row(last)+diagnostics%closure_correction
    end if

    diagnostics%evaluated=.true.
    diagnostics%resolved_top_level_cm=ztop
    diagnostics%top_node=top_node
    diagnostics%retained_top_fraction=ratiodz
    diagnostics%pre_rescale_sum=sumqdr
    diagnostics%source_ratio=ratio
  end subroutine
end module
