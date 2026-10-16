! Physical dead crop material awaits the next historical SoilManagement(5).
module mod_crop_senescence_residue
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 private
 integer,parameter,public::SENESCENCE_OK=0,SENESCENCE_INVALID=1
 type,public::crop_senescence_policy_t
  real(real64)::application_age(3)=0d0 ! root,leaf,stem
 end type
 type,public::crop_residue_pending_t
  real(real64)::clock=0d0
  real(real64)::dry_matter_kg_ha(3)=0d0,nitrogen_kg_ha(3)=0d0,application_age(3)=0d0
 contains
  procedure::valid=>pending_valid
  procedure::nitrogen_kg_m2=>pending_n
 end type
 public::build_pending_residue_materials,create_crop_residue_pending
contains
 pure logical function pending_valid(self)result(ok)
  class(crop_residue_pending_t),intent(in)::self
  ok=.false.
  if(.not.all(ieee_is_finite([self%clock,self%dry_matter_kg_ha,self%nitrogen_kg_ha,self%application_age])))return
  if(abs(self%clock)>1d9)return
  if(any(self%dry_matter_kg_ha<0d0).or.any(self%dry_matter_kg_ha>5d5))return
  if(any(self%nitrogen_kg_ha<0d0).or.any(self%nitrogen_kg_ha>self%dry_matter_kg_ha))return
  if(any(self%application_age<.67d0).or.any(self%application_age>100d0))return
  if(any(self%dry_matter_kg_ha>0d0.and.self%dry_matter_kg_ha<=1d-8))return
  ok=.true.
 end function
 pure real(real64)function pending_n(self)result(n)
  class(crop_residue_pending_t),intent(in)::self
  n=sum(self%nitrogen_kg_ha)*1d-4
 end function
 subroutine create_crop_residue_pending(clock,death_dm,death_n,policy,pending,status)
  real(real64),intent(in)::clock,death_dm(3),death_n(3)
  type(crop_senescence_policy_t),intent(in)::policy
  type(crop_residue_pending_t),intent(out)::pending
  integer,intent(out)::status
  pending%clock=clock;pending%dry_matter_kg_ha=death_dm;pending%nitrogen_kg_ha=death_n
  pending%application_age=policy%application_age;status=SENESCENCE_INVALID
  if(pending%valid())status=SENESCENCE_OK
 end subroutine
 subroutine build_pending_residue_materials(pending,materials,status)
  type(crop_residue_pending_t),intent(in)::pending
  type(b111_soil_n_material_t),intent(out)::materials(3)
  integer,intent(out)::status
  integer::i
  materials=b111_soil_n_material_t();status=SENESCENCE_INVALID
  if(.not.pending%valid())return
  do i=1,3
   materials(i)%application_kg_m2=pending%dry_matter_kg_ha(i)*1d-4
   materials(i)%application_age=pending%application_age(i)
   materials(i)%organic_matter_fraction=1d0
   if(pending%dry_matter_kg_ha(i)>0d0)materials(i)%organic_n_fraction= &
     pending%nitrogen_kg_ha(i)/pending%dry_matter_kg_ha(i)
  end do
  status=SENESCENCE_OK
 end subroutine
end module
