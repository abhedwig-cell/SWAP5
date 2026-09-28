program test_ppa_wu05a3_mpvolume_surface_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_mpvolume_surface
  implicit none
  real(real64) :: dz(3),subsidy(3),dynamic(3),static(3),diam(3),areas(3)
  real(real64) :: ad,as,at,asurface,capacity,expected
  integer(int32) :: status
  dz=10.0_real64; subsidy=[0.0_real64,0.5_real64,0.0_real64]
  dynamic=[0.1_real64,1.9_real64,0.1_real64]; static=1.0_real64; diam=1.0_real64

  call ppa_wu05a3_mpvolume_surface(3_int32,2_int32,2_int32,1_int32,dz,subsidy, &
      dynamic,static,diam,[0.25_real64,0.75_real64],ad,as,at,areas,asurface,capacity,status)
  call require(status==PPA_WU05A3_MPVOLUME_SURFACE_OK,1)
  call require(abs(ad-0.2_real64)<1.0e-12_real64 .and. abs(as-0.1_real64)<1.0e-12_real64,2)
  call require(abs(at-0.3_real64)<1.0e-12_real64 .and. abs(asurface)<1.0e-12_real64,3)
  call require(maxval(abs(areas(1:2)-[0.075_real64,0.225_real64]))<1.0e-12_real64,4)
  call require(abs(capacity-1.0e3_real64)<1.0e-12_real64,5)

  subsidy(2)=0.0_real64
  call ppa_wu05a3_mpvolume_surface(3_int32,2_int32,1_int32,2_int32,dz,subsidy, &
      [0.1_real64,10.0_real64,0.0_real64],static,diam,[0.25_real64,0.75_real64], &
      ad,as,at,areas,asurface,capacity,status)
  call require(status==PPA_WU05A3_MPVOLUME_SURFACE_OK,6)
  call require(abs(ad-1.0_real64)<1.0e-12_real64 .and. abs(as-0.1_real64)<1.0e-12_real64,7)
  call require(abs(at-0.6_real64)<1.0e-12_real64 .and. abs(asurface-0.6_real64)<1.0e-12_real64,8)
  call require(abs(sum(areas(1:2))-0.6_real64)<1.0e-12_real64,9)

  dynamic=0.0_real64; static=0.0_real64; dynamic(1)=1.0e-5_real64; diam=2.0_real64
  call ppa_wu05a3_mpvolume_surface(3_int32,1_int32,1_int32,1_int32,dz,subsidy, &
      dynamic,static,diam,[1.0_real64],ad,as,at,areas,asurface,capacity,status)
  call require(status==PPA_WU05A3_MPVOLUME_SURFACE_OK,10)
  expected=1.0_real64-(1.0_real64-1.0e-3_real64/2.0_real64)**2
  call require(abs(at)<1.0e-12_real64 .and. abs(asurface)<1.0e-12_real64,11)
  call require(abs(capacity-1.0e-14_real64)<1.0e-25_real64 .and. expected>0.0_real64,12)

  subsidy(2)=dz(2)
  call ppa_wu05a3_mpvolume_surface(3_int32,1_int32,2_int32,1_int32,dz,subsidy, &
      dynamic,static,diam,[1.0_real64],ad,as,at,areas,asurface,capacity,status)
  call require(status==PPA_WU05A3_MPVOLUME_SURFACE_INVALID,13)
  subsidy=0; areas=7
  call ppa_wu05a3_mpvolume_surface(3_int32,2_int32,1_int32,1_int32,dz,subsidy, &
      dynamic,static,diam,[0.5_real64,0.5_real64],ad,as,at,areas(1:1),asurface,capacity,status)
  call require(status==PPA_WU05A3_MPVOLUME_SURFACE_INVALID,14)
  call require(abs(areas(1))+abs(ad)+abs(as)+abs(at)+abs(asurface)+abs(capacity)<tiny(1.0_real64),15)
  call require(all(abs(areas(2:3)-7)<tiny(1.0_real64)),16)
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_SHORT_OUTPUT=PASS'

  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_CRACK_NODE_OVERRIDE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_STATIC_AND_DYNAMIC_AREA=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_MIN_WIDTH_CUTOFF=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_AREA_CLAMP_AND_DOMAIN_PARTITION=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_CAPACITY_LIMITS=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_SURFACE_INVALID_GEOMETRY_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MPVOLUME_SURFACE_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05a3_mpvolume_surface_source_oracle
