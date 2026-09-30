module mod_ppa_wu05a4_fixed_exchange_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: source_sink_provider_t
  implicit none
  private

  type, extends(source_sink_provider_t), public :: ppa_wu05a4_fixed_exchange_provider_t
    real(real64), allocatable :: source_rate(:)
    real(real64), allocatable :: sink_rate(:)
  contains
    procedure :: evaluate => ppa_wu05a4_fixed_exchange_evaluate
  end type ppa_wu05a4_fixed_exchange_provider_t

contains

  subroutine ppa_wu05a4_fixed_exchange_evaluate(self, pressure_head, water_content, source, sink)
    class(ppa_wu05a4_fixed_exchange_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)

    if (.not. allocated(self%source_rate) .or. .not. allocated(self%sink_rate)) &
         error stop 'PPA-WU05-A4 fixed exchange provider not initialized'
    if (size(source) /= size(self%source_rate) .or. size(sink) /= size(self%sink_rate)) &
         error stop 'PPA-WU05-A4 fixed exchange provider output shape mismatch'
    if (size(pressure_head) /= size(source) .or. size(water_content) /= size(source)) &
         error stop 'PPA-WU05-A4 fixed exchange provider state shape mismatch'

    source = self%source_rate
    sink = self%sink_rate
  end subroutine ppa_wu05a4_fixed_exchange_evaluate

end module mod_ppa_wu05a4_fixed_exchange_provider
