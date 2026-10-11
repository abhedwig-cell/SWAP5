module mod_ppa_wu05a12_test_constitutive
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: linear_test_constitutive_t
  contains
    procedure :: evaluate => test_evaluate
    procedure :: evaluate_demand => test_evaluate_demand
    procedure :: supports_point_conductivity => test_supports_point_conductivity
    procedure :: evaluate_point_conductivity => test_point_conductivity
  end type linear_test_constitutive_t

contains

  subroutine test_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(linear_test_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    water_content=0.4_real64+0.002_real64*pressure_head
    conductivity=1.0_real64
    capacity=0.002_real64
    dconductivity_dhead=0.0_real64
    if (.not.same_type_as(self,self)) error stop 'A12 test provider type'
  end subroutine test_evaluate

  subroutine test_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(linear_test_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    call self%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    if (demand_mask<0) error stop 'A12 test demand mask'
  end subroutine test_evaluate_demand

  logical function test_supports_point_conductivity(self) result(supported)
    class(linear_test_constitutive_t), intent(in) :: self
    supported=.true.
    if (.not.same_type_as(self,self)) supported=.false.
  end function test_supports_point_conductivity

  subroutine test_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(linear_test_constitutive_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head,water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    conductivity=1.0_real64
    available=node_index==1 .and. ieee_is_finite(pressure_head) .and. ieee_is_finite(water_content)
    if (.not.same_type_as(self,self)) available=.false.
  end subroutine test_point_conductivity

end module mod_ppa_wu05a12_test_constitutive

program test_ppa_wu05a12_rfm_hydraulic_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a12_test_constitutive, only: linear_test_constitutive_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_rfm_unponded_activation, only: RFM_ACTIVATION_AVAILABLE, &
       RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED
  use mod_fmr_rfm_activation_binding, only: fmr_rfm_hydraulic_activation_result_t, &
       evaluate_fmr_rfm_activation_from_view
  implicit none

  real(real64), parameter :: tol=1.0e-12_real64
  type(linear_test_constitutive_t) :: constitutive
  type(process_hydraulic_view_t) :: view
  type(fmr_rfm_hydraulic_activation_result_t) :: result
  logical :: ok

  view%active_nodes=1
  allocate(view%pressure_head(1),view%water_content(1))
  view%pressure_head(1)=-100.0_real64
  view%water_content(1)=0.2_real64
  view%ponding_depth=0.0_real64
  view%groundwater_level=-500.0_real64

  call evaluate_fmr_rfm_activation_from_view(view,constitutive,32,0.65_real64,8.0_real64,0.25_real64,result,ok)
  if (.not.ok .or. .not.result%hydraulic_available) error stop 'A12 binding unavailable'
  if (result%activation%status/=RFM_ACTIVATION_AVAILABLE) error stop 'A12 activation unavailable'
  if (abs(result%surface_conductivity_cm_per_day-1.0_real64)>tol) error stop 'A12 K oracle'
  if (abs(result%surface_sorptivity_cm_sqrt_day-sqrt(30.0_real64))>tol) error stop 'A12 S oracle'
  if (abs(result%activation%b50_cm_per_day-6.477225575051661_real64)>tol) error stop 'A12 b50 oracle'
  if (abs(result%activation%matrix_rate_cm_per_day-5.961748798503473_real64)>tol) error stop 'A12 matrix oracle'
  if (abs(result%activation%preferential_rate_cm_per_day-2.038251201496527_real64)>tol) error stop 'A12 pref oracle'
  if (abs(result%activation%preferential_fraction-0.25478140018706585_real64)>tol) error stop 'A12 fraction oracle'

  view%ponding_depth=0.01_real64
  call evaluate_fmr_rfm_activation_from_view(view,constitutive,32,0.65_real64,8.0_real64,0.25_real64,result,ok)
  if (.not.ok) error stop 'A12 ponding binding failed before A11'
  if (result%activation%status/=RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED) &
       error stop 'A12 ponding not passed fail closed'

  view%ponding_depth=0.0_real64
  call evaluate_fmr_rfm_activation_from_view(view,constitutive,0,0.65_real64,8.0_real64,0.25_real64,result,ok)
  if (ok) error stop 'A12 invalid panel count accepted'

  print '(a)', 'PPA_WU05A12_RFM_HYDRAULIC_BINDING=PASS'
end program test_ppa_wu05a12_rfm_hydraulic_binding
