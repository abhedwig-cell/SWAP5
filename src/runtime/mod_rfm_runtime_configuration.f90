module mod_rfm_runtime_configuration
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public :: RFM_SORPTIVITY_POLICY_EXACT=0
  integer,parameter,public :: RFM_SORPTIVITY_POLICY_A28_V1=1
  character(len=*),parameter,public :: RFM_SORPTIVITY_POLICY_A28_V1_NAME='A28_V1'

  type, public :: rfm_runtime_configuration_t
    logical :: enabled=.false.
    real(real64) :: sigma_b=-1.0_real64
    real(real64) :: f_mb=-1.0_real64
    real(real64) :: connectivity_p=-1.0_real64
    real(real64) :: z_ah_cm=-1.0_real64
    real(real64) :: z_ic_cm=-1.0_real64
    real(real64) :: chi_wall=-1.0_real64
    real(real64) :: exchange_length_cm=-1.0_real64
    real(real64) :: mb_contact_length_cm=-1.0_real64
    integer :: sorptivity_panels=0
    integer :: sorptivity_policy=RFM_SORPTIVITY_POLICY_EXACT
    integer :: mb_wall_node_index=0
    real(real64),allocatable :: endpoint_depth_cm(:), endpoint_contact_thickness_cm(:), endpoint_area_fraction(:)
    integer,allocatable :: endpoint_node_index(:)
  contains
    procedure,public::valid=>rfm_runtime_configuration_valid
    procedure,public::clear=>rfm_runtime_configuration_clear
    procedure,public::sorptivity_panels_for_head=>rfm_sorptivity_panels_for_head
  end type
contains
  pure logical function rfm_runtime_configuration_valid(self) result(ok)
    class(rfm_runtime_configuration_t),intent(in)::self
    integer::i,n
    ok=self%enabled.and.ieee_is_finite(self%sigma_b).and.self%sigma_b>0.0_real64.and. &
      ieee_is_finite(self%f_mb).and.self%f_mb>=0.0_real64.and.self%f_mb<=1.0_real64.and. &
      ieee_is_finite(self%connectivity_p).and.self%connectivity_p>0.0_real64.and. &
      ieee_is_finite(self%z_ah_cm).and.self%z_ah_cm>=0.0_real64.and. &
      ieee_is_finite(self%z_ic_cm).and.self%z_ic_cm>self%z_ah_cm.and. &
      ieee_is_finite(self%chi_wall).and.self%chi_wall>=0.0_real64.and. &
      ieee_is_finite(self%exchange_length_cm).and.self%exchange_length_cm>0.0_real64.and. &
      ieee_is_finite(self%mb_contact_length_cm).and.self%mb_contact_length_cm>0.0_real64.and. &
      self%sorptivity_panels>0.and.self%mb_wall_node_index>0.and.allocated(self%endpoint_depth_cm).and. &
      allocated(self%endpoint_contact_thickness_cm).and.allocated(self%endpoint_area_fraction).and.allocated(self%endpoint_node_index)
    if(.not.ok)return
    select case(self%sorptivity_policy)
    case(RFM_SORPTIVITY_POLICY_EXACT)
    case(RFM_SORPTIVITY_POLICY_A28_V1)
      ok=self%sorptivity_panels==64
    case default
      ok=.false.
    end select
    if(.not.ok)return
    n=size(self%endpoint_depth_cm)
    ok=n>0.and.size(self%endpoint_node_index)==n.and.size(self%endpoint_contact_thickness_cm)==n.and.size(self%endpoint_area_fraction)==n.and. &
      all(ieee_is_finite(self%endpoint_depth_cm)).and.all(self%endpoint_depth_cm>0.0_real64).and. &
      all(ieee_is_finite(self%endpoint_contact_thickness_cm)).and.all(self%endpoint_contact_thickness_cm>0.0_real64).and. &
      all(ieee_is_finite(self%endpoint_area_fraction)).and.all(self%endpoint_area_fraction>0.0_real64).and. &
      all(self%endpoint_area_fraction<=1.0_real64).and.all(self%endpoint_node_index>0)
    if(.not.ok)return
    do i=2,n
      if(self%endpoint_depth_cm(i)<=self%endpoint_depth_cm(i-1))then;ok=.false.;return;end if
    end do
    ok=self%endpoint_depth_cm(n)>=self%z_ic_cm
  end function
  subroutine rfm_runtime_configuration_clear(self)
    class(rfm_runtime_configuration_t),intent(inout)::self
    if(allocated(self%endpoint_depth_cm))deallocate(self%endpoint_depth_cm)
    if(allocated(self%endpoint_contact_thickness_cm))deallocate(self%endpoint_contact_thickness_cm)
    if(allocated(self%endpoint_area_fraction))deallocate(self%endpoint_area_fraction)
    if(allocated(self%endpoint_node_index))deallocate(self%endpoint_node_index)
    self%enabled=.false.;self%sigma_b=-1.0_real64;self%f_mb=-1.0_real64
    self%connectivity_p=-1.0_real64;self%z_ah_cm=-1.0_real64;self%z_ic_cm=-1.0_real64
    self%chi_wall=-1.0_real64;self%exchange_length_cm=-1.0_real64;self%mb_contact_length_cm=-1.0_real64
    self%sorptivity_panels=0;self%sorptivity_policy=RFM_SORPTIVITY_POLICY_EXACT;self%mb_wall_node_index=0
  end subroutine

  pure integer function rfm_sorptivity_panels_for_head(self,pressure_head_cm) result(panels)
    class(rfm_runtime_configuration_t),intent(in)::self
    real(real64),intent(in)::pressure_head_cm
    panels=0
    if(.not.ieee_is_finite(pressure_head_cm))return
    select case(self%sorptivity_policy)
    case(RFM_SORPTIVITY_POLICY_EXACT)
      panels=self%sorptivity_panels
    case(RFM_SORPTIVITY_POLICY_A28_V1)
      if(self%sorptivity_panels/=64)return
      if(pressure_head_cm<(-30.0_real64))then
        panels=64
      else if(pressure_head_cm<(-3.0_real64))then
        panels=32
      else
        panels=16
      end if
    end select
  end function
end module mod_rfm_runtime_configuration
