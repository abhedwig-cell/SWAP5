module mod_drainage_dramet3_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private
  integer, parameter, public :: DRAMET3_OK=0, DRAMET3_INVALID=1, DRAMET3_INTERPOLATION=2, DRAMET3_NUMERICAL=3
  integer, parameter, public :: DRAMET3_TYPE_DRAIN=1, DRAMET3_TYPE_CHANNEL=2
  integer, parameter, public :: DRAMET3_ALLOW_BOTH=1, DRAMET3_INFILTRATION_ONLY=2, DRAMET3_DRAINAGE_ONLY=3

  type, public :: dramet3_level_parameters_t
    real(real64) :: drain_bottom=0.0_real64
    real(real64) :: drainage_resistance=0.0_real64
    real(real64) :: infiltration_resistance=0.0_real64
    integer :: drain_type=DRAMET3_TYPE_DRAIN
    integer :: allocation=DRAMET3_ALLOW_BOTH
    logical :: limit_channel_infiltration=.false.
    logical :: empirical_interflow=.false.
    real(real64) :: interflow_coefficient=0.0_real64
    real(real64) :: interflow_exponent=0.0_real64
    real(real64), allocatable :: control_time(:)
    real(real64), allocatable :: control_level(:)
  end type

  type, public :: dramet3_level_result_t
    integer :: status=DRAMET3_INVALID
    logical :: evaluated=.false.
    real(real64) :: resolved_control_level=0.0_real64
    real(real64) :: head_difference=0.0_real64
    real(real64) :: signed_soil_to_drain_rate=0.0_real64
    logical :: drainage_branch=.false.
    logical :: infiltration_branch=.false.
    logical :: suppressed_by_allocation=.false.
    logical :: infiltration_head_limited=.false.
    logical :: control_clamped_to_bottom=.false.
  end type

  public :: evaluate_dramet3_level

contains

  subroutine evaluate_dramet3_level(p,view,t1900,dt,r)
    type(dramet3_level_parameters_t),intent(in)::p
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::t1900,dt
    type(dramet3_level_result_t),intent(out)::r
    real(real64)::control,diff,q,query
    integer::st
    r=dramet3_level_result_t()
    if(.not.valid_parameters(p))return
    if(.not.ieee_is_finite(view%groundwater_level).or..not.ieee_is_finite(t1900).or..not.ieee_is_finite(dt))return
    query=t1900+dt-1.0_real64
    if(.not.ieee_is_finite(query))then;r%status=DRAMET3_NUMERICAL;return;end if
    call interpolate_clamped(p%control_time,p%control_level,query,control,st)
    if(st/=DRAMET3_OK)then;r%status=st;return;end if
    if(control<p%drain_bottom)then
      control=p%drain_bottom;r%control_clamped_to_bottom=.true.
    end if
    diff=view%groundwater_level-control
    if(.not.ieee_is_finite(diff))then;r%status=DRAMET3_NUMERICAL;return;end if
    r%resolved_control_level=control
    r%head_difference=diff
    if(diff>=0.0_real64)then
      r%drainage_branch=.true.
      if(p%empirical_interflow)then
        q=p%interflow_coefficient*diff**p%interflow_exponent
      else
        q=diff/p%drainage_resistance
      end if
      if(p%allocation==DRAMET3_INFILTRATION_ONLY)then
        q=0.0_real64;r%suppressed_by_allocation=.true.
      end if
    else
      r%infiltration_branch=.true.
      if(p%drain_type==DRAMET3_TYPE_CHANNEL.and.p%limit_channel_infiltration)then
        if(diff<p%drain_bottom-control)then
          diff=p%drain_bottom-control
          r%head_difference=diff
          r%infiltration_head_limited=.true.
        end if
      end if
      if(p%infiltration_resistance<=0.0_real64)then
        r%status=DRAMET3_INVALID;return
      end if
      q=diff/p%infiltration_resistance
      if(p%allocation==DRAMET3_DRAINAGE_ONLY.or.p%drain_bottom>=control)then
        q=0.0_real64;r%suppressed_by_allocation=.true.
      end if
    end if
    if(.not.ieee_is_finite(q))then;r%status=DRAMET3_NUMERICAL;return;end if
    r%signed_soil_to_drain_rate=q
    r%evaluated=.true.;r%status=DRAMET3_OK
  end subroutine

  subroutine interpolate_clamped(x,y,q,v,status)
    real(real64),intent(in)::x(:),y(:),q
    real(real64),intent(out)::v
    integer,intent(out)::status
    integer::i,n
    status=DRAMET3_INTERPOLATION;v=0.0_real64;n=size(x)
    if(n<1.or.size(y)/=n)return
    if(any(.not.ieee_is_finite(x)).or.any(.not.ieee_is_finite(y)))return
    do i=2,n
      if(x(i)<=x(i-1))return
    end do
    if(q<=x(1))then;v=y(1);status=DRAMET3_OK;return;end if
    if(q>=x(n))then;v=y(n);status=DRAMET3_OK;return;end if
    do i=1,n-1
      if(q<=x(i+1))then
        v=y(i)+(q-x(i))*(y(i+1)-y(i))/(x(i+1)-x(i))
        status=DRAMET3_OK;return
      end if
    end do
  end subroutine

  logical function valid_parameters(p) result(ok)
    type(dramet3_level_parameters_t),intent(in)::p
    ok=.false.
    if(.not.ieee_is_finite(p%drain_bottom).or..not.ieee_is_finite(p%drainage_resistance).or. &
       .not.ieee_is_finite(p%infiltration_resistance))return
    if(p%drainage_resistance<=0.0_real64)return
    if(p%drain_type/=DRAMET3_TYPE_DRAIN.and.p%drain_type/=DRAMET3_TYPE_CHANNEL)return
    if(p%allocation<DRAMET3_ALLOW_BOTH.or.p%allocation>DRAMET3_DRAINAGE_ONLY)return
    if(.not.allocated(p%control_time).or..not.allocated(p%control_level))return
    if(size(p%control_time)<1.or.size(p%control_level)/=size(p%control_time))return
    if(p%empirical_interflow)then
      if(.not.ieee_is_finite(p%interflow_coefficient).or..not.ieee_is_finite(p%interflow_exponent))return
      if(p%interflow_coefficient<0.01_real64.or.p%interflow_coefficient>10.0_real64)return
      if(p%interflow_exponent<0.1_real64.or.p%interflow_exponent>1.0_real64)return
    end if
    ok=.true.
  end function

end module mod_drainage_dramet3_response
