module mod_ppa_wu05a6_rapid_drain_rate
  use, intrinsic :: iso_fortran_env, only: real64
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

  public :: evaluate_rapid_drain

contains

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
