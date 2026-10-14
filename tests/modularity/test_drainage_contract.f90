program test_drainage_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_drainage_hooghoudt_equivalent_depth
  implicit none
  type(hooghoudt_equivalent_depth_geometry_t) :: g, saved
  type(hooghoudt_equivalent_depth_prepared_t) :: p, again
  type(hooghoudt_equivalent_depth_diagnostics_t) :: d
  integer :: n,i,ios
  read(*,*,iostat=ios) n
  if(ios/=0.or.n<0) error stop 'invalid case count'
  do i=1,n
    read(*,*,iostat=ios) g%drain_spacing,g%drain_bottom_level,g%impermeable_base_level,g%wetted_perimeter
    if(ios/=0) error stop 'invalid geometry row'
    saved=g
    call prepare_hooghoudt_equivalent_depth(g,p,d)
    if(g%drain_spacing/=saved%drain_spacing.or.g%drain_bottom_level/=saved%drain_bottom_level.or. &
       g%impermeable_base_level/=saved%impermeable_base_level.or.g%wetted_perimeter/=saved%wetted_perimeter) &
       error stop 'geometry mutated'
    if(d%status==EQDEPTH_OK) then
      if(.not.p%is_valid.or..not.d%prepared) error stop 'validity mismatch'
      if(p%equivalent_depth<0.0_real64.or.p%equivalent_depth>p%depth_below_drain) error stop 'depth bounds'
      call prepare_hooghoudt_equivalent_depth(hooghoudt_equivalent_depth_geometry_t(),again,d)
      if(d%status/=EQDEPTH_INVALID_PARAMETERS.or.again%is_valid) error stop 'invalid geometry accepted'
      call prepare_hooghoudt_equivalent_depth(g,again,d)
      if(again%equivalent_depth/=p%equivalent_depth.or.again%branch/=p%branch) error stop 'A/B/A drift'
    else
      if(p%is_valid.or.d%prepared) error stop 'invalid geometry published'
    end if
    write(*,'(i0,1x,i0,1x,es25.17e3)') d%status,p%branch,p%equivalent_depth
  end do
end program
