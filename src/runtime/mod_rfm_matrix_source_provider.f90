module mod_rfm_matrix_source_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: source_sink_provider_t
  implicit none
  private

  type, extends(source_sink_provider_t), public :: rfm_matrix_source_provider_t
    integer :: active_nodes=0
    class(source_sink_provider_t), pointer :: base => null()
    real(real64), pointer :: rfm_source_rate(:) => null()
  contains
    procedure :: evaluate => rfm_matrix_source_evaluate
  end type

  public :: bind_rfm_matrix_source_provider

contains

  subroutine bind_rfm_matrix_source_provider(provider,base,rfm_source_rate,ok)
    type(rfm_matrix_source_provider_t),intent(out)::provider
    class(source_sink_provider_t),target,intent(in)::base
    real(real64),target,intent(in)::rfm_source_rate(:)
    logical,intent(out)::ok
    ok=.false.
    provider%active_nodes=0
    nullify(provider%base,provider%rfm_source_rate)
    if(size(rfm_source_rate)<=0)return
    if(any(.not.ieee_is_finite(rfm_source_rate)).or.any(rfm_source_rate<0.0_real64))return
    provider%active_nodes=size(rfm_source_rate)
    provider%base=>base
    provider%rfm_source_rate=>rfm_source_rate
    ok=.true.
  end subroutine

  subroutine rfm_matrix_source_evaluate(self,pressure_head,water_content,source,sink)
    class(rfm_matrix_source_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::source(:),sink(:)
    if(self%active_nodes<=0.or..not.associated(self%base).or..not.associated(self%rfm_source_rate)) &
      error stop 'A24 RFM matrix source provider not bound'
    if(size(pressure_head)/=self%active_nodes.or.size(water_content)/=self%active_nodes.or. &
       size(source)/=self%active_nodes.or.size(sink)/=self%active_nodes) &
      error stop 'A24 RFM matrix source shape mismatch'
    call self%base%evaluate(pressure_head,water_content,source,sink)
    source=source+self%rfm_source_rate
  end subroutine
end module mod_rfm_matrix_source_provider
