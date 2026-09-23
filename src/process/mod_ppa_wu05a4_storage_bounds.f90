! B1.11 MACRORATE standard-domain groundwater/drainage inventory bounds.
module mod_ppa_wu05a4_storage_bounds
  use, intrinsic::iso_fortran_env,only:real64
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_ppa_wu05a3_volundr,only:ppa_wu05a3_volume_under_level,PPA_WU05A3_OK
  implicit none
  private
  public::domain_storage_bounds
contains
  pure subroutine domain_storage_bounds(bottom_level,bottom_cell,dz,pore_volume,total_volume,storage, &
      groundwater_level,drainage_level,main_domain,groundwater_volume,minimum_storage,ok)
    real(real64),intent(in)::bottom_level,dz(:),pore_volume(:),total_volume,storage
    real(real64),intent(in)::groundwater_level,drainage_level
    integer,intent(in)::bottom_cell
    logical,intent(in)::main_domain
    real(real64),intent(out)::groundwater_volume,minimum_storage
    logical,intent(out)::ok
    real(real64)::ground,drain,minimum
    integer::status
    ok=.false.; groundwater_volume=0; minimum_storage=0
    if(.not.all(ieee_is_finite([bottom_level,total_volume,storage,groundwater_level,drainage_level]))) return
    if(total_volume<0.or.storage<0) return
    ! Validate geometry even when both physical branches are inactive.
    if(size(dz)<1.or.size(dz)/=size(pore_volume)) return
    if(bottom_cell<1.or.bottom_cell>size(dz)) return
    if(.not.all(ieee_is_finite(dz)).or..not.all(ieee_is_finite(pore_volume))) return
    if(any(dz<=0).or.any(pore_volume<0)) return
    ground=0
    if(bottom_level<groundwater_level.and.groundwater_level<900.0_real64) then
      call ppa_wu05a3_volume_under_level(groundwater_level,bottom_level,bottom_cell,dz,pore_volume,ground,status)
      if(status/=PPA_WU05A3_OK) return
      ground=min(ground,total_volume)
    end if
    minimum=min(ground,storage)
    if(main_domain) then
      drain=0
      if(bottom_level<drainage_level) then
        call ppa_wu05a3_volume_under_level(drainage_level,bottom_level,bottom_cell,dz,pore_volume,drain,status)
        if(status/=PPA_WU05A3_OK) return
      end if
      if(drain>1.e-6_real64.and.drain<minimum) minimum=drain
    end if
    groundwater_volume=ground; minimum_storage=minimum; ok=.true.
  end subroutine
end module
