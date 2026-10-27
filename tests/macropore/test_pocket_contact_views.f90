program test_pocket_contact_views
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64)::head(4),z(4),distance(4),deep,shallow
  logical::ok
  z=[-0.5_real64,-1.5_real64,-2.5_real64,-3.5_real64]
  distance=1.0_real64;distance(1)=0.5_real64
  head=[0.1_real64,-0.2_real64,-0.1_real64,0.5_real64]
  call require(minimum_pocket_node(head,2,3)==2,'minimum is not deepest crossing')
  call evaluate_b111_pocket_contact_limits(z,distance,head,1e-7_real64,2,3,2,deep,shallow,ok,.true.)
  call require(ok.and.deep==z(2).and.shallow==1e-7_real64,'original one-sided limits at active node')
  call require(head(2)==-0.2_real64.and.head(3)==-0.1_real64,'limit view never mutates physical profile')
  call evaluate_b111_pocket_contact_limits(z,distance,head,0.0_real64,2,3,2,deep,shallow,ok,.true.)
  call require(ok.and.shallow==z(1)+head(1),'zero film retains original surface convention')
  head=[-0.1_real64,0.1_real64,-0.2_real64,0.5_real64]
  call evaluate_b111_pocket_contact_limits(z,distance,head,1e-7_real64,3,3,3,deep,shallow,ok,.true.)
  call require(ok.and.shallow<z(1).and.shallow>z(2),'remaining shallow pocket owns other limit')
  head=[0.1_real64,0.0_real64,0.0_real64,0.5_real64]
  call require(minimum_pocket_node(head,2,3)==2,'ties choose first node deterministically')
  call require(minimum_pocket_node(head,0,3)==0,'invalid extent rejects')
  call evaluate_b111_pocket_contact_limits(z,distance,head,1e-7_real64,2,3,4,deep,shallow,ok,.true.)
  call require(.not.ok.and.deep==0.0_real64.and.shallow==0.0_real64,'invalid active node atomic')
  head(2)=ieee_value(0.0_real64,ieee_quiet_nan)
  call require(minimum_pocket_node(head,2,3)==0,'nonfinite minimum rejects')
  call evaluate_b111_pocket_contact_limits(z,distance,head,1e-7_real64,2,3,2,deep,shallow,ok,.true.)
  call require(.not.ok.and.deep==0.0_real64.and.shallow==0.0_real64,'nonfinite limit view atomic')
  print *,'PASS real minimum-pocket and original one-sided projection views'
contains
  subroutine require(valid,message)
    logical,intent(in)::valid
    character(*),intent(in)::message
    if(.not.valid)then
      print *,message
      error stop 1
    end if
  end subroutine
end program
