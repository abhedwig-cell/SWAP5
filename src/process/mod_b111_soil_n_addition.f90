module mod_b111_soil_n_addition
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_pool_state,only:soil_n_transfer_t
 implicit none
 private
 integer,parameter,public::B111_NADD_OK=0,B111_NADD_INVALID=1
 real(real64),parameter,public::B111_NADD_AMENDMENT_MIN_OM=1d-6
 real(real64),parameter,public::B111_NADD_RESIDUE_MIN_OM=1d-12
 type,public::b111_soil_n_material_t
   real(real64)::application_kg_m2=0d0
   real(real64)::application_age=0d0
   real(real64)::organic_matter_fraction=0d0
   real(real64)::organic_n_fraction=0d0
   real(real64)::ammonium_n_fraction=0d0
   real(real64)::nitrate_n_fraction=0d0
   real(real64)::volatilization_fraction=0d0
 end type
 type,public::b111_soil_n_split_parameters_t
   real(real64)::nfrac_fom_min=0d0
   real(real64)::nfrac_fom_max=0d0
   real(real64)::nfrac_humus=0d0
   real(real64)::asfa_min=0d0
   real(real64)::asfa_max=0d0
 end type
 public::build_b111_amendment_transfer,build_b111_residue_transfer
contains
 subroutine build_b111_soil_n_addition_transfer(depth_m,material,p,transfer,status,minimum_organic_matter_kg_m2)
  real(real64),intent(in)::depth_m
  real(real64),intent(in),optional::minimum_organic_matter_kg_m2
  type(b111_soil_n_material_t),intent(in)::material
  type(b111_soil_n_split_parameters_t),intent(in)::p
  type(soil_n_transfer_t),intent(out)::transfer
  integer,intent(out)::status
  real(real64)::am_nh4,am_no3,am_om,age,fdpm,fhum,frpm,asfa,fasfa1,fasfa2
  real(real64)::orgnfr,forgn1,forgn2,ff(8),organic_input,gross_n,volat_n,min_om
  transfer=soil_n_transfer_t();allocate(transfer%fom_delta_kg_m3(8));transfer%fom_delta_kg_m3=0d0
  status=B111_NADD_INVALID
  if(.not.all(ieee_is_finite([depth_m,material%application_kg_m2,material%application_age, &
       material%organic_matter_fraction,material%organic_n_fraction,material%ammonium_n_fraction, &
       material%nitrate_n_fraction,material%volatilization_fraction,p%nfrac_fom_min,p%nfrac_fom_max, &
       p%nfrac_humus,p%asfa_min,p%asfa_max])))return
  if(depth_m<=0d0.or.material%application_kg_m2<0d0.or.material%application_age<0d0.or. &
     min(material%organic_matter_fraction,material%organic_n_fraction,material%ammonium_n_fraction, &
         material%nitrate_n_fraction,material%volatilization_fraction)<0d0)return
  if(max(material%organic_matter_fraction,material%organic_n_fraction,material%ammonium_n_fraction, &
         material%nitrate_n_fraction,material%volatilization_fraction)>1d0)return
  if(p%nfrac_fom_min<0d0.or.p%nfrac_fom_max<=p%nfrac_fom_min.or.p%nfrac_humus<=0d0.or. &
     p%asfa_max<=p%asfa_min)return
  ! Bound all public arithmetic before exp/products/division (original valid path unchanged).
  if(depth_m<1d-3.or.depth_m>100d0.or.material%application_kg_m2>50d0)return
  if(material%application_age>100d0)return
  if(p%nfrac_fom_max>1d0.or.p%nfrac_humus>1d0.or.p%asfa_min<0d0.or.p%asfa_max>1d0)return
  if(p%nfrac_fom_max-p%nfrac_fom_min<1d-6.or.p%nfrac_humus<1d-6.or.p%asfa_max-p%asfa_min<1d-6)return
  min_om=B111_NADD_RESIDUE_MIN_OM
  if(present(minimum_organic_matter_kg_m2))min_om=minimum_organic_matter_kg_m2
  if(.not.ieee_is_finite(min_om).or.min_om<0d0)return
  am_nh4=material%ammonium_n_fraction*(1d0-material%volatilization_fraction)*material%application_kg_m2
  am_no3=material%nitrate_n_fraction*material%application_kg_m2
  volat_n=material%ammonium_n_fraction*material%volatilization_fraction*material%application_kg_m2
  am_om=material%organic_matter_fraction*material%application_kg_m2
  ! Literal routines omit subthreshold organic N. Such declared additions cannot
  ! enter the mass-conserving SWAP5 domain; keep both historical thresholds.
  if(am_om>0d0.and.am_om<min_om)return
  if(am_om>=min_om)then
    if(material%application_age<.67d0)return
    age=material%application_age
    fdpm=exp(-.59d0*(age-.67d0))
    fhum=min(1d0,max(0d0,.137d0*(age-2.5d0)))
    fhum=min(fhum,(material%organic_n_fraction-p%nfrac_fom_min)/p%nfrac_humus)
    if(fhum<0d0)return
    if(fhum>=1d0)return
    frpm=min(1d0,max(0d0,1d0-fdpm-fhum))
    asfa=.25d0/(1d0+exp(-2.7d0*(age-2d0)))+.03d0
    fasfa1=(p%asfa_max-asfa)/(p%asfa_max-p%asfa_min)
    fasfa2=1d0-fasfa1
    orgnfr=(material%organic_n_fraction-fhum*p%nfrac_humus)/(1d0-fhum)
    forgn1=(orgnfr-p%nfrac_fom_min)/(p%nfrac_fom_max-p%nfrac_fom_min)
    forgn2=1d0-forgn1
    if(min(fasfa1,fasfa2,forgn1,forgn2)<-1d-12)return
    ff=[fdpm*fasfa1*forgn1,fdpm*fasfa1*forgn2,fdpm*fasfa2*forgn1,fdpm*fasfa2*forgn2, &
        frpm*fasfa1*forgn1,frpm*fasfa1*forgn2,frpm*fasfa2*forgn1,frpm*fasfa2*forgn2]
    if(any(ff<0d0))return
    if(abs(sum(ff)+fhum-1d0)>1d-12)return
    transfer%fom_delta_kg_m3=ff*am_om/depth_m
    transfer%humus_delta_kg_m3=fhum*am_om/depth_m
  end if
  transfer%ammonium_n_delta_kg_m2=am_nh4
  transfer%nitrate_n_delta_kg_m2=am_no3
  organic_input=material%organic_n_fraction*am_om
  gross_n=material%ammonium_n_fraction*material%application_kg_m2+am_no3+organic_input
  transfer%external_n_input_kg_m2=gross_n
  transfer%external_n_output_kg_m2=volat_n
  status=B111_NADD_OK
 end subroutine

 subroutine build_b111_amendment_transfer(depth_m,material,p,transfer,status)
  real(real64),intent(in)::depth_m
  type(b111_soil_n_material_t),intent(in)::material
  type(b111_soil_n_split_parameters_t),intent(in)::p
  type(soil_n_transfer_t),intent(out)::transfer
  integer,intent(out)::status
  call build_b111_soil_n_addition_transfer(depth_m,material,p,transfer,status,B111_NADD_AMENDMENT_MIN_OM)
 end subroutine

 subroutine build_b111_residue_transfer(depth_m,material,p,transfer,status)
  real(real64),intent(in)::depth_m
  type(b111_soil_n_material_t),intent(in)::material
  type(b111_soil_n_split_parameters_t),intent(in)::p
  type(soil_n_transfer_t),intent(out)::transfer
  integer,intent(out)::status
  type(b111_soil_n_material_t)::residue
  real(real64)::correction,am_om
  logical::projected
  residue=material
  residue%volatilization_fraction=0d0
  call build_b111_soil_n_addition_transfer(depth_m,residue,p,transfer,status,B111_NADD_RESIDUE_MIN_OM)
  if(status==B111_NADD_OK)return
  projected=.false.
  ! Death-N / death-DM can round one spacing below an exact source class
  ! boundary. Keep organic transfers nonnegative and compensate with existing
  ! mineral N, instead of inventing N or admitting negative organic material.
  if(all(ieee_is_finite([material%organic_n_fraction,p%nfrac_fom_min])))then
   if(material%organic_n_fraction>=0d0.and.material%organic_n_fraction<p%nfrac_fom_min)then
    if(p%nfrac_fom_min-material%organic_n_fraction<=8d0*spacing(p%nfrac_fom_min))then
     residue%organic_n_fraction=p%nfrac_fom_min;projected=.true.
    end if
   end if
  end if
  if(.not.projected)return
  call build_b111_soil_n_addition_transfer(depth_m,residue,p,transfer,status,B111_NADD_RESIDUE_MIN_OM)
  if(status/=B111_NADD_OK)return
  am_om=material%application_kg_m2*material%organic_matter_fraction
  correction=(material%organic_n_fraction-residue%organic_n_fraction)*am_om
  transfer%ammonium_n_delta_kg_m2=transfer%ammonium_n_delta_kg_m2+correction
  ! Preserve the declared input, independently of the projected partition.
  transfer%external_n_input_kg_m2=material%ammonium_n_fraction*material%application_kg_m2+ &
    material%nitrate_n_fraction*material%application_kg_m2+material%organic_n_fraction*am_om
 end subroutine
end module
