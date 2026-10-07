module mod_drainage_discharge_layer_transform
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: DISLAYER_OK=0, DISLAYER_INVALID=1, DISLAYER_GEOMETRY=2
  real(real64), parameter :: SMALL_SUM=1.0e-8_real64

  type, public :: discharge_layer_diagnostics_t
    integer :: status=DISLAYER_INVALID
    logical :: evaluated=.false.
    integer :: top_node=0
    real(real64) :: top_fraction=0.0_real64
    real(real64) :: retained_before_scale=0.0_real64
    real(real64) :: scale=0.0_real64
    logical :: small_retained_fallback=.false.
  end type

  public :: derive_dynamic_discharge_layer_top
  public :: apply_discharge_layer_top

contains

  pure subroutine derive_dynamic_discharge_layer_top(dramet, fraction, groundwater_level, drain_bottom, shape, &
       head_difference, top_level, status)
    integer,intent(in)::dramet
    real(real64),intent(in)::fraction,groundwater_level,drain_bottom,shape,head_difference
    real(real64),intent(out)::top_level
    integer,intent(out)::status
    status=DISLAYER_INVALID;top_level=0.0_real64
    if(.not.all(ieee_is_finite([fraction,groundwater_level,drain_bottom,shape,head_difference])))return
    if(fraction<0.0_real64.or.fraction>1.0_real64)return
    select case(dramet)
    case(2)
      if(shape<=0.0_real64)return
      top_level=fraction*((groundwater_level-drain_bottom)/shape+drain_bottom) + &
           (1.0_real64-fraction)*drain_bottom
    case default
      top_level=fraction*groundwater_level + (1.0_real64-fraction)*(groundwater_level-head_difference)
    end select
    if(.not.ieee_is_finite(top_level))return
    status=DISLAYER_OK
  end subroutine

  pure subroutine apply_discharge_layer_top(dz, top_level, authoritative_scalar, nodal_rate, diagnostics)
    real(real64),intent(in)::dz(:),top_level,authoritative_scalar
    real(real64),intent(inout)::nodal_rate(:)
    type(discharge_layer_diagnostics_t),intent(out)::diagnostics
    integer::n,i,top_node
    real(real64)::zbottom,diff_top,ratio_dz,sumq,ratio

    diagnostics=discharge_layer_diagnostics_t()
    n=size(dz)
    if(n<1.or.size(nodal_rate)/=n)return
    if(any(.not.ieee_is_finite(dz)).or.any(dz<=0.0_real64))return
    if(any(.not.ieee_is_finite(nodal_rate)).or..not.ieee_is_finite(top_level).or. &
       .not.ieee_is_finite(authoritative_scalar))return
    if(top_level>0.0_real64)return

    top_node=1
    zbottom=-dz(1)
    do while(top_level<zbottom)
      top_node=top_node+1
      if(top_node>n)then
        diagnostics%status=DISLAYER_GEOMETRY;return
      end if
      zbottom=zbottom-dz(top_node)
    end do
    diff_top=top_level-zbottom
    ratio_dz=diff_top/dz(top_node)
    if(ratio_dz<0.0_real64.or.ratio_dz>1.0_real64)then
      diagnostics%status=DISLAYER_GEOMETRY;return
    end if

    sumq=ratio_dz*nodal_rate(top_node)
    if(top_node<n)sumq=sumq+sum(nodal_rate(top_node+1:n))
    if(abs(sumq)<SMALL_SUM)then
      ratio=1.0_real64
    else
      ratio=authoritative_scalar/sumq
    end if

    if(top_node>1)nodal_rate(1:top_node-1)=0.0_real64
    nodal_rate(top_node)=nodal_rate(top_node)*ratio*ratio_dz
    if(top_node<n)nodal_rate(top_node+1:n)=nodal_rate(top_node+1:n)*ratio
    if(abs(sumq)<SMALL_SUM.and.abs(authoritative_scalar)>SMALL_SUM)then
      nodal_rate(top_node)=authoritative_scalar
      diagnostics%small_retained_fallback=.true.
    end if

    diagnostics%status=DISLAYER_OK
    diagnostics%evaluated=.true.
    diagnostics%top_node=top_node
    diagnostics%top_fraction=ratio_dz
    diagnostics%retained_before_scale=sumq
    diagnostics%scale=ratio
  end subroutine

end module mod_drainage_discharge_layer_transform
