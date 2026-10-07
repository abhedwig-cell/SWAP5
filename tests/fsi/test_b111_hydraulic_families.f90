module b111_hyd_test_base
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: base_provider_t
  contains
    procedure :: evaluate => base_evaluate
    procedure :: supports_point_conductivity => base_supports_point
    procedure :: evaluate_point_conductivity => base_point
  end type
contains
  subroutine base_evaluate(self,h,theta,k,c,dk)
    class(base_provider_t),intent(in)::self
    real(real64),intent(in)::h(:)
    real(real64),intent(out)::theta(:),k(:),c(:),dk(:)
    theta=0.25_real64; k=1.25_real64; c=0.005_real64; dk=0.0_real64
  end subroutine
  logical function base_supports_point(self)
    class(base_provider_t),intent(in)::self
    base_supports_point=.true.
  end function
  subroutine base_point(self,node,h,theta,k,available)
    class(base_provider_t),intent(in)::self
    integer,intent(in)::node
    real(real64),intent(in)::h,theta
    real(real64),intent(out)::k
    logical,intent(out)::available
    k=1.25_real64; available=.true.
  end subroutine
end module

program test_b111_hydraulic_families
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_legacy_hydraulic_provider
  use mod_b111_extended_hydraulic_provider
  use b111_hyd_test_base
  implicit none
  integer, parameter :: n=10
  integer :: model(n), status, i
  real(real64) :: c(42,n), h(n), theta(n), k(n), cap(n), dk(n)
  real(real64) :: theta_v(n), k_v(n), cap_v(n), dk_v(n), temperature_c(n)
  type(base_provider_t), target :: base
  type(b111_legacy_hydraulic_provider_t), target :: legacy
  type(b111_extended_hydraulic_parameters_t), target :: extp, extp_vapor
  type(b111_extended_hydraulic_provider_t) :: ext, ext_vapor

  model=[1,2,3,5,6,7,8,9,10,11]
  h=-100.0_real64
  c=0.0_real64
  do i=1,n
    c(1,i)=0.06_real64; c(2,i)=0.44_real64; c(3,i)=12.5_real64
    c(4,i)=0.018_real64; c(5,i)=0.45_real64; c(6,i)=1.62_real64; c(7,i)=1.0_real64-1.0_real64/c(6,i)
    c(13,i)=0.0035_real64; c(14,i)=1.35_real64; c(15,i)=1.0_real64-1.0_real64/c(14,i)
    c(16,i)=0.63_real64; c(17,i)=0.37_real64
    c(18,i)=1.0e6_real64; c(19,i)=1.0e2_real64; c(20,i)=-1.5_real64; c(21,i)=0.04_real64
  end do

  call configure_b111_legacy_hydraulic_provider(legacy,c,model,status)
  if(status/=B111_LEGACY_HYD_OK) error stop 'legacy configure failed'
  call bind_b111_legacy_hydraulic_provider(legacy,base,1.0_real64,status)
  if(status/=B111_LEGACY_HYD_OK) error stop 'legacy bind failed'
  call initialize_b111_extended_hydraulic_parameters(extp,model,c,status)
  if(status/=B111_EXT_OK) error stop 'extended initialize failed'
  call bind_b111_extended_hydraulic_provider(ext,extp,legacy,status)
  if(status/=B111_EXT_OK) error stop 'extended bind failed'
  call ext%evaluate(h,theta,k,cap,dk)

  do i=1,n
    write(*,'(i0,1x,es24.16,3(1x,es24.16),1x,es24.16)') model(i),h(i),theta(i),k(i),cap(i),dk(i)
  end do

  temperature_c=20.0_real64
  call initialize_b111_extended_hydraulic_parameters(extp_vapor,model,c,status,.true.)
  if(status/=B111_EXT_OK) error stop 'extended vapor initialize failed'
  call bind_b111_extended_hydraulic_provider(ext_vapor,extp_vapor,legacy,status,temperature_c)
  if(status/=B111_EXT_OK) error stop 'extended vapor bind failed'
  call ext_vapor%evaluate(h,theta_v,k_v,cap_v,dk_v)
  do i=1,n
    if(model(i)>=8) write(*,'(a,1x,i0,1x,3(es24.16,1x))') 'V',model(i),theta_v(i),k_v(i),k_v(i)-k(i)
  end do

  if(theta(1)/=0.25_real64 .or. k(1)/=1.25_real64 .or. cap(1)/=0.005_real64) error stop 'model1 preservation failed'
  if(any(dk/=0.0_real64)) error stop 'K0 derivative reservation changed'
end program
