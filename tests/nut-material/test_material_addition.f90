program test_material_addition
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_n_pool_state
 use mod_b111_soil_n_addition
 implicit none
 type(soil_n_inventory_parameters_t)::owner
 type(soil_n_pool_state_t)::s,c
 type(soil_n_transfer_t)::x
 type(soil_n_receipt_t)::r
 type(b111_soil_n_material_t)::m,bad
 type(b111_soil_n_split_parameters_t)::p
 real(real64)::want(12),actual(12),nan
 integer::i,kind,status
 owner%depth_m=.3d0;owner%nfrac_fom=[.06d0,.002d0,.06d0,.002d0,.06d0,.002d0,.06d0,.002d0]
 owner%nfrac_biomass=.058d0;owner%nfrac_humus=.58d0/14d0
 p%nfrac_fom_min=.002d0;p%nfrac_fom_max=.06d0;p%nfrac_humus=.58d0/14d0;p%asfa_min=.04d0;p%asfa_max=.28d0
 call initialize_soil_n_pool_state(owner,spread(1d0,1,8),5d0,40d0,.02d0,.03d0,s,status)
 do kind=1,2
  do i=1,6
   m=b111_soil_n_material_t();m%application_kg_m2=.01d0*real(i,real64);m%application_age=.67d0+.5d0*i
   m%organic_matter_fraction=.5d0;m%organic_n_fraction=.025d0;m%ammonium_n_fraction=.02d0
   m%nitrate_n_fraction=.01d0;m%volatilization_fraction=.1d0*i
   if(i==5)then;m%organic_matter_fraction=0d0;m%application_age=0d0;end if
   if(i==6)m%application_kg_m2=merge(2d-6,2d-12,kind==1)
   if(kind==1)then
    call build_b111_amendment_transfer(.3d0,m,p,x,status)
   else
    call build_b111_residue_transfer(.3d0,m,p,x,status)
   end if
   call require(status==0,'source-valid material build')
   call apply_soil_n_transfer(owner,s,x,c,r);call require(r%status==0,'whole N material')
   call literal_material(kind,m,p,want)
   actual=[x%fom_delta_kg_m3,x%humus_delta_kg_m3,x%ammonium_n_delta_kg_m2,x%nitrate_n_delta_kg_m2, &
     x%external_n_output_kg_m2]
   call require(maxval(abs(actual-want))<=1d-12,'full literal material endpoint')
   call require(abs(sum(x%fom_delta_kg_m3)*.3d0+x%humus_delta_kg_m3*.3d0- &
     m%application_kg_m2*m%organic_matter_fraction)<=1d-12,'organic matter budget')
  end do
 end do
 nan=ieee_value(0d0,ieee_quiet_nan)
 m%application_kg_m2=1d0;m%organic_matter_fraction=.5d0;m%application_age=1d0
 do i=1,8
  bad=m
  select case(i)
  case(1);bad%application_kg_m2=nan
  case(2);bad%application_age=nan
  case(3);bad%ammonium_n_fraction=-1d0
  case(4);bad%application_kg_m2=1d100
  case(5);bad%application_age=.1d0
  case(6);bad%organic_n_fraction=0d0
  case(7);bad%application_kg_m2=1d-7
  case(8);bad%volatilization_fraction=1.1d0
  end select
  call build_b111_amendment_transfer(.3d0,bad,p,x,status)
  call require(status/=0,'material invalid rejected')
 end do
 print '(A)','MATERIAL_LITERAL_12_CASES_WHOLE_N_OM_THRESHOLDS_8_INVALID=PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,'FAIL ',label;error stop 1;end if
 end subroutine
 include 'material_oracle.inc'
end program
