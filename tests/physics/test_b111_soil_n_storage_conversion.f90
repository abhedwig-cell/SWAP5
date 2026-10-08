program test_b111_soil_n_storage_conversion
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b111_soil_n_storage_conversion
  implicit none
  type(b111_soil_n_concentration_state_t)::c
  real(real64)::nh4,no3
  integer::status

  call b111_soil_n_concentrations_from_mass(0.5_real64,0.3_real64,1.2_real64,0.4_real64, &
       0.39_real64,0.15_real64,c)
  call check(c%status==B111_NSTORE_OK,'mass to concentration')
  call near(c%cnh4_kg_m3,1.0_real64,'NH4 concentration')
  call near(c%cno3_kg_m3,1.0_real64,'NO3 concentration')

  call b111_soil_n_mass_from_concentrations(0.5_real64,0.3_real64,1.2_real64,0.4_real64, &
       c%cnh4_kg_m3,c%cno3_kg_m3,nh4,no3,status)
  call check(status==B111_NSTORE_OK,'concentration to mass')
  call near(nh4,0.39_real64,'NH4 roundtrip')
  call near(no3,0.15_real64,'NO3 roundtrip')

  print '(A)','B111_SOIL_N_STORAGE_CONVERSION_PASS'
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
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
