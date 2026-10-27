program test_positive_film_projection
  use, intrinsic :: iso_fortran_env,only:real64
  use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_b111_profile_groundwater_projection
  implicit none
  real(real64)::z(2),distance(2),head(2),pond
  type(b111_profile_groundwater_projection_t)::literal,corrected,explicit_literal
  integer::i
  z=[-0.5_real64,-1.5_real64];distance=[0.5_real64,1.0_real64]
  head=[0.05_real64,1.05_real64]
  do i=1,20
    pond=10.0_real64**(-i)
    call evaluate_b111_profile_groundwater_projection(z,distance,head,pond,literal)
    call evaluate_b111_profile_groundwater_projection(z,distance,head,pond,explicit_literal,.false.)
    call evaluate_b111_profile_groundwater_projection(z,distance,head,pond,corrected,.true.)
    call require(literal%valid.and.corrected%valid,'positive film valid')
    call require(corrected%level_cm==pond,'connected positive film owns free-water level')
    call require(corrected%crossing_lower_node==0,'no invented interior crossing')
    call require(literal%level_cm==explicit_literal%level_cm,'literal default unchanged')
    if(pond<1e-8_real64)then
      call require(literal%level_cm==z(1)+head(1),'historical floor preserved by default')
    else
      call require(literal%level_cm==pond,'historical thick film unchanged')
    end if
  end do
  call evaluate_b111_profile_groundwater_projection(z,distance,head,0.0_real64,literal)
  call evaluate_b111_profile_groundwater_projection(z,distance,head,0.0_real64,corrected,.true.)
  call require(literal%level_cm==corrected%level_cm,'zero film keeps original dry convention')
  head(1)=0.0_real64
  call evaluate_b111_profile_groundwater_projection(z,distance,head,1e-9_real64,corrected,.true.)
  call require(corrected%level_cm==1e-9_real64,'saturated zero-pressure node with positive surface film')
  head(1)=-0.05_real64
  call evaluate_b111_profile_groundwater_projection(z,distance,head,1e-9_real64,literal)
  call evaluate_b111_profile_groundwater_projection(z,distance,head,1e-9_real64,corrected,.true.)
  call require(literal%level_cm==corrected%level_cm,'interior dry pocket unchanged')
  call evaluate_b111_profile_groundwater_projection(z,distance,head,-1e-9_real64,corrected,.true.)
  call require(.not.corrected%valid.and..not.corrected%level_present,'negative film rejects atomically')
  call evaluate_b111_profile_groundwater_projection(z,distance,head, &
    ieee_value(0.0_real64,ieee_quiet_nan),corrected,.true.)
  call require(.not.corrected%valid.and..not.corrected%level_present,'nonfinite film rejects atomically')
  print *,'PASS positive-film convention, literal/zero/interior controls, invalid atomic controls'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print *,message
      error stop 1
    end if
  end subroutine
end program
