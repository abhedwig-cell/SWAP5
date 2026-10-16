program test_senescence_mapping
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_crop_senescence_residue
 use mod_b111_soil_n_addition
 use mod_soil_n_pool_state
 implicit none
 type(crop_senescence_policy_t)::policy
 type(crop_residue_pending_t)::pending
 type(b111_soil_n_material_t)::m(3)
 type(b111_soil_n_split_parameters_t)::split
 type(soil_n_transfer_t)::x
 real(real64)::dm(3),n(3),literal(12)
 integer::i,j,code
 policy%application_age=[1.57d0,.99d0,1.57d0]
 split=b111_soil_n_split_parameters_t(.002d0,.06d0,.58d0/14d0,.04d0,.28d0)
 dm=[2d0,4d0,3d0];n=dm*[.02d0,.03d0,.015d0]
 call create_crop_residue_pending(1d0,dm,n,policy,pending,code);call require(code==0,'actual organ producer mapping')
 call build_pending_residue_materials(pending,m,code);call require(code==0,'root leaf stem source conversion')
 do i=1,3
  call require(m(i)%application_kg_m2==dm(i)*1d-4.and.m(i)%organic_n_fraction==n(i)/dm(i),'literal management units ratio')
  call literal_material(2,m(i),split,literal)
  call build_b111_residue_transfer(.3d0,m(i),split,x,code)
  call require(code==0.and.maxval(abs(x%fom_delta_kg_m3-literal(1:8)))<=1d-12.and. &
    abs(x%humus_delta_kg_m3-literal(9))<=1d-12,'unchanged literal residue routine')
  call require(abs(x%external_n_input_kg_m2-n(i)*1d-4)<=1d-12.and.x%external_n_output_kg_m2==0d0,'soil boundary N')
 end do
 do j=1,8
  call create_crop_residue_pending(1d0,dm,n,policy,pending,code)
  select case(j)
  case(1);pending%dry_matter_kg_ha(1)=1d-8
  case(2);pending%dry_matter_kg_ha(1)=0d0
  case(3);pending%nitrogen_kg_ha(1)=-1d0
  case(4);pending%nitrogen_kg_ha(1)=3d0
  case(5);pending%clock=ieee_value(0d0,ieee_quiet_nan)
  case(6);pending%application_age(2)=.66d0
  case(7);pending%dry_matter_kg_ha(3)=huge(1d0)
  case(8);pending%application_age(3)=ieee_value(0d0,ieee_quiet_nan)
  end select
  call build_pending_residue_materials(pending,m,code);call require(code/=0,'invalid producer fail closed')
 end do
 call create_crop_residue_pending(0d0,dm*0d0,n*0d0,policy,pending,code)
 call require(code==0.and.pending%nitrogen_kg_m2()==0d0,'zero death')
 print '(A)','SENESCENCE_SOURCE_MAPPING_LITERAL_3_ORGANS_8_INVALID_ZERO=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
 include 'material_oracle.inc'
end program
