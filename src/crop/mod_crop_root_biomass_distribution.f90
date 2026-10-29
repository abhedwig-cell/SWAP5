! B1.11 MOD_cropdevelopment::finalize_wroot_node, SWLRVCONSTANT=0.
! Derived view of existing crop biomass and root geometry; no state ownership.
module mod_crop_root_biomass_distribution
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  integer,parameter,public::ROOT_BIOMASS_DISTRIBUTION_OK=0,ROOT_BIOMASS_DISTRIBUTION_INVALID=1
  type,public::crop_root_biomass_distribution_t
    real(real64),allocatable::mass_kg_ha(:),length_cm_cm3(:),node_top_density_kg_m3(:)
  end type
  public::derive_crop_root_biomass_distribution
contains
  pure subroutine derive_crop_root_biomass_distribution(root_biomass_kg_ha,specific_root_length_m_kg, &
       dz_cm,cumulative_fraction,result,status)
    real(real64),intent(in)::root_biomass_kg_ha,specific_root_length_m_kg,dz_cm(:),cumulative_fraction(:)
    type(crop_root_biomass_distribution_t),intent(out)::result
    integer,intent(out)::status
    type(crop_root_biomass_distribution_t)::candidate
    integer::i,n
    real(real64)::second_node_density
    result=crop_root_biomass_distribution_t();status=ROOT_BIOMASS_DISTRIBUTION_INVALID
    n=size(dz_cm)
    if(n<1.or.size(cumulative_fraction)/=n+1)return
    if(.not.all(ieee_is_finite([root_biomass_kg_ha,specific_root_length_m_kg])))return
    if(root_biomass_kg_ha<0d0.or.specific_root_length_m_kg<=0d0)return
    if(.not.all(ieee_is_finite(dz_cm)).or..not.all(ieee_is_finite(cumulative_fraction)))return
    if(any(dz_cm<=0d0).or.cumulative_fraction(1)/=0d0.or.cumulative_fraction(n+1)/=1d0)return
    if(any(cumulative_fraction(2:)<cumulative_fraction(:n)))return
    allocate(candidate%mass_kg_ha(n),candidate%length_cm_cm3(n),candidate%node_top_density_kg_m3(n))
    do i=1,n
      candidate%mass_kg_ha(i)=(cumulative_fraction(i+1)-cumulative_fraction(i))*root_biomass_kg_ha
      candidate%length_cm_cm3(i)=candidate%mass_kg_ha(i)*specific_root_length_m_kg/(1d6*dz_cm(i))
    end do
    do i=2,n
      candidate%node_top_density_kg_m3(i)=.5d0*(candidate%mass_kg_ha(i-1)/dz_cm(i-1)+ &
        candidate%mass_kg_ha(i)/dz_cm(i))
    end do
    ! Original reset_rootdistribution zeroes the unrooted second node. Keep
    ! that one-rooted-cell boundary without accessing beyond this derived view.
    second_node_density=0d0
    if(n>1)second_node_density=candidate%node_top_density_kg_m3(2)/dz_cm(2)
    candidate%node_top_density_kg_m3(1)=max(0d0,candidate%mass_kg_ha(1)/dz_cm(1)+ &
      (candidate%mass_kg_ha(1)/dz_cm(1)-second_node_density))
    ! Preserve source arithmetic, including the source node-top interpolation
    ! before the compartment-specific unit conversion.
    candidate%node_top_density_kg_m3=candidate%node_top_density_kg_m3*1d-4/(1d-2*dz_cm)
    if(.not.all(ieee_is_finite(candidate%mass_kg_ha)).or. &
       .not.all(ieee_is_finite(candidate%length_cm_cm3)).or. &
       .not.all(ieee_is_finite(candidate%node_top_density_kg_m3)))return
    result=candidate;status=ROOT_BIOMASS_DISTRIBUTION_OK
  end subroutine
end module
