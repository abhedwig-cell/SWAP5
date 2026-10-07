program test_swap431_dramet3
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_dramet3_response, only: drainage_dramet3_parameters_t
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, FMR_DRAIN_VARIANT_DRAMET3, FMR_DRAIN_BIND_OK
  implicit none
  type(fmr_drainage_response_level_parameters_t) :: p(5)
  type(fmr_drainage_response_level_control_t) :: c(5)
  type(fmr_drainage_response_diagnostics_t) :: d
  type(process_hydraulic_view_t) :: hv
  real(real64) :: q(5,4)
  integer :: i

  hv%active_nodes=4
  allocate(hv%pressure_head(4),hv%water_content(4))
  hv%pressure_head=-10.0_real64;hv%water_content=0.30_real64
  hv%ponding_depth=0.0_real64;hv%groundwater_level=-20.0_real64
  do i=1,5
    p(i)%variant=FMR_DRAIN_VARIANT_DRAMET3
    call base(p(i)%dramet3)
  end do

  p(1)%dramet3%drainage_resistance_day=100.0_real64
  call evaluate_fmr_drainage_response_bottom_lumped(p(1:1),c(1:1),hv,q(1:1,:),d,1.0_real64)
  call require(d%status==FMR_DRAIN_BIND_OK,'positive status')
  call near(q(1,4),0.30_real64,'positive DRARES')
  call require(all(q(1,1:3)==0.0_real64),'positive bottom lump')
  call near(d%level(1)%signed_soil_to_drain_rate,0.30_real64,'positive diagnostic')

  hv%groundwater_level=-80.0_real64
  p(2)%dramet3%infiltration_resistance_day=50.0_real64
  call evaluate_fmr_drainage_response_bottom_lumped(p(2:2),c(2:2),hv,q(2:2,:),d,1.0_real64)
  call near(q(2,4),-0.60_real64,'negative INFRES')

  hv%groundwater_level=-140.0_real64
  p(3)%dramet3%infiltration_resistance_day=50.0_real64
  p(3)%dramet3%drain_type=2;p(3)%dramet3%limit_infiltration_head=.true.
  call evaluate_fmr_drainage_response_bottom_lumped(p(3:3),c(3:3),hv,q(3:3,:),d,1.0_real64)
  call near(q(3,4),-1.0_real64,'SWLIMINF cap')

  hv%groundwater_level=-20.0_real64
  p(4)%dramet3%allocation_mode=2
  call evaluate_fmr_drainage_response_bottom_lumped(p(4:4),c(4:4),hv,q(4:4,:),d,1.0_real64)
  call near(q(4,4),0.0_real64,'SWALLO2 suppress drainage')

  hv%groundwater_level=-80.0_real64
  p(5)%dramet3%allocation_mode=3
  call evaluate_fmr_drainage_response_bottom_lumped(p(5:5),c(5:5),hv,q(5:5,:),d,1.0_real64)
  call near(q(5,4),0.0_real64,'SWALLO3 suppress infiltration')

  call base(p(1)%dramet3)
  p(1)%dramet3%surface_water_head_cm=[-150.0_real64,-150.0_real64]
  hv%groundwater_level=-80.0_real64
  call evaluate_fmr_drainage_response_bottom_lumped(p(1:1),c(1:1),hv,q(1:1,:),d,1.0_real64)
  call near(q(1,4),0.20_real64,'ZBOTDR clamp')

  call base(p(1)%dramet3)
  hv%groundwater_level=-20.0_real64
  call evaluate_fmr_drainage_response_bottom_lumped(p(1:1),c(1:1),hv,q(1:1,:),d,0.5_real64)
  call near(q(1,4),0.35_real64,'OWLTAB interpolation')

  write(*,'(A)') 'SW431_DRAMET3_SOURCE_SEMANTICS=PASS'
  write(*,'(A)') 'SW431_DRAIN_ALLOCATION=PASS'
  write(*,'(A)') 'SW431_DRAIN_INF_LIMIT=PASS'
contains
  subroutine base(x)
    type(drainage_dramet3_parameters_t),intent(out)::x
    x%zbotdr_cm=-100.0_real64
    x%drainage_resistance_day=100.0_real64
    x%infiltration_resistance_day=50.0_real64
    x%allocation_mode=1;x%drain_type=1;x%limit_infiltration_head=.false.
    x%canonical_origin_time=0.0_real64;x%legacy_t1900_origin=1000.0_real64
    allocate(x%surface_water_time_t1900(2),x%surface_water_head_cm(2))
    x%surface_water_time_t1900=[1000.0_real64,1001.0_real64]
    x%surface_water_head_cm=[-60.0_real64,-50.0_real64]
  end subroutine base
  subroutine near(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    call require(abs(a-b)<=1.0e-12_real64,label)
  end subroutine near
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(A,1X,A)')'SW431_DRAMET3_FAIL',trim(label);error stop 1
    end if
  end subroutine require
end program test_swap431_dramet3
