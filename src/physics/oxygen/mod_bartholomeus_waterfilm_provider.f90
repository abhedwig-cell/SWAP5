module mod_bartholomeus_waterfilm_provider
  use iso_fortran_env, only: real64, int64
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
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_REFINED_REFERENCE=3
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_OK=0
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_INVALID=1
  integer,parameter,public::BARTHOLOMEUS_WATERFILM_MODE_NOT_ADMITTED=2
  public::evaluate_bartholomeus_waterfilm

  type, public :: bartholomeus_waterfilm_trial_cache_t
    private
    logical :: active = .false.
    integer :: mode = 0
    integer(int64), allocatable :: key(:,:)
    real(real64), allocatable :: film(:)
  contains
    procedure :: reset => reset_waterfilm_cache
  end type bartholomeus_waterfilm_trial_cache_t

contains
  subroutine reset_waterfilm_cache(self,active)
    class(bartholomeus_waterfilm_trial_cache_t), intent(inout) :: self
    logical, intent(in) :: active

    self%active=active
    self%mode=0
    if(allocated(self%key))deallocate(self%key)
    if(allocated(self%film))deallocate(self%film)
  end subroutine reset_waterfilm_cache

  subroutine evaluate_bartholomeus_waterfilm(view,data,mode,waterfilm,status,cache)
    type(bartholomeus_runtime_view_t),intent(in)::view
    type(BartholomeusImmutableDataset),intent(in)::data
    integer,intent(in)::mode
    real(real64),allocatable,intent(out)::waterfilm(:)
    integer,intent(out)::status
    type(bartholomeus_waterfilm_trial_cache_t), optional, intent(inout) :: cache
    integer(int64), allocatable :: key(:,:)
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
    if(mode/=BARTHOLOMEUS_WATERFILM_REFERENCE.and.mode/=BARTHOLOMEUS_WATERFILM_REFINED_REFERENCE) return
    if(present(cache))then
      if(cache%active)then
        allocate(key(9,n))
        do i=1,n
          ! Exact inputs of the existing node quadrature and its saturation gate.
          key(:,i)=transfer([view%pressure_head_cm(i),view%water_content(i),view%soil_temperature_k(i), &
               data%soil(i)%saturated_water_content,data%soil(i)%waterfilm_capac_term,data%soil(i)%waterfilm_n_minus_1, &
               data%soil(i)%waterfilm_m_plus_1,data%soil(i)%waterfilm_alpha_per_pa,data%soil(i)%waterfilm_gen_n], &
               [0_int64])
        end do
        if(allocated(cache%key).and.cache%mode==mode)then
          if(size(cache%key,2)==n)then
            if(all(cache%key==key))then
              waterfilm=cache%film
              status=BARTHOLOMEUS_WATERFILM_OK
              return
            end if
          end if
        end if
      end if
    end if
    allocate(waterfilm(n))
    do i=1,n
      ! Legacy OxygenStress skips waterfilm and respiration at GFP < 1e-4.
      if(view%pressure_head_cm(i)>=0 .or. &
           data%soil(i)%saturated_water_content-view%water_content(i)<1.e-4_real64) then
        waterfilm(i)=0.0_real64
        cycle
      end if
      mp=-view%pressure_head_cm(i)*100.0_real64
      t=bartholomeus_temperature_parameters(view%soil_temperature_k(i))
      p%capac_term=data%soil(i)%waterfilm_capac_term
      p%n_minus_1=data%soil(i)%waterfilm_n_minus_1
      p%m_plus_1=data%soil(i)%waterfilm_m_plus_1
      p%alpha_per_pa=data%soil(i)%waterfilm_alpha_per_pa
      p%gen_n=data%soil(i)%waterfilm_gen_n
      p%surface_tension_water=t%surface_tension_water
      waterfilm(i)=bartholomeus_waterfilm_mvg_independent(mp,p,ok, &
           require_two_refinements=mode==BARTHOLOMEUS_WATERFILM_REFINED_REFERENCE)
      if(.not.ok .or. .not.ieee_is_finite(waterfilm(i))) return
      if(waterfilm(i)<0.0_real64) return
    end do
    if(allocated(key))then
      call move_alloc(key,cache%key)
      cache%film=waterfilm
      cache%mode=mode
    end if
    status=BARTHOLOMEUS_WATERFILM_OK
  end subroutine
end module
