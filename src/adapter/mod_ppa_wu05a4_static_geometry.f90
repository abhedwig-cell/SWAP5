! Candidate geometry for one static domain starting at the soil surface.
! No cracks, subsidence, covering layer, state commit or production binding.
module mod_ppa_wu05a4_static_geometry
  use, intrinsic::iso_fortran_env,only:real64,int32
  use mod_ppa_wu05a4_matrix_fraction
  use mod_ppa_wu05a3_mpvolume_surface
  implicit none
  private
  type,public::static_macro_geometry
    logical::valid=.false.
    real(real64),allocatable::matrix_fraction(:)
    real(real64)::surface_fraction=0,capacity=0
  end type
  public::prepare_static_macro_geometry
contains
  subroutine prepare_static_macro_geometry(static_volume,dz,diameter,geometry,ok)
    real(real64),intent(in)::static_volume(:),dz(:),diameter(:)
    type(static_macro_geometry),intent(out)::geometry
    logical,intent(out)::ok
    type(static_macro_geometry)::trial
    real(real64),allocatable::zeros(:)
    real(real64)::dynamic_area,static_area,total_area,domain_area(1)
    integer(int32)::status,n
    ok=.false.
    if(size(diameter)/=size(dz))return
    call static_matrix_fraction(static_volume,dz,trial%matrix_fraction,ok)
    if(.not.ok)return
    ok=.false.
    n=int(size(dz),int32)
    allocate(zeros(n)); zeros=0
    call ppa_wu05a3_mpvolume_surface(n,1_int32,1_int32,1_int32,dz,zeros,zeros,static_volume, &
        diameter,[1.0_real64],dynamic_area,static_area,total_area,domain_area, &
        trial%surface_fraction,trial%capacity,status)
    if(status/=PPA_WU05A3_MPVOLUME_SURFACE_OK)return
    trial%valid=.true.; geometry=trial; ok=.true.
  end subroutine
end module
