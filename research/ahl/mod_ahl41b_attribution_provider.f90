module mod_ahl41b_attribution_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider
  implicit none
  private

  integer, parameter, public :: AHL41B_ADAPTIVE_ALL=1
  integer, parameter, public :: AHL41B_EXACT_RC=2
  integer, parameter, public :: AHL41B_EXACT_K=3
  integer, parameter, public :: AHL41B_ANALYTICAL_ALL=4

  type, extends(constitutive_hydraulics_provider_t), public :: ahl41b_attribution_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    type(b110_adaptive_hydraulic_provider_t) :: adaptive
    integer :: mode=AHL41B_ADAPTIVE_ALL
    logical :: ready=.false.
  contains
    procedure :: evaluate => eval_provider
  end type

  public :: bind_ahl41b_attribution_provider

contains

  subroutine bind_ahl41b_attribution_provider(provider,parameters,step_duration,mode,valid)
    type(ahl41b_attribution_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    integer,intent(in)::mode
    logical,intent(out)::valid
    logical :: cache_hit

    valid=.false.; provider%ready=.false.; provider%mode=mode
    if(mode<AHL41B_ADAPTIVE_ALL .or. mode>AHL41B_ANALYTICAL_ALL) return
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(mode /= AHL41B_ANALYTICAL_ALL) then
      call bind_b110_adaptive_hydraulic_provider(provider%adaptive,parameters,step_duration,valid,cache_hit)
      if(.not.valid) return
    end if
    provider%ready=.true.; valid=.true.
  end subroutine

  subroutine eval_provider(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl41b_attribution_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64) :: wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))

    if(.not.self%ready) error stop 'AHL41B provider not ready'

    select case(self%mode)
    case(AHL41B_ANALYTICAL_ALL)
      call self%analytical%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    case default
      call self%adaptive%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
      if(self%mode==AHL41B_EXACT_RC .or. self%mode==AHL41B_EXACT_K) then
        call self%analytical%evaluate(pressure_head,wa,ka,ca,da)
        if(self%mode==AHL41B_EXACT_RC) then
          water_content=wa
          capacity=ca
        else
          conductivity=ka
        end if
      end if
    end select
  end subroutine
end module mod_ahl41b_attribution_provider
