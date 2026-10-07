program test_b111_crop_n_harvest_continuation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_crop_n_owner
  use mod_b111_crop_n_harvest_continuation
  implicit none
  type(b111_crop_n_state_t)::s,c
  type(b111_crop_n_harvest_forcing_t)::f
  type(b111_crop_n_harvest_receipt_t)::r
  integer::status

  call initialize_b111_crop_n_state(10.0_real64,5.0_real64,4.0_real64,3.0_real64,s,status)
  call check(status==B111_CROPN_OK,'init')
  ! Retained dead pools from earlier days.
  s%nloss_leaf_kg_ha=2.0_real64
  s%nloss_stem_kg_ha=1.0_real64
  ! Make the accounting origin consistent with retained dead material.
  s%initial_n_kg_ha=s%initial_n_kg_ha+3.0_real64
  call near(s%balance_residual(),0.0_real64,'preharvest crop balance')

  f%active=.true.
  f%root_dm_kg_ha=100.0_real64
  f%leaf_living_dm_kg_ha=100.0_real64
  f%stem_living_dm_kg_ha=80.0_real64
  f%storage_living_dm_kg_ha=60.0_real64
  f%leaf_dead_dm_kg_ha=20.0_real64
  f%stem_dead_dm_kg_ha=10.0_real64
  f%storage_dead_dm_kg_ha=0.0_real64
  f%leaf_fraction_to_soil=0.5_real64
  f%stem_fraction_to_soil=0.25_real64
  f%storage_fraction_to_soil=0.2_real64

  call apply_b111_crop_n_harvest(s,f,c,r)
  call check(r%status==B111_HARVEST_N_OK,'harvest')
  call near(r%root_residue_n_kg_ha,4.0_real64,'all living root N to residue')
  call near(r%leaf_residue_n_kg_ha,6.0_real64,'leaf living plus retained dead N fraction')
  call near(r%stem_residue_n_kg_ha,1.5_real64,'stem living plus retained dead N fraction')
  call near(r%storage_residue_n_kg_ha,0.6_real64,'storage living fraction')
  call near(c%nreturned_to_soil_total_kg_ha,12.1_real64,'cumulative returned N')
  call near(c%nloss_leaf_kg_ha,1.0_real64,'remaining dead leaf N')
  call near(c%nloss_stem_kg_ha,0.75_real64,'remaining dead stem N')
  call near(c%balance_residual(),0.0_real64,'postharvest crop balance')
  call near(r%external_harvest_n_kg_ha,0.0_real64,'bounded harvest route has no implicit offsite N')

  print '(A)','B111_CROP_N_HARVEST_CONTINUATION_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1.0e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
