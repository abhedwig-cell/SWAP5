! Four-organ delayed harvest material, source mapping from management_soil(task5).
! No incorporation/publication authority and no modification of the owner.
module mod_wofost81_harvest_materials
 use mod_wofost81_crop_owner_state,only:wofost81_crop_owner_state_t, &
   wofost81_harvest_record_t,WOFOST81_CROP_OWNER_OK,WOFOST81_HARVEST_INVALID
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t
 implicit none
 private
 public::build_wofost81_harvest_materials
contains
 subroutine build_wofost81_harvest_materials(owner,materials,status)
  type(wofost81_crop_owner_state_t),intent(in)::owner
  type(b111_soil_n_material_t),intent(out)::materials(4)
  integer,intent(out)::status
  type(wofost81_harvest_record_t)::h
  integer::i
  logical::available
  materials=b111_soil_n_material_t();status=WOFOST81_HARVEST_INVALID
  if(.not.owner%harvested())return
  if(owner%validate()/=WOFOST81_CROP_OWNER_OK)return
  call owner%harvest_snapshot(h,available)
  if(.not.available)return
  do i=1,4
   materials(i)%application_kg_m2=h%pending_dm(i)*1d-4
   materials(i)%application_age=h%policy%application_age(i)
   materials(i)%organic_matter_fraction=1d0
   if(h%pending_dm(i)>0d0)materials(i)%organic_n_fraction=h%pending_n(i)/h%pending_dm(i)
  end do
  status=WOFOST81_CROP_OWNER_OK
 end subroutine
end module
