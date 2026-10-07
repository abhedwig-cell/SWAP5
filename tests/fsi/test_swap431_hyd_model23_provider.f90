module test_swap431_hyd_model23_base
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  type, extends(constitutive_hydraulics_provider_t), public :: preservation_base_t
  contains
    procedure :: evaluate => base_evaluate
    procedure :: supports_point_conductivity => base_supports_point
    procedure :: evaluate_point_conductivity => base_point
  end type preservation_base_t
contains
  subroutine base_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(preservation_base_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    water_content = 0.3_real64
    conductivity = 2.0_real64
    capacity = 0.01_real64
    dconductivity_dhead = 0.0_real64
  end subroutine base_evaluate
  logical function base_supports_point(self) result(supported)
    class(preservation_base_t), intent(in) :: self
    supported = .true.
  end function base_supports_point
  subroutine base_point(self, node_index, pressure_head, water_content, conductivity, available)
    class(preservation_base_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    conductivity = 2.0_real64
    available = .true.
  end subroutine base_point
end module test_swap431_hyd_model23_base

program test_swap431_hyd_model23_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use test_swap431_hyd_model23_base, only: preservation_base_t
  use mod_b111_legacy_hydraulic_provider, only: b111_legacy_hydraulic_provider_t, &
       configure_b111_legacy_hydraulic_provider, bind_b111_legacy_hydraulic_provider, &
       B111_LEGACY_HYD_OK, B111_LEGACY_HYD_UNSUPPORTED_MODEL
  implicit none
  type(preservation_base_t), target :: base
  type(b111_legacy_hydraulic_provider_t) :: provider
  real(real64) :: cofgen(42,3), h(3), theta(3), conductivity(3), capacity(3), dkdh(3)
  real(real64) :: expected_theta, expected_capacity, expected_k, e
  real(real64) :: s1, s2, relsat, term1, term2, omega2, point_k
  integer :: model(3), status
  logical :: available

  cofgen = 0.0_real64
  model = [1,2,3]
  h = [-100.0_real64,-250.0_real64,-120.0_real64]
  cofgen(1,:) = [0.05_real64,0.08_real64,0.04_real64]
  cofgen(2,:) = [0.45_real64,0.48_real64,0.43_real64]
  cofgen(3,:) = [2.0_real64,5.0_real64,7.0_real64]
  cofgen(4,:) = [0.01_real64,0.004_real64,0.012_real64]
  cofgen(5,:) = 0.5_real64
  cofgen(6,:) = 1.6_real64
  cofgen(7,:) = 1.0_real64-1.0_real64/cofgen(6,:)
  cofgen(13,:) = 0.03_real64
  cofgen(14,:) = 2.2_real64
  cofgen(15,:) = 1.0_real64-1.0_real64/cofgen(14,:)
  cofgen(16,:) = 0.65_real64

  call configure_b111_legacy_hydraulic_provider(provider, cofgen, model, status)
  if (status /= B111_LEGACY_HYD_OK) error stop 'model23 configure failed'
  call bind_b111_legacy_hydraulic_provider(provider, base, 0.25_real64, status)
  if (status /= B111_LEGACY_HYD_OK) error stop 'model23 bind failed'
  call provider%evaluate(h, theta, conductivity, capacity, dkdh)

  if (theta(1) /= 0.3_real64 .or. conductivity(1) /= 2.0_real64 .or. capacity(1) /= 0.01_real64) &
       error stop 'model1 base preservation failed'

  e = exp(cofgen(4,2)*h(2))
  expected_theta = max(1.0000001_real64*cofgen(1,2), &
       cofgen(1,2)+(cofgen(2,2)-cofgen(1,2))*e)
  expected_capacity = cofgen(4,2)*(cofgen(2,2)-cofgen(1,2))*e
  expected_k = cofgen(3,2)*(expected_theta-cofgen(1,2))/(cofgen(2,2)-cofgen(1,2))
  call assert_close(theta(2), expected_theta, 1.0e-14_real64, 'model2 theta')
  call assert_close(capacity(2), expected_capacity, 1.0e-14_real64, 'model2 capacity')
  call assert_close(conductivity(2), expected_k, 1.0e-14_real64, 'model2 conductivity')

  omega2 = 1.0_real64-cofgen(16,3)
  s1 = (1.0_real64+abs(cofgen(4,3)*h(3))**cofgen(6,3))**(-cofgen(7,3))
  s2 = (1.0_real64+abs(cofgen(13,3)*h(3))**cofgen(14,3))**(-cofgen(15,3))
  relsat = cofgen(16,3)*s1+omega2*s2
  expected_theta = cofgen(1,3)+(cofgen(2,3)-cofgen(1,3))*relsat
  term1 = cofgen(16,3)*cofgen(4,3)*(1.0_real64-s1**(1.0_real64/cofgen(7,3)))**cofgen(7,3)
  term2 = omega2*cofgen(13,3)*(1.0_real64-s2**(1.0_real64/cofgen(15,3)))**cofgen(15,3)
  expected_k = cofgen(3,3)*relsat**cofgen(5,3) * &
       (1.0_real64-(term1+term2)/(cofgen(16,3)*cofgen(4,3)+omega2*cofgen(13,3)))**2
  call assert_close(theta(3), expected_theta, 1.0e-13_real64, 'model3 theta')
  call assert_close(conductivity(3), expected_k, 1.0e-13_real64, 'model3 conductivity')
  if (any(dkdh /= 0.0_real64)) error stop 'model23 K0 derivative reservation changed'

  call provider%evaluate_point_conductivity(2, h(2), 0.25_real64, point_k, available)
  if (.not. available) error stop 'model2 point conductivity unavailable'
  expected_k = cofgen(3,2)*(0.25_real64-cofgen(1,2))/(cofgen(2,2)-cofgen(1,2))
  call assert_close(point_k, expected_k, 1.0e-14_real64, 'model2 point supplied theta')

  model = [1,4,1]
  call configure_b111_legacy_hydraulic_provider(provider, cofgen, model, status)
  if (status /= B111_LEGACY_HYD_UNSUPPORTED_MODEL) error stop 'unsupported model fail-closed changed'

  print '(a)', 'SWAP431_HYD_MODEL23_PROVIDER_PASS'
contains
  subroutine assert_close(actual, expected, tolerance, label)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: label
    if (abs(actual-expected) > tolerance) then
      write(*,'(a,2(1x,es24.16))') trim(label), actual, expected
      error stop 'model23 oracle mismatch'
    end if
  end subroutine assert_close
end program test_swap431_hyd_model23_provider
