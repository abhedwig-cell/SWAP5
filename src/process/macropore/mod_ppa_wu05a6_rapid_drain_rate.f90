module mod_ppa_wu05a6_rapid_drain_rate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: rapid_drain_request_t
    integer :: num_nodes = 0
    integer :: top_water_node = 1
    integer :: bottom_domain_node = 0
    integer :: drain_type = 1
    logical :: enabled = .false.
    real(real64) :: saturated_top_fraction = 1.0_real64
    real(real64) :: water_level_cm = 0.0_real64
    real(real64) :: domain_bottom_cm = 0.0_real64
    real(real64) :: drain_level_cm = 0.0_real64
    real(real64) :: ponding_cm = 0.0_real64
    real(real64) :: step_duration = 0.0_real64
    real(real64) :: area_exponent = 3.0_real64
    real(real64) :: kd_reference = 0.0_real64
    real(real64) :: resistance_reference_day = 0.0_real64
    real(real64) :: flow_reduction = 1.0_real64
    real(real64) :: water_storage_cm = 0.0_real64
    real(real64) :: volume_under_drain_cm = 0.0_real64
    real(real64), allocatable :: diameter(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: volume_main_domain_cp(:)
  contains
    procedure, public :: valid => rapid_drain_request_valid
  end type rapid_drain_request_t

  type, public :: rapid_drain_result_t
    logical :: valid = .false.
    real(real64) :: total_amount_cm = 0.0_real64
    real(real64) :: resistance_day = 0.0_real64
    real(real64), allocatable :: amount_cp_cm(:)
    real(real64), allocatable :: kd_cp(:)
  end type rapid_drain_result_t

  public :: evaluate_rapid_drain, derive_rapid_volume_under_drain

contains

  pure subroutine derive_rapid_volume_under_drain(drain_level,z,dz,volume_main,top_node,bottom_node,volume_under,ok)
    real(real64),intent(in)::drain_level,z(:),dz(:),volume_main(:)
    integer,intent(in)::top_node,bottom_node
    real(real64),intent(out)::volume_under
    logical,intent(out)::ok
    integer::ic,n
    real(real64)::upper,lower,level,fraction,total
    ok=.false.;volume_under=0.0_real64;n=size(z)
    if(n<=0.or.size(dz)/=n.or.size(volume_main)/=n)return
    if(top_node<1.or.bottom_node<top_node.or.bottom_node>n)return
    if(.not.ieee_is_finite(drain_level).or.any(.not.ieee_is_finite(z)).or. &
         any(.not.ieee_is_finite(dz)).or.any(.not.ieee_is_finite(volume_main)))return
    if(any(dz<=0.0_real64).or.any(volume_main<0.0_real64))return
    do ic=2,n
      if(abs(z(ic)+0.5_real64*dz(ic)-(z(ic-1)-0.5_real64*dz(ic-1)))>1.0e-10_real64)return
    end do
    level=drain_level
    if(level>z(1)+0.5_real64*dz(1)+1.0e-10_real64.or. &
         level<z(n)-0.5_real64*dz(n)-1.0e-10_real64)return
    ! Preserve the admitted boundary tolerance and full-cell sum arithmetic.
    do ic=1,n
      upper=z(ic)+0.5_real64*dz(ic);lower=z(ic)-0.5_real64*dz(ic)
      if(abs(level-upper)<=1.0e-10_real64)then
        level=upper;exit
      else if(abs(level-lower)<=1.0e-10_real64)then
        level=lower;exit
      end if
    end do
    total=0.0_real64
    do ic=top_node,bottom_node
      upper=z(ic)+0.5_real64*dz(ic);lower=z(ic)-0.5_real64*dz(ic)
      if(upper<=level)then
        total=total+volume_main(ic)
      else if(lower<level)then
        ! B1.11 VOLUNDR: capacity below the level at uniform cell density.
        fraction=(level-lower)/dz(ic)
        total=total+fraction*volume_main(ic)
      end if
    end do
    if(.not.ieee_is_finite(total))return
    volume_under=total;ok=.true.
  end subroutine derive_rapid_volume_under_drain

  pure logical function rapid_drain_request_valid(self) result(ok)
    class(rapid_drain_request_t),intent(in)::self
    ok=self%num_nodes>0 .and. self%top_water_node>=1 .and. self%bottom_domain_node>=self%top_water_node .and. &
         self%bottom_domain_node<=self%num_nodes .and. self%step_duration>0.0_real64 .and. &
         self%saturated_top_fraction>=0.0_real64 .and. self%saturated_top_fraction<=1.0_real64 .and. &
         self%area_exponent>0.0_real64 .and. self%resistance_reference_day>0.0_real64 .and. &
         self%flow_reduction>=0.0_real64 .and. self%water_storage_cm>=0.0_real64 .and. &
         self%volume_under_drain_cm>=0.0_real64
    if(.not.ok)return
    ok=allocated(self%diameter) .and. allocated(self%dz) .and. allocated(self%volume_main_domain_cp)
    if(.not.ok)return
    ok=size(self%diameter)==self%num_nodes .and. size(self%dz)==self%num_nodes .and. &
         size(self%volume_main_domain_cp)==self%num_nodes .and. all(self%diameter>0.0_real64) .and. &
         all(self%dz>0.0_real64) .and. all(self%volume_main_domain_cp>=0.0_real64)
  end function rapid_drain_request_valid

  subroutine evaluate_rapid_drain(request,result)
    type(rapid_drain_request_t),intent(in)::request
    type(rapid_drain_result_t),intent(out)::result

    integer::ic
    real(real64)::ratio,width,kd_total,volume_under,drainable,delh,fac_res,total

    result=rapid_drain_result_t()
    if(.not.request%valid())return
    allocate(result%amount_cp_cm(request%num_nodes),result%kd_cp(request%num_nodes))
    result%amount_cp_cm=0.0_real64
    result%kd_cp=0.0_real64

    if(.not.request%enabled)then
      result%valid=.true.
      return
    end if
    if(.not.(request%domain_bottom_cm<request%drain_level_cm .or. request%drain_type/=1))then
      result%valid=.true.
      return
    end if

    kd_total=0.0_real64
    do ic=request%top_water_node,request%bottom_domain_node
      ratio=max(0.0_real64,min(1.0_real64,request%volume_main_domain_cp(ic)/request%dz(ic)))
      width=request%diameter(ic)*(1.0_real64-sqrt(max(0.0_real64,1.0_real64-ratio)))
      result%kd_cp(ic)=((width**request%area_exponent)/request%diameter(ic))*request%dz(ic)
      if(ic==request%top_water_node)result%kd_cp(ic)=request%saturated_top_fraction*result%kd_cp(ic)
      kd_total=kd_total+result%kd_cp(ic)
    end do

    volume_under=request%volume_under_drain_cm
    drainable=max(0.0_real64,request%water_storage_cm-volume_under)
    delh=request%water_level_cm-max(request%drain_level_cm,request%domain_bottom_cm)
    if(request%water_level_cm>-1.0e-7_real64)delh=delh+request%ponding_cm
    delh=max(0.0_real64,delh)

    total=0.0_real64
    if(kd_total>1.0e-10_real64)then
      fac_res=min(request%kd_reference/kd_total,1.1_real64)
      result%resistance_day=request%resistance_reference_day*fac_res
      total=request%flow_reduction*(delh/result%resistance_day)*request%step_duration
    end if
    total=min(max(0.0_real64,total),drainable)
    result%total_amount_cm=total

    if(kd_total>1.0e-15_real64)then
      do ic=request%top_water_node,request%bottom_domain_node
        result%amount_cp_cm(ic)=total*result%kd_cp(ic)/kd_total
      end do
    else
      result%total_amount_cm=0.0_real64
    end if
    result%valid=.true.
  end subroutine evaluate_rapid_drain

end module mod_ppa_wu05a6_rapid_drain_rate
