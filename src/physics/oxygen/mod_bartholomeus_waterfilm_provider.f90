module mod_bartholomeus_waterfilm_provider
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t, valid_bartholomeus_runtime_view
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset
  use mod_bartholomeus_temperature, only: BartholomeusTemperatureResult, bartholomeus_temperature_parameters
  use mod_bartholomeus_waterfilm, only: BartholomeusWaterfilmMvgInput
  use mod_bartholomeus_waterfilm_independent, only: bartholomeus_waterfilm_mvg_independent
  implicit none
  private

  integer,parameter,public::BARTHOLOMEUS_WATERFILM_REFERENCE=1
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_PRACTICAL=2
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_OK=0
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_INVALID=1
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_MODE_NOT_ADMITTED=2
  public::evaluate_bartholomeus_waterfilm

contains
  subroutine evaluate_bartholomeus_waterfilm(view,data,mode,waterfilm,status)
    type(bartholomeus_runtime_view_t),intent(in)::view
    type(BartholomeusImmutableDataset),intent(in)::data
    integer,intent(in)::mode
    real(real64),allocatable,intent(out)::waterfilm(:)
    integer,intent(out)::status
    type(BartholomeusWaterfilmMvgInput)::p
    type(BartholomeusTemperatureResult)::t
    real(real64)::mp
    logical::ok
    integer::i,n

    status=BARTHOLOMEUS_WATERFILM_INVALID; n=view%rooted_nodes
    if(.not.allocated(data%soil)) return
    if(n<0 .or. n>size(data%soil)) return
    if(.not.valid_bartholomeus_runtime_view(view)) return
    if(mode==BARTHOLOMEUS_WATERFILM_PRACTICAL) then
      status=BARTHOLOMEUS_WATERFILM_MODE_NOT_ADMITTED; return
    end if
    if(mode/=BARTHOLOMEUS_WATERFILM_REFERENCE) return
    allocate(waterfilm(n))
    do i=1,n
      ! Legacy OxygenStress skips waterfilm and respiration at GFP < 1e-4.
      if(view%pressure_head_cm(i)>=0 .or. &
           data%soil(i)%saturated_water_content-view%water_content(i)<1.e-4_real64) then
        waterfilm(i)=0.0_real64
        cycle
      end if
      mp=abs(view%pressure_head_cm(i))*98.0665_real64
      t=bartholomeus_temperature_parameters(view%soil_temperature_k(i))
      p%capac_term=data%soil(i)%waterfilm_capac_term
      p%n_minus_1=data%soil(i)%waterfilm_n_minus_1
      p%m_plus_1=data%soil(i)%waterfilm_m_plus_1
      p%alpha_per_pa=data%soil(i)%waterfilm_alpha_per_pa
      p%gen_n=data%soil(i)%waterfilm_gen_n
      p%surface_tension_water=t%surface_tension_water
      waterfilm(i)=bartholomeus_waterfilm_mvg_independent(mp,p,ok)
      if(.not.ok .or. .not.ieee_is_finite(waterfilm(i))) return
      if(waterfilm(i)<0.0_real64) return
    end do
    status=BARTHOLOMEUS_WATERFILM_OK
  end subroutine
end module
