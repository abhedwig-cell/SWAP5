program test_b111_crop_residue_return
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_n_pool_state, only: soil_n_transfer_t
  use mod_b111_crop_residue_return
  implicit none
  type(b111_crop_residue_return_forcing_t)::f
  type(b111_crop_residue_return_receipt_t)::r
  type(soil_n_transfer_t)::t

  f%depth_m=0.5_real64
  f%leaf_fraction_to_soil=0.5_real64
  f%root_apparent_age=1.27_real64
  f%leaf_apparent_age=0.99_real64
  f%root_dm_loss_kg_ha=100.0_real64
  f%leaf_dm_loss_kg_ha=200.0_real64
  f%root_n_loss_kg_ha=1.0_real64
  f%leaf_n_loss_kg_ha=2.0_real64
  f%split%nfrac_fom_min=0.005_real64
  f%split%nfrac_fom_max=0.03_real64
  f%split%nfrac_humus=0.05_real64
  f%split%asfa_min=0.03_real64
  f%split%asfa_max=0.28_real64

  call build_b111_crop_residue_return(f,t,r)
  call check(r%status==B111_CRES_OK,'residue return build')
  call near(r%root_n_return_kg_m2,1.0e-4_real64,'root N return')
  call near(r%leaf_n_return_kg_m2,1.0e-4_real64,'leaf N return')
  call near(r%internal_n_return_kg_m2,2.0e-4_real64,'internal N return')
  call near(t%external_n_input_kg_m2,r%internal_n_return_kg_m2,'soil subowner input identity')
  call near(t%external_n_output_kg_m2,0.0_real64,'no residue volatilization')
  call check(sum(t%fom_delta_kg_m3)+t%humus_delta_kg_m3>0.0_real64,'residue enters OM stores')
  print '(A)','B111_CROP_RESIDUE_RETURN_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
