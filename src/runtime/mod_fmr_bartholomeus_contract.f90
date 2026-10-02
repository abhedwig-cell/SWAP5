module mod_fmr_bartholomeus_contract
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_bartholomeus_activation
  use mod_bartholomeus_parameter_contract
  implicit none
  private
  type, public :: fmr_bartholomeus_parameters_t
    type(fmr_bartholomeus_selection_t) :: selection
    type(BartholomeusImmutableDataset) :: soil
    type(BartholomeusCropParameters) :: crop
    real(real64) :: specific_root_length_m_kg = 0.0_real64
  end type
  public :: valid_fmr_bartholomeus_parameters, matches_bartholomeus_hydraulic_owner
contains
  logical function matches_bartholomeus_hydraulic_owner(parameters,cofgen,dz_cm) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    real(real64),intent(in)::cofgen(:,:),dz_cm(:)
    integer::i,n
    real(real64)::expected(6),actual(6)
    ok=.false.;n=size(dz_cm)
    if(.not.allocated(parameters%soil%soil)) return
    if(size(parameters%soil%soil)/=n .or. size(cofgen,1)<7 .or. size(cofgen,2)/=n) return
    do i=1,n
      expected=[cofgen(2,i),dz_cm(i)*0.01_real64,cofgen(4,i)*0.01_real64, &
           cofgen(6,i)-1.0_real64,cofgen(7,i)+1.0_real64, &
           (cofgen(2,i)-cofgen(1,i))*0.01_real64*cofgen(4,i)*cofgen(6,i)*cofgen(7,i)]
      associate(p=>parameters%soil%soil(i))
        actual=[p%saturated_water_content,p%depth_m,p%waterfilm_alpha_per_pa, &
             p%waterfilm_n_minus_1,p%waterfilm_m_plus_1,p%waterfilm_capac_term]
        if(abs(p%waterfilm_gen_n-cofgen(6,i))>0.0_real64) return
      end associate
      if(any(.not.ieee_is_finite(expected)) .or. any(.not.ieee_is_finite(actual))) return
      if(any(abs(expected-actual)>0.0_real64)) return
    end do
    ok=.true.
  end function
  logical function valid_fmr_bartholomeus_parameters(parameters,active_nodes) result(ok)
    type(fmr_bartholomeus_parameters_t),intent(in)::parameters
    integer,intent(in)::active_nodes
    integer::route,wmode
    call select_fmr_bartholomeus_route(parameters%selection,route,wmode)
    ok=route==FMR_BARTHOLOMEUS_DISABLED
    if(ok) return
    if(route/=FMR_BARTHOLOMEUS_ACTIVE) return
    if(.not.ieee_is_finite(parameters%specific_root_length_m_kg)) return
    if(parameters%specific_root_length_m_kg<=0) return
    if(.not.ieee_is_finite(1.0_real64/parameters%specific_root_length_m_kg)) return
    ok=validate_bartholomeus_parameters(parameters%soil,parameters%crop,active_nodes)
  end function
end module
