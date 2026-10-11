module mod_ppa_wu05b12_analytic_fixture
  use iso_fortran_env,only:real64
  use mod_fmr_drainage_response_binding,only:fmr_drainage_response_level_parameters_t
  use mod_drainage_hooghoudt_equivalent_depth,only:hooghoudt_equivalent_depth_geometry_t, &
       hooghoudt_equivalent_depth_diagnostics_t,prepare_hooghoudt_equivalent_depth
  use mod_drainage_ernst_ipos45_preparation,only:ernst_ipos4_geometry_t,ernst_ipos5_geometry_t, &
       ernst_preparation_diagnostics_t,prepare_ernst_ipos4,prepare_ernst_ipos5
  implicit none
  private
  public::setup_b12_analytic_level,b12_analytic_rate_oracle
contains
  subroutine setup_b12_analytic_level(level,family,depth,status)
    type(fmr_drainage_response_level_parameters_t),intent(out)::level
    integer,intent(in)::family
    real(real64),intent(in)::depth
    integer,intent(out)::status
    type(hooghoudt_equivalent_depth_geometry_t)::geometry
    type(hooghoudt_equivalent_depth_diagnostics_t)::diagnostic
    type(ernst_ipos4_geometry_t)::g4
    type(ernst_ipos5_geometry_t)::g5
    type(ernst_preparation_diagnostics_t)::ed
    status=0;level%variant=family+2
    select case(family)
    case(1)
      level%hooghoudt_ipos1%drain_spacing=10._real64
      level%hooghoudt_ipos1%shape_factor=1._real64
      level%hooghoudt_ipos1%drain_bottom_level=depth
      level%hooghoudt_ipos1%horizontal_conductivity_top=.25_real64
      level%hooghoudt_ipos1%entry_resistance=1._real64
    case(2,3)
      geometry%drain_spacing=10._real64;geometry%drain_bottom_level=depth
      geometry%impermeable_base_level=depth-5._real64;geometry%wetted_perimeter=.2_real64
      call prepare_hooghoudt_equivalent_depth(geometry,level%hooghoudt_prepared,diagnostic)
      status=diagnostic%status
      level%hooghoudt_ipos2%shape_factor=1._real64
      level%hooghoudt_ipos2%horizontal_conductivity_top=.25_real64
      level%hooghoudt_ipos2%entry_resistance=1._real64
      level%hooghoudt_ipos3%shape_factor=1._real64
      level%hooghoudt_ipos3%horizontal_conductivity_top=.25_real64
      level%hooghoudt_ipos3%horizontal_conductivity_bottom=.125_real64
      level%hooghoudt_ipos3%entry_resistance=1._real64
    case(4)
      g4%drain_spacing=10._real64;g4%shape_factor=1._real64
      g4%drain_bottom_level=depth;g4%impermeable_base_level=depth-5._real64
      g4%interface_level=depth+.5_real64
      g4%horizontal_conductivity_bottom=.125_real64
      g4%vertical_conductivity_top=.25_real64;g4%vertical_conductivity_bottom=.125_real64
      g4%wetted_perimeter=.2_real64;g4%entry_resistance=1._real64
      call prepare_ernst_ipos4(g4,level%ernst_ipos4_prepared,ed);status=ed%status
    case(5)
      g5%drain_spacing=10._real64;g5%shape_factor=1._real64
      g5%drain_bottom_level=depth;g5%impermeable_base_level=depth-5._real64
      g5%interface_level=depth-1.5_real64
      g5%horizontal_conductivity_top=.25_real64;g5%horizontal_conductivity_bottom=.125_real64
      g5%vertical_conductivity_top=.25_real64
      g5%geometry_factor=2._real64;g5%wetted_perimeter=.2_real64;g5%entry_resistance=1._real64
      call prepare_ernst_ipos5(g5,level%ernst_ipos5_prepared,ed);status=ed%status
    case default
      status=999
    end select
  end subroutine

  pure real(real64) function b12_analytic_rate_oracle(family,gwl,depth) result(rate)
    integer,intent(in)::family
    real(real64),intent(in)::gwl,depth
    real(real64),parameter::pi=acos(-1._real64)
    real(real64)::d,x,fx,e,equivalent,rhor,rrad,rvert,denominator
    integer::j
    rate=0._real64;d=gwl-depth
    if(d<1.e-10_real64)return
    select case(family)
    case(1)
      rhor=100._real64/(4._real64*.25_real64*abs(d))
      rate=d/(rhor+1._real64)
    case(2,3)
      x=2._real64*pi*2.5_real64/10._real64;fx=0._real64
      do j=1,5,2
        e=exp(-2._real64*real(j,real64)*x)
        fx=fx+4._real64*e/(real(j,real64)*(1._real64-e))
      end do
      equivalent=min(2.5_real64,pi*10._real64/(8._real64*(log(50._real64)+fx)))
      denominator=8._real64*.25_real64*equivalent+4._real64*.25_real64*abs(d)
      if(family==3)denominator=8._real64*.125_real64*equivalent+4._real64*.25_real64*abs(d)
      rate=d/(100._real64/denominator+1._real64)
    case(4)
      rhor=100._real64/(8._real64*.125_real64*2.5_real64)
      rrad=10._real64/(pi*sqrt(.125_real64*.125_real64))*log(2.5_real64/.2_real64)
      rvert=d/.125_real64
      if(gwl>depth+.5_real64)rvert=(gwl-(depth+.5_real64))/.25_real64+.5_real64/.125_real64
      rate=d/(rhor+rrad+1._real64+rvert)
    case(5)
      rhor=100._real64/(8._real64*.25_real64*1.5_real64+8._real64*.125_real64*1._real64)
      rrad=10._real64/(pi*sqrt(.25_real64*.25_real64))*log(2._real64*1.5_real64/.2_real64)
      rvert=d/.25_real64
      rate=d/(rhor+rrad+1._real64+rvert)
    end select
  end function
end module
