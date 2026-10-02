module mod_bartholomeus_parameter_contract
  use iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_bartholomeus_soil_diffusivity, only: BartholomeusSoilDiffusivityPrecompute
  implicit none
  private
  public :: BartholomeusSoilNodeParameters, BartholomeusCropParameters, BartholomeusImmutableDataset
  public :: validate_bartholomeus_parameters, construct_bartholomeus_dataset

  type :: BartholomeusSoilNodeParameters
    real(real64) :: saturated_water_content
    real(real64) :: percent_org_mat
    real(real64) :: percent_sand
    real(real64) :: soil_density
    ! B1.11 oxygenstress depth = 0.01*dz(node): compartment thickness,
    ! NOT cumulative depth or nodal elevation. The name follows the kernel.
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
  subroutine construct_bartholomeus_dataset(cofgen,dz_cm,orgmat,psand,bdens, &
       theta_campbell_100,theta_campbell_500,theta_gfp,head100,head500, &
       initial_hysteresis_branch,data,ok)
    ! theta_* are evaluations from the owning hydraulic construction. They
    ! must include the applicable initial hysteresis branch, not current theta.
    ! No sharing/cache API is supplied: sharing requires ALL these dependencies.
    real(real64),intent(in)::cofgen(:,:),dz_cm(:),orgmat(:),psand(:),bdens(:)
    real(real64),intent(in)::theta_campbell_100(:),theta_campbell_500(:),theta_gfp(:),head100,head500
    integer,intent(in)::initial_hysteresis_branch
    type(BartholomeusImmutableDataset),intent(out)::data
    logical,intent(out)::ok
    type(BartholomeusImmutableDataset)::candidate
    integer::i,n
    real(real64)::b,gfp
    ok=.false.;n=size(dz_cm)
    if(n<=0 .or. size(cofgen,1)<7 .or. size(cofgen,2)/=n) return
    if(size(orgmat)/=n .or. size(psand)/=n .or. size(bdens)/=n) return
    if(size(theta_campbell_100)/=n .or. size(theta_campbell_500)/=n .or. size(theta_gfp)/=n) return
    if(any(.not.ieee_is_finite(cofgen(1:7,:)))) return
    if(any(.not.ieee_is_finite(dz_cm)) .or. any(dz_cm<=0)) return
    if(any(.not.ieee_is_finite(orgmat)) .or. any(orgmat<0) .or. any(orgmat>1)) return
    if(any(.not.ieee_is_finite(psand)) .or. any(psand<0) .or. any(psand>1)) return
    if(any(.not.ieee_is_finite(bdens)) .or. any(bdens<=0)) return
    if(any(.not.ieee_is_finite(theta_campbell_100)) .or. any(.not.ieee_is_finite(theta_campbell_500))) return
    if(any(.not.ieee_is_finite(theta_gfp))) return
    if(.not.ieee_is_finite(head100) .or. .not.ieee_is_finite(head500)) return
    if(head100>=0 .or. head500>=head100) return
    if(any(theta_campbell_500<=0) .or. any(theta_campbell_100<=theta_campbell_500)) return
    if(any(theta_campbell_100>cofgen(2,:)) .or. any(theta_gfp<0) .or. any(theta_gfp>=cofgen(2,:))) return
    if(any(cofgen(1,:)<0) .or. any(cofgen(2,:)<=cofgen(1,:)) .or. any(cofgen(2,:)>1)) return
    if(any(cofgen(4,:)<=0) .or. any(cofgen(6,:)<=1) .or. any(cofgen(7,:)<=0)) return
    allocate(candidate%soil(n))
    candidate%initial_hysteresis_branch=initial_hysteresis_branch
    do i=1,n
      b=(log10(-head500)-log10(-head100))/(log10(theta_campbell_100(i))-log10(theta_campbell_500(i)))
      gfp=cofgen(2,i)-theta_gfp(i)
      candidate%soil(i)%saturated_water_content=cofgen(2,i)
      candidate%soil(i)%percent_org_mat=orgmat(i)*100.0_real64
      candidate%soil(i)%percent_sand=psand(i)*(1.0_real64-orgmat(i))*100.0_real64
      candidate%soil(i)%soil_density=bdens(i)
      candidate%soil(i)%depth_m=dz_cm(i)*0.01_real64
      candidate%soil(i)%diffusivity%gfp100=gfp
      candidate%soil(i)%diffusivity%term1=2.0_real64*gfp**3+0.04_real64*gfp
      candidate%soil(i)%diffusivity%exponent=2.0_real64+3.0_real64/b
      candidate%soil(i)%waterfilm_capac_term=(cofgen(2,i)-cofgen(1,i))* &
           0.01_real64*cofgen(4,i)*cofgen(6,i)*cofgen(7,i)
      candidate%soil(i)%waterfilm_n_minus_1=cofgen(6,i)-1.0_real64
      candidate%soil(i)%waterfilm_m_plus_1=cofgen(7,i)+1.0_real64
      candidate%soil(i)%waterfilm_alpha_per_pa=0.01_real64*cofgen(4,i)
      candidate%soil(i)%waterfilm_gen_n=cofgen(6,i)
    end do
    data=candidate;ok=.true.
  end subroutine
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
