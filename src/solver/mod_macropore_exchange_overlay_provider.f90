module mod_macropore_exchange_overlay_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: source_sink_provider_t
  implicit none
  private

  type, extends(source_sink_provider_t), public :: macropore_exchange_overlay_provider_t
    class(source_sink_provider_t), pointer :: base => null()
    real(real64), allocatable :: exchange_rate(:)
  contains
    procedure :: evaluate => overlay_evaluate
  end type macropore_exchange_overlay_provider_t

contains

  subroutine overlay_evaluate(self,pressure_head,water_content,source,sink)
    class(macropore_exchange_overlay_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::source(:),sink(:)

    if(size(source)/=size(pressure_head) .or. size(sink)/=size(pressure_head) .or. &
       size(water_content)/=size(pressure_head)) error stop 'macropore overlay shape mismatch'
    source=0.0_real64
    sink=0.0_real64
    if(associated(self%base))call self%base%evaluate(pressure_head,water_content,source,sink)
    if(allocated(self%exchange_rate))then
      if(size(self%exchange_rate)/=size(source))error stop 'macropore exchange vector shape mismatch'
      source=source+max(self%exchange_rate,0.0_real64)
      sink=sink+max(-self%exchange_rate,0.0_real64)
    end if
  end subroutine overlay_evaluate

end module mod_macropore_exchange_overlay_provider
