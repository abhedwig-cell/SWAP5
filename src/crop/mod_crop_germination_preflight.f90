module mod_crop_germination_preflight
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: CROP_GERM_OK=0, CROP_GERM_INVALID=1
  type, public :: crop_germination_candidate_t
    logical :: valid=.false.
    logical :: complete=.false.
    real(real64) :: next_temperature_sum=0.0_real64
    real(real64) :: proposed_development_stage=0.0_real64
  end type
  public :: propose_crop_germination
contains
  ! B1.11 one-day temperature sum proposal. Caller supplies committed values
  ! and sampled physical forcing; no persistent crop state is mutated.
  pure subroutine propose_crop_germination(mode,temperature_sum,optimal_sum,base_temperature, &
       max_effective_temperature,air_temperature,average_pressure_head,dry_head,wet_head, &
       water_response_a,candidate,status)
    integer, intent(in) :: mode
    real(real64), intent(in) :: temperature_sum,optimal_sum,base_temperature, &
         max_effective_temperature,air_temperature,average_pressure_head,dry_head,wet_head,water_response_a
    type(crop_germination_candidate_t), intent(out) :: candidate
    integer, intent(out) :: status
    real(real64) :: needed_sum,pf_value,b_coeff,c_coeff,increment
    candidate=crop_germination_candidate_t()
    status=CROP_GERM_INVALID
    if(mode<0.or.mode>2) return
    if(mode==0) then
      candidate%valid=.true.
      candidate%complete=.true.
      candidate%next_temperature_sum=temperature_sum
      status=CROP_GERM_OK
      return
    end if
    if(.not.ieee_is_finite(temperature_sum).or..not.ieee_is_finite(optimal_sum)) return
    if(.not.ieee_is_finite(base_temperature).or..not.ieee_is_finite(max_effective_temperature)) return
    if(.not.ieee_is_finite(air_temperature)) return
    if(temperature_sum<0.0_real64.or.optimal_sum<=0.0_real64) return
    if(max_effective_temperature<base_temperature) return
    needed_sum=optimal_sum
    if(mode==2) then
      if(.not.ieee_is_finite(average_pressure_head).or..not.ieee_is_finite(dry_head)) return
      if(.not.ieee_is_finite(wet_head).or..not.ieee_is_finite(water_response_a)) return
      if(dry_head>=wet_head.or.wet_head>=0.0_real64.or.water_response_a<=0.0_real64) return
      pf_value=log10(max(1.0_real64,-average_pressure_head))
      c_coeff=-(optimal_sum-water_response_a*log10(-dry_head))
      b_coeff=optimal_sum+water_response_a*log10(-wet_head)
      if(average_pressure_head<dry_head) then
        needed_sum=water_response_a*pf_value-c_coeff
      else if(average_pressure_head>wet_head) then
        needed_sum=-water_response_a*pf_value+b_coeff
      end if
    end if
    if(.not.ieee_is_finite(needed_sum)) return
    increment=0.0_real64
    if(air_temperature>base_temperature) then
      increment=max(0.0_real64,min(air_temperature,max_effective_temperature)-base_temperature)
      if(needed_sum>=0.1_real64) increment=(optimal_sum/needed_sum)*increment
    end if
    if(.not.ieee_is_finite(increment)) return
    candidate%next_temperature_sum=temperature_sum+increment
    if(.not.ieee_is_finite(candidate%next_temperature_sum)) then
      candidate=crop_germination_candidate_t()
      return
    end if
    candidate%complete=candidate%next_temperature_sum>=optimal_sum
    if(.not.candidate%complete) candidate%proposed_development_stage= &
         -0.1_real64*max(1.0_real64-candidate%next_temperature_sum/optimal_sum,0.0_real64)
    candidate%valid=.true.
    status=CROP_GERM_OK
  end subroutine
end module mod_crop_germination_preflight
