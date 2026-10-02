module mod_bartholomeus_parameter_contract
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_bartholomeus_soil_diffusivity, only: BartholomeusSoilDiffusivityPrecompute
  implicit none
  private
  public :: BartholomeusSoilNodeParameters, BartholomeusCropParameters, BartholomeusImmutableDataset
  public :: validate_bartholomeus_parameters

  type :: BartholomeusSoilNodeParameters
    real(real64) :: saturated_water_content
    real(real64) :: percent_org_mat
    real(real64) :: percent_sand
    real(real64) :: soil_density
    real(real64) :: depth_m
    real(real64) :: waterfilm_capac_term
    real(real64) :: waterfilm_n_minus_1
    real(real64) :: waterfilm_m_plus_1
    real(real64) :: waterfilm_alpha_per_pa
    real(real64) :: waterfilm_gen_n
    type(BartholomeusSoilDiffusivityPrecompute) :: diffusivity
  end type

  type :: BartholomeusCropParameters
    real(real64) :: c_mroot
    real(real64) :: f_senes
    real(real64) :: q10_root
    real(real64) :: specific_resp_humus
    real(real64) :: q10_microbial
    real(real64) :: microbial_shape_m
    real(real64) :: root_shape_m
    real(real64) :: root_radius_m
    real(real64) :: max_resp_factor
  end type

  type :: BartholomeusImmutableDataset
    type(BartholomeusSoilNodeParameters), allocatable :: soil(:)
    integer :: initial_hysteresis_branch = 0
  end type

contains
  pure logical function validate_bartholomeus_parameters(data,crop,rooted_nodes) result(ok)
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    integer,intent(in)::rooted_nodes
    integer::i
    ok=.false.
    if(.not.allocated(data%soil)) return
    if(rooted_nodes<0 .or. rooted_nodes>size(data%soil)) return
    if(any(.not.ieee_is_finite([crop%c_mroot,crop%f_senes,crop%q10_root, &
         crop%specific_resp_humus,crop%q10_microbial,crop%microbial_shape_m, &
         crop%root_shape_m,crop%root_radius_m,crop%max_resp_factor]))) return
    if(crop%c_mroot<0 .or. crop%f_senes<0 .or. crop%specific_resp_humus<0) return
    if(crop%microbial_shape_m<=0 .or. crop%root_shape_m<=0 .or. crop%root_radius_m<=0) return
    if(crop%max_resp_factor<0 .or. crop%q10_root<=0 .or. crop%q10_microbial<=0) return
    do i=1,rooted_nodes
      if(any(.not.ieee_is_finite([data%soil(i)%saturated_water_content,data%soil(i)%percent_org_mat, &
           data%soil(i)%percent_sand,data%soil(i)%soil_density,data%soil(i)%depth_m, &
           data%soil(i)%waterfilm_capac_term,data%soil(i)%waterfilm_n_minus_1,data%soil(i)%waterfilm_m_plus_1, &
           data%soil(i)%waterfilm_alpha_per_pa,data%soil(i)%waterfilm_gen_n, &
           data%soil(i)%diffusivity%term1,data%soil(i)%diffusivity%exponent,data%soil(i)%diffusivity%gfp100]))) return
      if(data%soil(i)%percent_org_mat<0 .or. data%soil(i)%percent_org_mat>100) return
      if(data%soil(i)%percent_sand<0 .or. data%soil(i)%percent_sand>100) return
      if(data%soil(i)%waterfilm_capac_term<=0 .or. data%soil(i)%waterfilm_n_minus_1<=0) return
      if(data%soil(i)%waterfilm_m_plus_1<=0 .or. data%soil(i)%diffusivity%term1<=0) return
      if(data%soil(i)%diffusivity%exponent<=0) return
      if(data%soil(i)%saturated_water_content<=0 .or. data%soil(i)%saturated_water_content>1) return
      if(data%soil(i)%soil_density<=0 .or. data%soil(i)%depth_m<0) return
      if(data%soil(i)%waterfilm_alpha_per_pa<=0 .or. data%soil(i)%waterfilm_gen_n<=1) return
      if(data%soil(i)%diffusivity%gfp100<=0) return
    end do
    ok=.true.
  end function
end module
