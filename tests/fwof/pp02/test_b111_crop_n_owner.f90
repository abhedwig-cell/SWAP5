program test_b111_crop_n_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_crop_n_owner
  implicit none
  type(b111_crop_n_state_t)::s,c
  type(b111_crop_n_forcing_t)::f
  type(b111_crop_n_receipt_t)::r
  integer::status
  real(real64)::n0

  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,1.0_real64,s,status)
  call check(status==B111_CROPN_OK,'init')
  n0=s%anlv_kg_ha+s%anst_kg_ha+s%anrt_kg_ha+s%anso_kg_ha

  f%delt_day=1.0_real64
  f%dvs=0.5_real64;f%dvsnlt=1.0_real64;f%dvsnt=1.2_real64;f%reltr=1.0_real64
  f%nfixf=0.25_real64;f%tcnt_day=2.0_real64;f%fntrt=0.5_real64
  f%wlv_kg_ha=100.0_real64;f%wst_kg_ha=100.0_real64;f%wrt_kg_ha=100.0_real64;f%wso_kg_ha=100.0_real64
  f%nmaxlv=0.2_real64;f%nmaxst=0.1_real64;f%nmaxrt=0.08_real64;f%nmaxso=0.5_real64
  f%rnflv=0.01_real64;f%rnfst=0.01_real64;f%rnfrt=0.01_real64
  f%soil_supply_kg_m2_day=0.0005_real64

  call apply_b111_crop_n_day(s,f,c,r)
  call check(r%status==B111_CROPN_OK,'active day')
  call near(r%vegetative_demand_kg_ha,19.0_real64,'vegetative demand excludes storage')
  call near(r%soil_demand_kg_ha,14.25_real64,'soil demand split')
  call near(r%fixation_kg_ha,4.75_real64,'fixation split')
  call near(r%soil_uptake_kg_ha,5.0_real64,'soil supply limited')
  call near(c%nuptake_total_kg_ha,5.0_real64,'soil uptake cumulative')
  call near(c%nfix_total_kg_ha,4.75_real64,'fixation cumulative')
  call near(c%balance_residual(),0.0_real64,'crop N balance')

  ! Storage demand is deliberately not part of fixation/soil demand.
  f%nmaxso=5.0_real64
  call apply_b111_crop_n_day(s,f,c,r)
  call near(r%vegetative_demand_kg_ha,19.0_real64,'storage demand excluded')
  call near(r%fixation_kg_ha,4.75_real64,'storage excluded from fixation')

  ! Exact B1.11 cutoff: no soil uptake or fixation at DVSNLT or low RELTR.
  f%dvs=1.0_real64
  call apply_b111_crop_n_day(s,f,c,r)
  call check(r%status==B111_CROPN_OK,'DVS cutoff day')
  call near(r%soil_demand_kg_ha,0.0_real64,'DVS soil cutoff')
  call near(r%fixation_kg_ha,0.0_real64,'DVS fixation cutoff')
  f%dvs=0.5_real64;f%reltr=0.01_real64
  call apply_b111_crop_n_day(s,f,c,r)
  call near(r%soil_demand_kg_ha,0.0_real64,'RELTR soil cutoff')
  call near(r%fixation_kg_ha,0.0_real64,'RELTR fixation cutoff')

  call check(abs((c%anlv_kg_ha+c%anst_kg_ha+c%anrt_kg_ha+c%anso_kg_ha)-n0)<1000.0_real64, &
       'finite crop state')
  print '(A)','B111_CROP_N_OWNER_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
