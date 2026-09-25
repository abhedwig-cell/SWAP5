module mod_b110_direct_retention_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  use mod_b110_direct_retention_core, only: sample_b110_direct_retention
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: b110_direct_retention_provider_t
    type(b110_default_mvg_provider_t) :: analytical
    integer :: slot=0
    logical :: ready=.false.
  contains
    procedure :: evaluate => direct_retention_evaluate
    procedure :: evaluate_demand => direct_retention_evaluate_demand
  end type b110_direct_retention_provider_t

  public :: bind_b110_direct_retention_provider

contains

  subroutine bind_b110_direct_retention_provider(provider,parameters,step_duration,slot,ok)
    type(b110_direct_retention_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    integer,intent(in)::slot
    logical,intent(out)::ok

    provider%slot=0
    provider%ready=.false.
    ok=.false.
    if(slot<=0)return
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    provider%slot=slot
    provider%ready=.true.
    ok=.true.
  end subroutine bind_b110_direct_retention_provider

  subroutine direct_retention_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b110_direct_retention_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    if(.not.self%ready)error stop 'B110 direct-retention provider not ready'
    call self%analytical%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
  end subroutine direct_retention_evaluate

  subroutine direct_retention_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity, &
                                               dconductivity_dhead)
    class(b110_direct_retention_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    integer,intent(in)::demand_mask
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    real(real64)::theta_i,capacity_i
    real(real64)::water_fallback(size(pressure_head)),conductivity_fallback(size(pressure_head))
    real(real64)::capacity_fallback(size(pressure_head)),dkdh_fallback(size(pressure_head))
    logical::inside,need_fallback

    if(.not.self%ready)error stop 'B110 direct-retention provider not ready'

    if(demand_mask/=CONSTITUTIVE_DEMAND_WATER_CONTENT .and. demand_mask/=CONSTITUTIVE_DEMAND_CAPACITY)then
      call self%analytical%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity, &
           dconductivity_dhead)
      return
    end if

    need_fallback=any(pressure_head>-1.0_real64 .or. pressure_head< -1.0e6_real64)
    if(need_fallback)then
      call self%analytical%evaluate_demand(pressure_head,demand_mask,water_fallback,conductivity_fallback, &
           capacity_fallback,dkdh_fallback)
    end if

    do i=1,size(pressure_head)
      call sample_b110_direct_retention(self%slot,pressure_head(i),theta_i,capacity_i,inside)
      if(.not.inside)then
        if(demand_mask==CONSTITUTIVE_DEMAND_WATER_CONTENT)water_content(i)=water_fallback(i)
        if(demand_mask==CONSTITUTIVE_DEMAND_CAPACITY)capacity(i)=capacity_fallback(i)
      else if(demand_mask==CONSTITUTIVE_DEMAND_WATER_CONTENT)then
        water_content(i)=theta_i
      else
        capacity(i)=capacity_i
      end if
    end do
  end subroutine direct_retention_evaluate_demand

end module mod_b110_direct_retention_provider
