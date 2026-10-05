module frost_provider_mock
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: mock_provider_t
  contains
    procedure :: evaluate => mock_evaluate
    procedure :: supports_point_conductivity => mock_supports_point
    procedure :: evaluate_point_conductivity => mock_point
  end type mock_provider_t
contains
  subroutine mock_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(mock_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    water_content = 0.2_real64
    conductivity = 4.0_real64
    capacity = 2.0_real64
    dconductivity_dhead = 6.0_real64
    if (.not. same_type_as(self,self)) error stop 'unreachable'
    if (size(pressure_head) /= size(water_content)) error stop 'shape mismatch'
  end subroutine mock_evaluate

  logical function mock_supports_point(self)
    class(mock_provider_t), intent(in) :: self
    mock_supports_point = same_type_as(self,self)
  end function mock_supports_point

  subroutine mock_point(self, node_index, pressure_head, water_content, conductivity, available)
    class(mock_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available
    conductivity = 3.0_real64
    available = node_index > 0 .and. abs(pressure_head) < huge(pressure_head) .and. &
         abs(water_content) < huge(water_content) .and. same_type_as(self,self)
  end subroutine mock_point
end module frost_provider_mock

program test_ppa_wu05b_frost_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_DKDH
  use mod_frost_hydraulic_provider, only: frost_constitutive_provider_t, &
       bind_frost_constitutive_provider, FROST_PROVIDER_OK
  use frost_provider_mock, only: mock_provider_t
  implicit none
  type(mock_provider_t), target :: base
  type(frost_constitutive_provider_t) :: frost
  real(real64) :: factor(3), h(3), theta(3), k(3), c(3), dk(3), increment(3), point_k
  integer :: status
  logical :: available

  factor = [1.0_real64, 0.5_real64, 0.0_real64]
  call bind_frost_constitutive_provider(frost, base, factor, status)
  call require(status == FROST_PROVIDER_OK, 'provider binding')
  h = [-10.0_real64, -20.0_real64, -30.0_real64]
  call frost%evaluate(h, theta, k, c, dk)
  call require(all(abs(theta-0.2_real64) < 1.0e-14_real64), 'water content forwarded')
  call require(all(abs(c-2.0_real64) < 1.0e-14_real64), 'capacity forwarded')
  call require(abs(k(1)-4.0_real64) < 1.0e-14_real64, 'unfrozen conductivity')
  call require(abs(k(2)-2.0_real64-5.0e-11_real64) < 1.0e-14_real64, 'partial conductivity')
  call require(abs(k(3)-1.0e-10_real64) < 1.0e-20_real64, 'frozen floor')
  call require(all(abs(dk-[6.0_real64,3.0_real64,0.0_real64]) < 1.0e-14_real64), 'derivative scales')

  call frost%evaluate_demand(h, CONSTITUTIVE_DEMAND_CONDUCTIVITY+CONSTITUTIVE_DEMAND_DKDH, &
       theta, k, c, dk)
  call require(abs(k(3)-1.0e-10_real64) < 1.0e-20_real64, 'demand conductivity floor')
  call require(all(abs(dk-[6.0_real64,3.0_real64,0.0_real64]) < 1.0e-14_real64), 'demand derivative scaling')

  call frost%evaluate_water_content_increment(h, h, [0.4_real64,0.5_real64,0.6_real64], &
       [0.1_real64,0.2_real64,0.3_real64], increment)
  call require(all(abs(increment-0.3_real64) < 1.0e-14_real64), 'storage increment forwarded')
  call require(frost%supports_point_conductivity(), 'point conductivity capability forwarded')
  call frost%evaluate_point_conductivity(2, -1.0_real64, 0.2_real64, point_k, available)
  call require(available .and. abs(point_k-1.5_real64-5.0e-11_real64) < 1.0e-14_real64, &
       'point conductivity scaled with floor')
  print '(a)', 'PPA-WU05B frost provider: PASS'

contains
  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a)') 'FAIL: '//label
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05b_frost_provider
